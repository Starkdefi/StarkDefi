// @title StarkDefi Router Contract
// @author StarkDefi Labs
// @license MIT
// @description Modified UniswapV2 Router Contract

#[starknet::contract]
mod StarkDRouter {
    use starkDefi::dex::v1::router::interface::{IStarkDRouter, SwapPath};
    use starkDefi::utils::call_contract_with_selector_fallback;
    use starkDefi::utils::callFallback::UnwrapAndCast;

    use starkDefi::dex::v1::factory::{
        IStarkDFactoryABIDispatcherTrait, IStarkDFactoryABIDispatcher
    };
    use starkDefi::dex::v1::pair::interface::{IStarkDPairDispatcherTrait, IStarkDPairDispatcher};
    use starkDefi::utils::selectors::{transfer_from, transferFrom, balanceOf, balance_of};
    use starkDefi::utils::{ArrayTraitExt, ContractAddressPartialOrd};
    use array::SpanTrait;
    use array::ArrayTrait;
    use clone::Clone;
    use option::OptionTrait;
    use zeroable::Zeroable;
    use starknet::{
        ContractAddress, ClassHash, get_caller_address, get_block_timestamp, contract_address_const
    };
    use starkDefi::utils::upgradeable::{Upgradeable, IUpgradeable};


    #[storage]
    struct Storage {
        _factory: ContractAddress, 
    }

    #[constructor]
    fn constructor(ref self: ContractState, factory: ContractAddress) {
        assert(factory.is_non_zero(), 'invalid factory');
        self._factory.write(factory);
    }

    #[external(v0)]
    impl StarkDRouterImp of IStarkDRouter<ContractState> {
        /// @notice This function is used to get the factory address
        /// @return The factory address
        fn factory(self: @ContractState) -> ContractAddress {
            self._factory.read()
        }


        /// @notice This function is used to sort two token addresses
        /// @param tokenA The first token address
        /// @param tokenB The second token address
        /// @return The sorted token addresses
        fn sort_tokens(
            self: @ContractState, tokenA: ContractAddress, tokenB: ContractAddress
        ) -> (ContractAddress, ContractAddress) {
            assert(tokenA.is_non_zero() && tokenB.is_non_zero(), 'invalid pair');
            InternalFunctions::_sort_tokens(tokenA, tokenB)
        }


        /// @notice This function is used to get the quote of a token pair
        /// @param amountA The amount of the first token
        /// @param reserveA The reserve of the first token
        /// @param reserveB The reserve of the second token
        /// @return The quote of the token pair
        fn quote(self: @ContractState, amountA: u256, reserveA: u256, reserveB: u256) -> u256 {
            InternalFunctions::_quote(amountA, reserveA, reserveB)
        }

        /// @notice This function is used to get the output amounts of a swap
        /// @param amountIn The input amount of the swap
        /// @param path The path of the swap
        /// @return The output amounts of the swap
        fn get_amounts_out(
            self: @ContractState, amountIn: u256, path: Array::<SwapPath>
        ) -> Array::<u256> {
            let factory = self._factory.read();
            InternalFunctions::_get_amounts_out(factory, amountIn, path.span())
        }


