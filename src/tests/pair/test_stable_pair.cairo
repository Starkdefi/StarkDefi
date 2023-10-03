use core::traits::AddEq;
use array::ArrayTrait;
use starknet::account::Call;
use starknet::ContractAddress;
use starknet::get_caller_address;
use starknet::contract_address_const;
use starkDefi::tests::pair::test_pair_shared as Shared;
use Shared::{
    StarkDPair, StarkDPairImpl, STATE, IStarkDPairDispatcher, IStarkDPairDispatcherTrait,
    ERC20ABIDispatcher, ERC20ABIDispatcherTrait, AccountABIDispatcher, AccountABIDispatcherTrait,
    deploy_pair, token_at, transfer_erc20, add_initial_liquidity, add_more_liquidity, swap,
    remove_liqudity, with_decimals, deploy_erc20
};
use starkDefi::tests::utils::constants;
use starknet::testing;
use debug::PrintTrait;


//
// constructor
//

#[test]
#[available_gas(20000000)]
fn test_sPair_constructor() {
    let mut state = Shared::STATE();
    let token0 = deploy_erc20('Token0', 'TK0', with_decimals(10000), constants::ADDRESS_ONE());
    let token1 = deploy_erc20('Token1', 'TK1', with_decimals(10000), constants::ADDRESS_ONE());

    testing::set_caller_address(constants::CALLER());
    StarkDPair::constructor(
        ref state,
        token0.contract_address,
        token1.contract_address,
        true,
        constants::PAIR_FEES_CLASS_HASH()
    );
    assert(StarkDPairImpl::name(@state) == 'sStarkDefi Pair', 'Name eq sStarkDefi Pair');
    assert(StarkDPairImpl::symbol(@state) == 'sSTARKD-P', 'Symbol eq sSTARKD-P');
}

//
// deployed pair
//

#[test]
#[available_gas(4000000)]
fn test_deployed_sPair() {
    let (pairDispatcher, _) = deploy_pair(true);
    assert(pairDispatcher.name() == 'sStarkDefi Pair', 'Name eq sStarkDefi Pair');
    assert(pairDispatcher.symbol() == 'sSTARKD-P', 'Symbol eq sSTARKD-P');
}

#[test]
#[available_gas(20000000)]
fn test_sPair_mint() {
    let (pairDispatcher, accountDispatcher) = deploy_pair(true);

    let token0Dispatcher = token_at(pairDispatcher.token0());
    let token1Dispatcher = token_at(pairDispatcher.token1());

    // multicall transfer to pair
    let mut calls = array![];

    let transfer_amount = with_decimals(5000);
    // token0 transfer call
    let call0 = transfer_erc20(
        token0Dispatcher.contract_address, pairDispatcher.contract_address, transfer_amount
    );

    // token1 transfer call
    let call1 = transfer_erc20(
        token1Dispatcher.contract_address, pairDispatcher.contract_address, transfer_amount
    );

    calls.append(call0);
    calls.append(call1);

    // multicall
    accountDispatcher.__execute__(calls);

    // mint
    pairDispatcher.mint(accountDispatcher.contract_address);
    // sqrt (5000 * 5000) = 5000
    assert(pairDispatcher.total_supply() == transfer_amount, 'Total supply eq 3872');

    let (r1, r2, _) = pairDispatcher.get_reserves();
    assert(r1 == transfer_amount, 'Reserve 1 eq 5000');
    assert(r2 == transfer_amount, 'Reserve 2 eq 5000');
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('unequal amounts', 'ENTRYPOINT_FAILED'))]
fn test_sPair_mint_unmatched() {
    let (pairDispatcher, accountDispatcher) = deploy_pair(true);

    let token0Dispatcher = token_at(pairDispatcher.token0());
    let token1Dispatcher = token_at(pairDispatcher.token1());

    // multicall transfer to pair
    let mut calls = array![];

    let transfer_amount = with_decimals(5000);
    // token0 transfer call
    let call0 = transfer_erc20(
        token0Dispatcher.contract_address, pairDispatcher.contract_address, with_decimals(5000)
    );

    // token1 transfer call
    let call1 = transfer_erc20(
        token1Dispatcher.contract_address, pairDispatcher.contract_address, with_decimals(1000)
    );

    calls.append(call0);
    calls.append(call1);

    // multicall
    accountDispatcher.__execute__(calls);

    // mint
    pairDispatcher.mint(accountDispatcher.contract_address);
}

