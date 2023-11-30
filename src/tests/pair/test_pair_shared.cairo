use array::ArrayTrait;
use starknet::account::Call;
use starknet::ContractAddress;
use starknet::get_caller_address;
use starknet::contract_address_const;

use starkDefi::dex::v1::pair::StarkDPair;
use starkDefi::dex::v1::pair::StarkDPair::StarkDPairImpl;
use starkDefi::dex::v1::pair::StarkDPair::Mint;
use starkDefi::dex::v1::pair::StarkDPair::Burn;
use starkDefi::dex::v1::pair::StarkDPair::Swap;
use starkDefi::dex::v1::pair::StarkDPair::Sync;

use starkDefi::dex::v1::pair::interface::IStarkDPairABIDispatcher;
use starkDefi::dex::v1::pair::interface::IStarkDPairABIDispatcherTrait;
use starkDefi::dex::v1::pair::interface::{IFeesVaultDispatcher, IFeesVaultDispatcherTrait};

use starkDefi::dex::v1::factory::interface::IStarkDFactoryABIDispatcher;
use starkDefi::dex::v1::factory::interface::IStarkDFactoryABIDispatcherTrait;

use starkDefi::utils::selectors;
use starkDefi::token::erc20::interface::ERC20ABIDispatcher;
use starkDefi::token::erc20::interface::ERC20ABIDispatcherTrait;

use starkDefi::tests::helper_account::AccountABIDispatcher;
use starkDefi::tests::helper_account::interface::AccountABIDispatcherTrait;

use starkDefi::tests::factory::deploy_factory;

use starkDefi::tests::utils::constants;
use starkDefi::tests::utils::functions::{drop_event, pop_log, setup_erc20, with_decimals};
use starkDefi::tests::utils::{deploy_erc20, token_at};
use starkDefi::tests::utils::account::setup_account;
use starknet::testing;
use debug::PrintTrait;

//
// Setup
//

fn deploy_pair(stable: bool, feeTier: u8) -> (IStarkDPairABIDispatcher, AccountABIDispatcher) {
    let account = setup_account();
    let factory = deploy_factory(account.contract_address);
    let token0 = deploy_erc20('Token0', 'TK0', with_decimals(10000), account.contract_address);
    let token1 = deploy_erc20('Token1', 'TK1', with_decimals(10000), account.contract_address);

    let pair = factory
        .create_pair(token0.contract_address, token1.contract_address, stable, feeTier);

    (IStarkDPairABIDispatcher { contract_address: pair }, account)
}

fn STATE() -> StarkDPair::ContractState {
    StarkDPair::contract_state_for_testing()
}

fn setup(stable: bool, feeTier: u8) -> StarkDPair::ContractState {
    let mut state = STATE();

    testing::set_caller_address(constants::FACTORY());
    testing::set_contract_address(constants::PAIR());
    StarkDPair::constructor(
        ref state,
        constants::TOKEN_0(),
        constants::TOKEN_1(),
        stable,
        feeTier,
        constants::PAIR_FEES_CLASS_HASH()
    );
    drop_event(constants::ADDRESS_ZERO());

    state
}

//
// constructor
//

#[test]
#[available_gas(4000000)]
fn test_pair_constructor() {
    let mut state = STATE();
    let token0 = deploy_erc20('Token0', 'TK0', with_decimals(10000), constants::ADDRESS_ONE());
    let token1 = deploy_erc20('Token1', 'TK1', with_decimals(10000), constants::ADDRESS_ONE());

    testing::set_caller_address(constants::CALLER());
    StarkDPair::constructor(
        ref state,
        token0.contract_address,
        token1.contract_address,
        false,
        0,
        constants::PAIR_FEES_CLASS_HASH()
    );

    assert(StarkDPairImpl::token0(@state) == constants::ADDRESS_ONE(), 'Token0 eq ADDRESS_ONE');
    assert(StarkDPairImpl::token1(@state) == constants::ADDRESS_TWO(), 'Token1 eq ADDRESS_TWO');
    assert(StarkDPairImpl::factory(@state) == get_caller_address(), 'Factory eq caller address');
    assert(StarkDPairImpl::decimals(@state) == 18, 'Decimals eq 18');
    assert(StarkDPairImpl::total_supply(@state) == 0, 'Total supply eq 0');
}