        /// @notice This function is used to add liquidity to a pair
        /// @param tokenA The address of the first token
        /// @param tokenB The address of the second token
        /// @param stable Whether the pair is stable or not
        /// @param amountADesired The desired amount of the first token
        /// @param amountBDesired The desired amount of the second token
        /// @param amountAMin The minimum amount of the first token
        /// @param amountBMin The minimum amount of the second token
        /// @param to The address to receive the liquidity tokens
        /// @param deadline The deadline for the transaction
        /// @return The actual amounts of tokens A and B added to the pool and the amount of liquidity tokens minted
        fn add_liquidity(
            ref self: ContractState,
            tokenA: ContractAddress,
            tokenB: ContractAddress,
            stable: bool,
            amountADesired: u256,
            amountBDesired: u256,
            amountAMin: u256,
            amountBMin: u256,
            to: ContractAddress,
            deadline: u64
        ) -> (u256, u256, u256) {
            Modifiers::_ensure(deadline);
            let factory = self._factory.read();
            let (amountA, amountB) = InternalFunctions::_add_liquidity(
                ref self,
                tokenA,
                tokenB,
                stable,
                amountADesired,
                amountBDesired,
                amountAMin,
                amountBMin
            );
            let pair = InternalFunctions::_pair_for(factory, tokenA, tokenB, stable);
            let sender = get_caller_address();

            InternalFunctions::_transfer_token_from(tokenA, sender, pair, amountA);
            InternalFunctions::_transfer_token_from(tokenB, sender, pair, amountB);

            let liquidity = IStarkDPairDispatcher { contract_address: pair }.mint(to);
            (amountA, amountB, liquidity)
        }


        /// @notice This function is used to remove liquidity from a pair
        /// @param tokenA The address of the first token
        /// @param tokenB The address of the second token
        /// @param stable Whether the pair is stable or not
        /// @param liquidity The amount of liquidity to remove
        /// @param amountAMin The minimum amount of the first token
        /// @param amountBMin The minimum amount of the second token
        /// @param to The address to receive the tokens
        /// @param deadline The deadline for the transaction
        /// @return The actual amounts of tokens A and B removed from the pool
        fn remove_liquidity(
            ref self: ContractState,
            tokenA: ContractAddress,
            tokenB: ContractAddress,
            stable: bool,
            liquidity: u256,
            amountAMin: u256,
            amountBMin: u256,
            to: ContractAddress,
            deadline: u64
        ) -> (u256, u256) {
            Modifiers::_ensure(deadline);
            let factory = self._factory.read();

            let pair = InternalFunctions::_pair_for(factory, tokenA, tokenB, stable);
            let sender = get_caller_address();

            InternalFunctions::_transfer_token_from(pair, sender, pair, liquidity);

            let (amount0, amount1) = IStarkDPairDispatcher { contract_address: pair }.burn(to);
            let (token0, _) = InternalFunctions::_sort_tokens(tokenA, tokenB);
            let mut amountA: u256 = 0;
            let mut amountB: u256 = 0;

            if token0 == tokenA {
                amountA = amount0;
                amountB = amount1;
            } else {
                amountA = amount1;
                amountB = amount0;
            }

            assert(amountA >= amountAMin, 'insufficient A amount');
            assert(amountB >= amountBMin, 'insufficient B amount');
            (amountA, amountB)
        }

        /// @notice This function is used to swap an exact amount of input tokens for as many output tokens as possible
        /// @param amountIn The amount of input tokens
        /// @param amountOutMin The minimum amount of output tokens
        /// @param path The path of the swap
        /// @param to The address to receive the output tokens
        /// @param deadline The deadline for the transaction
        /// @return The output amounts of the swap
        fn swap_exact_tokens_for_tokens(
            ref self: ContractState,
            amountIn: u256,
            amountOutMin: u256,
            path: Array::<SwapPath>,
            to: ContractAddress,
            deadline: u64
        ) -> Array::<u256> {
            Modifiers::_ensure(deadline);
            let factory = self._factory.read();
            let amounts = InternalFunctions::_get_amounts_out(factory, amountIn, path.span());
            assert(*amounts[amounts.len() - 1] >= amountOutMin, 'insufficient output amount');
            let mut _path = path.clone();
            let _route = _path.pop_front().unwrap();

            let pair = InternalFunctions::_pair_for(
                factory, _route.tokenIn, _route.tokenOut, _route.stable
            );
            let sender = get_caller_address();

            InternalFunctions::_transfer_token_from(_route.tokenIn, sender, pair, *amounts[0]);
            InternalFunctions::_swap(ref self, amounts.span(), path.span(), to);
            amounts
        }

