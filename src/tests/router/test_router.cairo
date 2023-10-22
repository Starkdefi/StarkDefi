use array::ArrayTrait;
use clone::Clone;
use option::OptionTrait;
use result::ResultTrait;
use starknet::account::Call;
use starknet::ContractAddress;
use starknet::contract_address_const;

use starkDefi::dex::v1::pair::IStarkDPairDispatcher;
use starkDefi::dex::v1::pair::IStarkDPairDispatcherTrait;

use starkDefi::dex::v1::factory::interface::IStarkDFactoryABIDispatcher;
use starkDefi::dex::v1::factory::interface::IStarkDFactoryABIDispatcherTrait;

use starkDefi::dex::v1::router::StarkDRouter;
use starkDefi::dex::v1::router::interface::{IStarkDRouterDispatcher, SwapPath};
use starkDefi::dex::v1::router::interface::IStarkDRouterDispatcherTrait;

use starkDefi::utils::selectors;
use starkDefi::token::erc20::interface::ERC20ABIDispatcher;
use starkDefi::token::erc20::interface::ERC20ABIDispatcherTrait;

use starkDefi::tests::helper_account::AccountABIDispatcher;
use starkDefi::tests::helper_account::interface::AccountABIDispatcherTrait;

use starkDefi::tests::factory::deploy_factory;
use starkDefi::tests::utils::constants;
use starkDefi::tests::utils::functions::{drop_event, pop_log, setup_erc20, deploy, with_decimals};
use starkDefi::tests::utils::{deploy_erc20, token_at};
use starkDefi::tests::utils::account::setup_account;
use starkDefi::utils::{pow};

use starknet::testing;
use debug::PrintTrait;

//
// setup
//

fn deploy_router() -> (IStarkDRouterDispatcher, AccountABIDispatcher) {
    let account = setup_account(); // 0x1
    let factory = deploy_factory(account.contract_address); // 0x2

    {
        let mut calls = array![];
        let mut fee_calldata = array![];
        Serde::serialize(@constants::FEE_TO(), ref fee_calldata);

        calls
            .append(
                Call {
                    to: factory.contract_address,
                    selector: selectors::set_fee_to,
                    calldata: fee_calldata
                }
            );

        account.__execute__(calls);
    }

    let mut calldata = array![];
    Serde::serialize(@factory.contract_address, ref calldata);
    let router_address = deploy(StarkDRouter::TEST_CLASS_HASH, calldata); // 0x3

    (IStarkDRouterDispatcher { contract_address: router_address }, account)
}

fn deploy_tokens() -> (
    ERC20ABIDispatcher, ERC20ABIDispatcher, ERC20ABIDispatcher, ERC20ABIDispatcher
) {
    let account = contract_address_const::<1>();
    let total_supply = constants::TOTAL_SUPPLY(1_000_000_000);

    let token0 = deploy_erc20('Token0', 'TK0', total_supply, account); // 0x4
    let token1 = deploy_erc20('Token1', 'TK1', total_supply, account); // 0x5

    let token2 = deploy_erc20('Token2', 'TK2', total_supply, account); // 0x6
    let token3 = deploy_erc20('Token3', 'TK3', total_supply, account); // 0x7

    (token0, token1, token2, token3)
}

fn approve_spend(account: AccountABIDispatcher, spender: ContractAddress, amount: u128) {
    let mut calls = array![];
    let amount = with_decimals(amount);
    // approve all tokens
    let mut token0 = array![];
    Serde::serialize(@spender, ref token0);
    Serde::serialize(@amount, ref token0);

    let mut token1 = array![];
    Serde::serialize(@spender, ref token1);
    Serde::serialize(@amount, ref token1);

    let mut token2 = array![];
    Serde::serialize(@spender, ref token2);
    Serde::serialize(@amount, ref token2);

    let mut token3 = array![];
    Serde::serialize(@spender, ref token3);
    Serde::serialize(@amount, ref token3);

    calls
        .append(
            Call {
                to: contract_address_const::<4>(), selector: selectors::approve, calldata: token0
            }
        );
    calls
        .append(
            Call {
                to: contract_address_const::<5>(), selector: selectors::approve, calldata: token1
            }
        );
    calls
        .append(
            Call {
                to: contract_address_const::<6>(), selector: selectors::approve, calldata: token2
            }
        );
    calls
        .append(
            Call {
                to: contract_address_const::<7>(), selector: selectors::approve, calldata: token3
            }
        );

    account.__execute__(calls);
}

//
// constructor
//

#[test]
#[available_gas(2000000)]
fn test_deploy_router() {
    let (router, _) = deploy_router();
    assert(router.factory() == contract_address_const::<2>(), 'Factory eq deployed 0x2');
    assert(
        IStarkDFactoryABIDispatcher { contract_address: router.factory() }
            .fee_to() == constants::FEE_TO(),
        'FeeTo eq fee_to'
    );
}

//
// add_liquidity
//

