mod utils;
mod router;
mod interface;

use router::StarkDRouter;
use interface::IStarkDRouterDispatcher;
use interface::IStarkDRouterDispatcherTrait;

use starknet::ContractAddress;
use starknet::contract_address_const;
use starknet::SyscallResult;
use starknet::SyscallResultTrait;
use starknet::call_contract_syscall;
use array::ArrayTrait;
use box::BoxTrait;
use utils::UnwrapAndCast;

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
