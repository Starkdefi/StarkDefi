use starknet::{ContractAddress, ClassHash};

#[starknet::interface]
trait IStarkDFactory<TContractState> {
    fn fee_to(self: @TContractState) -> ContractAddress;
    fn fee_handler(self: @TContractState) -> ContractAddress;

    fn get_pair(
        self: @TContractState,
        tokenA: ContractAddress,
        tokenB: ContractAddress,
        stable: bool,
        fee: u8
    ) -> ContractAddress;
    fn get_fees(self: @TContractState) -> (u8, u8);
    fn protocol_fee_on(self: @TContractState) -> bool;
    fn get_fee(self: @TContractState, pair: ContractAddress) -> u8;
    fn valid_pair(self: @TContractState, pair: ContractAddress) -> bool;
    fn all_pairs(self: @TContractState) -> (u32, Array::<ContractAddress>);
    fn all_pairs_length(self: @TContractState) -> u32;
    fn class_hash_for_pair_contract(self: @TContractState) -> ClassHash;

    fn create_pair(
        ref self: TContractState,
        tokenA: ContractAddress,
        tokenB: ContractAddress,
        stable: bool,
        fee: u8
    ) -> ContractAddress;

    fn set_fee_to(ref self: TContractState, fee_to: ContractAddress);
    fn set_fee(ref self: TContractState, fee: u8, stable: bool);
    fn set_custom_pair_fee(ref self: TContractState, pair: ContractAddress, fee: u8);
    fn set_fee_handler(ref self: TContractState, handler_address: ContractAddress);
}

#[starknet::interface]
trait IStarkDFactoryABI<TContractState> {
    fn fee_to(self: @TContractState) -> ContractAddress;
    fn fee_handler(self: @TContractState) -> ContractAddress;

    fn get_pair(
        self: @TContractState,
        tokenA: ContractAddress,
        tokenB: ContractAddress,
        stable: bool,
        fee: u8
    ) -> ContractAddress;
    fn get_fees(self: @TContractState) -> (u8, u8);
    fn protocol_fee_on(self: @TContractState) -> bool;
    fn get_fee(self: @TContractState, pair: ContractAddress) -> u8;
    fn valid_pair(self: @TContractState, pair: ContractAddress) -> bool;
    fn all_pairs(self: @TContractState) -> (u32, Array::<ContractAddress>);
    fn all_pairs_length(self: @TContractState) -> u32;
    fn class_hash_for_pair_contract(self: @TContractState) -> ClassHash;

    fn create_pair(
        ref self: TContractState,
        tokenA: ContractAddress,
        tokenB: ContractAddress,
        stable: bool,
        fee: u8
    ) -> ContractAddress;

    fn set_fee_to(ref self: TContractState, fee_to: ContractAddress);
    fn set_fee(ref self: TContractState, fee: u8, stable: bool);
    fn set_custom_pair_fee(ref self: TContractState, pair: ContractAddress, fee: u8);
    fn set_fee_handler(ref self: TContractState, handler_address: ContractAddress);
    fn set_pair_contract_class(ref self: TContractState, class_hash_pair_contract: ClassHash);
    fn set_vault_contract_class(ref self: TContractState, vault_class_hash: ClassHash);
    fn assert_paused(self: @TContractState);
    fn assert_not_paused(self: @TContractState);
}
