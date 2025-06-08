use starknet::ContractAddress;

#[derive(Copy, Drop, Serde, starkent::Store)]
struct SwapPath {
    tokenIn: ContractAddress,
    tokenOut: ContractAddress,
    stable: bool,
    feeTier: u8,
}

#[starknet::interface]
trait IStarkDRouter<TContractState> {
    fn factory(self: @TContractState) -> ContractAddress;
    fn sort_tokens(
        self: @TContractState, tokenA: ContractAddress, tokenB: ContractAddress,
    ) -> (ContractAddress, ContractAddress);
    fn quote(self: @TContractState, amountA: u256, reserveA: u256, reserveB: u256) -> u256;
    fn get_amounts_out(self: @TContractState, amountIn: u256, path: Array<SwapPath>) -> Array<u256>;

    fn add_liquidity(
        ref self: TContractState,
        tokenA: ContractAddress,
        tokenB: ContractAddress,
        stable: bool,
        feeTier: u8,
        amountADesired: u256,
        amountBDesired: u256,
        amountAMin: u256,
        amountBMin: u256,
        to: ContractAddress,
        deadline: u64,
    ) -> (u256, u256, u256);
    fn remove_liquidity(
        ref self: TContractState,
        tokenA: ContractAddress,
        tokenB: ContractAddress,
        stable: bool,
        feeTier: u8,
        liquidity: u256,
        amountAMin: u256,
        amountBMin: u256,
        to: ContractAddress,
        deadline: u64,
    ) -> (u256, u256);
    fn swap_exact_tokens_for_tokens(
        ref self: TContractState,
        amountIn: u256,
        amountOutMin: u256,
        path: Array<SwapPath>,
        to: ContractAddress,
        deadline: u64,
    ) -> Array<u256>;
    fn swap_exact_tokens_for_tokens_supporting_fees_on_transfer_tokens(
        ref self: TContractState,
        amountIn: u256,
        amountOutMin: u256,
        path: Array<SwapPath>,
        to: ContractAddress,
        deadline: u64,
    );
}
