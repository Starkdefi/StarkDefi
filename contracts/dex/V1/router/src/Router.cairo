// @title StarkDefi Router Contract
// @author StarkDefi Labs
// @license MIT
// @description Based on UniswapV2 Router Contract

#[contract]
mod StarkDRouter {
    use array::SpanTrait;
    use array::ArrayTrait;
    use zeroable::Zeroable;
    use option::OptionTrait;
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use starknet::get_block_timestamp;
    use starknet::contract_address_const;
    use starkDefi::utils::{ArrayTraitExt, ContractAddressPartialOrd};

    // 
    // Interface
    //

    #[abi]
    trait IERC20 {
        fn transferFrom(sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool;
    }

    #[abi]
    trait IStarkDFactory {
        fn get_pair(tokenA: ContractAddress, tokenB: ContractAddress) -> ContractAddress;
        fn create_pair(tokenA: ContractAddress, tokenB: ContractAddress) -> ContractAddress;
    }

    #[abi]
    trait IStarkDPair {
        fn getReserves() -> (u256, u256, u64);
        fn mint(to: ContractAddress) -> u256;
        fn burn(to: ContractAddress) -> (u256, u256);
        fn swap(amount0Out: u256, amount1Out: u256, to: ContractAddress, data: Array::<felt252>);
    }

    //
    // Storage
    //

    #[storage]
    struct Storage {
        _factory: ContractAddress, 
    }

    //
    // Constructor
    //
    fn constructor(factory: ContractAddress) {
        assert(factory.is_non_zero(), 'invalid factory');
        _factory::write(factory);
    }

    // 
    // Getters
    //
    #[view]
    fn factory() -> ContractAddress {
        _factory::read()
    }

    #[view]
    fn sort_tokens(
        tokenA: ContractAddress, tokenB: ContractAddress
    ) -> (ContractAddress, ContractAddress) {
        assert(tokenA.is_non_zero() & tokenB.is_non_zero(), 'invalid pair');
        _sort_tokens(tokenA, tokenB)
    }

    #[view]
    fn quote(amountA: u256, reserveA: u256, reserveB: u256) -> u256 {
        _quote(amountA, reserveA, reserveB)
    }

    #[view]
    fn get_amount_out(amountIn: u256, reserveIn: u256, reserveOut: u256) -> u256 {
        _get_amount_out(amountIn, reserveIn, reserveOut)
    }

    #[view]
    fn get_amount_in(amountOut: u256, reserveIn: u256, reserveOut: u256) -> u256 {
        _get_amount_in(amountOut, reserveIn, reserveOut)
    }

    #[view]
    fn get_amounts_out(amountIn: u256, path: Array::<ContractAddress>) -> Array::<u256> {
        _get_amounts_out(amountIn, path.span())
    }

    #[view]
    fn get_amounts_in(amountOut: u256, path: Array::<ContractAddress>) -> Array::<u256> {
        _get_amounts_in(amountOut, path.span())
    }

    // 
    // Externals
    // 

    #[external]
    fn add_liquidity(
        tokenA: ContractAddress,
        tokenB: ContractAddress,
        amountADesired: u256,
        amountBDesired: u256,
        amountAMin: u256,
        amountBMin: u256,
        to: ContractAddress,
        deadline: u64
    ) -> (u256, u256, u256) {
        _ensure(deadline);
        let (amountA, amountB) = _add_liquidity(
            tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin
        );
        let pair = _pair_for(tokenA, tokenB);
        let sender = get_caller_address();
        IERC20Dispatcher { contract_address: tokenA }.transferFrom(sender, pair, amountA);
        IERC20Dispatcher { contract_address: tokenB }.transferFrom(sender, pair, amountB);
        let liquidity = IStarkDPairDispatcher { contract_address: pair }.mint(to);
        (amountA, amountB, liquidity)
    }

    #[external]
    fn remove_liquidity(
        tokenA: ContractAddress,
        tokenB: ContractAddress,
        liquidity: u256,
        amountAMin: u256,
        amountBMin: u256,
        to: ContractAddress,
        deadline: u64
    ) -> (u256, u256) {
        _ensure(deadline);
        let pair = _pair_for(tokenA, tokenB);
        let sender = get_caller_address();
        IERC20Dispatcher { contract_address: pair }.transferFrom(sender, pair, liquidity);
        let (amoun0, amount1) = IStarkDPairDispatcher { contract_address: pair }.burn(to);
        let (token0, _) = _sort_tokens(tokenA, tokenB);
        let mut amountA = 0;
        let mut amountB = 0;
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

    #[external]
    fn swap_exact_tokens_for_tokens(
        amountIn: u256,
        amountOutMin: u256,
        path: Array::<ContractAddress>,
        to: ContractAddress,
        deadline: u64
    ) -> Array::<u256> {}

    #[external]
    fn swap_tokens_for_exact_tokens(
        amountOut: u256,
        amountInMax: u256,
        path: Array::<ContractAddress>,
        to: ContractAddress,
        deadline: u64
    ) -> Array::<u256> {}

    // 
    // Internals & Libs
    //

    fn _ensure(deadline: u64) {
        assert(get_block_timestamp() <= deadline, 'expired');
    }

    fn _add_liquidity(
        tokenA: ContractAddress,
        tokenB: ContractAddress,
        amountADesired: u256,
        amountBDesired: u256,
        amountAMin: u256,
        amountBMin: u256
    ) -> (u256, u256) {
        let factory = _factory::read();
        let factoryDispatcher = IStarkDFactoryDispatcher { contract_address: factory };

        if (factoryDispatcher.get_pair(tokenA, tokenB) == contract_address_const::<0>()) {
            factoryDispatcher.create_pair(tokenA, tokenB);
        }

        let (reserveA, reserveB) = _get_reserves(tokenA, tokenB);

        if (reserveA == 0 & reserveB == 0) {
            (amountADesired, amountBDesired)
        } else {
            let amountBOptimal = _quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                assert(amountBOptimal >= amountBMin, 'INSUFFICIENT_B_AMOUNT');
                (amountADesired, amountBOptimal)
            } else {
                let amountAOptimal = _quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired, 'INSUFFICIENT_A_AMOUNT');
                assert(amountAOptimal >= amountAMin, 'INSUFFICIENT_A_AMOUNT');
                (amountAOptimal, amountBDesired)
            }
        }
    }

