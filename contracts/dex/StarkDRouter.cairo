%lang starknet

# @author StarkDefi
# @license MIT
# @description port of uniswap router

# TODO: Port uniswap router to cairo

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256
from dex.interfaces.IERC20 import IERC20
from dex.interfaces.IStarkDFactory import IStarkDFactory
from dex.interfaces.IStarkDPair import IStarkDPair
from dex.libraries.StarkDefiLib import StarkDefiLib
from starkware.cairo.common.math import assert_not_zero, assert_le
from starkware.cairo.common.alloc import alloc
from starkware.starknet.common.syscalls import get_block_timestamp

#
# Storage
#

@storage_var
func _factory() -> (address : felt):
end

#
# Constructor
#

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(factory : felt):
    with_attr error_message("invalid factory"):
        assert_not_zero(factory)
    end

    _factory.write(factory)
    return ()
end

#
# Getters
#

@view
func factory{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    address : felt
):
    let (address) = _factory.read()
    return (address)
end

@view
func sort_tokens{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    tokenA : felt, tokenB : felt
) -> (token0 : felt, token1 : felt):
    return StarkDefiLib.sort_tokens(tokenA, tokenB)
end

@view
func quote{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    amountA : Uint256, reserveA : Uint256, reserveB : Uint256
) -> (amountB : Uint256):
    return StarkDefiLib.quote(amountA, reserveA, reserveB)
end

@view
func get_amount_out{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    amountIn : Uint256, reserveIn : Uint256, reserveOut : Uint256
) -> (amountOut : Uint256):
    return StarkDefiLib.get_amount_out(amountIn, reserveIn, reserveOut)
end

@view
func get_amount_in{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    amountOut : Uint256, reserveIn : Uint256, reserveOut : Uint256
) -> (amountIn : Uint256):
    return StarkDefiLib.get_amount_in(amountOut, reserveIn, reserveOut)
end

@view
func get_amounts_out{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    amountIn : Uint256, path_len : felt, path : felt*
) -> (amounts_len : felt, amounts : Uint256*):
    alloc_locals
    let (local factory) = _factory.read()
    let (local amounts : Uint256*) = StarkDefiLib.get_amounts_out(factory, amountIn, path_len, path)
    return (path_len, amounts)
end

@view
func get_amounts_in{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    amountOut : Uint256, path_len : felt, path : felt*
) -> (amounts_len : felt, amounts : Uint256*):
    alloc_locals
    let (local factory) = _factory.read()
    let (local amounts : Uint256*) = StarkDefiLib.get_amounts_in(factory, amountOut, path_len, path)
    return (path_len, amounts)
end

#
# Externals
#

func _ensure{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(deadline : felt):
    let (block_timestamp) = get_block_timestamp()
    with_attr error_message("expired"):
        assert_le(block_timestamp, deadline)
    end
    return ()
end

@external
func add_liquidity{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    tokenA : felt,
    tokenB : felt,
    amountADesired : Uint256,
    amountBDesired : Uint256,
    amountAMin : Uint256,
    amountBMin : Uint256,
    to : felt,
    deadline : felt,
) -> (amountA : Uint256, amountB : Uint256, liquidity : Uint256):
    # TODO: implement add liquidity
    return (amountA=Uint256(0, 0), amountB=Uint256(0, 0), liquidity=Uint256(0, 0))
end

@external
func remove_liquidity{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    tokenA : felt,
    tokenB : felt,
    liquidity : Uint256,
    amountAMin : Uint256,
    amountBMin : Uint256,
    to : felt,
    deadline : felt,
) -> (amountA : Uint256, amountB : Uint256):
    # TODO: implement remove liquidity

    return (amountA=Uint256(0, 0), amountB=Uint256(0, 0))
end

@external
func swap_exact_tokens_for_tokens{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}(
    amountIn : Uint256,
    amountOutMin : Uint256,
    path_len : felt,
    path : felt*,
    to : felt,
    deadline : felt,
) -> (amounts_len : felt, amounts : Uint256*):
    # TODO: implement swap exact tokens for tokens
    alloc_locals
    let (local amounts : Uint256*) = alloc()
    return (amounts_len=0, amounts=amounts)
end

@external
func swap_tokens_for_exact_tokens{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}(
    amountOut : Uint256,
    amountInMax : Uint256,
    path_len : felt,
    path : felt*,
    to : felt,
    deadline : felt,
) -> (amounts_len : felt, amounts : Uint256*):
    # TODO: implement swap exact tokens for tokens
    alloc_locals
    let (local amounts : Uint256*) = alloc()
    return (amounts_len=0, amounts=amounts)
end

#
# Internals
#

func _add_liquidity{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    tokenA : felt,
    tokenB : felt,
    amountADesired : Uint256,
    amountBDesired : Uint256,
    amountAMin : Uint256,
    amountBMin : Uint256,
) -> (amountA : Uint256, amountB : Uint256):
    # TODO: Implement add liquidity
    return (amountA=Uint256(0, 0), amountB=Uint256(0, 0))
end

func _swap{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    current_index : felt, amounts_len : felt, amounts : Uint256*, path : felt*, _to : felt
):
    # TODO: implement swap
    return ()
end

func _pair_for{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    factory : felt, tokenA : felt, tokenB : felt
) -> (pair : felt):
    # TODO: implement pair for
    return (pair=0)
end

func _get_reserves{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    factory : felt, tokenA : felt, tokenB : felt
) -> (reserveA : Uint256, reserveB : Uint256):
    # TODO: implement get reserves
    return (reserveA=Uint256(0, 0), reserveB=Uint256(0, 0))
end
