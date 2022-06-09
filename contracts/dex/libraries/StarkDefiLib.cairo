%lang starknet

# @author StarkDefi
# @license MIT
# @description library for StarkDefi contracts

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.math import assert_not_equal, assert_not_zero, assert_le
from starkware.cairo.common.math_cmp import is_le_felt
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_lt,
    uint256_unsigned_div_rem,
)
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE, FALSE
from dex.interfaces.IStarkDFactory import IStarkDFactory
from dex.interfaces.IStarkDPair import IStarkDPair
from dex.libraries.safemath import SafeUint256

namespace StarkDefiLib:
    # Sort tokens by their address
    func sort_tokens{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        tokenA : felt, tokenB : felt
    ) -> (token0 : felt, token1 : felt):
        alloc_locals
        local token0
        local token1
        assert_not_equal(tokenA, tokenB)
        let (is_tokenA_less) = is_le_felt(tokenA, tokenB)
        if is_tokenA_less == 1:
            assert token0 = tokenA
            assert token1 = tokenB
        else:
            assert token0 = tokenB
            assert token1 = tokenA
        end
        assert_not_zero(token0)
        return (token0, token1)
    end

    func pair_for{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        factory : felt, tokenA : felt, tokenB : felt
    ) -> (pair : felt):
        alloc_locals
        let (local token0, local token1) = StarkDefiLib.sort_tokens(tokenA, tokenB)
        let (local pair) = IStarkDFactory.get_pair(
            contract_address=factory, token0=token0, token1=token1
        )
        return (pair)
    end

    func get_reserves{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        factory : felt, tokenA : felt, tokenB : felt
    ) -> (reserveA : Uint256, reserveB : Uint256):
        alloc_locals
        let (local token0, _) = StarkDefiLib.sort_tokens(tokenA, tokenB)
        let (local pair) = StarkDefiLib.pair_for(factory, tokenA, tokenB)
        let (local reserve0 : Uint256, local reserve1 : Uint256, _) = IStarkDPair.get_reserves(
            contract_address=pair
        )
        if tokenA == token0:
            return (reserve0, reserve1)
        else:
            return (reserve1, reserve0)
        end
    end

    func quote{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        amountA : Uint256, reserveA : Uint256, reserveB : Uint256
    ) -> (amountB : Uint256):
        alloc_locals
        let (is_amountA_gt_zero) = uint256_lt(Uint256(0, 0), amountA)

        # require(amountA > 0, 'UniswapV2Library: INSUFFICIENT_AMOUNT');
        with_attr error_message("insufficient amount"):
            assert is_amountA_gt_zero = TRUE
        end

        let (is_reserveA_gt_zero) = uint256_lt(Uint256(0, 0), reserveA)
        let (is_reserveB_gt_zero) = uint256_lt(Uint256(0, 0), reserveB)

        # require(reserveA > 0 && reserveB > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        with_attr error_message("insufficient liquidity"):
            assert is_reserveA_gt_zero = 1
            assert is_reserveB_gt_zero = 1
        end

        # amountB = amountA.mul(reserveB) / reserveA;
        let (amountA_x_reserveB : Uint256) = SafeUint256.mul(amountA, reserveB)
        let (amountB : Uint256, _) = uint256_unsigned_div_rem(amountA_x_reserveB, reserveA)
        return (amountB)
    end

    func get_amount_out{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        amountIn : Uint256, reserveIn : Uint256, reserveOut : Uint256
    ) -> (amountOut : Uint256):
        alloc_locals
        let (is_amountIn_gt_zero) = uint256_lt(Uint256(0, 0), amountIn)

        # require(amountIn > 0, 'UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT');
        with_attr error_message("insufficient input amount"):
            assert is_amountIn_gt_zero = TRUE
        end

        let (is_reserveIn_gt_zero) = uint256_lt(Uint256(0, 0), reserveIn)
        let (is_reserveOut_gt_zero) = uint256_lt(Uint256(0, 0), reserveOut)

        # require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        with_attr error_message("insufficient liquidity"):
            assert is_reserveIn_gt_zero = TRUE
            assert is_reserveOut_gt_zero = TRUE
        end

        let (amountIn_with_fee : Uint256) = SafeUint256.mul(amountIn, Uint256(997, 0))
        let (numerator : Uint256) = SafeUint256.mul(amountIn_with_fee, reserveOut)
        let (reserveIn_x_1000 : Uint256) = SafeUint256.mul(reserveIn, Uint256(1000, 0))
        let (local denominator : Uint256) = SafeUint256.add(reserveIn_x_1000, amountIn_with_fee)

        let (amountOut : Uint256, _) = uint256_unsigned_div_rem(numerator, denominator)
        return (amountOut)
    end

    func get_amount_in{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        amountOut : Uint256, reserveIn : Uint256, reserveOut : Uint256
    ) -> (amountIn : Uint256):
        alloc_locals
        let (is_amountOut_gt_zero) = uint256_lt(Uint256(0, 0), amountOut)

        # require(amountOut > 0, 'UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT');
        with_attr error_message("insufficient output amount"):
            assert is_amountOut_gt_zero = TRUE
        end

        let (is_reserveIn_gt_zero) = uint256_lt(Uint256(0, 0), reserveIn)
        let (is_reserveOut_gt_zero) = uint256_lt(Uint256(0, 0), reserveOut)

        # require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        with_attr error_message("insufficient liquidity"):
            assert is_reserveIn_gt_zero = TRUE
            assert is_reserveOut_gt_zero = TRUE
        end

        let (amountOut_mul_reserveIn : Uint256) = SafeUint256.mul(amountOut, reserveIn)
        let (numerator : Uint256) = SafeUint256.mul(amountOut_mul_reserveIn, Uint256(1000, 0))
        let (sub_result : Uint256) = SafeUint256.sub_lt(reserveOut, amountOut)
        let (denominator : Uint256) = SafeUint256.mul(sub_result, Uint256(997, 0))

        let (div_result : Uint256, _) = uint256_unsigned_div_rem(numerator, denominator)
        let (local amountIn : Uint256) = SafeUint256.add(div_result, Uint256(1, 0))

        return (amountIn)
    end

    func get_amounts_out{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        factory : felt, amountIn : Uint256, path_len : felt, path : felt*
    ) -> (amounts : Uint256*):
        alloc_locals

        # require(path.length >= 2, 'UniswapV2Library: INVALID_PATH');
        with_attr error_message("invalid path"):
            assert_le(2, path_len)
        end

        let (local amounts : Uint256*) = alloc()
        let (amounts_end : Uint256*) = _populate_amounts_out(
            factory, amountIn, 0, path_len, path, amounts
        )

        return (amounts)
    end

    func _populate_amounts_out{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        factory : felt,
        amountIn : Uint256,
        current_index : felt,
        path_len : felt,
        path : felt*,
        amounts : Uint256*,
    ) -> (amounts : Uint256*):
        alloc_locals

        if current_index == path_len:
            return (amounts)
        end

        if current_index == 0:
            assert [amounts] = amountIn
            tempvar syscall_ptr = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr
            tempvar range_check_ptr = range_check_ptr
        else:
            let (local reserveIn : Uint256, local reserveOut : Uint256) = StarkDefiLib.get_reserves(
                factory, [path - 1], [path]
            )
            let (local amountOut : Uint256) = StarkDefiLib.get_amount_out(
                [amounts - Uint256.SIZE], reserveIn, reserveOut
            )
            assert [amounts] = amountOut
            tempvar syscall_ptr = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr
            tempvar range_check_ptr = range_check_ptr
        end

        return _populate_amounts_out(
            factory, amountIn, current_index + 1, path_len, path + 1, amounts + Uint256.SIZE
        )
    end

    func get_amounts_in{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        factory : felt, amountOut : Uint256, path_len : felt, path : felt*
    ) -> (amounts : Uint256*):
        alloc_locals

        # require(path.length >= 2, 'UniswapV2Library: INVALID_PATH');
        with_attr error_message("invalid path"):
            assert_le(2, path_len)
        end
        let (local amounts : Uint256*) = alloc()
        let (amounts_end : Uint256*) = _populate_amounts_in(
            factory,
            amountOut,
            path_len - 1,
            path_len,
            path + (path_len - 1),
            amounts + (path_len - 1) * Uint256.SIZE,
        )

        return (amounts)
    end

    func _populate_amounts_in{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        factory : felt,
        amountOut : Uint256,
        current_index : felt,
        path_len : felt,
        path : felt*,
        amounts : Uint256*,
    ) -> (amounts : Uint256*):
        alloc_locals

        if current_index == path_len - 1:
            assert [amounts] = amountOut
            tempvar syscall_ptr = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr
            tempvar range_check_ptr = range_check_ptr
        else:
            let (local reserveIn : Uint256, local reserveOut : Uint256) = StarkDefiLib.get_reserves(
                factory, [path], [path + 1]
            )
            let (local amountIn : Uint256) = StarkDefiLib.get_amount_in(
                [amounts + Uint256.SIZE], reserveIn, reserveOut
            )
            assert [amounts] = amountIn
            tempvar syscall_ptr = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr
            tempvar range_check_ptr = range_check_ptr
        end

        if current_index == 0:
            return (amounts)
        end

        return _populate_amounts_in(
            factory, amountOut, current_index - 1, path_len, path - 1, amounts - Uint256.SIZE
        )
    end
end
