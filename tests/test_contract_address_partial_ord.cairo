use starknet::ContractAddress;
use traits::TryInto;
use zeroable::Zeroable;
use option::OptionTrait;
use starkDefi::utils::ContractAddressPartialOrd;
use debug::PrintTrait;
use starkDefi::utils::MinMax;

#[test]
fn test_return_is_le() {
    let contract_address0: ContractAddress = Zeroable::zero();
    let contract_address1: ContractAddress = 1.try_into().unwrap();
    assert(contract_address0 <= contract_address1, 'le');
}

#[test]
fn test_return_is_ge() {
    let contract_address0: ContractAddress = Zeroable::zero();
    let contract_address1: ContractAddress = 1.try_into().unwrap();

    assert(contract_address1 >= contract_address0, 'ge');
}

#[test]
fn test_return_is_lt() {
    let contract_address1: ContractAddress = 1.try_into().unwrap();
    let contract_address2: ContractAddress = 2.try_into().unwrap();

    assert(contract_address1 < contract_address2, 'lt');
}
#[test]
fn test_return_is_gt() {
    let contract_address1: ContractAddress = 1.try_into().unwrap();
    let contract_address2: ContractAddress = 2.try_into().unwrap();

    assert(contract_address2 > contract_address1, 'gt');
}
#[test]
fn test_min() {
    let a: u256 = 10;
    let b: u256 = 20;

    MinMax::min(a, b).print();
    assert(MinMax::min(a, b) == a, 'min');
}

#[test]
fn test_max() {
    let a: u256 = 10;
    let b: u256 = 20;

    MinMax::max(a, b).print();
    assert(MinMax::max(a, b) == b, 'max');
}

