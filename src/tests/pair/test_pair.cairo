use starkDefi::tests::helper_account::interface::AccountABIDispatcherTrait;
use array::ArrayTrait;
use option::OptionTrait;
use core::traits::Into;
use starknet::account::Call;
use starknet::ContractAddress;
use starknet::get_caller_address;
use starknet::contract_address_const;

use starkDefi::dex::v1::pair::StarkDPair;
use starkDefi::dex::v1::pair::StarkDPair::StarkDPairImpl;
use starkDefi::dex::v1::pair::StarkDPair::InternalFunctions;
use starkDefi::dex::v1::pair::StarkDPair::Mint;
use starkDefi::dex::v1::pair::StarkDPair::Burn;
use starkDefi::dex::v1::pair::StarkDPair::Swap;
use starkDefi::dex::v1::pair::StarkDPair::Sync;

use starkDefi::dex::v1::pair::interface::IStarkDPair;
use starkDefi::dex::v1::pair::IStarkDPairDispatcher;
use starkDefi::dex::v1::pair::IStarkDPairDispatcherTrait;

use starkDefi::dex::v1::factory::StarkDFactory;
use starkDefi::dex::v1::factory::StarkDFactory::StarkDFactoryImpl;
use starkDefi::dex::v1::factory::interface::IStarkDFactoryDispatcherTrait;

use starkDefi::token::erc20::ERC20;
use starkDefi::token::erc20::selectors;
use starkDefi::token::erc20::ERC20::ERC20Impl;
use starkDefi::token::erc20::ERC20::Transfer;
use starkDefi::token::erc20::interface::ERC20ABIDispatcherTrait;


use starkDefi::tests::helper_account::Account;
use starkDefi::tests::helper_account::AccountABIDispatcher;

use starkDefi::tests::factory::factory_setup;
use starkDefi::tests::factory::deploy_factory;

use starkDefi::tests::utils::constants;
use starkDefi::tests::utils::functions::{drop_event, pop_log, setup_erc20, deploy};
use starkDefi::tests::utils::{deploy_erc20, token_at};
use starkDefi::tests::utils::account::setup_account;
use starknet::testing;
use debug::PrintTrait;

//
// Setup
//

fn deploy_pair() -> (IStarkDPairDispatcher, AccountABIDispatcher) {
    let account = setup_account();
    let factory = deploy_factory();
    let token0 = deploy_erc20('Token0', 'TK0', 10000, account.contract_address);
    let token1 = deploy_erc20('Token1', 'TK1', 10000, account.contract_address);

    let pair = factory.create_pair(token0.contract_address, token1.contract_address);

    (IStarkDPairDispatcher { contract_address: pair }, account)
}


fn STATE() -> StarkDPair::ContractState {
    StarkDPair::contract_state_for_testing()
}

fn setup() -> StarkDPair::ContractState {
    let mut state = STATE();

    testing::set_caller_address(constants::FACTORY());
    testing::set_contract_address(constants::PAIR());
    StarkDPair::constructor(ref state, constants::TOKEN_0(), constants::TOKEN_1());
    drop_event(constants::ADDRESS_ZERO());

    state
}

//
// constructor
//

#[test]
#[available_gas(2000000)]
fn test_constructor() {
    let mut state = STATE();
    testing::set_caller_address(constants::CALLER());
    StarkDPair::constructor(ref state, constants::ADDRESS_ONE(), constants::ADDRESS_TWO());

    assert(StarkDPairImpl::token0(@state) == constants::ADDRESS_ONE(), 'Token0 eq ADDRESS_ONE');
    assert(StarkDPairImpl::token1(@state) == constants::ADDRESS_TWO(), 'Token1 eq ADDRESS_TWO');
    assert(StarkDPairImpl::factory(@state) == get_caller_address(), 'Factory eq caller address');

    // Starkd-p token
    assert(StarkDPairImpl::name(@state) == 'StarkDefi Pair', 'Name eq StarkDefi Pair');
    assert(StarkDPairImpl::symbol(@state) == 'STARKD-P', 'Symbol eq STARKD-P');
    assert(StarkDPairImpl::decimals(@state) == 18, 'Decimals eq 18');
    assert(StarkDPairImpl::total_supply(@state) == 0, 'Total supply eq 0');
}