    // @dev requires the initial amount to have already been sent to the first pair
    fn _swap(amounts: Span::<u256>, path: Span::<ContractAddress>, _to: ContractAddress) {
        let mut index: u32 = 0;
        loop {
            if index == path.len() - 1 {
                break ();
            }
            let (token0, _) = _sort_tokens(*path[index], *path[index + 1]);
            let mut amount0Out: u256 = 0;
            let mut amount1Out: u256 = 0;

            if *path[index] == token0 {
                amount1Out = *amounts[index + 1];
            } else {
                amount0Out = *amounts[index + 1];
            }

            let mut to: ContractAddress = _to;
            if index < path.len() - 2 {
                to = _pair_for(*path[index + 1], *path[index + 2]);
            }

            IStarkDPairDispatcher {
                contract_address: _pair_for(*path[index], *path[index + 1])
            }.swap(amount0Out, amount1Out, to, ArrayTrait::<felt252>::new());
            index += 1;
        }
    }

    fn _pair_for(tokenA: ContractAddress, tokenB: ContractAddress) -> ContractAddress {
        let (token0, token1) = _sort_tokens(tokenA, tokenB);
        IStarkDFactoryDispatcher { contract_address: _factory::read() }.get_pair(token0, token1)
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

    fn _get_reserves(tokenA: ContractAddress, tokenB: ContractAddress) -> (u256, u256) {
        let (token0, _) = _sort_tokens(tokenA, tokenB);
        let pair = _pair_for(tokenA, tokenB);
        let (reserve0, reserve1, _) = IStarkDPairDispatcher {
            contract_address: pair
        }.getReserves();

        if tokenA == token0 {
            (reserve0, reserve1)
        } else {
            (reserve1, reserve0)
        }
    }

    fn _quote(amountA: u256, reserveA: u256, reserveB: u256) -> u256 {
        assert(amountA > 0, 'insufficient amount');
        assert(reserveA > 0 & reserveB > 0, 'insufficient liquidity');
        (amountA * reserveB) / reserveA
    }

    fn _get_amount_out(amountIn: u256, reserveIn: u256, reserveOut: u256) -> u256 {
        assert(amountIn > 0, 'insufficient input amount');
        assert(reserveIn > 0 & reserveOut > 0, 'insufficient liquidity');
        let amountInWithFee = amountIn * 997;
        let numerator = amountInWithFee * reserveOut;
        let denominator = (reserveIn * 1000) + amountInWithFee;
        numerator / denominator
    }

    fn _get_amount_in(amountOut: u256, reserveIn: u256, reserveOut: u256) -> u256 {
        assert(amountOut > 0, 'insufficient output amount');
        assert(reserveIn > 0 & reserveOut > 0, 'insufficient liquidity');
        let numerator = reserveIn * amountOut * 1000;
        let denominator = (reserveOut - amountOut) * 997;
        (numerator / denominator) + 1
    }

    fn _get_amounts_out(amountIn: u256, path: Span::<ContractAddress>) -> Array::<u256> {
        assert(path.len() >= 2, 'invalid path');
        let mut amounts = ArrayTrait::<u256>::new();
        amounts.append(amountIn);

        let mut index = 0;

        loop {
            if index == (path.len() - 1) {
                break true;
            }

            let (reserveIn, reserveOut) = _get_reserves(*path[index], *path[index + 1]);
            amounts.append(_get_amount_out(*amounts[index], reserveIn, reserveOut));
            index += 1;
        };
        amounts
    }

    fn _get_amounts_in(amountOut: u256, path: Span::<ContractAddress>) -> Array::<u256> {
        assert(path.len() >= 2, 'invalid path');
        let mut amounts = ArrayTrait::<u256>::new();
        amounts.append(amountOut);

        let mut index = path.len() - 1;

        loop {
            if index == 0 {
                break true;
            }

            let (reserveIn, reserveOut) = _get_reserves(*path[index - 1], *path[index]);
            amounts.append(_get_amount_in(*amounts[path.len() - index], reserveIn, reserveOut));
            index -= 1;
        };
        amounts.reverse()
    }
}
