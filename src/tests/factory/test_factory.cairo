use array::ArrayTrait;
use option::OptionTrait;
use starknet::{ContractAddress, contract_address_const};

use starkDefi::dex::v1::factory::StarkDFactory;
use starkDefi::dex::v1::factory::StarkDFactory::StarkDFactoryImpl;
use starkDefi::dex::v1::factory::StarkDFactory::InternalFunctions;
use starkDefi::dex::v1::factory::StarkDFactory::PairCreated;
use starkDefi::dex::v1::factory::IStarkDFactoryDispatcher;
use starkDefi::dex::v1::factory::IStarkDFactoryDispatcherTrait;
use starkDefi::token::erc20::interface::ERC20ABIDispatcher;
use starkDefi::token::erc20::interface::ERC20ABIDispatcherTrait;
use starkDefi::tests::utils::constants::{
    FEE_TO_SETTER, ADDRESS_ZERO, ADDRESS_ONE, ADDRESS_TWO, ADDRESS_THREE, PAIR_CLASS_HASH,
    PAIR_FEES_CLASS_HASH, TOTAL_SUPPLY
};
use starkDefi::tests::utils::deploy_erc20;
use starkDefi::tests::utils::functions::{drop_event, pop_log, deploy};
use starknet::testing;

//
// Setup
//

fn deploy_factory(address: ContractAddress) -> IStarkDFactoryDispatcher {
    let mut calldata = array![];
    if address != ADDRESS_ZERO() {
        Serde::serialize(@address, ref calldata);
    } else {
        Serde::serialize(@FEE_TO_SETTER(), ref calldata);
    }
    Serde::serialize(@PAIR_CLASS_HASH(), ref calldata);
    Serde::serialize(@PAIR_FEES_CLASS_HASH(), ref calldata);

    let address = deploy(StarkDFactory::TEST_CLASS_HASH, calldata);
    IStarkDFactoryDispatcher { contract_address: address }
}

fn deploy_tokens() -> (ContractAddress, ContractAddress) {
    let account = contract_address_const::<1>();
    let total_supply = TOTAL_SUPPLY(1_000_000_000);

    let token0 = deploy_erc20('Token0', 'TK0', total_supply, account);
    let token1 = deploy_erc20('Token1', 'TK1', total_supply, account);

    (token0.contract_address, token1.contract_address)
}

fn STATE() -> StarkDFactory::ContractState {
    StarkDFactory::contract_state_for_testing()
}

fn setup() -> StarkDFactory::ContractState {
    let mut state = STATE();
    StarkDFactory::constructor(
        ref state, FEE_TO_SETTER(), PAIR_CLASS_HASH(), PAIR_FEES_CLASS_HASH()
    );
    state
}

//
// constructor
//

#[test]
#[available_gas(2000000)]
fn test_constructor() {
    let mut state = STATE();
    StarkDFactory::constructor(
        ref state, FEE_TO_SETTER(), PAIR_CLASS_HASH(), PAIR_FEES_CLASS_HASH()
    );

    assert(StarkDFactoryImpl::fee_to(@state) == FEE_TO_SETTER(), 'FeeTo eq FEE_TO_SETTER');
    assert(
        StarkDFactoryImpl::fee_handler(@state) == FEE_TO_SETTER(), 'FeeToSetter eq FEE_TO_SETTER'
    );
    assert(
        StarkDFactoryImpl::class_hash_for_pair_contract(@state) == PAIR_CLASS_HASH(),
        'class_hash eq pair_class_hash'
    );
    assert(StarkDFactoryImpl::get_fees(@state) == (4, 30), 'get_fees eq (4, 30)');
    assert(StarkDFactoryImpl::all_pairs_length(@state) == 0, 'pair_len eq 0');
}

#[test]
#[available_gas(2000000)]
fn test_deployed_factory() {
    let factory = deploy_factory(FEE_TO_SETTER());

    assert(factory.fee_to() == FEE_TO_SETTER(), 'FeeTo eq FEE_TO_SETTER');
    assert(factory.fee_handler() == FEE_TO_SETTER(), 'FeeToSetter eq FEE_TO_SETTER');
    assert(
        factory.class_hash_for_pair_contract() == PAIR_CLASS_HASH(), 'class_hash eq pair_class_hash'
    );
    assert(factory.get_fees() == (4, 30), 'get_fees eq (4, 30)');
    assert(factory.all_pairs_length() == 0, 'pair_len eq 0');
}

//
// Getters
//

