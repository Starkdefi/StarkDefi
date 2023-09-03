use array::ArrayTrait;
use option::OptionTrait;
use result::ResultTrait;
use starknet::account::Call;
use starknet::ContractAddress;
use starknet::contract_address_const;

use starkDefi::dex::v1::pair::IStarkDPairDispatcher;
use starkDefi::dex::v1::pair::IStarkDPairDispatcherTrait;

use starkDefi::dex::v1::factory::interface::IStarkDFactoryDispatcher;
use starkDefi::dex::v1::factory::interface::IStarkDFactoryDispatcherTrait;

use starkDefi::dex::v1::router::StarkDRouter;
use starkDefi::dex::v1::router::interface::IStarkDRouterDispatcher;
use starkDefi::dex::v1::router::interface::IStarkDRouterDispatcherTrait;

use starkDefi::token::erc20::selectors;
use starkDefi::token::erc20::interface::ERC20ABIDispatcher;
use starkDefi::token::erc20::interface::ERC20ABIDispatcherTrait;

use starkDefi::tests::helper_account::AccountABIDispatcher;
use starkDefi::tests::helper_account::interface::AccountABIDispatcherTrait;

use starkDefi::tests::factory::deploy_factory;
use starkDefi::tests::utils::constants;
use starkDefi::tests::utils::functions::{drop_event, pop_log, setup_erc20, deploy};
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
    let amount = u256 { low: amount * pow(10, 18), high: 0 };
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
        IStarkDFactoryDispatcher { contract_address: router.factory() }
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
    amountADesired: u128,
    amountBDesired: u128,
    slipTolerance: u256,
    deadline: u64
) -> (u256, u256, u256) {
    let amountA: u256 = u256 { low: amountADesired * pow(10, 18), high: 0 };
    let amountB: u256 = u256 { low: amountBDesired * pow(10, 18), high: 0 };

    let amountAMin: u256 = amountA * (10000 - slipTolerance) / 10000;
    let amountBMin: u256 = amountB * (10000 - slipTolerance) / 10000;

    let mut calldata = array![];
    Serde::serialize(@tokenA, ref calldata);
    Serde::serialize(@tokenB, ref calldata);
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
        amount0Desired,
        amount1Desired,
        slipTolerance,
        deadline
    );

    let expected_liquidity = 999999999999999999999000;
    assert(
        amount0 == u256 { low: amount0Desired * pow(10, 18), high: 0 }, 'amount0 eq amount0Desired'
    );
    assert(
        amount1 == u256 { low: amount1Desired * pow(10, 18), high: 0 }, 'amount1 eq amount1Desired'
    );
    assert(liquidity == expected_liquidity, 'liquidity eq expected_liquidity');
}