fn add_liquidity(
    router: IStarkDRouterDispatcher,
    account: AccountABIDispatcher,
    tokenA: ContractAddress,
    tokenB: ContractAddress,
    stable: bool,
    feeTier: u8,
    amountADesired: u128,
    amountBDesired: u128,
    slipTolerance: u256,
    deadline: u64
) -> (u256, u256, u256) {
    let amountA: u256 = with_decimals(amountADesired);
    let amountB: u256 = with_decimals(amountBDesired);

    let amountAMin: u256 = amountA * (10000 - slipTolerance) / 10000;
    let amountBMin: u256 = amountB * (10000 - slipTolerance) / 10000;

    let mut calldata = array![];
    Serde::serialize(@tokenA, ref calldata);
    Serde::serialize(@tokenB, ref calldata);
    Serde::serialize(@stable, ref calldata);
    Serde::serialize(@feeTier, ref calldata);
    Serde::serialize(@amountA, ref calldata);
    Serde::serialize(@amountB, ref calldata);
    Serde::serialize(@amountAMin, ref calldata);
    Serde::serialize(@amountBMin, ref calldata);
    Serde::serialize(@account.contract_address, ref calldata);
    Serde::serialize(@deadline, ref calldata);

    let ret = account
        .__execute__(
            array![
                Call {
                    to: router.contract_address,
                    selector: selectors::add_liquidity,
                    calldata: calldata
                }
            ]
        );

    let mut call1_ret = *ret.at(0);
    let call1_retval = Serde::<(u256, u256, u256)>::deserialize(ref call1_ret);

    call1_retval.unwrap()
}

fn create_pair(
    stable: bool, feeTier: u8
) -> (
    IStarkDRouterDispatcher,
    AccountABIDispatcher,
    IStarkDPairDispatcher,
    ERC20ABIDispatcher,
    ERC20ABIDispatcher
) {
    let (router, account) = deploy_router();
    let factory = IStarkDFactoryABIDispatcher { contract_address: router.factory() };
    let (token0, token1, _, _) = deploy_tokens();

    let pair = factory
        .create_pair(token0.contract_address, token1.contract_address, stable, feeTier);

    (router, account, IStarkDPairDispatcher { contract_address: pair }, token0, token1)
}

fn add_initial_liquidity(
    stable: bool, feeTier: u8
) -> (
    IStarkDRouterDispatcher,
    AccountABIDispatcher,
    IStarkDFactoryABIDispatcher,
    ERC20ABIDispatcher,
    ERC20ABIDispatcher
) {
    let (router, account) = deploy_router();
    let factory = IStarkDFactoryABIDispatcher { contract_address: router.factory() };
    let (token0, token1, _, _) = deploy_tokens();

    let amount0Desired = 100_000_000;
    let amount1Desired = 100_000_000;
    let slipTolerance = 100; // 1%
    let deadline = 1;

    approve_spend(account, router.contract_address, 1_000_000_000);

    add_liquidity(
        router,
        account,
        token0.contract_address,
        token1.contract_address,
        stable,
        feeTier,
        amount0Desired,
        amount1Desired,
        slipTolerance,
        deadline
    );

    (router, account, factory, token0, token1)
}

