use starknet::account::Call;
use starknet::ContractAddress;
use starknet::get_caller_address;
use starknet::contract_address_const;
use starkdefi::tests::pair::test_pair_shared as Shared;
use Shared::{
    StarkDPair, StarkDPairImpl, STATE, IStarkDPairABIDispatcher, IStarkDPairABIDispatcherTrait,
    ERC20ABIDispatcher, ERC20ABIDispatcherTrait, AccountABIDispatcher, AccountABIDispatcherTrait,
    deploy_pair, token_at, transfer_erc20, add_initial_liquidity, add_more_liquidity, swap,
    remove_liqudity, with_decimals, deploy_erc20
};
use starkdefi::tests::utils::constants;
use starknet::testing;

//
// constructor
//

#[test]
#[available_gas(20000000)]
fn test_vPair_constructor() {
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
    assert(StarkDPairImpl::name(@state) == 'vStarkDefi Pair', 'Name eq vStarkDefi Pair');
    assert(StarkDPairImpl::symbol(@state) == 'vSTARKD-P', 'Symbol eq vSTARKD-P');
}

//
// deployed pair
//

#[test]
#[available_gas(4000000)]
fn test_deployed_vPair() {
    let (pairDispatcher, _) = deploy_pair(false, 0);
    assert(pairDispatcher.name() == 'vStarkDefi Pair', 'Name eq vStarkDefi Pair');
    assert(pairDispatcher.symbol() == 'vSTARKD-P', 'Symbol eq vSTARKD-P');
}

#[test]
#[available_gas(20000000)]
fn test_vPair_mint() {
    let (pairDispatcher, accountDispatcher) = deploy_pair(false, 0);

    let token0Dispatcher = token_at(pairDispatcher.token0());
    let token1Dispatcher = token_at(pairDispatcher.token1());

    // multicall transfer to pair
    let mut calls = array![];

    // token0 transfer call
    let call0 = transfer_erc20(
        token0Dispatcher.contract_address, pairDispatcher.contract_address, 5000
    );

    // token1 transfer call
    let call1 = transfer_erc20(
        token1Dispatcher.contract_address, pairDispatcher.contract_address, 3000
    );

    calls.append(call0);
    calls.append(call1);

    // multicall
    accountDispatcher.__execute__(calls);

    // mint
    pairDispatcher.mint(accountDispatcher.contract_address);
    // sqrt (5000 * 3000) = 3872
    assert(pairDispatcher.total_supply() == 3872, 'Total supply eq 3872');

    let (r1, r2, _) = pairDispatcher.get_reserves();
    assert(r1 == 5000, 'Reserve 1 eq 5000');
    assert(r2 == 3000, 'Reserve 2 eq 3000');
}

#[test]
#[available_gas(40000000)]
fn test_vPair_mint_more_lp() {
    let stable = false;
    let feeTier = 0;
    let (mut pairDispatcher, mut accountDispatcher) = add_initial_liquidity(
        false, 5000, 3000, stable, feeTier
    );
    let token0Dispatcher = token_at(pairDispatcher.token0());
    let token1Dispatcher = token_at(pairDispatcher.token1());

    let (res0, res1, _) = pairDispatcher.get_reserves();
    assert(res0 == with_decimals(5000), 'Reserve 1 eq 5000');
    assert(res1 == with_decimals(3000), 'Reserve 2 eq 3000');
    // sqrt (5000 * 3000) = 3872
    assert(pairDispatcher.total_supply() == 3872983346207416885179, 'Total supply eq 3872');

    // add more liquidity
    add_more_liquidity(ref pairDispatcher, ref accountDispatcher, 1000, 2000);
    let (res0, res1, _) = pairDispatcher.get_reserves();
    assert(res0 == with_decimals(6000), 'Reserve 1 eq 6000');
    assert(res1 == with_decimals(5000), 'Reserve 2 eq 5000');
    // (3872.98 +(1000*3872.98)/5000)
    assert(pairDispatcher.total_supply() == 4647580015448900262214, 'Total supply ~eq 4647');

    // add more liqudity
    add_more_liquidity(ref pairDispatcher, ref accountDispatcher, 2000, 500);
    let (res0, res1, _) = pairDispatcher.get_reserves();
    assert(res0 == with_decimals(8000), 'Reserve 1 eq 8000');
    assert(res1 == with_decimals(5500), 'Reserve 2 eq 5500');
    // (4647.58+(500*4647.58)/5000)
    assert(pairDispatcher.total_supply() == 5112338016993790288435, 'Total supply ~eq 5112');
}

