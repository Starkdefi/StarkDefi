use starknet::ContractAddress;
use starknet::contract_address_to_felt252;
use traits::Into;

impl ContractAddressPartialOrd of PartialOrd<ContractAddress> {
    #[inline(always)]
    fn le(lhs: ContractAddress, rhs: ContractAddress) -> bool {
        let lhs_u256: u256 = contract_address_to_felt252(lhs).into();
        let rhs_u256: u256 = contract_address_to_felt252(rhs).into();
        lhs_u256 <= rhs_u256
    }

    #[inline(always)]
    fn ge(lhs: ContractAddress, rhs: ContractAddress) -> bool {
        let lhs_u256: u256 = contract_address_to_felt252(lhs).into();
        let rhs_u256: u256 = contract_address_to_felt252(rhs).into();
        lhs_u256 >= rhs_u256
    }

    #[inline(always)]
    fn lt(lhs: ContractAddress, rhs: ContractAddress) -> bool {
        let lhs_u256: u256 = contract_address_to_felt252(lhs).into();
        let rhs_u256: u256 = contract_address_to_felt252(rhs).into();
        lhs_u256 < rhs_u256
    }

    #[inline(always)]
    fn gt(lhs: ContractAddress, rhs: ContractAddress) -> bool {
        let lhs_u256: u256 = contract_address_to_felt252(lhs).into();
        let rhs_u256: u256 = contract_address_to_felt252(rhs).into();
        lhs_u256 > rhs_u256
    }
}
