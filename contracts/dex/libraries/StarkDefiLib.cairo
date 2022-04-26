%lang starknet

# @author StarkDefi
# @license MIT
# @description library for StarkDefi contracts

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.math import assert_not_equal, assert_not_zero
from starkware.cairo.common.math_cmp import is_le_felt
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.alloc import alloc

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
        # TODO: implement this function
        return (amountB=Uint256(0, 0))
    end

    func get_amount_out{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        amountIn : Uint256, reserveIn : Uint256, reserveOut : Uint256
    ) -> (amountOut : Uint256):
        # TODO: implement this function
        return (amountOut=Uint256(0, 0))
    end

    func get_amount_in{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        amountOut : Uint256, reserveIn : Uint256, reserveOut : Uint256
    ) -> (amountIn : Uint256):
        # TODO: implement this function
        return (amountIn=Uint256(0, 0))
    end

    func get_amounts_out{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        factory : felt, amountIn : Uint256, path_len : felt, path : felt*
    ) -> (amounts :  Uint256*):
        # TODO: implement this function
        alloc_locals
        let (local amounts: Uint256*) = alloc()
        return (amounts=amounts)
    end

    func get_amounts_in{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        factory : felt, amountOut : Uint256, path_len : felt, path : felt*
    ) -> (amounts : Uint256*):
        # TODO: implement this function
        alloc_locals
        let (local amounts: Uint256*) = alloc()
        return (amounts=amounts)
    end
end