//
// deployed pair
//

#[test]
#[available_gas(20000000)]
fn test_deployed_pair() {
    let (pairDispatcher, accountDispatcher) = deploy_pair(false, 0);

    assert(pairDispatcher.token0() == constants::ADDRESS_THREE(), 'Token0 eq ADDRESS_THREE');
    assert(pairDispatcher.token1() == constants::ADDRESS_FOUR(), 'Token1 eq ADDRESS_FOUR');
    assert(pairDispatcher.factory() == constants::ADDRESS_TWO(), 'Factory eq ADDRESS_TWO');

    // tokens
    let token0Dispatcher = token_at(pairDispatcher.token0());
    let token1Dispatcher = token_at(pairDispatcher.token1());

    assert(token0Dispatcher.name() == 'Token0', 'Token0 name eq Token0');
    assert(token0Dispatcher.symbol() == 'TK0', 'Token0 symbol eq TK0');
    assert(token0Dispatcher.decimals() == 18, 'Token0 decimals eq 18');
    assert(token0Dispatcher.total_supply() == with_decimals(10000), 'Token0 total supply eq 10000');
    assert(
        token0Dispatcher.balance_of(accountDispatcher.contract_address) == with_decimals(10000),
        'Token0 balance eq 10000'
    );

    assert(token1Dispatcher.name() == 'Token1', 'Token1 name eq Token1');
    assert(token1Dispatcher.symbol() == 'TK1', 'Token1 symbol eq TK1');
    assert(token1Dispatcher.decimals() == 18, 'Token1 decimals eq 18');
    assert(token1Dispatcher.total_supply() == with_decimals(10000), 'Token1 total supply eq 10000');
    assert(
        token1Dispatcher.balance_of(accountDispatcher.contract_address) == with_decimals(10000),
        'Token1 balance eq 10000'
    );

    assert(pairDispatcher.decimals() == 18, 'Decimals eq 18');
    assert(pairDispatcher.total_supply() == 0, 'Total supply eq 0');
}

//
// mint
//

fn transfer_erc20(token: ContractAddress, to: ContractAddress, amount: u256) -> Call {
    let mut call = array![];
    Serde::serialize(@to, ref call);
    Serde::serialize(@amount, ref call);
    Call { to: token, selector: selectors::transfer, calldata: call }
}

fn add_initial_liquidity(
    ignore_decimals: bool, token0_amount: u256, token1_amount: u256, stable: bool, feeTier: u8
) -> (IStarkDPairABIDispatcher, AccountABIDispatcher) {
    let (pairDispatcher, accountDispatcher) = deploy_pair(stable, feeTier);
    let token0Dispatcher = token_at(pairDispatcher.token0());
    let token1Dispatcher = token_at(pairDispatcher.token1());

    let mut calls = array![];

    let token0_amount = if ignore_decimals {
        token0_amount
    } else {
        with_decimals(token0_amount.low)
    };
    let token1_amount = if ignore_decimals {
        token1_amount
    } else {
        with_decimals(token1_amount.low)
    };
    // token0 transfer call
    calls
        .append(
            transfer_erc20(
                token0Dispatcher.contract_address, pairDispatcher.contract_address, token0_amount
            )
        );

    // token1 transfer call
    calls
        .append(
            transfer_erc20(
                token1Dispatcher.contract_address, pairDispatcher.contract_address, token1_amount
            )
        );

    // mint lp
    let mut mint_calldata = array![];
    Serde::serialize(@accountDispatcher.contract_address, ref mint_calldata);

    calls
        .append(
            Call {
                to: pairDispatcher.contract_address,
                selector: selectors::mint,
                calldata: mint_calldata
            }
        );
    // multicall
    accountDispatcher.__execute__(calls);

    (pairDispatcher, accountDispatcher)
}