fn add_multiple_liquidity(
    stable: bool, feeTier: u8
) -> (
    IStarkDRouterDispatcher,
    AccountABIDispatcher,
    IStarkDFactoryABIDispatcher,
    ERC20ABIDispatcher,
    ERC20ABIDispatcher,
    ERC20ABIDispatcher,
    ERC20ABIDispatcher
) {
    let (router, account) = deploy_router();
    let factory = IStarkDFactoryABIDispatcher { contract_address: router.factory() };
    let (token0, token1, token2, token3) = deploy_tokens();

    let amount0Desired = with_decimals(100_000_000);
    let amount1Desired = with_decimals(100_000_000);
    let minAmount = with_decimals(0);
    let deadline = 1;

    approve_spend(account, router.contract_address, 1_000_000_000);

    let mut calls = array![];

    // token0, token1
    let mut t0t1_calldata = array![];
    Serde::serialize(@token0.contract_address, ref t0t1_calldata);
    Serde::serialize(@token1.contract_address, ref t0t1_calldata);
    Serde::serialize(@stable, ref t0t1_calldata);
    Serde::serialize(@feeTier, ref t0t1_calldata);
    Serde::serialize(@amount0Desired, ref t0t1_calldata);
    Serde::serialize(@amount1Desired, ref t0t1_calldata);
    Serde::serialize(@minAmount, ref t0t1_calldata);
    Serde::serialize(@minAmount, ref t0t1_calldata);
    Serde::serialize(@account.contract_address, ref t0t1_calldata);
    Serde::serialize(@deadline, ref t0t1_calldata);

    calls
        .append(
            Call {
                to: router.contract_address,
                selector: selectors::add_liquidity,
                calldata: t0t1_calldata
            }
        );

    // token0, token2
    let mut t0t2_calldata = array![];
    let amount0 = amount0Desired + with_decimals(10_222_789);
    let amount1 = amount1Desired + with_decimals(10_222_789);
    Serde::serialize(@token0.contract_address, ref t0t2_calldata);
    Serde::serialize(@token2.contract_address, ref t0t2_calldata);
    Serde::serialize(@stable, ref t0t2_calldata);
    Serde::serialize(@feeTier, ref t0t2_calldata);
    Serde::serialize(@amount0, ref t0t2_calldata);
    Serde::serialize(@amount1, ref t0t2_calldata);
    Serde::serialize(@minAmount, ref t0t2_calldata);
    Serde::serialize(@minAmount, ref t0t2_calldata);
    Serde::serialize(@account.contract_address, ref t0t2_calldata);
    Serde::serialize(@deadline, ref t0t2_calldata);

    calls
        .append(
            Call {
                to: router.contract_address,
                selector: selectors::add_liquidity,
                calldata: t0t2_calldata
            }
        );

    // token0, token3
    let mut t0t3_calldata = array![];
    let amount0 = amount0Desired + with_decimals(6_222_789);
    let amount1 = amount1Desired + with_decimals(20_222_789);
    Serde::serialize(@token0.contract_address, ref t0t3_calldata);
    Serde::serialize(@token3.contract_address, ref t0t3_calldata);
    Serde::serialize(@stable, ref t0t3_calldata);
    Serde::serialize(@feeTier, ref t0t3_calldata);
    Serde::serialize(@amount0, ref t0t3_calldata);
    Serde::serialize(@amount1, ref t0t3_calldata);
    Serde::serialize(@minAmount, ref t0t3_calldata);
    Serde::serialize(@minAmount, ref t0t3_calldata);
    Serde::serialize(@account.contract_address, ref t0t3_calldata);
    Serde::serialize(@deadline, ref t0t3_calldata);

    calls
        .append(
            Call {
                to: router.contract_address,
                selector: selectors::add_liquidity,
                calldata: t0t3_calldata
            }
        );

    // token1, token2
    let mut t1t2_calldata = array![];
    let amount0 = amount0Desired + with_decimals(80_222_789);
    let amount1 = amount1Desired + with_decimals(80_222_789);
    Serde::serialize(@token1.contract_address, ref t1t2_calldata);
    Serde::serialize(@token2.contract_address, ref t1t2_calldata);
    Serde::serialize(@stable, ref t1t2_calldata);
    Serde::serialize(@feeTier, ref t1t2_calldata);
    Serde::serialize(@amount0, ref t1t2_calldata);
    Serde::serialize(@amount1, ref t1t2_calldata);
    Serde::serialize(@minAmount, ref t1t2_calldata);
    Serde::serialize(@minAmount, ref t1t2_calldata);
    Serde::serialize(@account.contract_address, ref t1t2_calldata);
    Serde::serialize(@deadline, ref t1t2_calldata);

    calls
        .append(
            Call {
                to: router.contract_address,
                selector: selectors::add_liquidity,
                calldata: t1t2_calldata
            }
        );

    // token1, token3
    let mut t1t3_calldata = array![];
    let amount0 = amount0Desired + with_decimals(999_704);
    let amount1 = amount1Desired + with_decimals(10_257_832);
    Serde::serialize(@token1.contract_address, ref t1t3_calldata);
    Serde::serialize(@token3.contract_address, ref t1t3_calldata);
    Serde::serialize(@stable, ref t1t3_calldata);
    Serde::serialize(@feeTier, ref t1t3_calldata);
    Serde::serialize(@amount0, ref t1t3_calldata);
    Serde::serialize(@amount1, ref t1t3_calldata);
    Serde::serialize(@minAmount, ref t1t3_calldata);
    Serde::serialize(@minAmount, ref t1t3_calldata);
    Serde::serialize(@account.contract_address, ref t1t3_calldata);
    Serde::serialize(@deadline, ref t1t3_calldata);

    calls
        .append(
            Call {
                to: router.contract_address,
                selector: selectors::add_liquidity,
                calldata: t1t3_calldata
            }
        );

    // token2, token3
    let mut t2t3_calldata = array![];
    let amount0 = amount0Desired + with_decimals(64_235_889);

    Serde::serialize(@token2.contract_address, ref t2t3_calldata);
    Serde::serialize(@token3.contract_address, ref t2t3_calldata);
    Serde::serialize(@stable, ref t2t3_calldata);
    Serde::serialize(@feeTier, ref t2t3_calldata);
    Serde::serialize(@amount0, ref t2t3_calldata);
    Serde::serialize(@amount1Desired, ref t2t3_calldata);
    Serde::serialize(@minAmount, ref t2t3_calldata);
    Serde::serialize(@minAmount, ref t2t3_calldata);
    Serde::serialize(@account.contract_address, ref t2t3_calldata);
    Serde::serialize(@deadline, ref t2t3_calldata);

    calls
        .append(
            Call {
                to: router.contract_address,
                selector: selectors::add_liquidity,
                calldata: t2t3_calldata
            }
        );

    account.__execute__(calls);

    (router, account, factory, token0, token1, token2, token3)
}

#[test]
#[available_gas(20000000)]
fn test_router_add_new_liquidity() {
    let (router, account) = deploy_router();
    let (token0, token1, _, _) = deploy_tokens();

    let amount0Desired = 1_000_000;
    let amount1Desired = 1_000_000;
    let slipTolerance = 100; // 1%
    let deadline = 1;

    approve_spend(account, router.contract_address, 100_000_000);

    let (amount0, amount1, liquidity) = add_liquidity(
        router,
        account,
        token0.contract_address,
        token1.contract_address,
        false,
        0,
        amount0Desired,
        amount1Desired,
        slipTolerance,
        deadline
    );

    let expected_liquidity = 999999999999999999999000;
    assert(amount0 == with_decimals(amount0Desired), 'amount0 eq amount0Desired');
    assert(amount1 == with_decimals(amount1Desired), 'amount1 eq amount1Desired');
    assert(liquidity == expected_liquidity, 'liquidity eq expected_liquidity');
}