#[test]
#[available_gas(2000000)]
fn test_fee_to() {
    let mut state = setup();
    assert(StarkDFactoryImpl::fee_to(@state) == FEE_TO_SETTER(), 'FeeTo eq FEE_TO_SETTER');
}

#[test]
#[available_gas(2000000)]
fn test_get_fees() {
    let mut state = setup();
    assert(StarkDFactoryImpl::get_fees(@state) == (4, 30), 'get_fees eq (4, 30)');
}

#[test]
#[available_gas(2000000)]
fn test_fee_handler() {
    let mut state = setup();
    assert(
        StarkDFactoryImpl::fee_handler(@state) == FEE_TO_SETTER(), 'feeHandler eq FEE_TO_SETTER'
    );
}

#[test]
#[available_gas(2000000)]
fn test_class_hash_for_pair_contract() {
    let mut state = setup();
    assert(
        StarkDFactoryImpl::class_hash_for_pair_contract(@state) == PAIR_CLASS_HASH(),
        'class_hash eq pair_class_hash'
    );
}

#[test]
#[available_gas(2000000)]
fn test_all_pairs_length() {
    let mut state = setup();
    assert(StarkDFactoryImpl::all_pairs_length(@state) == 0, 'pair_len eq 0');
}

#[test]
#[available_gas(20000000)]
fn test_get_pair() {
    let mut state = setup();
    let (token0, token1) = deploy_tokens();
    let pair = StarkDFactoryImpl::create_pair(ref state, token0, token1, false);
    let got_pair = StarkDFactoryImpl::get_pair(@state, token0, token1, false);
    assert(got_pair == pair, 'got_pair eq `pair`');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('StarkDefi: PAIR_NOT_FOUND',))]
fn test_get_pair_not_found() {
    let mut state = setup();
    let pair = StarkDFactoryImpl::get_pair(@state, ADDRESS_ONE(), ADDRESS_TWO(), false);
    assert(pair != ADDRESS_ZERO(), 'StarkDefi: PAIR_NOT_FOUND');
}

#[test]
#[available_gas(2000000)]
fn test_all_pairs() {
    let mut state = setup();
    let (len, pairs) = StarkDFactoryImpl::all_pairs(@state);
    assert(len == 0, 'len eq 0');
    assert(pairs.len() == 0, 'pairs len eq 0');
}

//
// create pair

#[test]
#[available_gas(20000000)]
fn test_create_pair() {
    let mut state = setup();
    let (token0, token1) = deploy_tokens();
    let pair = StarkDFactoryImpl::create_pair(ref state, token0, token1, false);

    assert_event_pair_created(@state, token0, token1, pair, 1);
    assert(pair != ADDRESS_ZERO(), 'pair neq 0');
    assert(StarkDFactoryImpl::all_pairs_length(@state) == 1, 'pair_len eq 1');
    let (len, pairs) = StarkDFactoryImpl::all_pairs(@state);
    assert(len == 1, 'len eq 1');
    assert(pairs.len() == 1, 'pairs len eq 1');
    assert(*pairs.at(0) == pair, 'pairs[0] eq `pair`');

    let got_pair = StarkDFactoryImpl::get_pair(@state, token0, token1, false);
    assert(got_pair == pair, 'got_pair eq `pair`');
}

#[test]
#[available_gas(20000000)]
fn test_deployed_create_pair() {
    let factory = deploy_factory(ADDRESS_ZERO());
    let (token0, token1) = deploy_tokens();

    let pair = factory.create_pair(token0, token1, true);

    let event = testing::pop_log::<PairCreated>(factory.contract_address).unwrap();

    assert(event.pair == pair, 'pair eq `pair`');
    assert(event.pair_count == 1, 'pair_count eq 1');
}

#[test]
#[available_gas(20000000)]
// need tokens to be deployed
fn test_create_pair_twice() {
    let mut state = setup();
    let (token0, token1) = deploy_tokens();
    let pair1 = StarkDFactoryImpl::create_pair(ref state, token0, token1, false);
    drop_event(ADDRESS_ZERO());
    let pair2 = StarkDFactoryImpl::create_pair(ref state, token0, token1, true);

    assert_event_pair_created(@state, token0, token1, pair2, 2);
    assert(pair1 != ADDRESS_ZERO(), 'pair1 neq 0');
    assert(pair2 != pair1, 'pair2 neq pair1');
    assert(StarkDFactoryImpl::all_pairs_length(@state) == 2, 'pair_len eq 2');
    let (len, pairs) = StarkDFactoryImpl::all_pairs(@state);
    assert(len == 2, 'len eq 2');
    assert(pairs.len() == 2, 'pairs len eq 2');
    assert(*pairs.at(0) == pair1, 'pairs[0] eq `pair1`');

    let got_pair1 = StarkDFactoryImpl::get_pair(@state, token0, token1, false);
    assert(got_pair1 == pair1, 'got_pair eq `pair1`');
    let got_pair2 = StarkDFactoryImpl::get_pair(@state, token0, token1, true);
    assert(got_pair2 == pair2, 'got_pair eq `pair1`');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('invalid token address',))]
