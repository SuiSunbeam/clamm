module amm::stable_tuple_core {
  use std::vector;
  use std::type_name::{TypeName, get};
  
  use sui::clock::Clock;
  use sui::coin::{Self, Coin};
  use sui::object::{Self, UID};
  use sui::dynamic_field as df;
  use sui::tx_context::TxContext;
  use sui::vec_set::{Self, VecSet};
  use sui::dynamic_object_field as dof;
  use sui::balance::{Self, Supply, Balance};

  use amm::errors;
  use amm::asserts;
  use amm::curves::StableTuple;
  use amm::utils::calculate_fee_amount;
  use amm::metadata::{
    Metadata,
    get_decimals_scalar, 
  };
  use amm::stable_tuple_math::{
    get_amp,
    invariant_,
    calculate_out_balance_from_in_balance,
    calculate_balance_from_reduced_lp_supply,
  };
  use amm::interest_pool::{
    Self as core,
    Pool,
    Nothing,
    new_pool,
    new_pool_hooks,
  };

  const INITIAL_FEE_PERCENT: u256 = 250000000000000; // 0.025%
  const MAX_FEE_PERCENT: u256 = 20000000000000000; // 2%
  const PRECISION: u256 = 1_000_000_000_000_000_000; // 1e18

  struct StateKey has drop, copy, store {}

  struct CoinStatekey has drop, copy, store { type: TypeName }

  struct AdminCoinBalanceKey has drop, copy, store { type: TypeName }

  struct CoinState<phantom CoinType> has store {
    decimals: u256,
    index: u64,
    balance: Balance<CoinType>
  }

  struct State<phantom LpCoin> has key, store {
    id: UID,
    lp_coin_supply: Supply<LpCoin>,
    balances: vector<u256>,
    initial_a: u256,
    future_a: u256,
    initial_a_time: u256,
    future_a_time: u256,
    fee_percent: u256,
    n_coins: u64
  }

  public(friend) fun new_3_pool<Label, CoinA, CoinB, CoinC, LpCoin>(
    c: &Clock,
    initial_a: u256,
    coin_a: Coin<CoinA>,
    coin_b: Coin<CoinB>,
    coin_c: Coin<CoinC>,
    metadata: &Metadata,     
    lp_coin_supply: Supply<LpCoin>,
    ctx: &mut TxContext
  ): (Pool<StableTuple, Label, Nothing>, Coin<LpCoin>) {
    assert!(coin::value(&coin_a) != 0 && coin::value(&coin_b) != 0 && coin::value(&coin_c) != 0, errors::no_zero_liquidity_amounts());

    let pool = new_pool<StableTuple,  Label>(make_coins(vector[get<CoinA>(), get<CoinB>(), get<CoinC>()]), ctx);
    // * IMPORTANT Make sure the n_coins argument is correct
    add_state<LpCoin>(core::borrow_mut_uid(&mut pool), initial_a, lp_coin_supply, 3, ctx);

    let state = load_mut_state<LpCoin>(core::borrow_mut_uid(&mut pool));

    // * IMPORTANT Make sure the indexes and CoinTypes match the make_coins vector and they are in the correct order
    register_coin<CoinA>(&mut state.id, metadata, 0);
    register_coin<CoinB>(&mut state.id, metadata, 1);
    register_coin<CoinC>(&mut state.id, metadata, 2);

    let lp_coin = add_liquidity_3_pool(&mut pool, c, coin_a, coin_b, coin_c, 0, ctx);

    (pool, lp_coin)
  }

  public(friend) fun new_4_pool<Label, CoinA, CoinB, CoinC, CoinD, LpCoin>(
    c: &Clock,
    initial_a: u256,
    coin_a: Coin<CoinA>,
    coin_b: Coin<CoinB>,
    coin_c: Coin<CoinC>,
    coin_d: Coin<CoinD>,
    metadata: &Metadata,     
    lp_coin_supply: Supply<LpCoin>,
    ctx: &mut TxContext
  ): (Pool<StableTuple, Label, Nothing>, Coin<LpCoin>) {
    assert!(
      coin::value(&coin_a) != 0 
      && coin::value(&coin_b) != 0 
      && coin::value(&coin_c) != 0
      && coin::value(&coin_d) != 0,
      errors::no_zero_liquidity_amounts()
    );

    let pool = new_pool<StableTuple,  Label>(
      make_coins(vector[get<CoinA>(), get<CoinB>(), get<CoinC>(), get<CoinD>()]), 
      ctx
    );

    // * IMPORTANT Make sure the n_coins argument is correct
    add_state<LpCoin>(core::borrow_mut_uid(&mut pool), initial_a, lp_coin_supply, 4, ctx);

    let state = load_mut_state<LpCoin>(core::borrow_mut_uid(&mut pool));

    // * IMPORTANT Make sure the indexes and CoinTypes match the make_coins vector and they are in the correct order
    register_coin<CoinA>(&mut state.id, metadata, 0);
    register_coin<CoinB>(&mut state.id, metadata, 1);
    register_coin<CoinC>(&mut state.id, metadata, 2);
    register_coin<CoinD>(&mut state.id, metadata, 3);

    let lp_coin = add_liquidity_4_pool(&mut pool, c, coin_a, coin_b, coin_c, coin_d, 0, ctx);

    (pool, lp_coin)
  }

// amp: u256, token_in_index: u256, token_out_index: u256, token_amount_out: u256, balances: &vector<u256>

  public(friend) fun swap<Label, HookWitness, CoinIn, LpCoin, CoinOut>(
    pool: &mut Pool<StableTuple, Label, HookWitness>,
    c: &Clock,
    coin_in: Coin<CoinIn>,
    min_amount: u64,
    ctx: &mut TxContext
  ): Coin<CoinOut> {
    asserts::assert_coin_has_value(&coin_in);
    let state = load_mut_state<LpCoin>(core::borrow_mut_uid(pool));

    let coin_in_state = load_coin_state<CoinIn>(&mut state.id);
    let coin_out_state = load_coin_state<CoinOut>(&mut state.id);

    let coin_in_value = coin::value(&coin_in);

    let admin_coin_in = coin::split(&mut coin_in, calculate_fee_amount(coin_in_value, state.fee_percent), ctx);

    // Has no admin fee
    let normalized_value = (coin::value(&coin_in) as u256) * PRECISION / coin_in_state.decimals;

    let amp = get_amp(state.initial_a, state.initial_a_time, state.future_a, state.future_a_time, c);

    let prev_k = invariant_(amp, &state.balances);

    let new_out_balance = calculate_out_balance_from_in_balance(
      amp,
      (coin_in_state.index as u256),
      (coin_out_state.index as u256),
      *vector::borrow(&state.balances, coin_in_state.index) + normalized_value,
      &state.balances
    );

    let amount_out = *vector::borrow(&state.balances, coin_out_state.index) - new_out_balance;
    let normalized_amount_out = ((amount_out * coin_out_state.decimals / PRECISION) as u64);

    let admin_amount_out = calculate_fee_amount(normalized_amount_out, state.fee_percent);

    let normalized_amount_out = normalized_amount_out - admin_amount_out;

    assert!(normalized_amount_out >= min_amount, errors::slippage());

    // Update balances
    let coin_in_balance = vector::borrow_mut(&mut state.balances, coin_in_state.index);
    *coin_in_balance = *coin_in_balance + normalized_value;

    let coin_out_balance = vector::borrow_mut(&mut state.balances, coin_out_state.index);
    // We need to remove the admin fee from balance
    *coin_out_balance = *coin_out_balance - ((((normalized_amount_out + admin_amount_out) as u256) * PRECISION / coin_out_state.decimals) as u256); 

    // * Invariant must hold after all balances updates
    assert!(invariant_(amp, &state.balances) >= prev_k, errors::invalid_invariant());

    /*
    * The admin fees are not part of the liquidity (do not accrue swap fees) and not counted on the invariant calculation
    * Fees are applied both on coin in and coin out to keep the balance in the pool
    * 1 - Deposit coin_in (without admin fees) to balance
    * 2 - Deposit coin_admin_in (admin fees on coin)
    * 3 - Deposit coin_admin_out (admin fees on coin out)
    * 4 - Take coin_out for user
    */
    balance::join(&mut coin_in_state.balance, coin::into_balance(coin_in));
    balance::join(load_admin_balance<CoinIn>(&mut state.id), coin::into_balance(admin_coin_in));

    let coin_out_balance = &mut coin_out_state.balance;

    balance::join(load_admin_balance<CoinOut>(&mut state.id), balance::split(coin_out_balance, admin_amount_out));

    coin::take(coin_out_balance, normalized_amount_out, ctx)
  }


  public(friend) fun add_liquidity_3_pool<Label, HookWitness, CoinA, CoinB, CoinC, LpCoin>(
    pool: &mut Pool<StableTuple, Label, HookWitness>,
    c: &Clock,
    coin_a: Coin<CoinA>,
    coin_b: Coin<CoinB>,
    coin_c: Coin<CoinC>,
    lp_coin_min_amount: u64,
    ctx: &mut TxContext     
  ): Coin<LpCoin> {
    let state = load_mut_state<LpCoin>(core::borrow_mut_uid(pool));
    
    let amp = get_amp(state.initial_a, state.initial_a_time, state.future_a, state.future_a_time, c);    
    let supply_value = (balance::supply_value(&state.lp_coin_supply) as u256);

    let prev_k = invariant_(amp, &state.balances);

    deposit_coin<CoinA, LpCoin>(state, coin_a);
    deposit_coin<CoinB, LpCoin>(state, coin_b);
    deposit_coin<CoinC, LpCoin>(state, coin_c);

    let mint_amount = calculate_mint_amount(state, amp, prev_k, lp_coin_min_amount);

    coin::from_balance(
      balance::increase_supply(
        &mut state.lp_coin_supply, 
        mint_amount
      ), 
      ctx
    )
  }

  public(friend) fun add_liquidity_4_pool<Label, HookWitness, CoinA, CoinB, CoinC, CoinD, LpCoin>(
    pool: &mut Pool<StableTuple, Label, HookWitness>,
    c: &Clock,
    coin_a: Coin<CoinA>,
    coin_b: Coin<CoinB>,
    coin_c: Coin<CoinC>,
    coin_d: Coin<CoinD>,
    lp_coin_min_amount: u64,
    ctx: &mut TxContext     
  ): Coin<LpCoin> {
    let state = load_mut_state<LpCoin>(core::borrow_mut_uid(pool));
    
    let amp = get_amp(state.initial_a, state.initial_a_time, state.future_a, state.future_a_time, c);    
    let prev_k = invariant_(amp, &state.balances);

    deposit_coin<CoinA, LpCoin>(state, coin_a);
    deposit_coin<CoinB, LpCoin>(state, coin_b);
    deposit_coin<CoinC, LpCoin>(state, coin_c);
    deposit_coin<CoinD, LpCoin>(state, coin_d);

    let mint_amount = calculate_mint_amount(state, amp, prev_k, lp_coin_min_amount);

    coin::from_balance(
      balance::increase_supply(
        &mut state.lp_coin_supply, 
        mint_amount
      ), 
      ctx
    )
  }

  public(friend) fun remove_one_coin_liquidity<Label, HookWitness, CoinType, LpCoin>(
    pool: &mut Pool<StableTuple, Label, HookWitness>, 
    c: &Clock,
    lp_coin: Coin<LpCoin>,
    min_amount: u64,
    ctx: &mut TxContext    
  ): Coin<CoinType> {
    asserts::assert_coin_has_value(&lp_coin);
    let lp_coin_value = coin::value(&lp_coin);

    let state = load_mut_state<LpCoin>(core::borrow_mut_uid(pool));
    
    let coin_state = load_coin_state<CoinType>(&mut state.id);

    balance::decrease_supply(&mut state.lp_coin_supply, coin::into_balance(lp_coin));

    let current_coin_balance = vector::borrow_mut(&mut state.balances, coin_state.index);
    let initial_coin_balance = *current_coin_balance;
    
    *current_coin_balance = calculate_balance_from_reduced_lp_supply(
      get_amp(state.initial_a, state.initial_a_time, state.future_a, state.future_a_time, c),
      (coin_state.index as u256),
      &state.balances,
      (coin::value(&lp_coin) as u256),
      (balance::supply_value(&state.lp_coin_supply) as u256),
    );

    let amount_to_take = (((*current_coin_balance - initial_coin_balance) * coin_state.decimals / PRECISION) as u64);

    assert!(amount_to_take >= min_amount, errors::slippage());

    coin::take(&mut coin_state.balance, amount_to_take, ctx)
  }

  public(friend) fun remove_balanced_liquidity_3_pool<Label, HookWitness, CoinA, CoinB, CoinC, LpCoin>(
    pool: &mut Pool<StableTuple, Label, HookWitness>, 
    lp_coin: Coin<LpCoin>,
    min_amounts: vector<u64>,
    ctx: &mut TxContext
  ): (Coin<CoinA>, Coin<CoinB>, Coin<CoinC>) {
    asserts::assert_coin_has_value(&lp_coin);

    let lp_coin_value = coin::value(&lp_coin);
    let state = load_mut_state<LpCoin>(core::borrow_mut_uid(pool));

    let (coin_a, coin_b, coin_c) = (
      take_coin<CoinA, LpCoin>(state, lp_coin_value, min_amounts, ctx),
      take_coin<CoinB, LpCoin>(state, lp_coin_value, min_amounts, ctx),
      take_coin<CoinC, LpCoin>(state, lp_coin_value, min_amounts, ctx),
    );

    balance::decrease_supply(&mut state.lp_coin_supply, coin::into_balance(lp_coin));

    (coin_a, coin_b, coin_c)
  }

  public(friend) fun remove_balanced_liquidity_4_pool<Label, HookWitness, CoinA, CoinB, CoinC, CoinD, LpCoin>(
    pool: &mut Pool<StableTuple, Label, HookWitness>, 
    lp_coin: Coin<LpCoin>,
    min_amounts: vector<u64>,
    ctx: &mut TxContext
  ): (Coin<CoinA>, Coin<CoinB>, Coin<CoinC>, Coin<CoinD>) {
    asserts::assert_coin_has_value(&lp_coin);

    let lp_coin_value = coin::value(&lp_coin);
    let state = load_mut_state<LpCoin>(core::borrow_mut_uid(pool));

    let (coin_a, coin_b, coin_c, coin_d) = (
      take_coin<CoinA, LpCoin>(state, lp_coin_value, min_amounts, ctx),
      take_coin<CoinB, LpCoin>(state, lp_coin_value, min_amounts, ctx),
      take_coin<CoinC, LpCoin>(state, lp_coin_value, min_amounts, ctx),
      take_coin<CoinD, LpCoin>(state, lp_coin_value, min_amounts, ctx),
    );

    balance::decrease_supply(&mut state.lp_coin_supply, coin::into_balance(lp_coin));

    (coin_a, coin_b, coin_c, coin_d)
  }

  fun calculate_mint_amount<LpCoin>(state: &State<LpCoin>, amp: u256, prev_k: u256, lp_coin_min_amount: u64): u64 {
    let new_k = invariant_(amp, &state.balances);

    assert!(new_k > prev_k, errors::invalid_invariant());

    let supply_value = (balance::supply_value(&state.lp_coin_supply) as u256);

    let mint_amount = if (supply_value == 0) { (new_k as u64) } else { ((supply_value * (new_k - prev_k) / prev_k) as u64) };

    assert!(mint_amount >= lp_coin_min_amount, errors::slippage());

    mint_amount
  }

  fun deposit_coin<CoinType, LpCoin>(state: &mut State<LpCoin>, coin_in: Coin<CoinType>) {
    let coin_value = (coin::value(&coin_in) as u256);

    if (coin_value == 0) {
      coin::destroy_zero(coin_in);
      return
    };

    let coin_state = load_coin_state<CoinType>(&mut state.id);

    // Update the balance for the coin
    let current_balance = vector::borrow_mut(&mut state.balances, coin_state.index);
    *current_balance = *current_balance + (coin_value * PRECISION / coin_state.decimals);

    balance::join(&mut coin_state.balance, coin::into_balance(coin_in));
  }

  fun take_coin<CoinType, LpCoin>(
    state: &mut State<LpCoin>, 
    lp_coin_value: u64, 
    min_amounts: vector<u64>, 
    ctx: &mut TxContext
  ): Coin<CoinType> {
    let coin_state = load_coin_state<CoinType>(&mut state.id);    

    let current_balance = vector::borrow_mut(&mut state.balances, coin_state.index);

    let denormalized_value = *current_balance * coin_state.decimals / PRECISION;

    let balance_to_remove = denormalized_value * (lp_coin_value as u256) / (balance::supply_value(&state.lp_coin_supply) as u256);

    assert!((balance_to_remove as u64) >= *vector::borrow(&min_amounts, coin_state.index), errors::slippage());

    *current_balance = *current_balance - (balance_to_remove * PRECISION / coin_state.decimals);

    coin::take(&mut coin_state.balance, (balance_to_remove as u64), ctx)
  }

  fun register_coin<CoinType>(id: &mut UID, metadata: &Metadata, index: u64) {
    let coin_name = get<CoinType>();

    df::add(id, AdminCoinBalanceKey { type: coin_name }, balance::zero<CoinType>());
    df::add(id, CoinStatekey { type: coin_name }, CoinState {
      decimals: (get_decimals_scalar<CoinType>(metadata) as u256),
      balance: balance::zero<CoinType>(),
      index
    });
  }

  fun add_state<LpCoin>(
    id: &mut UID,
    initial_a: u256,
    lp_coin_supply: Supply<LpCoin>,
    n_coins: u64,
    ctx: &mut TxContext
  ) {
    asserts::assert_supply_has_zero_value(&lp_coin_supply);
    dof::add(id, StateKey {}, 
      State {
        id: object::new(ctx),
        balances: vector[],
        initial_a,
        future_a: initial_a,
        initial_a_time: 0,
        future_a_time: 0,
        fee_percent: INITIAL_FEE_PERCENT,
        lp_coin_supply,
        n_coins
      }
    );
  }

  // @dev It makes sure that all coins are unique
  fun make_coins(data: vector<TypeName>): VecSet<TypeName> {
    let len = vector::length(&data);
    let set = vec_set::empty();
    let i = 0;

    while (len > i) {
      vec_set::insert(&mut set, *vector::borrow(&data, i));
      i = i + 1;
    };

    set
  }

  fun load_coin_state<CoinType>(id: &mut UID): &mut CoinState<CoinType> {
    df::borrow_mut(id, CoinStatekey { type: get<CoinType>() })
  } 

  fun load_admin_balance<CoinType>(id: &mut UID): &mut Balance<CoinType> {
    df::borrow_mut(id, AdminCoinBalanceKey  { type: get<CoinType>() })
  } 


  fun load_state<LpCoin>(id: &UID): &State<LpCoin> {
    dof::borrow(id, StateKey {})
  }

  fun load_mut_state<LpCoin>(id: &mut UID): &mut State<LpCoin> {
    dof::borrow_mut(id, StateKey {})
  }
}