#[test]
#[available_gas(200000000)]
fn test_sPair_mint_more_lp() {
    let stable = true;
    let _5000 = with_decimals(5000);
    let (mut pairDispatcher, mut accountDispatcher) = add_initial_liquidity(
        false, 5000, 5000, stable
    );
    let token0Dispatcher = token_at(pairDispatcher.token0());
    let token1Dispatcher = token_at(pairDispatcher.token1());

    let (res0, res1, _) = pairDispatcher.get_reserves();
    assert(res0 == _5000, 'Reserve 1 eq 5000');
    assert(res1 == _5000, 'Reserve 2 eq 5000');
    assert(pairDispatcher.total_supply() == _5000, 'Total supply eq 5000');

    // add more liquidity
    let _2000 = with_decimals(2000);
    add_more_liquidity(ref pairDispatcher, ref accountDispatcher, 2000, 2000);
    let (res0, res1, _) = pairDispatcher.get_reserves();
    assert(res0 == _5000 + _2000, 'Reserve 1 eq 7000');
    assert(res1 == _5000 + _2000, 'Reserve 2 eq 7000');
    assert(pairDispatcher.total_supply() == _5000 + _2000, 'Total supply eq 7000');

    // add more liqudity
    let _500 = with_decimals(500);
    add_more_liquidity(ref pairDispatcher, ref accountDispatcher, 500, 500);
    let (res0, res1, _) = pairDispatcher.get_reserves();
    assert(res0 == _5000 + _2000 + _500, 'Reserve 1 eq 7500');
    assert(res1 == _5000 + _2000 + _500, 'Reserve 2 eq 7500');
    assert(pairDispatcher.total_supply() == _5000 + _2000 + _500, 'Total supply eq 7500');
}

#[test]
#[available_gas(20000000)]
fn test_sPair_swap_token0_for_token1() {
    let stable = true;
    let (mut pairDispatcher, mut accountDispatcher) = add_initial_liquidity(
        false, 5000, 5000, stable
    );
    let token0Dispatcher = token_at(pairDispatcher.token0());
    let token1Dispatcher = token_at(pairDispatcher.token1());

    // swap
    swap(ref pairDispatcher, ref accountDispatcher, with_decimals(30), 0, with_decimals(29), false);
    let (res0, res1, _) = pairDispatcher.get_reserves();

    let _5030 = 5029988000000000000000;
    let _4971 = 4971000000000000000000;

    assert(res0 == _5030, 'Reserve 0 eq ~= 5030');
    assert(res1 == _4971, 'Reserve 1 eq 4971');
    assert(
        token0Dispatcher.balance_of(pairDispatcher.contract_address) == _5030,
        'Token0 balance eq 5030'
    );
    assert(
        token1Dispatcher.balance_of(pairDispatcher.contract_address) == _4971,
        'Token1 balance eq 4971'
    );

    assert(
        token0Dispatcher.balance_of(accountDispatcher.contract_address) == with_decimals(4970),
        'Token0 balance eq 4970'
    );
    assert(
        token1Dispatcher.balance_of(accountDispatcher.contract_address) == with_decimals(5029),
        'Token1 balance eq 5029'
    )
}


#[test]
#[available_gas(40000000)]
fn test_sPair_swap_token1_for_token0() {
    let stable = true;
    let (mut pairDispatcher, mut accountDispatcher) = add_initial_liquidity(
        false, 5000, 5000, stable
    );
    let token0Dispatcher = token_at(pairDispatcher.token0());
    let token1Dispatcher = token_at(pairDispatcher.token1());

    // swap
    swap(ref pairDispatcher, ref accountDispatcher, with_decimals(30), with_decimals(29), 0, false);
    let (res0, res1, _) = pairDispatcher.get_reserves();

    let _5030 = 5029988000000000000000;
    let _4971 = 4971000000000000000000;

    assert(res0 == _4971, 'Reserve 0 eq 4971');
    assert(res1 == _5030, 'Reserve 1 eq ~= 5030');
    assert(
        token1Dispatcher.balance_of(pairDispatcher.contract_address) == _5030,
        'Token1 balance eq 5030'
    );
    assert(
        token0Dispatcher.balance_of(pairDispatcher.contract_address) == _4971,
        'Token0 balance eq 4971'
    );
}

#[test]
#[available_gas(200000000)]
fn test_sPair_get_amount_out() {
    let (pairDispatcher, accountDispatcher) = add_initial_liquidity(false, 10000, 10000, true);
    let amountIn = with_decimals(1);
    let tokenIn = pairDispatcher.token0();

    let amountOut = pairDispatcher.get_amount_out(tokenIn, amountIn);
    assert(amountOut == 999500089971006498, 'amount out eq 0.9995...');

    let tokenIn = pairDispatcher.token1();
    let amountIn = with_decimals(690);
    let amountOut = pairDispatcher.get_amount_out(tokenIn, amountIn);
    assert(amountOut == 645221523025290456516, 'amount out eq 645.22...');
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('invariant K', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED'))]
fn test_sPair_swap_invariant_k() {
    let stable = true;
    let (mut pairDispatcher, mut accountDispatcher) = add_initial_liquidity(
        false, 5000, 5000, stable
    );
    // swap
    swap(ref pairDispatcher, ref accountDispatcher, 50, 51, 0, false);
}