#[test]
#[available_gas(20000000)]
fn test_router_add_more_liquidity() {
    let (router, account, factoryDispatcher, token0, token1) = add_initial_liquidity(false, 0);

    let amount0Desired = 100_000_000;
    let amount1Desired = 100_000_000;
    let slipTolerance = 100; // 1%
    let deadline = 1;

    // add more liquidity
    let (_, _, liquidity) = add_liquidity(
        router,
        account,
        token0.contract_address,
        token1.contract_address,
        false,
        0,
        amount0Desired - 80_222_789,
        amount1Desired - 80_222_789,
        slipTolerance,
        deadline
    );

    assert(liquidity == with_decimals(19777211), 'liquidity eq expected_liquidity');
}

#[test]
#[available_gas(40000000)]
#[should_panic(expected: ('INSUFFICIENT_B_AMOUNT', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED'))]
fn test_router_add_liquidity_insufficient_b() {
    let (router, account, _, token0, token1) = add_initial_liquidity(false, 0);

    let amount0Desired = 100_000_000;
    let amount1Desired = 100_000_000;
    let slipTolerance = 100; // 1%
    let deadline = 1;

    add_liquidity(
        router,
        account,
        token0.contract_address,
        token1.contract_address,
        false,
        0,
        amount0Desired,
        amount1Desired,
        slipTolerance,
        deadline
    );

    // add more liquidity
    let (_, _, liquidity) = add_liquidity(
        router,
        account,
        token0.contract_address,
        token1.contract_address,
        false,
        0,
        amount0Desired - 80_222_789,
        amount1Desired - 40_222_789,
        slipTolerance,
        deadline
    );
}

#[test]
#[available_gas(40000000)]
#[should_panic(expected: ('INSUFFICIENT_A_AMOUNT', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED'))]
fn test_router_add_liquidity_insufficient_a() {
    let (router, account, _, token0, token1) = add_initial_liquidity(false, 0);

    let amount0Desired = 100_000_000;
    let amount1Desired = 100_000_000;
    let slipTolerance = 100; // 1%
    let deadline = 1;

    add_liquidity(
        router,
        account,
        token0.contract_address,
        token1.contract_address,
        false,
        0,
        amount0Desired,
        amount1Desired,
        slipTolerance,
        deadline
    );

    // add more liquidity
    let (_, _, liquidity) = add_liquidity(
        router,
        account,
        token0.contract_address,
        token1.contract_address,
        false,
        0,
        amount0Desired - 40_222_789,
        amount1Desired - 80_222_789,
        slipTolerance,
        deadline
    );
}

//
// remove_liquidity
//

fn remove_liquidity(
    router: IStarkDRouterDispatcher,
    account: AccountABIDispatcher,
    tokenA: ContractAddress,
    tokenB: ContractAddress,
    stable: bool,
    feeTier: u8,
    liquidity: u256,
    amountAMin: u256,
    amountBMin: u256,
    deadline: u64
) -> (u256, u256) {
    let factoryDispatcher = IStarkDFactoryABIDispatcher { contract_address: router.factory() };
    let lp_token_address = factoryDispatcher.get_pair(tokenA, tokenB, stable, feeTier);

    let mut calls = array![];

    // approve lp tokens
    let mut approve_calldata = array![];
    Serde::serialize(@router.contract_address, ref approve_calldata);
    Serde::serialize(@liquidity, ref approve_calldata);

    calls
        .append(
            Call { to: lp_token_address, selector: selectors::approve, calldata: approve_calldata }
        );

    // remove liquidity
    let mut remove_calldata = array![];
    Serde::serialize(@tokenA, ref remove_calldata);
    Serde::serialize(@tokenB, ref remove_calldata);
    Serde::serialize(@stable, ref remove_calldata);
    Serde::serialize(@feeTier, ref remove_calldata);
    Serde::serialize(@liquidity, ref remove_calldata);
    Serde::serialize(@amountAMin, ref remove_calldata);
    Serde::serialize(@amountBMin, ref remove_calldata);
    Serde::serialize(@account.contract_address, ref remove_calldata);
    Serde::serialize(@deadline, ref remove_calldata);

    calls
        .append(
            Call {
                to: router.contract_address,
                selector: selectors::remove_liquidity,
                calldata: remove_calldata
            }
        );

    let ret = account.__execute__(calls);

    let mut call1_ret = *ret.at(1);
    let call1_retval = Serde::<(u256, u256)>::deserialize(ref call1_ret);

    call1_retval.unwrap()
}

#[test]
#[available_gas(40000000)]
fn test_router_remove_all_liquidity() {
    let stable = false;
    let feeTier = 0;
    let (router, account, factoryDispatcher, token0, token1) = add_initial_liquidity(
        stable, feeTier
    );

    let pairDispatcher = IStarkDPairDispatcher {
        contract_address: factoryDispatcher
            .get_pair(token0.contract_address, token1.contract_address, stable, feeTier)
    };
    let lp_balance = pairDispatcher.balance_of(account.contract_address);

    let (amount0, amount1) = remove_liquidity(
        router,
        account,
        token0.contract_address,
        token1.contract_address,
        stable,
        feeTier,
        lp_balance,
        0,
        0,
        1
    );

    let expected_amounts = 99999999999999999999999000;
    assert(amount0 == expected_amounts, 'amount0 eq expected_amounts');
    assert(amount1 == expected_amounts, 'amount1 eq expected_amounts');
    assert(pairDispatcher.balance_of(account.contract_address) == 0, 'lp_balance eq 0');
    assert(pairDispatcher.total_supply() == 1000, 'total_supply eq 1000');
}

