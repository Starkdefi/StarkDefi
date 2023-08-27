use array::ArrayTrait;
use option::OptionTrait;
use starknet::ContractAddress;

use starkDefi::dex::v1::factory::StarkDFactory;
use starkDefi::dex::v1::factory::StarkDFactory::StarkDFactoryImpl;
use starkDefi::dex::v1::factory::StarkDFactory::InternalFunctions;
use starkDefi::dex::v1::factory::StarkDFactory::PairCreated;
use starkDefi::tests::utils::constants::{
    FEE_TO_SETTER, FEE_TO, ADDRESS_ZERO, ADDRESS_ONE, ADDRESS_TWO,ADDRESS_THREE, PAIR_CLASS_HASH
};
use starkDefi::tests::utils::functions::{drop_event, pop_log, deploy};
use starkDefi::utils::{ContractAddressPartialOrd};
use starknet::testing;

//
// Setup
//

fn STATE() -> StarkDFactory::ContractState {
    StarkDFactory::contract_state_for_testing()
}

fn setup() -> StarkDFactory::ContractState {
    let mut state = STATE();
    StarkDFactory::constructor(ref state, FEE_TO_SETTER(), PAIR_CLASS_HASH());
    state
}

//
// constructor
//

#[test]
#[available_gas(2000000)]
fn test_constructor() {
    let mut state = STATE();
    StarkDFactory::constructor(ref state, FEE_TO_SETTER(), PAIR_CLASS_HASH());

    assert(StarkDFactoryImpl::fee_to(@state) == ADDRESS_ZERO(), 'FeeTo eq 0');
    assert(
        StarkDFactoryImpl::fee_to_setter(@state) == FEE_TO_SETTER(), 'FeeToSetter eq FEE_TO_SETTER'
    );
    assert(
        StarkDFactoryImpl::class_hash_for_pair_contract(@state) == PAIR_CLASS_HASH(),
        'class_hash eq pair_class_hash'
    );
    assert(StarkDFactoryImpl::all_pairs_length(@state) == 0, 'pair_len eq 0');
}

//
// Getters
//

#[test]
#[available_gas(2000000)]
fn test_fee_to() {
    let mut state = setup();
    assert(StarkDFactoryImpl::fee_to(@state) == ADDRESS_ZERO(), 'FeeTo eq 0');
}

