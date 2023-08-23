use starknet::ContractAddress;
use option::OptionTrait;
use array::ArrayTrait;
use array::SpanTrait;
use starknet::SyscallResult;
use starknet::SyscallResultTrait;
use starknet::call_contract_syscall;
use starknet::contract_address_to_felt252;
use traits::TryInto;
use traits::Into;

// from OpenZeppelin Contracts
trait UnwrapAndCast<T> {
    fn unwrap_and_cast(self: SyscallResult<Span<felt252>>) -> T;
}

impl UnwrapAndCastBool of UnwrapAndCast<bool> {
    fn unwrap_and_cast(self: SyscallResult<Span<felt252>>) -> bool {
        (*self.unwrap_syscall().at(0)).try_into().unwrap()
    }
}

impl UnwrapAndCastContractAddress of UnwrapAndCast<ContractAddress> {
    fn unwrap_and_cast(self: SyscallResult<Span<felt252>>) -> ContractAddress {
        (*self.unwrap_syscall().at(0)).try_into().unwrap()
    }
}

impl UnwrapFelt of UnwrapAndCast<felt252> {
    fn unwrap_and_cast(self: SyscallResult<Span<felt252>>) -> felt252 {
        *self.unwrap_syscall().at(0)
    }
}

impl UnwrapAndCastU8 of UnwrapAndCast<u8> {
    fn unwrap_and_cast(self: SyscallResult<Span<felt252>>) -> u8 {
        (*self.unwrap_syscall().at(0)).try_into().unwrap()
    }
}

impl UnwrapAndCastU256 of UnwrapAndCast<u256> {
    fn unwrap_and_cast(self: SyscallResult<Span<felt252>>) -> u256 {
        let unwrapped = self.unwrap_syscall();
        u256 {
            low: (*unwrapped.at(0)).try_into().unwrap(),
            high: (*unwrapped.at(1)).try_into().unwrap(),
        }
    }
}

impl BoolIntoFelt252 of Into<bool, felt252> {
    fn into(self: bool) -> felt252 {
        if self {
            return 1;
        } else {
            return 0;
        }
    }
}

impl Felt252TryIntoBool of TryInto<felt252, bool> {
    fn try_into(self: felt252) -> Option<bool> {
        if self == 0 {
            Option::Some(false)
        } else if self == 1 {
            Option::Some(true)
        } else {
            Option::None(())
        }
    }
}

