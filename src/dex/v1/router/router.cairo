// @title StarkDefi Router Contract
// @author StarkDefi Labs
// @license MIT
// @description Based on UniswapV2 Router Contract

#[starknet::contract]
mod StarkDRouter {
    use starkDefi::dex::v1::router::interface::IStarkDRouter;
    use starkDefi::dex::v1::router::call_contract_with_selector_fallback;

    use starkDefi::dex::v1::router::utils::UnwrapFelt;
    use starkDefi::dex::v1::factory::{IStarkDFactoryDispatcherTrait, IStarkDFactoryDispatcher};
    use starkDefi::dex::v1::pair::interface::{IStarkDPairDispatcherTrait, IStarkDPairDispatcher};
    use starkDefi::token::erc20::selectors::{transfer_from, transferFrom};
    use starkDefi::utils::{ArrayTraitExt, ContractAddressPartialOrd};
    use array::SpanTrait;
    use array::ArrayTrait;
    use zeroable::Zeroable;
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use starknet::get_block_timestamp;
    use starknet::contract_address_const;

    #[storage]
    struct Storage {
        _factory: ContractAddress, 
    }

    #[contructor]
    fn constructor(ref self: ContractState, factory: ContractAddress) {
        assert(factory.is_non_zero(), 'invalid factory');
        self._factory.write(factory);
    }

    #[external(v0)]
    impl StarkDRouter of IStarkDRouter<ContractState> {
        fn factory(self: @ContractState) -> ContractAddress {
            self._factory.read()
        }


        fn sort_tokens(
            self: @ContractState, tokenA: ContractAddress, tokenB: ContractAddress
        ) -> (ContractAddress, ContractAddress) {
            assert(tokenA.is_non_zero() & tokenB.is_non_zero(), 'invalid pair');
            InternalFunctions::_sort_tokens(tokenA, tokenB)
        }


        fn quote(self: @ContractState, amountA: u256, reserveA: u256, reserveB: u256) -> u256 {
            InternalFunctions::_quote(amountA, reserveA, reserveB)
        }


        fn get_amount_out(
            self: @ContractState, amountIn: u256, reserveIn: u256, reserveOut: u256
        ) -> u256 {
            InternalFunctions::_get_amount_out(amountIn, reserveIn, reserveOut)
        }


        fn get_amount_in(
            self: @ContractState, amountOut: u256, reserveIn: u256, reserveOut: u256
        ) -> u256 {
            InternalFunctions::_get_amount_in(amountOut, reserveIn, reserveOut)
        }


        fn get_amounts_out(
            self: @ContractState, amountIn: u256, path: Array::<ContractAddress>
        ) -> Array::<u256> {
            let factory = self._factory.read();
            InternalFunctions::_get_amounts_out(factory, amountIn, path.span())
        }


        fn get_amounts_in(
            self: @ContractState, amountOut: u256, path: Array::<ContractAddress>
        ) -> Array::<u256> {
            let factory = self._factory.read();
            InternalFunctions::_get_amounts_in(factory, amountOut, path.span())
        }

        fn add_liquidity(
            ref self: ContractState,
            tokenA: ContractAddress,
            tokenB: ContractAddress,
            amountADesired: u256,
            amountBDesired: u256,
            amountAMin: u256,
            amountBMin: u256,
            to: ContractAddress,
            deadline: u64
        ) -> (u256, u256, u256) {
            InternalFunctions::_ensure(deadline);
            let factory = self._factory.read();
            let (amountA, amountB) = InternalFunctions::_add_liquidity(
                ref self, tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin
            );
            let pair = InternalFunctions::_pair_for(factory, tokenA, tokenB);
            let sender = get_caller_address();

            InternalFunctions::_transfer_token_from(tokenA, sender, pair, amountA);
            InternalFunctions::_transfer_token_from(tokenB, sender, pair, amountB);

            let liquidity = IStarkDPairDispatcher { contract_address: pair }.mint(to);
            (amountA, amountB, liquidity)
        }