        /// @notice This function is used to swap an exact amount of input tokens for as many output tokens as possible, 
        ///         while also supporting tokens that charge a fee on transfer
        /// @param amountIn The amount of input tokens
        /// @param amountOutMin The minimum amount of output tokens
        /// @param path The path of the swap
        /// @param to The address to receive the output tokens
        /// @param deadline The deadline for the transaction
        fn swap_exact_tokens_for_tokens_supporting_fees_on_transfer_tokens(
            ref self: ContractState,
            amountIn: u256,
            amountOutMin: u256,
            path: Array::<SwapPath>,
            to: ContractAddress,
            deadline: u64
        ) {
            Modifiers::_ensure(deadline);
            let mut _path = path.clone();
            let _route = _path.pop_front().unwrap();
            let factory = self._factory.read();
            let pair = InternalFunctions::_pair_for(
                factory, _route.tokenIn, _route.tokenOut, _route.stable
            );
            let sender = get_caller_address();

            InternalFunctions::_transfer_token_from(_route.tokenIn, sender, pair, amountIn);
            let _end_route: SwapPath = if (_path.len() > 0) {
                *_path[_path.len() - 1]
            } else {
                _route
            };
            let prevBalance = InternalFunctions::_balance_of(_end_route.tokenOut, to);
            self._swap_supporting_fee_on_transfer_tokens(path.span(), to);
            assert(
                InternalFunctions::_balance_of(_end_route.tokenOut, to)
                    - prevBalance >= amountOutMin,
                'insufficient output amount'
            );
        }
    }

    #[external(v0)]
    fn set_factory(ref self: ContractState, factory: ContractAddress) {
        assert(factory.is_non_zero(), 'invalid factory');
        Modifiers::assert_only_handler(@self);
        self._factory.write(factory);
    }

    #[external(v0)]
    impl UpgradableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            Modifiers::assert_only_handler(@self);
            let mut state = Upgradeable::unsafe_new_contract_state();
            Upgradeable::InternalImpl::_upgrade(ref state, new_class_hash);
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _sort_tokens(
            tokenA: ContractAddress, tokenB: ContractAddress
        ) -> (ContractAddress, ContractAddress) {
            assert(tokenA != tokenB, 'identical addresses');
            let (token0, token1) = if tokenA < tokenB {
                (tokenA, tokenB)
            } else {
                (tokenB, tokenA)
            };
            assert(token0.is_non_zero(), 'invalid token0');
            (token0, token1)
        }

        /// @notice try transferFrom & transfer_from
        fn _transfer_token_from(
            token: ContractAddress,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) {
            let mut call_data = Default::default();
            Serde::serialize(@sender, ref call_data);
            Serde::serialize(@recipient, ref call_data);
            Serde::serialize(@amount, ref call_data);

            call_contract_with_selector_fallback(
                token, transferFrom, transfer_from, call_data.span()
            )
                .unwrap_syscall();
        }

        /// @notice try balanceOf & balance_of
        fn _balance_of(token: ContractAddress, account: ContractAddress) -> u256 {
            let mut call_data = array![];
            Serde::serialize(@account, ref call_data);

            call_contract_with_selector_fallback(token, balanceOf, balance_of, call_data.span())
                .unwrap_and_cast()
        }

