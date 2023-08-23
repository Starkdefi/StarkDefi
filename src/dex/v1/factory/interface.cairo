use starknet::{ContractAddress, ClassHash};

#[starknet::interface]
trait IStarkDFactory<TContractState> {
    fn fee_to(self: @TContractState) -> ContractAddress;
    fn fee_to_setter(self: @TContractState) -> ContractAddress;

    fn get_pair(
        self: @TContractState, tokenA: ContractAddress, tokenB: ContractAddress
    ) -> ContractAddress;
    fn all_pairs(self: @TContractState) -> (u32, Array::<ContractAddress>);
    fn all_pairs_length(self: @TContractState) -> u32;
    fn class_hash_for_pair_contract(self: @TContractState) -> ClassHash;

    fn create_pair(
        ref self: TContractState, tokenA: ContractAddress, tokenB: ContractAddress
    ) -> ContractAddress;

    fn set_fee_to(ref self: TContractState, fee_to_address: ContractAddress);
    fn set_fee_to_setter(ref self: TContractState, fee_to_setter_address: ContractAddress);
}