// * 2 Pool - USDC - ETH
// All values tested agaisnt Curve pool
#[test_only]
module clamm::volatile_2pool_quote_tests {
  use sui::clock;
  use sui::coin::burn_for_testing as burn;

  use sui::test_utils::assert_eq;
  use sui::test_scenario::{Self as test, next_tx, ctx}; 

  use clamm::eth::ETH;
  use clamm::usdc::USDC;
  use clamm::lp_coin::LP_COIN;
  use clamm::curves::Volatile;
  use clamm::interest_clamm_volatile;
  use clamm::interest_pool::InterestPool;
  use clamm::init_interest_amm_volatile::setup_2pool;
  use clamm::amm_test_utils ::{people, scenario, mint, add_decimals};

  #[test]
  fun test_quote_swap() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;
    
    setup_2pool(test, 4500, 3);
    let c = clock::create_for_testing(ctx(test));

    next_tx(test, alice);
    {
      let pool = test::take_shared<InterestPool<Volatile>>(test);

      let expected_amount = interest_clamm_volatile::quote_swap<USDC, ETH, LP_COIN>(
        &pool,
        &c,
        add_decimals(1499, 6)
      );

      let coin_out = interest_clamm_volatile::swap<USDC, ETH, LP_COIN>(
        &mut pool,
        &c,
        mint(1499, 6, ctx(test)),
        expected_amount,
        ctx(test)  
      );

      assert_eq(burn(coin_out), expected_amount);

      let expected_amount = interest_clamm_volatile::quote_swap<ETH, USDC, LP_COIN>(
        &pool,
        &c,
        add_decimals(25, 8)
      );

      let coin_out = interest_clamm_volatile::swap<ETH, USDC, LP_COIN>(
        &mut pool,
        &c,
        mint(25, 8, ctx(test)),
        expected_amount,
        ctx(test)  
      );

      assert_eq(burn(coin_out), expected_amount);      

      test::return_shared(pool);
    };

    clock::destroy_for_testing(c);
    test::end(scenario);    
  }  
}