        fn _add_liquidity(
            ref self: ContractState,
            tokenA: ContractAddress,
            tokenB: ContractAddress,
            stable: bool,
            amountADesired: u256,
            amountBDesired: u256,
            amountAMin: u256,
            amountBMin: u256
        ) -> (u256, u256) {
            let factory = self._factory.read();
            let factoryDispatcher = IStarkDFactoryABIDispatcher { contract_address: factory };

            let pair = factoryDispatcher.get_pair(tokenA, tokenB, stable);

            if (pair == contract_address_const::<0>()) {
                factoryDispatcher.create_pair(tokenA, tokenB, stable);
            }

            let (reserveA, reserveB) = InternalFunctions::_get_reserves(
                factory, tokenA, tokenB, stable
            );

            if (reserveA == 0 && reserveB == 0) {
                (amountADesired, amountBDesired)
            } else {
                let amountBOptimal = InternalFunctions::_quote(amountADesired, reserveA, reserveB);
                if (amountBOptimal <= amountBDesired) {
                    assert(amountBOptimal >= amountBMin, 'INSUFFICIENT_B_AMOUNT');
                    (amountADesired, amountBOptimal)
                } else {
                    let amountAOptimal = InternalFunctions::_quote(
                        amountBDesired, reserveB, reserveA
                    );
                    assert(amountAOptimal <= amountADesired, 'AMOUNT_A_OPTIMAL_!_ADESIRED');
                    assert(amountAOptimal >= amountAMin, 'INSUFFICIENT_A_AMOUNT');
                    (amountAOptimal, amountBDesired)
                }
            }
        }

        /// @notice This function is used to swap tokens
        /// @dev This function requires the initial amount to have already been sent to the first pair
        /// @param amounts The amounts of the tokens
        /// @param path The path of the swap
        /// @param _to The address to receive the output tokens
        fn _swap(
            ref self: ContractState,
            amounts: Span::<u256>,
            path: Span::<SwapPath>,
            _to: ContractAddress
        ) {
            let mut index: u32 = 0;
            let factory = self._factory.read();
            let mut _path = path;
            let first_route: SwapPath = *_path[0];
            let mut _path_to: ContractAddress = first_route.tokenOut;

            loop {
                match _path.pop_front() {
                    Option::Some(route) => {
                        if (index > 0) {
                            assert(_path_to == *route.tokenIn, 'invalid path');
                            _path_to = *route.tokenOut;
                        }

                        let (token0, _) = InternalFunctions::_sort_tokens(
                            *route.tokenIn, *route.tokenOut
                        );

                        let mut amount0Out: u256 = 0;
                        let mut amount1Out: u256 = 0;

                        if *route.tokenIn == token0 {
                            amount1Out = *amounts[index + 1];
                        } else {
                            amount0Out = *amounts[index + 1];
                        }

                        let to = if index < path.len() - 1 {
                            let _next: SwapPath = *path[index + 1];

                            InternalFunctions::_pair_for(
                                factory, _next.tokenIn, _next.tokenOut, _next.stable
                            )
                        } else {
                            _to
                        };

                        IStarkDPairDispatcher {
                            contract_address: InternalFunctions::_pair_for(
                                factory, *route.tokenIn, *route.tokenOut, *route.stable
                            )
                        }.swap(amount0Out, amount1Out, to, ArrayTrait::<felt252>::new());

                        index += 1;
                    },
                    Option::None(_) => {
                        break ();
                    }
                };
            }
        }

        /// @dev swap supporting fee-on-transfer tokens
        ///      requires the initial amount to have already been sent to the first pair
        fn _swap_supporting_fee_on_transfer_tokens(
            ref self: ContractState, path: Span::<SwapPath>, _to: ContractAddress
        ) {
            let factory = self._factory.read();
            let mut index: u32 = 0;
            let mut _path = path;
            let first_route: SwapPath = *_path[0];
            let mut _path_to: ContractAddress = first_route.tokenOut;
            loop {
                match _path.pop_front() {
                    Option::Some(route) => {
                        if (index > 0) {
                            assert(_path_to == *route.tokenIn, 'invalid path');
                            _path_to = *route.tokenOut;
                        }

                        let (token0, _) = InternalFunctions::_sort_tokens(
                            *route.tokenIn, *route.tokenOut
                        );
                        let pair = InternalFunctions::_pair_for(
                            factory, *route.tokenIn, *route.tokenOut, *route.stable
                        );

                        let pairDispatcher = IStarkDPairDispatcher { contract_address: pair };

                        let (reserveA, _) = InternalFunctions::_get_reserves(
                            factory, *route.tokenIn, *route.tokenOut, *route.stable
                        );

                        let balance_tokenIn = InternalFunctions::_balance_of(*route.tokenIn, pair);
                        let amountIn = balance_tokenIn - reserveA;

                        let amountOut = pairDispatcher.get_amount_out(*route.tokenIn, amountIn);

                        let (amount0Out, amount1Out) = if *route.tokenIn == token0 {
                            (0, amountOut)
                        } else {
                            (amountOut, 0)
                        };

                        let to = if index < path.len() - 1 {
                            let _next: SwapPath = *path[index + 1];
                            InternalFunctions::_pair_for(
                                factory, _next.tokenIn, _next.tokenOut, _next.stable
                            )
                        } else {
                            _to
                        };

                        pairDispatcher
                            .swap(amount0Out, amount1Out, to, ArrayTrait::<felt252>::new());

                        index += 1;
                    },
                    Option::None(_) => {
                        break ();
                    }
                };
            }
        }

