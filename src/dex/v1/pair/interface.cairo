use starknet::{ContractAddress};

#[starknet::interface]
trait IStarkDPair<TContractState> {
    fn name(self: @TContractState) -> felt252;
    fn symbol(self: @TContractState) -> felt252;
    fn decimals(self: @TContractState) -> u8;
    fn total_supply(self: @TContractState) -> u256;
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn allowance(self: @TContractState, owner: ContractAddress, spender: ContractAddress) -> u256;

    fn approve(ref self: TContractState, spender: ContractAddress, amount: u256) -> bool;
    fn increase_allowance(
        ref self: TContractState, spender: ContractAddress, addedValue: u256
    ) -> bool;
    fn decrease_allowance(
        ref self: TContractState, spender: ContractAddress, subtractedValue: u256
    ) -> bool;
    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u256) -> bool;
    fn transfer_from(
        ref self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256
    ) -> bool;

    fn factory(self: @TContractState) -> ContractAddress;
    fn token0(self: @TContractState) -> ContractAddress;
    fn token1(self: @TContractState) -> ContractAddress;
    fn get_reserves(self: @TContractState) -> (u256, u256, u64);
    fn price0_cumulative_last(self: @TContractState) -> u256;
    fn price1_cumulative_last(self: @TContractState) -> u256;
    fn kLast(self: @TContractState) -> u256;

    fn mint(ref self: TContractState, to: ContractAddress) -> u256;
    fn burn(ref self: TContractState, to: ContractAddress) -> (u256, u256);
    fn swap(
        ref self: TContractState,
        amount0Out: u256,
        amount1Out: u256,
        to: ContractAddress,
        data: Array::<felt252>
    );
    fn skim(ref self: TContractState, to: ContractAddress);
    fn sync(ref self: TContractState);
}


#[starknet::interface]
trait IStarkDCallee<TContractState> {
    fn hook(
        ref self: TContractState,
        sender: ContractAddress,
        amount0Out: u256,
        amount1Out: u256,
        data: Array::<felt252>
    );
}

#[starknet::interface]
trait IPairFees<TContractState> {
    fn claim_lp_fees(ref self: TContractState, user: ContractAddress, amount0: u256, amount1: u256);
    fn claim_protocol_fees(ref self: TContractState);
}
