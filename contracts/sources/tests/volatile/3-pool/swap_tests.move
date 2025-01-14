// * 3 Pool - USDC - BTC - ETH
// All values tested agaisnt Curve pool
#[test_only]
module clamm::volatile_3pool_swap_tests {
  use sui::clock;
  use sui::coin::burn_for_testing as burn;

  use sui::test_utils::assert_eq;
  use sui::test_scenario::{Self as test, next_tx, ctx}; 

  use clamm::interest_clamm_volatile;
  use clamm::btc::BTC;
  use clamm::eth::ETH;
  use clamm::usdc::USDC;
  use clamm::lp_coin::LP_COIN;
  use clamm::curves::Volatile;
  use clamm::interest_pool::InterestPool;
  use clamm::init_interest_amm_volatile::setup_3pool;
  use clamm::amm_test_utils ::{people, scenario, mint};

  const BTC_DECIMALS_SCALAR: u64 = 1000000000;
  const ETH_DECIMALS_SCALAR: u64 = 1000000000;
  const USDC_DECIMALS_SCALAR: u64 = 1000000; 
  const POW_10_18: u256 = 1_000_000_000_000_000_000;

  #[test]
  fun extreme_usdc_swaps() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;
    
    setup_3pool(test, 150000, 3, 100);

    let c = clock::create_for_testing(ctx(test));

    next_tx(test, alice); 
    {
      let pool = test::take_shared<InterestPool<Volatile>>(test);  

      clock::increment_for_testing(&mut c, 14_000);

      let i = 0;

      while (5 > i) {

        clock::increment_for_testing(&mut c, 22_000);

        burn(interest_clamm_volatile::swap<USDC, BTC, LP_COIN>(
          &mut pool,
          &c,
          mint(40_000, 6, ctx(test)),
          0,
          ctx(test)
          )
        );



        i = i + 1;
      };

      assert_eq(
        interest_clamm_volatile::balances<LP_COIN>(&pool),
        vector[350_000 * POW_10_18, 1269800855063115831, 100 * POW_10_18]
      );
      assert_eq(
        interest_clamm_volatile::coin_balance<LP_COIN, USDC>(&pool),
        350_000 * USDC_DECIMALS_SCALAR
      );
     assert_eq(
        interest_clamm_volatile::coin_balance<LP_COIN, BTC>(&pool),
        1269800857
      );
     assert_eq(
        interest_clamm_volatile::coin_balance<LP_COIN, ETH>(&pool),
        100 * ETH_DECIMALS_SCALAR
      );
     assert_eq(
        interest_clamm_volatile::coin_last_price<BTC, LP_COIN>(&pool),
        241613396579540753549299
      );  
     assert_eq(
        interest_clamm_volatile::coin_last_price<ETH, LP_COIN>(&pool),
        1500000000000000000000
      );  
     assert_eq(
        interest_clamm_volatile::coin_price<BTC, LP_COIN>(&pool),
        47500000000000000000000
      );
     assert_eq(
        interest_clamm_volatile::coin_price<ETH, LP_COIN>(&pool),
        1500000000000000000000
      );
     assert_eq(
        interest_clamm_volatile::coin_price_oracle<BTC, LP_COIN>(&pool),
        47507405753129087513320
      ); 
     assert_eq(
        interest_clamm_volatile::coin_price_oracle<ETH, LP_COIN>(&pool),
        1500000000000000000000
      ); 
     assert_eq(
        interest_clamm_volatile::xcp_profit<LP_COIN>(&pool),
        1001184991177003540
      );  
     assert_eq(
        interest_clamm_volatile::xcp_profit_a<LP_COIN>(&pool),
        POW_10_18
      );  
     assert_eq(
        interest_clamm_volatile::virtual_price<LP_COIN>(&pool),
        1001184991177003540
      ); 
     assert_eq(
        interest_clamm_volatile::invariant_<LP_COIN>(&pool),
        443010486250003678766705
      ); 

      test::return_shared(pool);
    };
    
