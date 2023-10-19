use starknet::ContractAddress;
use option::OptionTrait;
use array::SpanTrait;
use array::ArrayTrait;
use starknet::SyscallResult;
use starknet::SyscallResultTrait;
use traits::TryInto;
use starknet::call_contract_syscall;
use box::BoxTrait;


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

fn call_contract_with_selector_fallback(
    contract: ContractAddress,
    selector_type1: felt252,
    selector_type2: felt252,
    call_data: Span<felt252>
) -> SyscallResult<Span<felt252>> {
    match call_contract_syscall(contract, selector_type1, call_data) {
        Result::Ok(res) => Result::Ok(res),
        Result::Err(err) => {
            if *err.at(0) == 'ENTRYPOINT_NOT_FOUND' {
                call_contract_syscall(contract, selector_type2, call_data)
            } else {
                Result::Err(err)
            }
        }
    }
}