#[test]
#[available_gas(200000000)]
fn test_vPair_swap_token0_for_token1() {
    let stable = false;
    let feeTier = 0;
    let (mut pairDispatcher, mut accountDispatcher) = add_initial_liquidity(
        false, 5000, 3000, stable, feeTier
    );
    let token0Dispatcher = token_at(pairDispatcher.token0());
    let token1Dispatcher = token_at(pairDispatcher.token1());

    // swap
    swap(ref pairDispatcher, ref accountDispatcher, with_decimals(30), 0, with_decimals(17), false);
    let (res0, res1, _) = pairDispatcher.get_reserves();

    let _5030 = 5029910000000000000000;
    let _2983 = with_decimals(2983);

    assert(res0 == _5030, 'Reserve 1 eq 5030');
    assert(res1 == _2983, 'Reserve 2 eq 2983');

    assert(
        token0Dispatcher.balance_of(pairDispatcher.contract_address) == _5030,
        'Token0 balance eq 5030'
    );
    assert(
        token1Dispatcher.balance_of(pairDispatcher.contract_address) == _2983,
        'Token1 balance eq 2983'
    );

    assert(
        token0Dispatcher.balance_of(accountDispatcher.contract_address) == with_decimals(4970),
        'Token0 balance eq 4970'
    );
    assert(
        token1Dispatcher.balance_of(accountDispatcher.contract_address) == with_decimals(7017),
        'Token1 balance eq 7017'
    )
}

#[test]
#[available_gas(20000000)]
fn test_vPair_swap_token1_for_token0() {
    let stable = false;
    let feeTier = 0;
    let (mut pairDispatcher, mut accountDispatcher) = add_initial_liquidity(
        false, 5000, 3000, stable, feeTier
    );
    let token0Dispatcher = token_at(pairDispatcher.token0());
    let token1Dispatcher = token_at(pairDispatcher.token1());

    // swap
    swap(ref pairDispatcher, ref accountDispatcher, with_decimals(50), with_decimals(81), 0, false);
    let (res0, res1, _) = pairDispatcher.get_reserves();

    let _4919 = with_decimals(4919);
    let _3050 = 3049850000000000000000;
    assert(res0 == _4919, 'Reserve 0 eq 4919');
    assert(res1 == _3050, 'Reserve 1 ~eq 3050');
    assert(
        token0Dispatcher.balance_of(pairDispatcher.contract_address) == _4919,
        'Token0 balance eq 4919'
    );
    assert(
        token1Dispatcher.balance_of(pairDispatcher.contract_address) == _3050,
        'Token1 balance eq 3050'
    );
}


#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('PAIR: invariant K', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED'))]
fn test_vPair_swap_invariant_k() {
    let stable = false;
    let feeTier = 0;
    let (mut pairDispatcher, mut accountDispatcher) = add_initial_liquidity(
        false, 5000, 3000, stable, feeTier
    );
    // swap
    swap(ref pairDispatcher, ref accountDispatcher, 50, 100, 0, false);
}

#[test]
#[available_gas(200000000)]
fn test_vPair_get_amount_out() {
    let (pairDispatcher, accountDispatcher) = add_initial_liquidity(false, 5000, 4103, false, 0);
    let amountIn = with_decimals(100);
    let tokenIn = pairDispatcher.token0();

    let amountOut = pairDispatcher.get_amount_out(tokenIn, amountIn);
    assert(amountOut == 80214345941918152048, 'amount out eq 8021...');

    let tokenIn = pairDispatcher.token1();
    let amountIn = with_decimals(690);
    let amountOut = pairDispatcher.get_amount_out(tokenIn, amountIn);
    assert(amountOut == 717950377066665553452, 'amount out eq 8021...');
}
