// @title StarkDefi Pair Contract
// @author StarkDefi Labs
// @license MIT
// @description Based on UniswapV2 Pair Contract

#[starknet::contract]
mod StarkDPair {
    use starkDefi::dex::v1::factory::{IStarkDFactoryDispatcherTrait, IStarkDFactoryDispatcher};
    use starkDefi::dex::v1::pair::interface::IStarkDPair;
    use starkDefi::dex::v1::pair::interface::{
        IStarkDCalleeDispatcherTrait, IStarkDCalleeDispatcher
    };
    use starkDefi::utils::MinMax;
    use traits::Into;

    use starkDefi::token::erc20::{ERC20, ERC20ABIDispatcherTrait, ERC20ABIDispatcher};
    use integer::u256_sqrt;
    use zeroable::Zeroable;
    use array::ArrayTrait;
    use option::OptionTrait;
    use starknet::ContractAddress;
    use starknet::contract_address_const;
    use starknet::get_caller_address;
    use starknet::get_block_timestamp;
    use starknet::get_contract_address;
    use integer::u128_try_from_felt252;


    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Mint: Mint,
        Burn: Burn,
        Swap: Swap,
        Sync: Sync,
    }

    #[derive(Drop, starknet::Event)]
    struct Mint {
        #[key]
        sender: ContractAddress,
        amount0: u256,
        amount1: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct Burn {
        #[key]
        sender: ContractAddress,
        amount0: u256,
        amount1: u256,
        #[key]
        to: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct Swap {
        #[key]
        sender: ContractAddress,
        amount0In: u256,
        amount1In: u256,
        amount0Out: u256,
        amount1Out: u256,
        #[key]
        to: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct Sync {
        reserve0: u256,
        reserve1: u256,
    }

    #[storage]
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

    #[contructor]
    fn constructor(ref self: ContractState, tokenA: ContractAddress, tokenB: ContractAddress) {
        assert(tokenA.is_non_zero() & tokenB.is_non_zero(), 'invalid address');
        let mut erc20_state = ERC20::unsafe_new_contract_state();
        ERC20::InternalImpl::initializer(ref erc20_state, 'StarkDefi Pair', 'STARKD-P');

        self._entry_locked.write(false);
        self._token0.write(tokenA);
        self._token1.write(tokenB);
        self._factory.write(get_caller_address());
    }

    #[external(v0)]
    impl StarkDPair of IStarkDPair<ContractState> {
        fn name(self: @ContractState) -> felt252 {
            let erc20_state = ERC20::unsafe_new_contract_state();
            ERC20::ERC20Impl::name(@erc20_state)
        }


        fn symbol(self: @ContractState) -> felt252 {
            let erc20_state = ERC20::unsafe_new_contract_state();
            ERC20::ERC20Impl::symbol(@erc20_state)
        }

        fn decimals(self: @ContractState) -> u8 {
            let erc20_state = ERC20::unsafe_new_contract_state();
            ERC20::ERC20Impl::decimals(@erc20_state)
        }


        fn total_supply(self: @ContractState) -> u256 {
            InternalFunctions::_total_supply(self)
        }


        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            InternalFunctions::_balance_of(self, account)
        }


        fn allowance(
            self: @ContractState, owner: ContractAddress, spender: ContractAddress
        ) -> u256 {
            let erc20_state = ERC20::unsafe_new_contract_state();
            ERC20::ERC20Impl::allowance(@erc20_state, owner, spender)
        }


        fn factory(self: @ContractState) -> ContractAddress {
            self._factory.read()
        }


        fn token0(self: @ContractState) -> ContractAddress {
            self._token0.read()
        }

        fn token1(self: @ContractState) -> ContractAddress {
            self._token1.read()
        }

        fn get_reserves(self: @ContractState) -> (u256, u256, u64) {
            InternalFunctions::_get_reserves(self)
        }


        fn price0_cumulative_last(self: @ContractState) -> u256 {
            self._price_0_cumulative_last.read()
        }


        fn price1_cumulative_last(self: @ContractState) -> u256 {
            self._price_1_cumulative_last.read()
        }


        fn kLast(self: @ContractState) -> u256 {
            self._klast.read()
        }


        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            let mut erc20_state = ERC20::unsafe_new_contract_state();
            ERC20::ERC20Impl::transfer(ref erc20_state, recipient, amount);
            true
        }


        fn transfer_from(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) -> bool {
            let mut erc20_state = ERC20::unsafe_new_contract_state();
            ERC20::ERC20Impl::transfer_from(ref erc20_state, sender, recipient, amount);
            true
        }


        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            let mut erc20_state = ERC20::unsafe_new_contract_state();
            ERC20::ERC20Impl::approve(ref erc20_state, spender, amount);
            true
        }


        fn increase_allowance(
            ref self: ContractState, spender: ContractAddress, addedValue: u256
        ) -> bool {
            let mut erc20_state = ERC20::unsafe_new_contract_state();
            ERC20::increase_allowance(ref erc20_state, spender, addedValue);
            true
        }

        fn decrease_allowance(
            ref self: ContractState, spender: ContractAddress, subtractedValue: u256
        ) -> bool {
            let mut erc20_state = ERC20::unsafe_new_contract_state();
            ERC20::decreaseAllowance(ref erc20_state, spender, subtractedValue);
            true
        }

        fn mint(ref self: ContractState, to: ContractAddress) -> u256 {
            Modifiers::_lock(ref self);
            let (reserve0, reserve1, _) = InternalFunctions::_get_reserves(@self);
            let this_address = get_contract_address();
            let balance0 = ERC20ABIDispatcher {
                contract_address: self._token0.read()
            }.balance_of(this_address);
            let balance1 = ERC20ABIDispatcher {
                contract_address: self._token1.read()
            }.balance_of(this_address);
            let amount0 = balance0 - reserve0;
            let amount1 = balance1 - reserve1;

            let feeOn = InternalFunctions::_mint_fee(ref self, reserve0, reserve1);
            let totalSupply = InternalFunctions::_total_supply(@self);

            let mut lockedLiquidity: u256 = 0;
            let liquidity = if (totalSupply == 0) {
                lockedLiquidity = 1000; // calling ERC20::_mint here doesn't work
                u256 { low: u256_sqrt(amount0 * amount1) - 1000, high: 0 }
            } else {
                let liquidity0 = (amount0 * totalSupply) / reserve0;
                let liquidity1 = (amount1 * totalSupply) / reserve1;
                MinMax::min(liquidity0, liquidity1)
            };

            assert(liquidity > 0, 'insufficient liquidity minted');
            let mut erc20_state = ERC20::unsafe_new_contract_state();

            if totalSupply == 0 {
                ERC20::InternalImpl::_mint(
                    ref erc20_state, contract_address_const::<1>(), lockedLiquidity
                );
            }
            ERC20::InternalImpl::_mint(ref erc20_state, to, liquidity);

            InternalFunctions::_update(ref self, balance0, balance1, reserve0, reserve1);
            if feeOn {
                self._klast.write(reserve0 * reserve1);
            }

            self.emit(Mint { sender: get_caller_address(), amount0, amount1 });
            Modifiers::_unlock(ref self);
            liquidity
        }

        fn burn(ref self: ContractState, to: ContractAddress) -> (u256, u256) {
            Modifiers::_lock(ref self);
            let (reserve0, reserve1, _) = InternalFunctions::_get_reserves(@self);
            let this_address = get_contract_address();
            let token0Dispatcher = ERC20ABIDispatcher { contract_address: self._token0.read() };
            let token1Dispatcher = ERC20ABIDispatcher { contract_address: self._token1.read() };

            let mut balance0 = token0Dispatcher.balance_of(this_address);
            let mut balance1 = token1Dispatcher.balance_of(this_address);
            let liquidity = InternalFunctions::_balance_of(@self, this_address);

            let feeOn = InternalFunctions::_mint_fee(ref self, reserve0, reserve1);
            let totalSupply = InternalFunctions::_total_supply(@self);
            let amount0 = (liquidity * balance0) / totalSupply;
            let amount1 = (liquidity * balance1) / totalSupply;
            assert((amount0 > 0) & (amount1 > 0), 'insufficient liquidity burned');

            let mut erc20_state = ERC20::unsafe_new_contract_state();
            ERC20::InternalImpl::_burn(ref erc20_state, get_contract_address(), liquidity);

            token0Dispatcher.transfer(to, amount0);
            token1Dispatcher.transfer(to, amount1);

            balance0 = token0Dispatcher.balance_of(this_address);
            balance1 = token1Dispatcher.balance_of(this_address);

            self._update(balance0, balance1, reserve0, reserve1);
            if feeOn {
                self._klast.write(reserve0 * reserve1);
            }

            self.emit(Burn { sender: get_caller_address(), amount0, amount1, to });

            Modifiers::_unlock(ref self);
            (amount0, amount1)
        }

        fn swap(
            ref self: ContractState,
            amount0Out: u256,
            amount1Out: u256,
            to: ContractAddress,
            data: Array::<felt252>
        ) {
            Modifiers::_lock(ref self);
            assert((amount0Out > 0) | (amount1Out > 0), 'insufficient output amount');
            let (reserve0, reserve1, _) = InternalFunctions::_get_reserves(@self);
            assert((amount0Out < reserve0) & (amount1Out < reserve1), 'insufficient liquidity');

            let token0 = self._token0.read();
            let token1 = self._token1.read();
            assert((to != token0) & (to != token1), 'invalid to');

            let this_address = get_contract_address();

            let token0Dispatcher = ERC20ABIDispatcher { contract_address: token0 };
            let token1Dispatcher = ERC20ABIDispatcher { contract_address: token1 };

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

            let balance0 = token0Dispatcher.balance_of(this_address);
            let balance1 = token1Dispatcher.balance_of(this_address);

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

            assert((amount0In > 0) | (amount1In > 0), 'insufficient input amount');

            let balance0Adjusted = (balance0 * 1000) - (amount0In * 3);
            let balance1Adjusted = (balance1 * 1000) - (amount1In * 3);
            assert(
                balance0Adjusted * balance1Adjusted >= reserve0 * reserve1 * 1000 * 1000,
                'invariant K'
            );

            InternalFunctions::_update(ref self, balance0, balance1, reserve0, reserve1);

            self
                .emit(
                    Swap {
                        sender: get_caller_address(),
                        amount0In,
                        amount1In,
                        amount0Out,
                        amount1Out,
                        to
                    }
                );

            Modifiers::_unlock(ref self);
        }

        fn skim(ref self: ContractState, to: ContractAddress) {
            Modifiers::_lock(ref self);
            let (reserve0, reserve1, _) = InternalFunctions::_get_reserves(@self);
            let this_address = get_contract_address();

            let token0Dispatcher = ERC20ABIDispatcher { contract_address: self._token0.read() };
            let token1Dispatcher = ERC20ABIDispatcher { contract_address: self._token1.read() };

            let balance0 = token0Dispatcher.balance_of(this_address);
            let balance1 = token1Dispatcher.balance_of(this_address);

            token0Dispatcher.transfer(to, balance0 - reserve0);
            token1Dispatcher.transfer(to, balance1 - reserve1);

            Modifiers::_unlock(ref self);
        }

        fn sync(ref self: ContractState, ) {
            Modifiers::_lock(ref self);
            let this_address = get_contract_address();

            let balance0 = ERC20ABIDispatcher {
                contract_address: self._token0.read()
            }.balance_of(this_address);

            let balance1 = ERC20ABIDispatcher {
                contract_address: self._token1.read()
            }.balance_of(this_address);

            let (reserve0, reserve1, _) = InternalFunctions::_get_reserves(@self);

            InternalFunctions::_update(ref self, balance0, balance1, reserve0, reserve1);

            Modifiers::_unlock(ref self);
        }
    }


    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _total_supply(self: @ContractState) -> u256 {
            let erc20_state = ERC20::unsafe_new_contract_state();
            ERC20::ERC20Impl::total_supply(@erc20_state)
        }

        fn _balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            let erc20_state = ERC20::unsafe_new_contract_state();
            ERC20::ERC20Impl::balance_of(@erc20_state, account)
        }

        fn _get_reserves(self: @ContractState) -> (u256, u256, u64) {
            (self._reserve0.read(), self._reserve1.read(), self._block_timestamp_last.read())
        }

        fn _mint_fee(ref self: ContractState, reserve0: u256, reserve1: u256) -> bool {
            let fee_to: ContractAddress = IStarkDFactoryDispatcher {
                contract_address: self._factory.read()
            }.fee_to();
            let fee_on: bool = fee_to != Zeroable::zero();
            let k_last: u256 = self._klast.read();

            if fee_on {
                if k_last != 0 {
                    let root_k = u256 { low: u256_sqrt(reserve0 * reserve1), high: 0 };
                    let root_k_last = u256 { low: u256_sqrt(k_last), high: 0 };

                    if root_k > root_k_last {
                        let numerator = self._total_supply() * (root_k - root_k_last);
                        let denominator = (root_k * 5) + root_k_last;
                        let liquidity = numerator / denominator;

                        if liquidity > 0 {
                            let mut erc20_state = ERC20::unsafe_new_contract_state();
                            ERC20::InternalImpl::_mint(ref erc20_state, fee_to, liquidity);
                        }
                    }
                }
            } else if k_last != 0 {
                self._klast.write(0);
            }

            fee_on
        }

        fn _update(
            ref self: ContractState, balance0: u256, balance1: u256, reserve0: u256, reserve1: u256
        ) {
            assert((balance0.high == 0) & (balance1.high == 0), 'overflow');

            let block_timestamp = get_block_timestamp();
            let timeElapsed = block_timestamp - self._block_timestamp_last.read();

            if ((timeElapsed > 0) & (reserve0 != 0) & (reserve1 != 0)) {
                self
                    ._price_0_cumulative_last
                    .write(
                        self._price_0_cumulative_last.read() + (reserve1 / reserve0) * u256 {
                            low: u128_try_from_felt252(timeElapsed.into()).unwrap(), high: 0
                        }
                    );
                self
                    ._price_1_cumulative_last
                    .write(
                        self._price_1_cumulative_last.read() + (reserve0 / reserve1) * u256 {
                            low: u128_try_from_felt252(timeElapsed.into()).unwrap(), high: 0
                        }
                    );
            }

            self._reserve0.write(balance0);
            self._reserve1.write(balance1);
            self._block_timestamp_last.write(block_timestamp);

            self.emit(Sync { reserve0, reserve1 });
        }
    }


    #[generate_trait]
    impl Modifiers of ModifiersTrait {
        // @notice locks the entry point to prevent reentrancy attacks
        fn _lock(ref self: ContractState) {
            assert(!self._entry_locked.read(), 'locked');
            self._entry_locked.write(true);
        }

        // @notice unlocks the entry point
        fn _unlock(ref self: ContractState) {
            assert(self._entry_locked.read(), 'unlocked');
            self._entry_locked.write(false);
        }
    }
}