    clock::destroy_for_testing(c);
    test::end(scenario);
  }

  #[test]
  fun extreme_btc_swaps() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;
    
    setup_3pool(test, 150000, 3, 100);

    let c = clock::create_for_testing(ctx(test));

    next_tx(test, alice); 
    {
      let pool = test::take_shared<InterestPool<Volatile>>(test);  

      clock::increment_for_testing(&mut c, 14_000);

      let i = 0;

      while (5 > i) {

        clock::increment_for_testing(&mut c, 22_000);

        burn(interest_clamm_volatile::swap<BTC, ETH, LP_COIN>(
          &mut pool,
          &c,
          mint(5, 8, ctx(test)),
          0,
          ctx(test)
          )
        );

        i = i + 1;
      };

      assert_eq(
        interest_clamm_volatile::balances<LP_COIN>(&pool),
        vector[150_000 * POW_10_18, 5500000000000000000, 54027773845506102414]
      );
      assert_eq(
        interest_clamm_volatile::coin_balance<LP_COIN, USDC>(&pool),
        150_000 * USDC_DECIMALS_SCALAR
      );
     assert_eq(
        interest_clamm_volatile::coin_balance<LP_COIN, BTC>(&pool),
        5500000000
      );
     assert_eq(
        interest_clamm_volatile::coin_balance<LP_COIN, ETH>(&pool),
        54027773847
      );
     assert_eq(
        interest_clamm_volatile::coin_last_price<BTC, LP_COIN>(&pool),
        47500000000000000000000
      );  
     assert_eq(
        interest_clamm_volatile::coin_last_price<ETH, LP_COIN>(&pool),
        4343512371979121649547
      );  
     assert_eq(
        interest_clamm_volatile::coin_price<BTC, LP_COIN>(&pool),
        47500000000000000000000
      );
     assert_eq(
        interest_clamm_volatile::coin_price<ETH, LP_COIN>(&pool),
        1500000000000000000000
      );
     assert_eq(
        interest_clamm_volatile::coin_price_oracle<BTC, LP_COIN>(&pool),
        47500000000000000000000
      ); 
     assert_eq(
        interest_clamm_volatile::coin_price_oracle<ETH, LP_COIN>(&pool),
        1500106236319621921633
      ); 
     assert_eq(
        interest_clamm_volatile::xcp_profit<LP_COIN>(&pool),
        1000751898361443297
      );  
     assert_eq(
        interest_clamm_volatile::xcp_profit_a<LP_COIN>(&pool),
        POW_10_18
      );  
     assert_eq(
        interest_clamm_volatile::virtual_price<LP_COIN>(&pool),
        1000751898361443297
      ); 
     assert_eq(
        interest_clamm_volatile::invariant_<LP_COIN>(&pool),
        442818848680020564855580
      ); 

      test::return_shared(pool);
    };
    
    clock::destroy_for_testing(c);
    test::end(scenario);
  }  

  #[test]
  fun extreme_eth_swaps() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;
    
    setup_3pool(test, 150000, 3, 100);

    let c = clock::create_for_testing(ctx(test));

    next_tx(test, alice); 
    {
      let pool = test::take_shared<InterestPool<Volatile>>(test);  

      clock::increment_for_testing(&mut c, 14_000);

      let i = 0;

      while (5 > i) {

        clock::increment_for_testing(&mut c, 23_000);

        burn(interest_clamm_volatile::swap<ETH, USDC, LP_COIN>(
          &mut pool,
          &c,
          mint(40, 9, ctx(test)),
          0,
          ctx(test)
          )
        );

        i = i + 1;
      };

      assert_eq(
        interest_clamm_volatile::balances<LP_COIN>(&pool),
        vector[49285237353557890973886, 3 * POW_10_18, 300 * POW_10_18]
      );
      assert_eq(
        interest_clamm_volatile::coin_balance<LP_COIN, USDC>(&pool),
        49285237357
      );
     assert_eq(
        interest_clamm_volatile::coin_balance<LP_COIN, BTC>(&pool),
        3 * ETH_DECIMALS_SCALAR
      );
     assert_eq(
        interest_clamm_volatile::coin_balance<LP_COIN, ETH>(&pool),
        300 * BTC_DECIMALS_SCALAR
      );
     assert_eq(
        interest_clamm_volatile::coin_last_price<BTC, LP_COIN>(&pool),
        47500000000000000000000
      );  
     assert_eq(
        interest_clamm_volatile::coin_last_price<ETH, LP_COIN>(&pool),
        191456323292332621417
      );  
     assert_eq(
        interest_clamm_volatile::coin_price<BTC, LP_COIN>(&pool),
        47500000000000000000000
      );
     assert_eq(
        interest_clamm_volatile::coin_price<ETH, LP_COIN>(&pool),
        1500000000000000000000
      );
     assert_eq(
        interest_clamm_volatile::coin_price_oracle<BTC, LP_COIN>(&pool),
        47500000000000000000000
      ); 
     assert_eq(
        interest_clamm_volatile::coin_price_oracle<ETH, LP_COIN>(&pool),
        1499902676449293924913
      ); 
     assert_eq(
        interest_clamm_volatile::xcp_profit<LP_COIN>(&pool),
        1001616388232902130
      );  
     assert_eq(
        interest_clamm_volatile::xcp_profit_a<LP_COIN>(&pool),
        POW_10_18
      );  
     assert_eq(
        interest_clamm_volatile::virtual_price<LP_COIN>(&pool),
        1001616388232902130
      ); 
     assert_eq(
        interest_clamm_volatile::invariant_<LP_COIN>(&pool),
        443201373469832832623384
      ); 

      test::return_shared(pool);
    };
    
    clock::destroy_for_testing(c);
    test::end(scenario);
  }    

  #[test]
  fun do_1000_swaps() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;
    
    setup_3pool(test, 150000, 3, 100);
    let c = clock::create_for_testing(ctx(test));

    next_tx(test, alice);
    {
      let pool = test::take_shared<InterestPool<Volatile>>(test);  

      clock::increment_for_testing(&mut c, 14_000);

      let i = 0;

      while (200 > i) {

        clock::increment_for_testing(&mut c, 1_000);

        burn(interest_clamm_volatile::swap<ETH, USDC, LP_COIN>(
          &mut pool,
          &c,
          mint(75, 9, ctx(test)),
          0,
          ctx(test)
          )
        );

        clock::increment_for_testing(&mut c, 1_000);

        burn(interest_clamm_volatile::swap<BTC, ETH, LP_COIN>(
          &mut pool,
          &c,
          mint(1, 9, ctx(test)),
          0,
          ctx(test)
          )
        );        

        clock::increment_for_testing(&mut c, 1_000);

        burn(interest_clamm_volatile::swap<USDC, BTC, LP_COIN>(
          &mut pool,
          &c,
          mint(100_000, 6, ctx(test)),
          0,
          ctx(test)
          )
        );

        clock::increment_for_testing(&mut c, 22_000);
        i = i + 1;
      };        

      test::return_shared(pool);
    };
    
    next_tx(test, alice);
    {
      let pool = test::take_shared<InterestPool<Volatile>>(test);  

      clock::increment_for_testing(&mut c, 14_000);

      let i = 0;

      while (200 > i) {

        clock::increment_for_testing(&mut c, 1_000);

        burn(interest_clamm_volatile::swap<ETH, USDC, LP_COIN>(
          &mut pool,
          &c,
          mint(75, 9, ctx(test)),
          0,
          ctx(test)
          )
        );

        clock::increment_for_testing(&mut c, 1_000);

        burn(interest_clamm_volatile::swap<BTC, ETH, LP_COIN>(
          &mut pool,
          &c,
          mint(1, 9, ctx(test)),
          0,
          ctx(test)
          )
        );        

        clock::increment_for_testing(&mut c, 1_000);

        burn(interest_clamm_volatile::swap<USDC, BTC, LP_COIN>(
          &mut pool,
          &c,
          mint(100_000, 6, ctx(test)),
          0,
          ctx(test)
          )
        );

        clock::increment_for_testing(&mut c, 22_000);
        i = i + 1;
      };        

      test::return_shared(pool);
    };

    next_tx(test, alice);
    {
      let pool = test::take_shared<InterestPool<Volatile>>(test);  

      clock::increment_for_testing(&mut c, 14_000);

      let i = 0;

      while (200 > i) {

        clock::increment_for_testing(&mut c, 1_000);

        burn(interest_clamm_volatile::swap<ETH, USDC, LP_COIN>(
          &mut pool,
          &c,
          mint(75, 9, ctx(test)),
          0,
          ctx(test)
          )
        );

        clock::increment_for_testing(&mut c, 1_000);

        burn(interest_clamm_volatile::swap<BTC, ETH, LP_COIN>(
          &mut pool,
          &c,
          mint(1, 9, ctx(test)),
          0,
          ctx(test)
          )
        );        

        clock::increment_for_testing(&mut c, 1_000);

        burn(interest_clamm_volatile::swap<USDC, BTC, LP_COIN>(
          &mut pool,
          &c,
          mint(100_000, 6, ctx(test)),
          0,
          ctx(test)
          )
        );

        clock::increment_for_testing(&mut c, 22_000);
        i = i + 1;
      };        

      test::return_shared(pool);
    };

    next_tx(test, alice);
    {
      let pool = test::take_shared<InterestPool<Volatile>>(test);  

      clock::increment_for_testing(&mut c, 14_000);

      let i = 0;

      while (200 > i) {

        clock::increment_for_testing(&mut c, 1_000);

        burn(interest_clamm_volatile::swap<ETH, USDC, LP_COIN>(
          &mut pool,
          &c,
          mint(75, 9, ctx(test)),
          0,
          ctx(test)
          )
        );

        clock::increment_for_testing(&mut c, 1_000);

        burn(interest_clamm_volatile::swap<BTC, ETH, LP_COIN>(
          &mut pool,
          &c,
          mint(1, 9, ctx(test)),
          0,
          ctx(test)
          )
        );        

        clock::increment_for_testing(&mut c, 1_000);

        burn(interest_clamm_volatile::swap<USDC, BTC, LP_COIN>(
          &mut pool,
          &c,
          mint(100_000, 6, ctx(test)),
          0,
          ctx(test)
          )
        );

        clock::increment_for_testing(&mut c, 22_000);
        i = i + 1;
      };        

      test::return_shared(pool);
    };

    next_tx(test, alice);
    {
      let pool = test::take_shared<InterestPool<Volatile>>(test);  

      clock::increment_for_testing(&mut c, 14_000);

      let i = 0;

      while (200 > i) {

        clock::increment_for_testing(&mut c, 1_000);

        burn(interest_clamm_volatile::swap<ETH, USDC, LP_COIN>(
          &mut pool,
          &c,
          mint(75, 9, ctx(test)),
          0,
          ctx(test)
          )
        );

        clock::increment_for_testing(&mut c, 1_000);

        burn(interest_clamm_volatile::swap<BTC, ETH, LP_COIN>(
          &mut pool,
          &c,
          mint(1, 9, ctx(test)),
          0,
          ctx(test)
          )
        );        

        clock::increment_for_testing(&mut c, 1_000);

        burn(interest_clamm_volatile::swap<USDC, BTC, LP_COIN>(
          &mut pool,
          &c,
          mint(100_000, 6, ctx(test)),
          0,
          ctx(test)
          )
        );

        clock::increment_for_testing(&mut c, 22_000);
        i = i + 1;
      };  

      assert_eq(
        interest_clamm_volatile::balances<LP_COIN>(&pool),
        vector[49285237353557890973886, 3 * POW_10_18, 300 * POW_10_18]
      );
      assert_eq(
        interest_clamm_volatile::coin_balance<LP_COIN, USDC>(&pool),
        49285237357
      );
     assert_eq(
        interest_clamm_volatile::coin_balance<LP_COIN, BTC>(&pool),
        3 * ETH_DECIMALS_SCALAR
      );
     assert_eq(
        interest_clamm_volatile::coin_balance<LP_COIN, ETH>(&pool),
        300 * BTC_DECIMALS_SCALAR
      );
     assert_eq(
        interest_clamm_volatile::coin_last_price<BTC, LP_COIN>(&pool),
        47500000000000000000000
      );  
     assert_eq(
        interest_clamm_volatile::coin_last_price<ETH, LP_COIN>(&pool),
        191456323292332621417
      );  
     assert_eq(
        interest_clamm_volatile::coin_price<BTC, LP_COIN>(&pool),
        47500000000000000000000
      );
     assert_eq(
        interest_clamm_volatile::coin_price<ETH, LP_COIN>(&pool),
        1500000000000000000000
      );
     assert_eq(
        interest_clamm_volatile::coin_price_oracle<BTC, LP_COIN>(&pool),
        47500000000000000000000
      ); 
     assert_eq(
        interest_clamm_volatile::coin_price_oracle<ETH, LP_COIN>(&pool),
        1499902676449293924913
      ); 
     assert_eq(
        interest_clamm_volatile::xcp_profit<LP_COIN>(&pool),
        1001616388232902130
      );  
     assert_eq(
        interest_clamm_volatile::xcp_profit_a<LP_COIN>(&pool),
        POW_10_18
      );  
     assert_eq(
        interest_clamm_volatile::virtual_price<LP_COIN>(&pool),
        1001616388232902130
      ); 
     assert_eq(
        interest_clamm_volatile::invariant_<LP_COIN>(&pool),
        443201373469832832623384
      );             

      test::return_shared(pool);
    };        

    clock::destroy_for_testing(c);
    test::end(scenario);      
  }  
}