fn test_create_pair_invalid_token() {
    let mut state = setup();
    StarkDFactoryImpl::create_pair(ref state, ADDRESS_ZERO(), ADDRESS_TWO(), false);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('identical addresses',))]
fn test_create_pair_identical_token() {
    let mut state = setup();
    StarkDFactoryImpl::create_pair(ref state, ADDRESS_ONE(), ADDRESS_ONE(), false);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('pair exists',))]
fn test_create_pair_pair_exists() {
    let mut state = setup();
    let (token0, token1) = deploy_tokens();
    StarkDFactoryImpl::create_pair(ref state, token0, token1, true);
    StarkDFactoryImpl::create_pair(ref state, token0, token1, true);
}


//
// set fee to
//

#[test]
#[available_gas(2000000)]
fn test_set_fee_to() {
    let mut state = setup();
    testing::set_caller_address(FEE_TO_SETTER());
    StarkDFactoryImpl::set_fee_to(ref state, ADDRESS_ONE());
    assert(StarkDFactoryImpl::fee_to(@state) == ADDRESS_ONE(), 'FeeTo eq ADDRESS_ONE');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('not allowed',))]
fn test_set_fee_to_not_allowed() {
    let mut state = setup();
    testing::set_caller_address(ADDRESS_ONE());
    StarkDFactoryImpl::set_fee_to(ref state, ADDRESS_ONE());
}

//
// set fees
//

#[test]
#[available_gas(2000000)]
fn test_set_fees() {
    let mut state = setup();
    testing::set_caller_address(FEE_TO_SETTER());

    // volatile
    StarkDFactoryImpl::set_fee(ref state, 35, false);
    assert(StarkDFactoryImpl::get_fees(@state) == (4, 35), 'get_fees eq (4, 35)');

    // stable
    StarkDFactoryImpl::set_fee(ref state, 10, true);
    assert(StarkDFactoryImpl::get_fees(@state) == (10, 35), 'get_fees eq (10, 35)');

}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('not allowed',))]
fn test_set_fees_not_allowed() {
    let mut state = setup();
    testing::set_caller_address(ADDRESS_ONE());
    StarkDFactoryImpl::set_fee(ref state, 35, false);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('invalid fee',))]
fn test_set_fees_invalid() {
    let mut state = setup();
    testing::set_caller_address(FEE_TO_SETTER());
    StarkDFactoryImpl::set_fee(ref state, 0, false);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('invalid fee',))]
fn test_set_fees_max() {
    let mut state = setup();
    testing::set_caller_address(FEE_TO_SETTER());
    StarkDFactoryImpl::set_fee(ref state, 101, false);
}

//
// set custom pair fee
//
#[test]
#[available_gas(20000000)]
fn test_set_custom_pair_fee() {
    let mut state = setup();
    let (token0, token1) = deploy_tokens();
    let vPair = StarkDFactoryImpl::create_pair(ref state, token0, token1, false);
    let sPair = StarkDFactoryImpl::create_pair(ref state, token0, token1, true);

    // get default fees
    let vFees = StarkDFactoryImpl::get_fee(@state, vPair);
    let sFees = StarkDFactoryImpl::get_fee(@state, sPair);
    assert(vFees == 30, 'vFees eq 4');
    assert(sFees == 4, 'sFees eq 30');

    // set custom fees
    testing::set_caller_address(FEE_TO_SETTER());
    StarkDFactoryImpl::set_custom_pair_fee(ref state, vPair, 50);
    StarkDFactoryImpl::set_custom_pair_fee(ref state, sPair, 10);

    assert(StarkDFactoryImpl::get_fee(@state, vPair) == 50, 'vFees eq 50');
    assert(StarkDFactoryImpl::get_fee(@state, sPair) == 10, 'sFees eq 10');
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('not allowed',))]
fn test_set_custom_pair_fee_not_allowed() {
    let mut state = setup();
    let (token0, token1) = deploy_tokens();
    let vPair = StarkDFactoryImpl::create_pair(ref state, token0, token1, false);
    testing::set_caller_address(ADDRESS_ONE());
    StarkDFactoryImpl::set_custom_pair_fee(ref state, vPair, 50);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('fee too high',))]
