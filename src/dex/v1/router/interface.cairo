use starknet::ContractAddress;

#[starknet::interface]
trait IStarkDRouter<TContractState> {
    fn factory(self: @TContractState) -> ContractAddress;
    fn sort_tokens(
        self: @TContractState, tokenA: ContractAddress, tokenB: ContractAddress
    ) -> (ContractAddress, ContractAddress);
    fn quote(self: @TContractState, amountA: u256, reserveA: u256, reserveB: u256) -> u256;
    fn get_amount_out(
        self: @TContractState, amountIn: u256, reserveIn: u256, reserveOut: u256
    ) -> u256;
    fn get_amount_in(
        self: @TContractState, amountOut: u256, reserveIn: u256, reserveOut: u256
    ) -> u256;
    fn get_amounts_out(
        self: @TContractState, amountIn: u256, path: Array::<ContractAddress>
    ) -> Array::<u256>;
    fn get_amounts_in(
        self: @TContractState, amountOut: u256, path: Array::<ContractAddress>
    ) -> Array::<u256>;

    fn add_liquidity(
        ref self: TContractState,
        tokenA: ContractAddress,
        tokenB: ContractAddress,
        amountADesired: u256,
        amountBDesired: u256,
        amountAMin: u256,
        amountBMin: u256,
        to: ContractAddress,
        deadline: u64
    ) -> (u256, u256, u256);
    fn remove_liquidity(
        ref self: TContractState,
        tokenA: ContractAddress,
        tokenB: ContractAddress,
        liquidity: u256,
        amountAMin: u256,
        amountBMin: u256,
        to: ContractAddress,
        deadline: u64
    ) -> (u256, u256);
    fn swap_exact_tokens_for_tokens(
        ref self: TContractState,
        amountIn: u256,
        amountOutMin: u256,
        path: Array::<ContractAddress>,
        to: ContractAddress,
        deadline: u64
    ) -> Array::<u256>;
    fn swap_tokens_for_exact_tokens(
        ref self: TContractState,
        amountOut: u256,
        amountInMax: u256,
        path: Array::<ContractAddress>,
        to: ContractAddress,
        deadline: u64
    ) -> Array::<u256>;
}