#[test]
#[available_gas(40000000)]
fn test_router_remove_liqudity_some() {
    let stable = false;
    let feeTier = 0;
    let (router, account, factoryDispatcher, token0, token1) = add_initial_liquidity(
        stable, feeTier
    );

    let pairDispatcher = IStarkDPairDispatcher {
        contract_address: factoryDispatcher
            .get_pair(token0.contract_address, token1.contract_address, stable, feeTier)
    };
    let lp_balance = pairDispatcher.balance_of(account.contract_address);

    let (amount0, amount1) = remove_liquidity(
        router,
        account,
        token0.contract_address,
        token1.contract_address,
        stable,
        feeTier,
        lp_balance / 2,
        0,
        0,
        1
    );

    let expected_amounts = 49999999999999999999999500;
    assert(amount0 == expected_amounts, 'amount0 eq expected_amounts');
    assert(amount1 == expected_amounts, 'amount1 eq expected_amounts');

    assert(
        pairDispatcher.balance_of(account.contract_address) == expected_amounts,
        'lp_balance eq expected_amounts'
    );
}

#[test]
#[available_gas(40000000)]
#[should_panic(expected: ('insufficient A amount', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED'))]
fn test_router_remove_liqudity_less_A() {
    let stable = false;
    let feeTier = 0;
    let (router, account, factoryDispatcher, token0, token1) = add_initial_liquidity(
        stable, feeTier
    );

    remove_liquidity(
        router,
        account,
        token0.contract_address,
        token1.contract_address,
        stable,
        feeTier,
        with_decimals(99_000_000),
        with_decimals(100_000_000),
        0,
        1
    );
}

#[test]
#[available_gas(40000000)]
#[should_panic(expected: ('insufficient B amount', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED'))]
fn test_router_remove_liqudity_less_B() {
    let stable = false;
    let feeTier = 0;
    let (router, account, factoryDispatcher, token0, token1) = add_initial_liquidity(
        stable, feeTier
    );

    remove_liquidity(
        router,
        account,
        token0.contract_address,
        token1.contract_address,
        stable,
        feeTier,
        with_decimals(99_000_000),
        0,
        with_decimals(100_000_000),
        1
    );
}

//
// Getters
//

#[test]
#[available_gas(20000000)]
fn test_router_quote() {
    let stable = false;
    let feeTier = 0;
    let (router, account, factoryDispatcher, token0, token1) = add_initial_liquidity(
        stable, feeTier
    );

    let pairDispatcher = IStarkDPairDispatcher {
        contract_address: factoryDispatcher
            .get_pair(token0.contract_address, token1.contract_address, stable, feeTier)
    };

    let (res0, res1, _) = pairDispatcher.get_reserves();
    let amount = with_decimals(100_000);

    let amountOut = router.quote(amount, res0, res1);

    assert(amountOut == with_decimals(100_000), 'amountOut eq amount');
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('insufficient amount', 'ENTRYPOINT_FAILED'))]
fn test_router_quote_insufficient_amount() {
    let stable = false;
    let feeTier = 0;
    let (router, _, _, _, _) = add_initial_liquidity(stable, feeTier);

    router.quote(0, 1, 1);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('insufficient liquidity', 'ENTRYPOINT_FAILED'))]
fn test_router_quote_insufficient_liquidity() {
    let stable = false;
    let feeTier = 0;
    let (router, _, _, _, _) = add_initial_liquidity(stable, feeTier);

    router.quote(1, 0, 1);
}

#[test]
#[available_gas(20000000)]
fn test_router_get_amount_out() {
    let stable = false;
    let feeTier = 0;
    let (router, account, factoryDispatcher, token0, token1) = add_initial_liquidity(
        stable, feeTier
    );

    let pairDispatcher = IStarkDPairDispatcher {
        contract_address: factoryDispatcher
            .get_pair(token0.contract_address, token1.contract_address, stable, feeTier)
    };

    let (resIn, resOut, _) = pairDispatcher.get_reserves();

    let amountIn = with_decimals(100_000);
    let amountOut = pairDispatcher.get_amount_out(token0.contract_address, amountIn);

    assert(amountOut == 99600698103990321649315, 'amountOut eq amount');
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('insufficient input amount', 'ENTRYPOINT_FAILED'))]
fn test_router_get_amount_out_insufficient_amount() {
    let stable = false;
    let feeTier = 0;
    let (router, _, factoryDispatcher, token0, token1) = add_initial_liquidity(stable, feeTier);

    let pairDispatcher = IStarkDPairDispatcher {
        contract_address: factoryDispatcher
            .get_pair(token0.contract_address, token1.contract_address, stable, feeTier)
    };

    pairDispatcher.get_amount_out(token0.contract_address, 0);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('insufficient liquidity', 'ENTRYPOINT_FAILED'))]
fn test_router_get_amount_out_insufficient_liquidity() {
    let stable = false;
    let feeTier = 0;
    let (router, _, pairDispatcher, token0, token1) = create_pair(stable, feeTier);

    let amountIn = with_decimals(100_000);
    pairDispatcher.get_amount_out(token0.contract_address, amountIn);
}