#[test]
#[available_gas(2000000)]
fn test_fee_to_setter() {
    let mut state = setup();
    assert(
        StarkDFactoryImpl::fee_to_setter(@state) == FEE_TO_SETTER(), 'FeeToSetter eq FEE_TO_SETTER'
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
#[available_gas(2000000)]
fn test_get_pair() {
    let mut state = setup();
    let pair = StarkDFactoryImpl::create_pair(ref state, ADDRESS_ONE(), ADDRESS_TWO());
    let got_pair = StarkDFactoryImpl::get_pair(@state, ADDRESS_ONE(), ADDRESS_TWO());
    assert(got_pair == pair, 'got_pair eq `pair`');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('StarkDefi: PAIR_NOT_FOUND',))]
fn test_get_pair_not_found() {
    let mut state = setup();
    let pair = StarkDFactoryImpl::get_pair(@state, ADDRESS_ONE(), ADDRESS_TWO());
    assert(pair == ADDRESS_ZERO(), 'pair eq 0');
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
#[available_gas(2000000)]
fn test_create_pair() {
    let mut state = setup();
    let pair = StarkDFactoryImpl::create_pair(ref state, ADDRESS_ONE(), ADDRESS_TWO());

    assert_event_pair_created(@state, ADDRESS_ONE(), ADDRESS_TWO(), pair, 1);
    assert(pair != ADDRESS_ZERO(), 'pair neq 0');
    assert(StarkDFactoryImpl::all_pairs_length(@state) == 1, 'pair_len eq 1');
    let (len, pairs) = StarkDFactoryImpl::all_pairs(@state);
    assert(len == 1, 'len eq 1');
    assert(pairs.len() == 1, 'pairs len eq 1');
    assert(*pairs.at(0) == pair, 'pairs[0] eq `pair`');

    let got_pair = StarkDFactoryImpl::get_pair(@state, ADDRESS_ONE(), ADDRESS_TWO());
    assert(got_pair == pair, 'got_pair eq `pair`');
}

#[test]
#[available_gas(2000000)]
fn test_create_pair_twice() {
    let mut state = setup();
    let pair1 = StarkDFactoryImpl::create_pair(ref state, ADDRESS_ONE(), ADDRESS_TWO());
    drop_event(ADDRESS_ZERO());
    let pair2 = StarkDFactoryImpl::create_pair(ref state, ADDRESS_THREE(), ADDRESS_TWO());

    assert_event_pair_created(@state, ADDRESS_ONE(), ADDRESS_TWO(), pair2, 2);
    assert(pair1 != ADDRESS_ZERO(), 'pair1 neq 0');
    assert(pair2 != pair1, 'pair2 neq pair1');
    assert(StarkDFactoryImpl::all_pairs_length(@state) == 2, 'pair_len eq 2');
    let (len, pairs) = StarkDFactoryImpl::all_pairs(@state);
    assert(len == 2, 'len eq 2');
    assert(pairs.len() == 2, 'pairs len eq 2');
    assert(*pairs.at(0) == pair1, 'pairs[0] eq `pair1`');

    let got_pair = StarkDFactoryImpl::get_pair(@state, ADDRESS_THREE(), ADDRESS_TWO());
    assert(got_pair == pair2, 'got_pair eq `pair1`');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('invalid token address',))]
fn test_create_pair_invalid_token() {
    let mut state = setup();
    StarkDFactoryImpl::create_pair(ref state, ADDRESS_ZERO(), ADDRESS_TWO());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('identical addresses',))]
fn test_create_pair_identical_token() {
    let mut state = setup();
    StarkDFactoryImpl::create_pair(ref state, ADDRESS_ONE(), ADDRESS_ONE());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('pair exists',))]
fn test_create_pair_pair_exists() {
    let mut state = setup();
    StarkDFactoryImpl::create_pair(ref state, ADDRESS_ONE(), ADDRESS_TWO());
    StarkDFactoryImpl::create_pair(ref state, ADDRESS_ONE(), ADDRESS_TWO());
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
// set fee to setter
//

#[test]
#[available_gas(2000000)]
fn test_set_fee_to_setter() {
    let mut state = setup();
    testing::set_caller_address(FEE_TO_SETTER());
    StarkDFactoryImpl::set_fee_to_setter(ref state, ADDRESS_ONE());
    assert(
        StarkDFactoryImpl::fee_to_setter(@state) == ADDRESS_ONE(), 'FeeToSetter eq ADDRESS_ONE'
    );
}

#[test]
#[available_gas(2000000)]
fn test_set_fee_to_setter_new_setter() {
    let mut state = setup();
    testing::set_caller_address(FEE_TO_SETTER());
    StarkDFactoryImpl::set_fee_to_setter(ref state, ADDRESS_ONE());
    assert(
        StarkDFactoryImpl::fee_to_setter(@state) == ADDRESS_ONE(), 'FeeToSetter eq ADDRESS_ONE'
    );
    testing::set_caller_address(ADDRESS_ONE());
    StarkDFactoryImpl::set_fee_to_setter(ref state, ADDRESS_TWO());
    assert(
        StarkDFactoryImpl::fee_to_setter(@state) == ADDRESS_TWO(), 'FeeToSetter eq ADDRESS_TWO'
    );
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('not allowed',))]
fn test_set_fee_to_setter_not_allowed() {
    let mut state = setup();
    testing::set_caller_address(ADDRESS_ONE());
    StarkDFactoryImpl::set_fee_to_setter(ref state, ADDRESS_ONE());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('invalid fee to setter',))]
fn test_set_fee_to_setter_invalid() {
    let mut state = setup();
    testing::set_caller_address(FEE_TO_SETTER());
    StarkDFactoryImpl::set_fee_to_setter(ref state, ADDRESS_ZERO());
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
