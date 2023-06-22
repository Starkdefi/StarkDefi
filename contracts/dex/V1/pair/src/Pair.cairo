// @title StarkDefi Pair Contract
// @author StarkDefi Labs
// @license MIT
// @description Based on UniswapV2 Pair Contract

#[contract]
mod StarkDPair {
    // use 
    use token::ERC20;
    use traits::Into;
    use integer::u256_sqrt;
    use zeroable::Zeroable;
    use array::ArrayTrait;
    use option::OptionTrait;
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use starknet::get_block_timestamp;
    use starknet::get_contract_address;
    use integer::u128_try_from_felt252;

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
        assert(tokenA.is_non_zero() & tokenB.is_non_zero(), 'invalid address');
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
        let (reserve0, reserve1, _) = _get_reserves();
        let token0Dispatcher = IERC20Dispatcher { contract_address: _token0::read() };
        let token1Dispatcher = IERC20Dispatcher { contract_address: _token1::read() };

        let mut balance0 = token0Dispatcher.balanceOf(this_address);
        let mut balance1 = token1Dispatcher.balanceOf(this_address);
        let liquidity = balanceOf(this_address);

        let feeOn = _mint_fee(reserve0, reserve1);
        let totalSupply = totalSupply();
        let amount0 = (liquidity * balance0) / totalSupply;
        let amount1 = (liquidity * balance1) / totalSupply;
        assert(amount0 > 0 & amount1 > 0, 'insufficient liquidity burned');

        ERC20::_burn(get_contract_address(), liquidity);

        token0Dispatcher.transfer(to, amount0);
        token1Dispatcher.transfer(to, amount1);

        balance0 = token0Dispatcher.balanceOf(this_address);
        balance1 = token1Dispatcher.balanceOf(this_address);

        _update(balance0, balance1, reserve0, reserve1);
        if feeOn {
            _klast::write(reserve0 * reserve1);
        }

        Burn(get_caller_address(), amount0, amount1, to);

        _unlock();
        (amount0, amount1)
    }

    #[external]
    fn swap(amount0Out: u256, amount1Out: u256, to: ContractAddress, data: Array::<felt252>) {
        _lock();
        assert(amount0Out > 0 | amount1Out > 0, 'insufficient output amount');
        let (reserve0, reserve1, _) = _get_reserves();
        assert(amount0Out < reserve0 & amount1Out < reserve1, 'insufficient liquidity');

        let token0 = _token0::read();
        let token1 = _token1::read();
        assert(to != token0 & to != token1, 'invalid to');

        let this_address = get_contract_address();

        let token0Dispatcher = IERC20Dispatcher { contract_address: token0 };
        let token1Dispatcher = IERC20Dispatcher { contract_address: token1 };

        if amount0Out > 0 {
            token0Dispatcher.transfer(to, amount0Out);
        }
        if amount1Out > 0 {
            token1Dispatcher.transfer(to, amount1Out);
        }
        if data.len() > 0 {
            IStarkDCalleeDispatcher {
                contract_address: to
            }.starkd_call(get_caller_address(), amount0Out, amount1Out, data);
        }

        let balance0 = token0Dispatcher.balanceOf(this_address);
        let balance1 = token1Dispatcher.balanceOf(this_address);

        let amount0In = if balance0 > reserve0 - amount0Out {
            balance0 - (reserve0 - amount0Out)
        } else {
            0
        };

        let amount1In = if balance1 > reserve1 - amount1Out {
            balance1 - (reserve1 - amount1Out)
        } else {
            0
        };

        assert(amount0In > 0 | amount1In > 0, 'insufficient input amount');

        let balance0Adjusted = (balance0 * 1000) - (amount0In * 3);
        let balance1Adjusted = (balance1 * 1000) - (amount1In * 3);
        assert(
            balance0Adjusted * balance1Adjusted >= reserve0 * reserve1 * 1000 * 1000, 'invariant K'
        );

        _update(balance0, balance1, reserve0, reserve1);

        Swap(get_caller_address(), amount0In, amount1In, amount0Out, amount1Out, to);

        _unlock();
    }

    #[external]
    fn skim(to: ContractAddress) {
        _lock();
        let (reserve0, reserve1, _) = _get_reserves();
        let this_address = get_contract_address();

        let token0Dispatcher = IERC20Dispatcher { contract_address: _token0::read() };
        let token1Dispatcher = IERC20Dispatcher { contract_address: _token1::read() };

        let balance0 = token0Dispatcher.balanceOf(this_address);
        let balance1 = token1Dispatcher.balanceOf(this_address);

        token0Dispatcher.transfer(to, balance0 - reserve0);
        token1Dispatcher.transfer(to, balance1 - reserve1);

        _unlock();
    }

    #[external]
    fn sync() {
        _lock();
        let this_address = get_contract_address();

        let balance0 = IERC20Dispatcher {
            contract_address: _token0::read()
        }.balanceOf(this_address);

        let balance1 = IERC20Dispatcher {
            contract_address: _token1::read()
        }.balanceOf(this_address);

        let (reserve0, reserve1, _) = _get_reserves();

        _update(balance0, balance1, reserve0, reserve1);

        _unlock();
    }

    //
    // Internals
    //

    fn _get_reserves() -> (u256, u256, u64) {
        (_reserve0::read(), _reserve1::read(), _block_timestamp_last::read())
    }

    fn _mint_fee(reserve0: u256, reserve1: u256) -> bool {
        let fee_to = IStarkDFactoryDispatcher { contract_address: _factory::read() }.fee_to();
        let fee_on = fee_to != Zeroable::zero();
        let k_last: u256 = _klast::read();

        if fee_on {
            if k_last != 0 {
                let root_k = u256 { low: u256_sqrt(reserve0 * reserve1), high: 0 };
                let root_k_last = u256 { low: u256_sqrt(k_last), high: 0 };

                if root_k > root_k_last {
                    let numerator = totalSupply() * (root_k - root_k_last);
                    let denominator = (root_k * 5) + root_k_last;
                    let liquidity = numerator / denominator;

                    if liquidity > 0 {
                        ERC20::_mint(fee_to, liquidity);
                    }
                }
            }
        } else if k_last != 0 {
            _klast::write(0);
        }

        fee_on
    }

    fn _update(balance0: u256, balance1: u256, reserve0: u256, reserve1: u256) {
        assert(balance0.high == 0 & balance1.high == 0, 'overflow');

        let block_timestamp = get_block_timestamp();
        let timeElapsed = block_timestamp - _block_timestamp_last::read();

        if (timeElapsed > 0 & reserve0 != 0 & reserve1 != 0) {
            _price_0_cumulative_last::write(
                _price_0_cumulative_last::read() + (reserve1 / reserve0) * u256 {
                    low: u128_try_from_felt252(timeElapsed.into()).unwrap(), high: 0
                }
            );
            _price_1_cumulative_last::write(
                _price_1_cumulative_last::read() + (reserve0 / reserve1) * u256 {
                    low: u128_try_from_felt252(timeElapsed.into()).unwrap(), high: 0
                }
            );
        }

        _reserve0::write(balance0);
        _reserve1::write(balance1);
        _block_timestamp_last::write(block_timestamp);
        Sync(reserve0, reserve1);
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