#[test]
#[available_gas(200000000)]
fn test_router_get_amounts_out() {
    let stable = false;
    let feeTier = 0;
    let (router, _, _, token0, token1, token2, token3) = add_multiple_liquidity(stable, feeTier);

    let amountIn = with_decimals(1_000);
    let path: Array::<SwapPath> = array![
        SwapPath {
            tokenIn: token0.contract_address, tokenOut: token3.contract_address, stable, feeTier
        },
        SwapPath {
            tokenIn: token3.contract_address, tokenOut: token2.contract_address, stable, feeTier
        },
        SwapPath {
            tokenIn: token2.contract_address, tokenOut: token1.contract_address, stable, feeTier
        }
    ];

    let amounts = router.get_amounts_out(amountIn, path);

    let expected_amounts = array![
        amountIn, 1128392473536953390081, 1847644947951066853782, 1842083184716188827616
    ];
    assert(*amounts.at(0) == *expected_amounts.at(0), 'amount0 eq expected_amount @0');
    assert(*amounts.at(1) == *expected_amounts.at(1), 'amount1 eq expected_amount @1');
    assert(*amounts.at(2) == *expected_amounts.at(2), 'amount2 eq expected_amount @2');
    assert(*amounts.at(3) == *expected_amounts.at(3), 'amount3 eq expected_amount @3');
}

#[test]
#[available_gas(200000000)]
#[should_panic(expected: ('invalid path', 'ENTRYPOINT_FAILED'))]
fn test_router_get_amounts_out_invalid_path() {
    let stable = false;
    let feeTier = 0;
    let (router, _, _, token0, _, _, _) = add_multiple_liquidity(stable, feeTier);

    let amountIn = with_decimals(1_000);
    let path: Array::<SwapPath> = array![];

    router.get_amounts_out(amountIn, path);
}

//
// swap
//

fn swap_exact_tokens_for_tokens(
    router: IStarkDRouterDispatcher,
    account: AccountABIDispatcher,
    amountIn: u256,
    amountOutMin: u256,
    path: Array::<SwapPath>,
    to: ContractAddress,
    deadline: u64
) -> Array::<u256> {
    let mut calldata = array![];
    Serde::serialize(@amountIn, ref calldata);
    Serde::serialize(@amountOutMin, ref calldata);
    Serde::serialize(@path, ref calldata);
    Serde::serialize(@to, ref calldata);
    Serde::serialize(@deadline, ref calldata);

    let ret = account
        .__execute__(
            array![
                Call {
                    to: router.contract_address,
                    selector: selectors::swap_exact_tokens_for_tokens,
                    calldata: calldata
                }
            ]
        );

    let mut call1_ret = *ret.at(0);
    let call1_retval = Serde::<Array<u256>>::deserialize(ref call1_ret);

    call1_retval.unwrap()
}

fn swap_exact_tokens_for_tokens_supporting_fees_on_transfer_tokens(
    router: IStarkDRouterDispatcher,
    account: AccountABIDispatcher,
    amountOut: u256,
    amountInMax: u256,
    path: Array::<SwapPath>,
    to: ContractAddress,
    deadline: u64
) {
    let mut calldata = array![];
    Serde::serialize(@amountOut, ref calldata);
    Serde::serialize(@amountInMax, ref calldata);
    Serde::serialize(@path, ref calldata);
    Serde::serialize(@to, ref calldata);
    Serde::serialize(@deadline, ref calldata);

    let ret = account
        .__execute__(
            array![
                Call {
                    to: router.contract_address,
                    selector: selectors::swap_exact_tokens_for_tokens_supporting_fees_on_transfer_tokens,
                    calldata: calldata
                }
            ]
        );
}

#[test]
#[available_gas(200000000)]
fn test_router_swap_exact_tokens_for_tokens() {
    let stable = false;
    let feeTier = 100;
    let (router, account, _, token0, token1, token2, token3) = add_multiple_liquidity(
        stable, feeTier
    );
    let slipTolerance = 100; // 1%

    let amountIn: u256 = with_decimals(10_000);
    let path: Array::<SwapPath> = array![
        SwapPath {
            tokenIn: token0.contract_address, tokenOut: token3.contract_address, stable, feeTier
        },
        SwapPath {
            tokenIn: token3.contract_address, tokenOut: token2.contract_address, stable, feeTier
        },
        SwapPath {
            tokenIn: token2.contract_address, tokenOut: token1.contract_address, stable, feeTier
        }
    ];

    let token0_balance_before = token0.balance_of(account.contract_address);
    let token1_balance_before = token1.balance_of(account.contract_address);

    let amounts = router.get_amounts_out(amountIn, path.clone());
    let amountOutMin = *amounts.at(3) * (10000 - slipTolerance) / 10000;

    let swap_amounts = swap_exact_tokens_for_tokens(
        router, account, amountIn, amountOutMin, path, account.contract_address, 1
    );

    assert(*swap_amounts.at(3) >= amountOutMin, 'amountOutMin <= swap_amounts[3]');
    let token0_balance_after = token0.balance_of(account.contract_address);
    let token1_balance_after = token1.balance_of(account.contract_address);

    assert(
        token0_balance_before - token0_balance_after == with_decimals(10_000), 'balances 0 checks'
    );
    assert(
        token1_balance_after - token1_balance_before == *swap_amounts.at(3), 'balances 1 checks'
    );
}