        fn remove_liquidity(
            ref self: ContractState,
            tokenA: ContractAddress,
            tokenB: ContractAddress,
            liquidity: u256,
            amountAMin: u256,
            amountBMin: u256,
            to: ContractAddress,
            deadline: u64
        ) -> (u256, u256) {
            InternalFunctions::_ensure(deadline);
            let factory = self._factory.read();

            let pair = InternalFunctions::_pair_for(factory, tokenA, tokenB);
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

        fn swap_exact_tokens_for_tokens(
            ref self: ContractState,
            amountIn: u256,
            amountOutMin: u256,
            path: Array::<ContractAddress>,
            to: ContractAddress,
            deadline: u64
        ) -> Array::<u256> {
            InternalFunctions::_ensure(deadline);
            let factory = self._factory.read();
            let amounts = InternalFunctions::_get_amounts_out(factory, amountIn, path.span());
            assert(*amounts[amounts.len() - 1] >= amountOutMin, 'insufficient output amount');
            let pair = InternalFunctions::_pair_for(factory, *path[0], *path[1]);
            let sender = get_caller_address();

            InternalFunctions::_transfer_token_from(*path[0], sender, pair, *amounts[0]);

            InternalFunctions::_swap(ref self, amounts.span(), path.span(), to);
            amounts
        }

        fn swap_tokens_for_exact_tokens(
            ref self: ContractState,
            amountOut: u256,
            amountInMax: u256,
            path: Array::<ContractAddress>,
            to: ContractAddress,
            deadline: u64
        ) -> Array::<u256> {
            InternalFunctions::_ensure(deadline);
            let factory = self._factory.read();
            let amounts = InternalFunctions::_get_amounts_in(factory, amountOut, path.span());
            assert(*amounts[0] <= amountInMax, 'excessive input amount');
            let pair = InternalFunctions::_pair_for(factory, *path[0], *path[1]);
            let sender = get_caller_address();

            InternalFunctions::_transfer_token_from(*path[0], sender, pair, *amounts[0]);
            InternalFunctions::_swap(ref self, amounts.span(), path.span(), to);
            amounts
        }
    }


    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _ensure(deadline: u64) {
            assert(get_block_timestamp() <= deadline, 'expired');
        }

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
                token, transfer_from, transferFrom, call_data.span()
            )
                .unwrap_syscall();
        }

        fn _add_liquidity(
            ref self: ContractState,
            tokenA: ContractAddress,
            tokenB: ContractAddress,
            amountADesired: u256,
            amountBDesired: u256,
            amountAMin: u256,
            amountBMin: u256
        ) -> (u256, u256) {
            let factory = self._factory.read();
            let factoryDispatcher = IStarkDFactoryDispatcher { contract_address: factory };

            let pair = factoryDispatcher.get_pair(tokenA, tokenB);

            if (pair == contract_address_const::<0>()) {
                factoryDispatcher.create_pair(tokenA, tokenB);
            }

            let (reserveA, reserveB) = InternalFunctions::_get_reserves(factory, tokenA, tokenB);

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
                    assert(amountAOptimal <= amountADesired, '');
                    assert(amountAOptimal >= amountAMin, 'INSUFFICIENT_A_AMOUNT');
                    (amountAOptimal, amountBDesired)
                }
            }
        }

        // @dev requires the initial amount to have already been sent to the first pair
        fn _swap(
            ref self: ContractState,
            amounts: Span::<u256>,
            path: Span::<ContractAddress>,
            _to: ContractAddress
        ) {
            let mut index: u32 = 0;
            let factory = self._factory.read();
            loop {
                if index == path.len() - 1 {
                    break ();
                }
                let (token0, _) = InternalFunctions::_sort_tokens(*path[index], *path[index + 1]);
                let mut amount0Out: u256 = 0;
                let mut amount1Out: u256 = 0;

                if *path[index] == token0 {
                    amount1Out = *amounts[index + 1];
                } else {
                    amount0Out = *amounts[index + 1];
                }

                let mut to: ContractAddress = _to;
                if index < path.len() - 2 {
                    to = InternalFunctions::_pair_for(factory, *path[index + 1], *path[index + 2]);
                }

                IStarkDPairDispatcher {
                    contract_address: InternalFunctions::_pair_for(
                        factory, *path[index], *path[index + 1]
                    )
                }.swap(amount0Out, amount1Out, to, ArrayTrait::<felt252>::new());
                index += 1;
            }
        }

        fn _pair_for(
            factory: ContractAddress, tokenA: ContractAddress, tokenB: ContractAddress
        ) -> ContractAddress {
            let (token0, token1) = InternalFunctions::_sort_tokens(tokenA, tokenB);
            IStarkDFactoryDispatcher { contract_address: factory }.get_pair(token0, token1)
        }

        fn _get_reserves(
            factory: ContractAddress, tokenA: ContractAddress, tokenB: ContractAddress
        ) -> (u256, u256) {
            let (token0, _) = InternalFunctions::_sort_tokens(tokenA, tokenB);
            let pair = InternalFunctions::_pair_for(factory, tokenA, tokenB);
            let (reserve0, reserve1, _) = IStarkDPairDispatcher {
                contract_address: pair
            }.get_reserves();

            if tokenA == token0 {
                (reserve0, reserve1)
            } else {
                (reserve1, reserve0)
            }
        }

        fn _quote(amountA: u256, reserveA: u256, reserveB: u256) -> u256 {
            assert(amountA > 0, 'insufficient amount');
            assert(reserveA > 0 && reserveB > 0, 'insufficient liquidity');
            (amountA * reserveB) / reserveA
        }

        fn _get_amount_out(amountIn: u256, reserveIn: u256, reserveOut: u256) -> u256 {
            assert(amountIn > 0, 'insufficient input amount');
            assert(reserveIn > 0 && reserveOut > 0, 'insufficient liquidity');
            let amountInWithFee = amountIn * 997;
            let numerator = amountInWithFee * reserveOut;
            let denominator = (reserveIn * 1000) + amountInWithFee;
            numerator / denominator
        }

        fn _get_amount_in(amountOut: u256, reserveIn: u256, reserveOut: u256) -> u256 {
            assert(amountOut > 0, 'insufficient output amount');
            assert(reserveIn > 0 && reserveOut > 0, 'insufficient liquidity');
            let numerator = reserveIn * amountOut * 1000;
            let denominator = (reserveOut - amountOut) * 997;
            (numerator / denominator) + 1
        }

        fn _get_amounts_out(
            factory: ContractAddress, amountIn: u256, path: Span::<ContractAddress>
        ) -> Array::<u256> {
            assert(path.len() >= 2, 'invalid path');
            let mut amounts = ArrayTrait::<u256>::new();
            amounts.append(amountIn);

            let mut index: u32 = 0;

            loop {
                if index == (path.len() - 1) {
                    break true;
                }

                let (reserveIn, reserveOut) = InternalFunctions::_get_reserves(
                    factory, *path[index], *path[index + 1]
                );
                amounts
                    .append(
                        InternalFunctions::_get_amount_out(*amounts[index], reserveIn, reserveOut)
                    );
                index += 1;
            };
            amounts
        }

        fn _get_amounts_in(
            factory: ContractAddress, amountOut: u256, path: Span::<ContractAddress>
        ) -> Array::<u256> {
            assert(path.len() >= 2, 'invalid path');
            let mut amounts = ArrayTrait::<u256>::new();
            amounts.append(amountOut);

            let mut index = path.len() - 1;

            loop {
                if index == 0 {
                    break true;
                }

                let (reserveIn, reserveOut) = InternalFunctions::_get_reserves(
                    factory, *path[index - 1], *path[index]
                );
                amounts
                    .append(
                        InternalFunctions::_get_amount_in(
                            *amounts[path.len() - index], reserveIn, reserveOut
                        )
                    );
                index -= 1;
            };
            amounts.reverse()
        }
    }
}