fn add_more_liquidity(
    ref pairDispatcher: IStarkDPairABIDispatcher,
    ref accountDispatcher: AccountABIDispatcher,
    token0_amount: u256,
    token1_amount: u256
) {
    let token0Dispatcher = token_at(pairDispatcher.token0());
    let token1Dispatcher = token_at(pairDispatcher.token1());

    let mut calls = array![];

    // token0 transfer call
    calls
        .append(
            transfer_erc20(
                token0Dispatcher.contract_address,
                pairDispatcher.contract_address,
                with_decimals(token0_amount.low)
            )
        );

    // token1 transfer call
    calls
        .append(
            transfer_erc20(
                token1Dispatcher.contract_address,
                pairDispatcher.contract_address,
                with_decimals(token1_amount.low)
            )
        );

    // mint lp
    let mut mint_calldata = array![];
    Serde::serialize(@accountDispatcher.contract_address, ref mint_calldata);

    calls
        .append(
            Call {
                to: pairDispatcher.contract_address,
                selector: selectors::mint,
                calldata: mint_calldata
            }
        );
    // multicall
    accountDispatcher.__execute__(calls);
}

#[test]
#[available_gas(20000000)]
fn test_mint() {
    let (pairDispatcher, accountDispatcher) = deploy_pair(false, 0);

    let token0Dispatcher = token_at(pairDispatcher.token0());
    let token1Dispatcher = token_at(pairDispatcher.token1());

    assert(pairDispatcher.total_supply() == 0, 'Total supply eq 0');
    assert(pairDispatcher.balance_of(accountDispatcher.contract_address) == 0, 'Balance eq 0');

    // multicall transfer to pair
    let mut calls = array![];

    // token0 transfer call
    let call0 = transfer_erc20(
        token0Dispatcher.contract_address, pairDispatcher.contract_address, with_decimals(5000)
    );

    // token1 transfer call
    let call1 = transfer_erc20(
        token1Dispatcher.contract_address, pairDispatcher.contract_address, with_decimals(3000)
    );

    calls.append(call0);
    calls.append(call1);

    // multicall
    accountDispatcher.__execute__(calls);
    assert(
        token0Dispatcher.balance_of(pairDispatcher.contract_address) == with_decimals(5000),
        'Token0 balance eq 5000'
    );
    assert(
        token1Dispatcher.balance_of(pairDispatcher.contract_address) == with_decimals(3000),
        'Token1 balance eq 3000'
    );

    // mint
    pairDispatcher.mint(accountDispatcher.contract_address);
    assert(
        pairDispatcher.balance_of(accountDispatcher.contract_address) == 3872983346207416884179,
        'Balance eq 38729...'
    );
    assert(
        pairDispatcher.balance_of(contract_address_const::<'deAd'>()) == 1000, 'Balance eq 1000'
    );
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('u128_sub Overflow', 'ENTRYPOINT_FAILED'))]
fn test_mint_no_zero_tokens() {
    let (pairDispatcher, accountDispatcher) = deploy_pair(false, 0);
    // mint
    pairDispatcher.mint(accountDispatcher.contract_address);
}

#[test]
#[available_gas(20000000)]
#[should_panic(
    expected: ('insufficient liquidity minted', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED')
)]
fn test_mint_not_enough_tokens() {
    let stable = false;
    let (pairDispatcher, accountDispatcher) = add_initial_liquidity(true, 1000, 1000, stable, 0);
}

//
// swap
//

