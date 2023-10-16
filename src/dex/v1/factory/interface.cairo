use starknet::{ContractAddress, ClassHash};

#[starknet::interface]
trait IStarkDFactory<TContractState> {
    fn fee_to(self: @TContractState) -> ContractAddress;
    fn fee_handler(self: @TContractState) -> ContractAddress;

    fn get_pair(
        self: @TContractState, tokenA: ContractAddress, tokenB: ContractAddress, stable: bool
    ) -> ContractAddress;
    fn get_fees(self: @TContractState) -> (u256, u256);
    fn protocol_fee_on(self: @TContractState) -> bool;
    fn get_fee(self: @TContractState, pair: ContractAddress) -> u256;
    fn valid_pair(self: @TContractState, pair: ContractAddress) -> bool;
    fn all_pairs(self: @TContractState) -> (u32, Array::<ContractAddress>);
    fn all_pairs_length(self: @TContractState) -> u32;
    fn class_hash_for_pair_contract(self: @TContractState) -> ClassHash;

    fn create_pair(
        ref self: TContractState, tokenA: ContractAddress, tokenB: ContractAddress, stable: bool
    ) -> ContractAddress;

    fn set_fee_to(ref self: TContractState, fee_to: ContractAddress);
    fn set_fee(ref self: TContractState, fee: u256, stable: bool);
    fn set_custom_pair_fee(ref self: TContractState, pair: ContractAddress, fee: u256);
    fn set_fee_handler(ref self: TContractState, handler_address: ContractAddress);
    fn set_class_hash_for_pair_contract(
        ref self: TContractState, class_hash_pair_contract: ClassHash
    );
    fn set_class_hash_for_vault_contract(ref self: TContractState, vault_class_hash: ClassHash);
}