        fn _pair_for(
            factory: ContractAddress, tokenA: ContractAddress, tokenB: ContractAddress, stable: bool
        ) -> ContractAddress {
            let (token0, token1) = InternalFunctions::_sort_tokens(tokenA, tokenB);
            IStarkDFactoryABIDispatcher {
                contract_address: factory
            }.get_pair(token0, token1, stable)
        }

        fn _get_reserves(
            factory: ContractAddress, tokenA: ContractAddress, tokenB: ContractAddress, stable: bool
        ) -> (u256, u256) {
            let (token0, _) = InternalFunctions::_sort_tokens(tokenA, tokenB);
            let pair = InternalFunctions::_pair_for(factory, tokenA, tokenB, stable);
            let (reserve0, reserve1, _) = IStarkDPairDispatcher {
                contract_address: pair
            }.get_reserves();

            if tokenA == token0 {
                (reserve0, reserve1)
            } else {
                (reserve1, reserve0)
            }
        }


        /// @dev This implementation only caters to volatile pools and may result in insufficient liquidity for stable pool
        fn _quote(amountA: u256, reserveA: u256, reserveB: u256) -> u256 {
            assert(amountA > 0, 'insufficient amount');
            assert(reserveA > 0 && reserveB > 0, 'insufficient liquidity');
            (amountA * reserveB) / reserveA
        }

        fn _get_amounts_out(
            factory: ContractAddress, amountIn: u256, path: Span::<SwapPath>
        ) -> Array::<u256> {
            assert(path.len() >= 1, 'invalid path');
            let mut amounts = ArrayTrait::<u256>::new();
            let mut _path = path;
            amounts.append(amountIn);

            let mut index: u32 = 0;

            loop {
                match _path.pop_front() {
                    Option::Some(route) => {
                        let pair = InternalFunctions::_pair_for(
                            factory, *route.tokenIn, *route.tokenOut, *route.stable
                        );
                        let factoryDispatcher = IStarkDFactoryABIDispatcher {
                            contract_address: factory
                        };

                        if (factoryDispatcher.valid_pair(pair)) {
                            amounts
                                .append(
                                    IStarkDPairDispatcher {
                                        contract_address: pair
                                    }.get_amount_out(*route.tokenIn, *amounts[index])
                                )
                        }
                        index += 1;
                    },
                    Option::None(_) => {
                        break ();
                    }
                };
            };
            amounts
        }
    }

    #[generate_trait]
    impl Modifiers of ModifiersTrait {
        /// @notice This function is used to ensure that the current block timestamp is less than or equal to the deadline
        /// @param deadline The deadline for the transaction
        fn _ensure(deadline: u64) {
            assert(get_block_timestamp() <= deadline, 'expired');
        }

        /// @notice This function is used to ensure that the caller is the handler
        fn assert_only_handler(self: @ContractState) {
            let factoryDipatcher = IStarkDFactoryABIDispatcher {
                contract_address: self._factory.read()
            };
            let caller = get_caller_address();
            assert(caller == factoryDipatcher.fee_handler(), 'not allowed');
        }
    }
}