fn swap(
    ref pairDispatcher: IStarkDPairABIDispatcher,
    ref accountDispatcher: AccountABIDispatcher,
    amountToSwap: u256,
    amount0Out: u256,
    amount1Out: u256,
    test_invalid_to: bool
) {
    let token0Dispatcher = token_at(pairDispatcher.token0());
    let token1Dispatcher = token_at(pairDispatcher.token1());

    let mut calls = array![];

    // transfer token to be swapped
    let token_to_be_swapped = if amount0Out == 0 {
        token0Dispatcher.contract_address
    } else {
        token1Dispatcher.contract_address
    };

    calls
        .append(transfer_erc20(token_to_be_swapped, pairDispatcher.contract_address, amountToSwap));

    // swap
    let data: Array::<felt252> = array![];

    let mut swap_calldata = array![];
    Serde::serialize(@amount0Out, ref swap_calldata);
    Serde::serialize(@amount1Out, ref swap_calldata);
    if test_invalid_to {
        Serde::serialize(@pairDispatcher.token0(), ref swap_calldata);
    } else {
        Serde::serialize(@accountDispatcher.contract_address, ref swap_calldata);
    }
    Serde::serialize(@data, ref swap_calldata);
    calls
        .append(
            Call {
                to: pairDispatcher.contract_address,
                selector: selectors::swap,
                calldata: swap_calldata
            }
        );

    // multicall
    accountDispatcher.__execute__(calls);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('insufficient liquidity', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED'))]
fn test_swap_insufficient_liquidity() {
    let stable = true;
    let (mut pairDispatcher, mut accountDispatcher) = add_initial_liquidity(
        false, 2500, 2500, stable, 0
    );
    // swap
    let amount = with_decimals(5000);
    swap(ref pairDispatcher, ref accountDispatcher, amount, amount, 0, false);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('insufficient output amount', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED'))]
fn test_vPair_swap_insufficient_output_amount() {
    let stable = false;
    let (mut pairDispatcher, mut accountDispatcher) = add_initial_liquidity(
        false, 5000, 3000, stable, 0
    );
    // swap
    swap(ref pairDispatcher, ref accountDispatcher, with_decimals(50), 0, 0, false);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('invalid to', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED'))]
fn test_swap_invalid_to() {
    let stable = true;
    let (mut pairDispatcher, mut accountDispatcher) = add_initial_liquidity(
        false, 5000, 5000, stable, 0
    );
    // swap
    swap(ref pairDispatcher, ref accountDispatcher, 50, 81, 0, true);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('insufficient input amount', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED'))]
fn test_swap_insufficient_input_amount() {
    let stable = false;
    let (mut pairDispatcher, mut accountDispatcher) = add_initial_liquidity(
        false, 5000, 3000, stable, 0
    );
    // swap
    swap(ref pairDispatcher, ref accountDispatcher, 0, 81, 0, false);
}

//
// burn
//

fn remove_liqudity(
    ref pairDispatcher: IStarkDPairABIDispatcher,
    ref accountDispatcher: AccountABIDispatcher,
    amount: u256,
    no_decimal: bool
) {
    let mut calls = array![];

    // transfer lp to pair
    calls
        .append(
            transfer_erc20(
                pairDispatcher.contract_address,
                pairDispatcher.contract_address,
                if (!no_decimal) {
                    with_decimals(amount.low)
                } else {
                    amount
                }
            )
        );

    // burn
    let mut burn_calldata = array![];
    Serde::serialize(@accountDispatcher.contract_address, ref burn_calldata);

    calls
        .append(
            Call {
                to: pairDispatcher.contract_address,
                selector: selectors::burn,
                calldata: burn_calldata
            }
        );

    // multicall
    accountDispatcher.__execute__(calls);
}

#[test]
#[available_gas(40000000)]
fn test_burn() {
    let stable = false;
    let (mut pairDispatcher, mut accountDispatcher) = add_initial_liquidity(
        false, 5000, 3000, stable, 0
    );
    let token0Dispatcher = token_at(pairDispatcher.token0());
    let token1Dispatcher = token_at(pairDispatcher.token1());

    // add more liquidity
    add_more_liquidity(ref pairDispatcher, ref accountDispatcher, 1000, 2000);
    add_more_liquidity(ref pairDispatcher, ref accountDispatcher, 2000, 500);

    assert(pairDispatcher.total_supply() == 5112338016993790288435, 'Total supply eq 5112...');
    assert(
        pairDispatcher
            .balance_of(accountDispatcher.contract_address) == (5112338016993790288435 - 1000),
        'Balance eq 5112...'
    );

    // remove liquidity
    remove_liqudity(ref pairDispatcher, ref accountDispatcher, 1000, false);
    assert(pairDispatcher.total_supply() == 4112338016993790288435, 'Total supply eq 4112...');
    assert(
        pairDispatcher
            .balance_of(accountDispatcher.contract_address) == (4112338016993790288435 - 1000),
        'Balance eq 4112...'
    );
    // ~= 2000 + (1000*8000)/5110
    assert(
        token0Dispatcher.balance_of(accountDispatcher.contract_address) == 3564841756043400761689,
        'Token0 balance eq 3564...'
    );
    // ~= 4500 + (1000*5500)/5110
    assert(
        token1Dispatcher.balance_of(accountDispatcher.contract_address) == 5575828707279838023661,
        'Token1 balance eq 5575...'
    )
}

#[test]
#[available_gas(20000000)]
fn test_burn_remove_all_liquidity() {
    let stable = false;
    let (mut pairDispatcher, mut accountDispatcher) = add_initial_liquidity(
        false, 5000, 3000, stable, 0
    );
    let token0Dispatcher = token_at(pairDispatcher.token0());
    let token1Dispatcher = token_at(pairDispatcher.token1());

    assert(pairDispatcher.total_supply() == 3872983346207416885179, 'Total supply eq 3872...');

    // remove liquidity
    remove_liqudity(ref pairDispatcher, ref accountDispatcher, 3872983346207416884179, true);
    assert(pairDispatcher.total_supply() == 1000, 'Total supply eq 0...1000');

    // ~= 5000 + (2872*5000)/3872
    assert(
        token0Dispatcher.balance_of(accountDispatcher.contract_address) == 9999999999999999998709,
        'Token0 balance eq 9999...'
    );
    // ~= 7000 + (2872*3000)/3872
    assert(
        token1Dispatcher.balance_of(accountDispatcher.contract_address) == 9999999999999999999225,
        'Token1 balance eq 9224...'
    )
}

#[test]
#[available_gas(20000000)]
#[should_panic(
    expected: ('insufficient liquidity burned', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED')
)]
fn test_burn_insufficient_liquidity() {
    let stable = false;
    let (mut pairDispatcher, mut accountDispatcher) = add_initial_liquidity(
        false, 5000, 3000, stable, 0
    );
    // remove liquidity
    remove_liqudity(ref pairDispatcher, ref accountDispatcher, 0, false);
}

//
// skim
//

#[test]
#[available_gas(20000000)]
fn test_skim() {
    let (pairDispatcher, accountDispatcher) = add_initial_liquidity(false, 5000, 3000, false, 0);
    let token0Dispatcher = token_at(pairDispatcher.token0());

    // transfer token0 to pair
    let mut calls = array![];
    calls
        .append(
            transfer_erc20(
                token0Dispatcher.contract_address,
                pairDispatcher.contract_address,
                with_decimals(1000)
            )
        );

    accountDispatcher.__execute__(calls);

    assert(
        token0Dispatcher.balance_of(pairDispatcher.contract_address) == 6000000000000000000000,
        'Token0 balance eq 6000'
    );

    // skim
    pairDispatcher.skim(accountDispatcher.contract_address);
    assert(
        token0Dispatcher.balance_of(pairDispatcher.contract_address) == 5000000000000000000000,
        'Token0 balance eq 5000'
    );
}

//
// sync
//

#[test]
#[available_gas(20000000)]
fn test_sync() {
    let (pairDispatcher, accountDispatcher) = add_initial_liquidity(false, 5000, 3000, false, 0);
    let token0Dispatcher = token_at(pairDispatcher.token0());

    // transfer token0 to pair
    let mut calls = array![];
    calls
        .append(
            transfer_erc20(
                token0Dispatcher.contract_address,
                pairDispatcher.contract_address,
                with_decimals(1000)
            )
        );

    accountDispatcher.__execute__(calls);

    let (res1, _, _) = pairDispatcher.get_reserves();
    assert(res1 == with_decimals(5000), 'Reserve 1 eq 5000');

    // sync
    pairDispatcher.sync();

    let (res1, _, _) = pairDispatcher.get_reserves();
    assert(res1 == with_decimals(6000), 'Reserve 1 eq 6000');
//
}

//
// fee
//

#[test]
#[available_gas(50000000)]
fn test_fees_collected_on_swap() {
    let stable = false;
    let feeTier = 0;
    let (mut pairDispatcher, mut accountDispatcher) = add_initial_liquidity(
        false, 5000, 3000, stable, feeTier
    );
    let fee_vault = pairDispatcher.fee_vault();
    let token0Dispatcher = token_at(pairDispatcher.token0());
    let token1Dispatcher = token_at(pairDispatcher.token1());

    assert(token0Dispatcher.balance_of(fee_vault) == 0, 'Fee vault balance eq 0');
    assert(token1Dispatcher.balance_of(fee_vault) == 0, 'Fee vault balance eq 0');

    // swaps
    swap(
        ref pairDispatcher,
        ref accountDispatcher,
        with_decimals(3000),
        0,
        with_decimals(1122),
        false
    );
    swap(
        ref pairDispatcher,
        ref accountDispatcher,
        with_decimals(5000),
        with_decimals(5438),
        0,
        false
    );
    swap(
        ref pairDispatcher,
        ref accountDispatcher,
        with_decimals(5000),
        0,
        with_decimals(3882),
        false
    );
    swap(
        ref pairDispatcher,
        ref accountDispatcher,
        with_decimals(6000),
        with_decimals(4670),
        0,
        false
    );

    // check fee vault

    // 0.3% of (3000+5000) = 24
    assert(token0Dispatcher.balance_of(fee_vault) == with_decimals(24), 'Fee vault balance eq 24');
    // 0.3% of (5000+6000) = 33
    assert(token1Dispatcher.balance_of(fee_vault) == with_decimals(33), 'Fee vault balance eq 33');
}

#[test]
#[available_gas(100000000)]
fn test_claim_fees() {
    let stable = false;
    let feeTier = 1;
    let (mut pairDispatcher, mut accountDispatcher) = add_initial_liquidity(
        false, 5000, 3000, stable, feeTier
    );
    let fee_vault = pairDispatcher.fee_vault();
    let token0Dispatcher = token_at(pairDispatcher.token0());
    let token1Dispatcher = token_at(pairDispatcher.token1());
    // swaps
    swap(
        ref pairDispatcher,
        ref accountDispatcher,
        with_decimals(3000),
        0,
        with_decimals(1122),
        false
    );
    swap(
        ref pairDispatcher,
        ref accountDispatcher,
        with_decimals(5000),
        with_decimals(5438),
        0,
        false
    );
    swap(
        ref pairDispatcher,
        ref accountDispatcher,
        with_decimals(5000),
        0,
        with_decimals(3882),
        false
    );
    swap(
        ref pairDispatcher,
        ref accountDispatcher,
        with_decimals(6000),
        with_decimals(4670),
        0,
        false
    );

    // claim fee
    let mut calls = array![];
    calls
        .append(
            Call {
                to: pairDispatcher.contract_address,
                selector: selectors::claim_fees,
                calldata: array![]
            }
        );
    accountDispatcher.__execute__(calls);

    assert(token0Dispatcher.balance_of(fee_vault) < with_decimals(1), 'Fee vault balance lt 1');
    assert(token1Dispatcher.balance_of(fee_vault) < with_decimals(1), 'Fee vault balance lt 1');
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('insufficient input amount', 'ENTRYPOINT_FAILED'))]
fn test_get_amount_out_insufficient_in() {
    let (pairDispatcher, accountDispatcher) = add_initial_liquidity(false, 5000, 4103, false, 0);
    pairDispatcher.get_amount_out(pairDispatcher.token0(), 0);
}

