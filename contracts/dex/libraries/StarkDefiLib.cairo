%lang starknet

# @author StarkDefi
# @license MIT
# @description library for StarkDefi contracts

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.math import assert_not_equal, assert_not_zero
from starkware.cairo.common.math_cmp import is_le_felt
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_lt,
    uint256_mul,
    uint256_add,
    uint256_unsigned_div_rem,
)
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE, FALSE

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
        let (amountA_x_reserveB : Uint256) = uint256_mul(amountA, reserveB)
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

        let (amountIn_with_fee : Uint256) = uint256_mul(amountIn, Uint256(997, 0))
        let (numerator : Uint256) = uint256_mul(amountIn_with_fee, reserveOut)
        let (reserveIn_x_1000 : Uint256) = uint256_mul(reserveIn, Uint256(1000, 0))
        let (local denominator : Uint256) = uint256_add(reserveIn_x_1000, amountIn_with_fee)

        let (amountOut : Uint256, _) = uint256_unsigned_div_rem(numerator, denominator)
        return (amountOut)
    end

    func get_amount_in{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        amountOut : Uint256, reserveIn : Uint256, reserveOut : Uint256
    ) -> (amountIn : Uint256):
        # TODO: implement this function
        return (amountIn=Uint256(0, 0))
    end

    func get_amounts_out{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        factory : felt, amountIn : Uint256, path_len : felt, path : felt*
    ) -> (amounts : Uint256*):
        # TODO: implement this function
        alloc_locals
        let (local amounts : Uint256*) = alloc()
        return (amounts=amounts)
    end

    func get_amounts_in{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        factory : felt, amountOut : Uint256, path_len : felt, path : felt*
    ) -> (amounts : Uint256*):
        # TODO: implement this function
        alloc_locals
        let (local amounts : Uint256*) = alloc()
        return (amounts=amounts)
    end
end
