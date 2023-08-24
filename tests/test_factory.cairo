use snforge_std::{declare, PreparedContract, deploy, PrintTrait, start_prank, stop_prank};


use array::ArrayTrait;
use result::ResultTrait;
use starknet::ContractAddress;
use starknet::ClassHash;
use starknet::contract_address_const;
use starkDefi::dex::v1::factory::{IStarkDFactoryDispatcher, IStarkDFactoryDispatcherTrait};
use starkDefi::dex::v1::pair::{IStarkDPairDispatcher, IStarkDPairDispatcherTrait};

fn deploy_factory() -> (ClassHash, ContractAddress) {
    let ADDRESS_ONE = contract_address_const::<1>();
    let pair_class_hash = declare('StarkDPair');
    let class_hash = declare('StarkDFactory');

    let mut callData = Default::default();
    Serde::serialize(@ADDRESS_ONE, ref callData);
    Serde::serialize(@pair_class_hash, ref callData);

    let prepared = PreparedContract { class_hash: class_hash, constructor_calldata: @callData };

    let factory_address = deploy(prepared).unwrap();
    (pair_class_hash, factory_address)
}

#[test]
fn feeTo_feeToSetter_allPairLength_classHash() {
    let ADDRESS_ZERO = contract_address_const::<0>();
    let ADDRESS_ONE = contract_address_const::<1>();

    let (pair_class_hash, factory_address) = deploy_factory();
    let factory = IStarkDFactoryDispatcher { contract_address: factory_address };

    let feeToSetter = factory.fee_to_setter();
    assert(feeToSetter == ADDRESS_ONE, 'feeTo == address 1');

    let feeTo = factory.fee_to();
    assert(feeTo == ADDRESS_ZERO, 'feeTo == address 0');

    let (allPairsLen, _) = factory.all_pairs();
    assert(allPairsLen == 0, 'allPairs == 0');

    let pair_classHash = factory.class_hash_for_pair_contract();
    assert(pair_classHash == pair_class_hash, 'pair class hash mismatch');
}

fn create_pair(token0: ContractAddress, token1: ContractAddress) -> ContractAddress {
    let ADDRESS_ZERO = contract_address_const::<0>();

    let (pair_class_hash, factory_address) = deploy_factory();
    let factory = IStarkDFactoryDispatcher { contract_address: factory_address };

    let pair_address = factory.create_pair(token0, token1);
    assert(pair_address != ADDRESS_ZERO, 'invalid pair');

    let (allPairsLen, pairs) = factory.all_pairs();
    assert(allPairsLen == 1, 'length mismatch');
    assert(*pairs.at(0) == pair_address, 'pair mismatch');

    let pairLength = factory.all_pairs_length();
    assert(pairLength == 1, 'length mismatch');
    assert(allPairsLen == pairLength, 'length mismatch');

    let pair = IStarkDPairDispatcher { contract_address: pair_address };
    assert(pair.factory() == factory_address, 'factory mismatch');
    assert(pair.token0() == token0, 'token0 mismatch');
    assert(pair.token1() == token1, 'token1 mismatch');

    pair_address
}

#[test]
fn create_pair_test() {
    let token0 = contract_address_const::<2>();
    let token1 = contract_address_const::<3>();

    let pair_address = create_pair(token0, token1);
}

#[test]
#[should_panic(expected: ('invalid token address',))]
fn create_pair_0() {
    let token0 = contract_address_const::<0>();
    let token1 = contract_address_const::<3>();
    let pair2 = create_pair(token1, token0);
}

#[test]
#[should_panic(expected: ('identical addresses',))]
fn create_pair_same_address() {
    let token0 = contract_address_const::<3>();
    let token1 = contract_address_const::<3>();
    let pair2 = create_pair(token1, token0);
}

#[test]
fn create_pair_reversed() {
    let token0 = contract_address_const::<1>();
    let token1 = contract_address_const::<2>();

    let (_, factory_address) = deploy_factory();
    let factory = IStarkDFactoryDispatcher { contract_address: factory_address };

    let pair1 = factory.create_pair(token0, token1);
    let pair2 = factory.get_pair(token1, token0);
    assert(pair1 == pair2, 'pair mismatch');
}

#[test]
fn create_pair_multiple() {
    let token0 = contract_address_const::<1>();
    let token1 = contract_address_const::<2>();
    let token2 = contract_address_const::<3>();

    let (_, factory_address) = deploy_factory();
    let factory = IStarkDFactoryDispatcher { contract_address: factory_address };
    assert(factory.all_pairs_length() == 0, 'length mismatch');

    let pair1 = factory.create_pair(token0, token1);
    let pair2 = factory.create_pair(token0, token2);
    let pair3 = factory.create_pair(token1, token2);

    assert(factory.all_pairs_length() == 3, 'length mismatch');
}

#[test]
fn set_fee_to_setter() {
    let ADDRESS_ONE = contract_address_const::<1>();
    let ADDRESS_TWO = contract_address_const::<2>();

    let (_, factory_address) = deploy_factory();
    let factory = IStarkDFactoryDispatcher { contract_address: factory_address };
    assert(factory.fee_to_setter() == ADDRESS_ONE, 'feeToSetter == address 1');

    start_prank(factory_address, ADDRESS_ONE);
    factory.set_fee_to_setter(ADDRESS_TWO);
    stop_prank(factory_address);

    assert(factory.fee_to_setter() == ADDRESS_TWO, 'feeToSetter == address 2');
}

#[test]
fn set_fee_to() {
    let ADDRESS_ZERO = contract_address_const::<0>();
    let ADDRESS_ONE = contract_address_const::<1>();

    let (_, factory_address) = deploy_factory();
    let factory = IStarkDFactoryDispatcher { contract_address: factory_address };
    assert(factory.fee_to() == ADDRESS_ZERO, 'feeTo == address 0');

    start_prank(factory_address, ADDRESS_ONE);
    factory.set_fee_to(ADDRESS_ONE);
    stop_prank(factory_address);

    assert(factory.fee_to() == ADDRESS_ONE, 'feeTo == address 1');
}

#[test]
#[should_panic(expected: ('not allowed',))]
fn set_fee_to_setter_fail() {
    let ADDRESS_TWO = contract_address_const::<2>();

    let (_, factory_address) = deploy_factory();
    let factory = IStarkDFactoryDispatcher { contract_address: factory_address };

    factory.set_fee_to_setter(ADDRESS_TWO);
}

#[test]
#[should_panic(expected: ('invalid fee to setter',))]
fn set_fee_to_setter_address_0() {
    let ADDRESS_ZERO = contract_address_const::<0>();
    let ADDRESS_ONE = contract_address_const::<1>();

    let (_, factory_address) = deploy_factory();
    let factory = IStarkDFactoryDispatcher { contract_address: factory_address };

    start_prank(factory_address, ADDRESS_ONE);
    factory.set_fee_to_setter(ADDRESS_ZERO);
}

#[test]
#[should_panic(expected: ('not allowed',))]
fn set_fee_to_fail() {
    let ADDRESS_ONE = contract_address_const::<1>();

    let (_, factory_address) = deploy_factory();
    let factory = IStarkDFactoryDispatcher { contract_address: factory_address };

    factory.set_fee_to(ADDRESS_ONE);
}