fn test_set_custom_pair_fee_too_high() {
    let mut state = setup();
    let (token0, token1) = deploy_tokens();
    let vPair = StarkDFactoryImpl::create_pair(ref state, token0, token1, false);
    testing::set_caller_address(FEE_TO_SETTER());
    StarkDFactoryImpl::set_custom_pair_fee(ref state, vPair, 101);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('invalid pair',))]
fn test_set_custom_pair_fee_invalid_pair() {
    let mut state = setup();
    testing::set_caller_address(FEE_TO_SETTER());
    StarkDFactoryImpl::set_custom_pair_fee(ref state, ADDRESS_ZERO(), 50);
}

//
// set fee handler
//

#[test]
#[available_gas(2000000)]
fn test_set_fee_handler() {
    let mut state = setup();
    testing::set_caller_address(FEE_TO_SETTER());
    StarkDFactoryImpl::set_fee_handler(ref state, ADDRESS_ONE());
    assert(StarkDFactoryImpl::fee_handler(@state) == ADDRESS_ONE(), 'FeeToSetter eq ADDRESS_ONE');
}

#[test]
#[available_gas(2000000)]
fn test_set_fee_handler_new_handler() {
    let mut state = setup();
    testing::set_caller_address(FEE_TO_SETTER());
    StarkDFactoryImpl::set_fee_handler(ref state, ADDRESS_ONE());
    assert(StarkDFactoryImpl::fee_handler(@state) == ADDRESS_ONE(), 'FeeToSetter eq ADDRESS_ONE');
    testing::set_caller_address(ADDRESS_ONE());
    StarkDFactoryImpl::set_fee_handler(ref state, ADDRESS_TWO());
    assert(StarkDFactoryImpl::fee_handler(@state) == ADDRESS_TWO(), 'FeeToSetter eq ADDRESS_TWO');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('not allowed',))]
fn test_set_fee_handler_not_allowed() {
    let mut state = setup();
    testing::set_caller_address(ADDRESS_ONE());
    StarkDFactoryImpl::set_fee_handler(ref state, ADDRESS_ONE());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('invalid handler address',))]
fn test_set_fee_handler_invalid() {
    let mut state = setup();
    testing::set_caller_address(FEE_TO_SETTER());
    StarkDFactoryImpl::set_fee_handler(ref state, ADDRESS_ZERO());
}

//
// internal functions
//

#[test]
#[available_gas(2000000)]
fn test_sort_tokens() {
    let mut state = setup();
    let (token0, token1) = InternalFunctions::sort_tokens(@state, ADDRESS_ONE(), ADDRESS_TWO());
    assert(token0 == ADDRESS_ONE(), 'token0 eq ADDRESS_ONE');
    assert(token1 == ADDRESS_TWO(), 'token1 eq ADDRESS_TWO');

    let (token0, token1) = InternalFunctions::sort_tokens(@state, ADDRESS_TWO(), ADDRESS_ONE());
    assert(token0 == ADDRESS_ONE(), 'token0 eq ADDRESS_TWO');
    assert(token1 == ADDRESS_TWO(), 'token1 eq ADDRESS_ONE');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('identical addresses',))]
fn test_sort_tokens_identical() {
    let mut state = setup();
    InternalFunctions::sort_tokens(@state, ADDRESS_ONE(), ADDRESS_ONE());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('invalid token0',))]
fn test_sort_tokens_invalid_token0() {
    let mut state = setup();
    InternalFunctions::sort_tokens(@state, ADDRESS_ZERO(), ADDRESS_ONE());
}


//
// utils
//

fn assert_event_pair_created(
    state: @StarkDFactory::ContractState,
    tokenA: ContractAddress,
    tokenB: ContractAddress,
    pair: ContractAddress,
    pair_count: u32
) {
    // let (token0, token1) = InternalFunctions::sort_tokens(state, tokenA, tokenB);
    let event = pop_log::<PairCreated>(ADDRESS_ZERO()).unwrap();
    assert(event.pair == pair, 'pair eq `pair`');
    assert(event.pair_count == pair_count, 'pair_count eq `pair_count`');
}
