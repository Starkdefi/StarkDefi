// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.7.0 (account/account.cairo)

use array::ArrayTrait;
use starknet::account::Call;


#[starknet::interface]
trait Multicall<TState> {
    fn multicall(self: @TState, calls: Array<Call>) -> (u64, Array<Span<felt252>>);

    fn current_timestamp(self: @TState) -> u64;
}

#[starknet::contract]
mod SimpleMulticall {
    use starknet::info::get_block_number;
    use starknet::get_block_timestamp;
    use super::{Call, ArrayTrait};


    #[storage]
    struct Storage {}

    #[constructor]
    fn constructor(ref self: ContractState) {}

    #[external(v0)]
    impl MulticallImpl of super::Multicall<ContractState> {
        fn multicall(self: @ContractState, mut calls: Array<Call>) -> (u64, Array<Span<felt252>>) {
            (get_block_number(), _execute_calls(calls))
        }

        fn current_timestamp(self: @ContractState) -> u64 {
            get_block_timestamp()
        }
    }

    #[internal]
    fn _execute_calls(mut calls: Array<Call>) -> Array<Span<felt252>> {
        let mut res = ArrayTrait::new();
        loop {
            match calls.pop_front() {
                Option::Some(call) => {
                    let _res = _execute_single_call(call);
                    res.append(_res);
                },
                Option::None(_) => {
                    break ();
                },
            };
        };
        res
    }

    #[internal]
    fn _execute_single_call(call: Call) -> Span<felt252> {
        let Call{to, selector, calldata } = call;
        starknet::call_contract_syscall(to, selector, calldata.span()).unwrap_syscall()
    }
}