#[test]
#[available_gas(200000000)]
fn test_router_swap_exact_tokens_for_tokens_3() {
    let stable = false;
    let feeTier = 0;
    let (router, account, _, token0, token1, token2, token3) = add_multiple_liquidity(
        stable, feeTier
    );
    let slipTolerance = 50; // 0.5%

    let amountIn: u256 = with_decimals(1_000);
    let path: Array::<SwapPath> = array![
        SwapPath {
            tokenIn: token0.contract_address, tokenOut: token3.contract_address, stable, feeTier
        },
        SwapPath {
            tokenIn: token3.contract_address, tokenOut: token1.contract_address, stable, feeTier
        }
    ];

    let balance0_before = token0.balance_of(account.contract_address);
    let balance1_before = token1.balance_of(account.contract_address);

    let amounts = router.get_amounts_out(amountIn, path.clone());
    let amountOutMin = *amounts.at(2) * (10000 - slipTolerance) / 10000;

    let swap_amounts = swap_exact_tokens_for_tokens(
        router, account, amountIn, amountOutMin, path, account.contract_address, 1
    );
    assert(*swap_amounts.at(2) >= amountOutMin, 'amountOutMin <= swap_amounts[3]');

    let balance0_after = token0.balance_of(account.contract_address);
    let balance1_after = token1.balance_of(account.contract_address);

    assert(balance0_before - balance0_after == with_decimals(1_000), 'balances 0 checks');
    assert(balance1_after - balance1_before == *swap_amounts.at(2), 'balances 1 checks');
}

#[test]
#[available_gas(200000000)]
fn test_router_swap_exact_tokens_for_tokens_2() {
    let stable = false;
    let feeTier = 0;
    let (router, account, _, token0, token1, token2, token3) = add_multiple_liquidity(
        stable, feeTier
    );
    let slipTolerance = 50; // 0.5%

    let amountIn: u256 = with_decimals(1_000);
    let path: Array::<SwapPath> = array![
        SwapPath {
            tokenIn: token2.contract_address, tokenOut: token0.contract_address, stable, feeTier
        }
    ];

    let balance2_before = token2.balance_of(account.contract_address);
    let balance0_before = token0.balance_of(account.contract_address);

    let amounts = router.get_amounts_out(amountIn, path.clone());
    let amountOutMin = *amounts.at(1) * (10000 - slipTolerance) / 10000;

    let swap_amounts = swap_exact_tokens_for_tokens(
        router, account, amountIn, amountOutMin, path, account.contract_address, 1
    );

    assert(*swap_amounts.at(1) >= amountOutMin, 'amountOutMin <= swap_amounts[3]');

    let balance2_after = token2.balance_of(account.contract_address);
    let balance0_after = token0.balance_of(account.contract_address);

    assert(balance2_before - balance2_after == with_decimals(1_000), 'balances 2 checks');
    assert(balance0_after - balance0_before == *swap_amounts.at(1), 'balances 0 checks');
}

#[test]
#[available_gas(200000000)]
fn test_router_swap_exact_tokens_for_tokens_multiple() {
    let stable = false;
    let feeTier = 0;
    let (router, account, _, token0, token1, token2, token3) = add_multiple_liquidity(
        stable, feeTier
    );
    let slipTolerance = 50; // 0.5%

    let amountIn: u256 = with_decimals(1_000);
    let path: Array::<SwapPath> = array![
        SwapPath {
            tokenIn: token2.contract_address, tokenOut: token0.contract_address, stable, feeTier
        }
    ];

    let amounts = router.get_amounts_out(amountIn, path.clone());
    let amountOutMin = *amounts.at(1) * (10000 - slipTolerance) / 10000;

    let swap_amounts1 = swap_exact_tokens_for_tokens(
        router, account, amountIn, amountOutMin, path.clone(), account.contract_address, 1
    );

    // swap 2
    let amounts = router.get_amounts_out(amountIn, path.clone());
    let amountOutMin = *amounts.at(1) * (10000 - slipTolerance) / 10000;

    swap_exact_tokens_for_tokens(
        router, account, amountIn, amountOutMin, path.clone(), account.contract_address, 1
    );

    // swap 3
    let amounts = router.get_amounts_out(amountIn * 8, path.clone());
    let amountOutMin = *amounts.at(1) * (10000 - slipTolerance) / 10000;

    swap_exact_tokens_for_tokens(
        router, account, amountIn * 8, amountOutMin, path.clone(), account.contract_address, 1
    );

    // swap 4
    let amounts = router.get_amounts_out(amountIn * 10, path.clone());
    let amountOutMin = *amounts.at(1) * (10000 - slipTolerance) / 10000;

    swap_exact_tokens_for_tokens(
        router, account, amountIn * 10, amountOutMin, path.clone(), account.contract_address, 1
    );

    // swap 5
    let amounts = router.get_amounts_out(amountIn, path.clone());
    let amountOutMin = *amounts.at(1) * (10000 - slipTolerance) / 10000;

    let swap_amounts5 = swap_exact_tokens_for_tokens(
        router, account, amountIn, amountOutMin, path, account.contract_address, 1
    );

    assert(*swap_amounts1.at(1) != *swap_amounts5.at(1), 'first & last swap amounts')
}

