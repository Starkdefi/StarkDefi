use starknet::ContractAddress;
use integer::u256_from_felt252;
use starknet::contract_address_to_felt252;

use debug::PrintTrait;

impl ContractAddressPartialOrd of PartialOrd<ContractAddress> {
    #[inline(always)]
    fn le(lhs: ContractAddress, rhs: ContractAddress) -> bool {
        u256_from_felt252(
            contract_address_to_felt252(lhs)
        ) <= u256_from_felt252(contract_address_to_felt252(rhs))
    }

    #[inline(always)]
    fn ge(lhs: ContractAddress, rhs: ContractAddress) -> bool {
        u256_from_felt252(
            contract_address_to_felt252(lhs)
        ) >= u256_from_felt252(contract_address_to_felt252(rhs))
    }

    #[inline(always)]
    fn lt(lhs: ContractAddress, rhs: ContractAddress) -> bool {
        u256_from_felt252(
            contract_address_to_felt252(lhs)
        ) < u256_from_felt252(contract_address_to_felt252(rhs))
    }

    #[inline(always)]
    fn gt(lhs: ContractAddress, rhs: ContractAddress) -> bool {
        u256_from_felt252(
            contract_address_to_felt252(lhs)
        ) > u256_from_felt252(contract_address_to_felt252(rhs))
    }
}
