use starkDefi::token::erc20::ERC20;
use starkDefi::token::erc20::ERC20::Transfer;
use starkDefi::token::erc20::ERC20::Approval;
use starkDefi::token::erc20::ERC20ABIDispatcher;
use starkDefi::token::erc20::ERC20ABIDispatcherTrait;
use starkDefi::tests::utils::constants::{OWNER, ADDRESS_ZERO};
use array::ArrayTrait;
use array::SpanTrait;
use core::result::ResultTrait;
use option::OptionTrait;
use starknet::class_hash::Felt252TryIntoClassHash;
use starknet::ContractAddress;
use starknet::testing;
use traits::TryInto;

fn deploy(contract_class_hash: felt252, calldata: Array<felt252>) -> ContractAddress {
    let (address, _) = starknet::deploy_syscall(
        contract_class_hash.try_into().unwrap(), 0, calldata.span(), false
    )
        .unwrap();
    address
}

fn deploy_erc20(
    name: felt252, symbol: felt252, initial_supply: u256, recipient: ContractAddress
) -> ERC20ABIDispatcher {
    let mut calldata = array![];
    Serde::serialize(@name, ref calldata);
    Serde::serialize(@symbol, ref calldata);
    Serde::serialize(@initial_supply, ref calldata);
    Serde::serialize(@recipient, ref calldata);
    let address = deploy(ERC20::TEST_CLASS_HASH, calldata);
    ERC20ABIDispatcher { contract_address: address }
}

fn token_at(address: ContractAddress) -> ERC20ABIDispatcher {
    ERC20ABIDispatcher { contract_address: address }
}

// OZ
/// Pop the earliest unpopped logged event for the contract as the requested type
/// and checks there's no more data left on the event, preventing unaccounted params.
/// Indexed event members are currently not supported, so they are ignored.
fn pop_log<T, impl TDrop: Drop<T>, impl TEvent: starknet::Event<T>>(
    address: ContractAddress
) -> Option<T> {
    let (mut keys, mut data) = testing::pop_log_raw(address)?;
    let ret = starknet::Event::deserialize(ref keys, ref data);
    assert(data.is_empty(), 'Event has extra data');
    ret
}

fn assert_no_events_left(address: ContractAddress) {
    assert(testing::pop_log_raw(address).is_none(), 'Events remaining on queue');
}

fn drop_event(address: ContractAddress) {
    testing::pop_log_raw(address);
}


fn erc20_state() -> ERC20::ContractState {
    ERC20::contract_state_for_testing()
}

fn setup_erc20(name: felt252, symbol: felt252, supply: u256) -> ERC20::ContractState {
    let mut state = erc20_state();
    ERC20::constructor(ref state, name, symbol, supply, OWNER());
    drop_event(ADDRESS_ZERO());
    state
}

fn assert_event_approval(owner: ContractAddress, spender: ContractAddress, value: u256) {
    let event = pop_log::<Approval>(ADDRESS_ZERO()).unwrap();
    assert(event.owner == owner, 'Invalid `owner`');
    assert(event.spender == spender, 'Invalid `spender`');
    assert(event.value == value, 'Invalid `value`');
}

fn assert_only_event_approval(owner: ContractAddress, spender: ContractAddress, value: u256) {
    assert_event_approval(owner, spender, value);
    assert_no_events_left(ADDRESS_ZERO());
}

fn assert_event_transfer(from: ContractAddress, to: ContractAddress, value: u256) {
    let event = pop_log::<Transfer>(ADDRESS_ZERO()).unwrap();
    assert(event.from == from, 'Invalid `from`');
    assert(event.to == to, 'Invalid `to`');
    assert(event.value == value, 'Invalid `value`');
}

fn assert_only_event_transfer(from: ContractAddress, to: ContractAddress, value: u256) {
    assert_event_transfer(from, to, value);
    assert_no_events_left(ADDRESS_ZERO());
}

use serde::Serde;

trait SerializedAppend<T> {
    fn append_serde(ref self: Array<felt252>, value: T);
}

impl SerializedAppendImpl<T, impl TSerde: Serde<T>, impl TDrop: Drop<T>> of SerializedAppend<T> {
    fn append_serde(ref self: Array<felt252>, value: T) {
        value.serialize(ref self);
    }
}