//
// deployed pair
//

#[test]
#[available_gas(4000000)]
fn test_deployed_pair() {
    let (pairDispatcher, accountDispatcher) = deploy_pair();

    assert(pairDispatcher.token0() == constants::ADDRESS_THREE(), 'Token0 eq ADDRESS_THREE');
    assert(pairDispatcher.token1() == constants::ADDRESS_FOUR(), 'Token1 eq ADDRESS_FOUR');
    assert(pairDispatcher.factory() == constants::ADDRESS_TWO(), 'Factory eq ADDRESS_TWO');

    // tokens
    let token0Dispatcher = token_at(pairDispatcher.token0());
    let token1Dispatcher = token_at(pairDispatcher.token1());

    assert(token0Dispatcher.name() == 'Token0', 'Token0 name eq Token0');
    assert(token0Dispatcher.symbol() == 'TK0', 'Token0 symbol eq TK0');
    assert(token0Dispatcher.decimals() == 18, 'Token0 decimals eq 18');
    assert(token0Dispatcher.total_supply() == 10000, 'Token0 total supply eq 10000');
    assert(
        token0Dispatcher.balance_of(accountDispatcher.contract_address) == 10000,
        'Token0 balance eq 10000'
    );

    assert(token1Dispatcher.name() == 'Token1', 'Token1 name eq Token1');
    assert(token1Dispatcher.symbol() == 'TK1', 'Token1 symbol eq TK1');
    assert(token1Dispatcher.decimals() == 18, 'Token1 decimals eq 18');
    assert(token1Dispatcher.total_supply() == 10000, 'Token1 total supply eq 10000');
    assert(
        token1Dispatcher.balance_of(accountDispatcher.contract_address) == 10000,
        'Token1 balance eq 10000'
    );

    // Starkd-p token
    assert(pairDispatcher.name() == 'StarkDefi Pair', 'Name eq StarkDefi Pair');
    assert(pairDispatcher.symbol() == 'STARKD-P', 'Symbol eq STARKD-P');
    assert(pairDispatcher.decimals() == 18, 'Decimals eq 18');
    assert(pairDispatcher.total_supply() == 0, 'Total supply eq 0');
}

//
// mint
//

#[test]
#[available_gas(4000000)]
fn test_mint() {
    let (pairDispatcher, accountDispatcher) = deploy_pair();
    

    let token0Dispatcher = token_at(pairDispatcher.token0());
    let token1Dispatcher = token_at(pairDispatcher.token1());

    assert(pairDispatcher.total_supply() == 0, 'Total supply eq 0');
    assert(pairDispatcher.balance_of(accountDispatcher.contract_address) == 0, 'Balance eq 0');

    // multicall transfer to pair
    let mut calls = array![];

    // token0 transfer call
    let mut token0TransferCall = array![];
    let amount0: u256 = 1000;
    Serde::serialize(@pairDispatcher.contract_address, ref token0TransferCall);
    Serde::serialize(@amount0, ref token0TransferCall);
    let call0 = Call {
        to: token0Dispatcher.contract_address,
        selector: selectors::transfer,
        calldata: token0TransferCall
    };

    // token1 transfer call
    let mut token1TransferCall = array![];
    let amount1: u256 = 1000;
    Serde::serialize(@pairDispatcher.contract_address, ref token1TransferCall);
    Serde::serialize(@amount1, ref token1TransferCall);
    let call1 = Call {
        to: token1Dispatcher.contract_address,
        selector: selectors::transfer,
        calldata: token1TransferCall
    };

    calls.append(call0);
    calls.append(call1);

    // multicall
    let ret = accountDispatcher.__execute__(calls);

    assert(token0Dispatcher.balance_of(pairDispatcher.contract_address) == 1000, 'Token0 balance eq 1000');
    assert(token1Dispatcher.balance_of(pairDispatcher.contract_address) == 1000, 'Token1 balance eq 1000');
    assert(pairDispatcher.total_supply() == 0, 'Total supply eq 0');
    assert(pairDispatcher.balance_of(accountDispatcher.contract_address) == 0, 'Balance eq 0');

    
    // mint

}
