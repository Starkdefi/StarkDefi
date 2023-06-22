// @title StarkDefi Pair Contract
// @author StarkDefi Labs
// @license MIT
// @description Based on UniswapV2 Pair Contract

#[contract]
mod StarkDPair {
    // use 
    use token::ERC20;
    use array::ArrayTrait;
    use starknet::ContractAddress;
    use starknet::get_caller_address;

    //
    // Events
    //

    #[event]
    fn Mint(sender: ContractAddress, amount0: u256, amount1: u256) {}

    #[external]
    fn Burn(sender: ContractAddress, amount0: u256, amount1: u256, to: ContractAddress) {}

    #[event]
    fn Swap(
        sender: ContractAddress,
        amount0In: u256,
        amount1In: u256,
        amount0Out: u256,
        amount1Out: u256,
        to: ContractAddress
    ) {}

    #[event]
    fn Sync(reserve0: u256, reserve1: u256) {}

    // 
    // Interface
    // 

    #[abi]
    trait IStarkDFactory {
        fn fee_to() -> ContractAddress;
    }

    #[abi]
    trait IERC20 {
        fn balanceOf(account: ContractAddress) -> u256;
        fn transfer(recipient: ContractAddress, amount: u256) -> bool;
        fn transferFrom(sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool;
    }

    #[abi]
    trait IStarkDCallee {
        fn starkd_call(
            sender: ContractAddress, amount0Out: u256, amount1Out: u256, data: Array::<felt252>
        );
    }

    // 
    // Storage
    //

    struct Storage {
        _token0: ContractAddress,
        _token1: ContractAddress,
        _reserve0: u256,
        _reserve1: u256,
        _block_timestamp_last: u64,
        _price_0_cumulative_last: u256,
        _price_1_cumulative_last: u256,
        _klast: u256,
        _factory: ContractAddress,
        _entry_locked: bool,
    }

    //
    // Constructor
    //

    #[contructor]
    fn constructor(tokenA: ContractAddress, tokenB: ContractAddress) {
        assert(
            tokenA.is_not_zero() & tokenB.is_not_zero() & factory.is_not_zero(), 'invalid address'
        );
        ERC20::initializer('StarkDefi Pair', 'STARKD-P');
        _entry_locked::write(false);
        _token0::write(tokenA);
        _token1::write(tokenB);
        _factory::write(get_caller_address());
    }

    // 
    // Getters
    // 
    #[view]
    fn name() -> felt252 {
        ERC20::name()
    }

    #[view]
    fn symbol() -> felt252 {
        ERC20::symbol()
    }

    #[view]
    fn decimals() -> u8 {
        ERC20::decimals()
    }

    #[view]
    fn totalSupply() -> u256 {
        ERC20::totalSupply()
    }

    #[view]
    fn balanceOf(account: ContractAddress) -> u256 {
        ERC20::balanceOf(account)
    }

    #[view]
    fn allowance(owner: ContractAddress, spender: ContractAddress) -> u256 {
        ERC20::allowance(owner, spender)
    }

    #[view]
    fn factory() -> ContractAddress {
        _factory::read()
    }

    #[view]
    fn token0() -> ContractAddress {
        _token0::read()
    }

    #[view]
    fn token1() -> ContractAddress {
        _token1::read()
    }

    #[view]
    fn getReserves() -> (u256, u256, u64) {
        _get_reserves()
    }

    #[view]
    fn price0CumulativeLast() -> u256 {
        _price_0_cumulative_last::read()
    }

    #[view]
    fn price1CumulativeLast() -> u256 {
        _price_1_cumulative_last::read()
    }

    #[view]
    fn kLast() -> u256 {
        _klast::read()
    }

    // 
    // Externals

    #[external]
    fn transfer(recipient: ContractAddress, amount: u256) -> bool {
        ERC20::transfer(recipient, amount);
        true
    }

    #[external]
    fn transferFrom(sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool {
        ERC20::transferFrom(sender, recipient, amount);
        true
    }

    #[external]
    fn approve(spender: ContractAddress, amount: u256) -> bool {
        ERC20::approve(spender, amount);
        true
    }

    #[external]
    fn increaseAllowance(spender: ContractAddress, addedValue: u256) -> bool {
        ERC20::increaseAllowance(spender, addedValue);
        true
    }

    #[external]
    fn decreaseAllowance(spender: ContractAddress, subtractedValue: u256) -> bool {
        ERC20::decreaseAllowance(spender, subtractedValue);
        true
    }

    #[external]
    fn mint(to: ContractAddress) -> u256 {
        _lock();
        // TODO: implement pair mint
        0
    }

    #[external]
    fn burn(to: ContractAddress) -> (u256, u256) {
        _lock();
        // TODO: implement pair burn
        (0, 0)
    }

    #[external]
    fn swap(amount0Out: u256, amount1Out: u256, to: u256, data: Array::<felt256>) {
        _lock();
    // TODO: implement pair swap
    }

    #[external]
    fn skim(to: ContractAddress) {
        _lock();
    // TODO: implement pair skim
    }

    #[external]
    fn sync() {
        _lock();
    // TODO: implement pair sync
    }


    //
    // Internals
    //

    fn _get_reserves() -> (u256, u256, u64) {
        (_reserve0::read(), _reserve1::read(), _block_timestamp_last::read())
    }

    fn _mint_fee(reserve0: u256, reserve1: u256) -> (u256, u256) {
        // TODO: implement mint fee
        (0, 0)
    }

    fn _update(
        balance0: u256, balance1: u256, reserve0: u256, reserve1: u256
    ) { // TODO: implement update
    }

    //
    // Modifiers
    //

    // @notice locks the entry point to prevent reentrancy attacks
    fn _lock() {
        assert(!_entry_locked::read(), 'locked');
        _entry_locked::write(true);
    }

    // @notice unlocks the entry point
    fn _unlock() {
        assert(_entry_locked::read(), 'unlocked');
        _entry_locked::write(false);
    }
}