#[test]
#[available_gas(200000000)]
#[should_panic(expected: ('invalid path', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED'))]
fn test_router_swap_exact_tokens_for_tokens_invalid_path_progression() {
    let stable = false;
    let feeTier = 0;
    let (router, account, _, token0, token1, token2, token3) = add_multiple_liquidity(
        stable, feeTier
    );
    let slipTolerance = 50; // 0.5%

    let amountIn: u256 = with_decimals(1_000);
    let path: Array::<SwapPath> = array![
        SwapPath {
            tokenIn: token0.contract_address, tokenOut: token3.contract_address, stable, feeTier
        },
        SwapPath {
            tokenIn: token0.contract_address, tokenOut: token1.contract_address, stable, feeTier
        }
    ];

    let amounts = router.get_amounts_out(amountIn, path.clone());
    let amountOutMin = *amounts.at(2) * (10000 - slipTolerance) / 10000;

    let swap_amounts = swap_exact_tokens_for_tokens(
        router, account, amountIn, amountOutMin, path, account.contract_address, 1
    );
}

#[test]
#[available_gas(200000000)]
fn test_router_swap_exact_tokens_for_tokens_supporting_fees_on_transfer_tokens_multiple() {
    let stable = false;
    let feeTier = 0;
    let (router, account, _, token0, token1, token2, token3) = add_multiple_liquidity(
        stable, feeTier
    );
    let slipTolerance = 50; // 0.5%

    let amountIn: u256 = with_decimals(1_000);
    let path: Array::<SwapPath> = array![
        SwapPath {
            tokenIn: token2.contract_address, tokenOut: token0.contract_address, stable, feeTier
        }
    ];

    let amounts = router.get_amounts_out(amountIn, path.clone());
    let amountOutMin = *amounts.at(1) * (10000 - slipTolerance) / 10000;

    swap_exact_tokens_for_tokens_supporting_fees_on_transfer_tokens(
        router, account, amountIn, amountOutMin, path.clone(), account.contract_address, 1
    );

    // swap 2
    let amounts = router.get_amounts_out(amountIn, path.clone());
    let amountOutMin = *amounts.at(1) * (10000 - slipTolerance) / 10000;

    swap_exact_tokens_for_tokens_supporting_fees_on_transfer_tokens(
        router, account, amountIn, amountOutMin, path.clone(), account.contract_address, 1
    );

    // swap 3
    let amounts = router.get_amounts_out(amountIn * 8, path.clone());
    let amountOutMin = *amounts.at(1) * (10000 - slipTolerance) / 10000;

    swap_exact_tokens_for_tokens_supporting_fees_on_transfer_tokens(
        router, account, amountIn * 8, amountOutMin, path.clone(), account.contract_address, 1
    );

    // swap 4
    let amounts = router.get_amounts_out(amountIn * 10, path.clone());
    let amountOutMin = *amounts.at(1) * (10000 - slipTolerance) / 10000;

    swap_exact_tokens_for_tokens_supporting_fees_on_transfer_tokens(
        router, account, amountIn * 10, amountOutMin, path.clone(), account.contract_address, 1
    );

    // swap 5
    let amounts = router.get_amounts_out(amountIn, path.clone());
    let amountOutMin = *amounts.at(1) * (10000 - slipTolerance) / 10000;

    swap_exact_tokens_for_tokens_supporting_fees_on_transfer_tokens(
        router, account, amountIn, amountOutMin, path, account.contract_address, 1
    );
}

#[test]
#[available_gas(200000000)]
#[should_panic(expected: ('invalid path', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED'))]
fn test_router_swap_exact_tokens_for_tokens_supporting_fees_on_transfer_tokens_invalid_path_progression() {
    let stable = false;
    let feeTier = 0;
    let (router, account, _, token0, token1, token2, token3) = add_multiple_liquidity(
        stable, feeTier
    );
    let slipTolerance = 50; // 0.5%

    let amountIn: u256 = with_decimals(1_000);
    let path: Array::<SwapPath> = array![
        SwapPath {
            tokenIn: token0.contract_address, tokenOut: token3.contract_address, stable, feeTier
        },
        SwapPath {
            tokenIn: token0.contract_address, tokenOut: token1.contract_address, stable, feeTier
        }
    ];

    let amounts = router.get_amounts_out(amountIn, path.clone());
    let amountOutMin = *amounts.at(2) * (10000 - slipTolerance) / 10000;

    swap_exact_tokens_for_tokens_supporting_fees_on_transfer_tokens(
        router, account, amountIn, amountOutMin, path, account.contract_address, 1
    );
}

#[test]
#[available_gas(200000000)]
#[should_panic(expected: ('insufficient output amount', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED'))]
fn test_router_swap_exact_tokens_for_tokens_invalid() {
    let stable = false;
    let feeTier = 0;
    let (router, account, _, token0, token1, token2, token3) = add_multiple_liquidity(
        stable, feeTier
    );

    let amountIn: u256 = with_decimals(1_000);
    let path: Array::<SwapPath> = array![
        SwapPath {
            tokenIn: token2.contract_address, tokenOut: token0.contract_address, stable, feeTier
        }
    ];

    let amounts = router.get_amounts_out(amountIn, path.clone());
    let amountOutMin = *amounts.at(1) * 3;
    swap_exact_tokens_for_tokens(
        router, account, amountIn, amountOutMin, path.clone(), account.contract_address, 1
    );
}
