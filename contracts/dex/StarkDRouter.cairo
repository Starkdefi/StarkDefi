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
) -> (amountB : felt):
    return StarkDefiLib.quote(amountA, reserveA, reserveB)
end

@view
func get_amount_out{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    amountIn : Uint256, reserveIn : Uint256, reserveOut : Uint256
) -> (amountOut : felt):
    return StarkDefiLib.get_amount_out(amountIn, reserveIn, reserveOut)
end

@view
func get_amount_in{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    amountOut : Uint256, reserveIn : Uint256, reserveOut : Uint256
) -> (amountIn : felt):
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
) -> (amounts_len : felt, amounts : felt*):
    alloc_locals
    let (local factory) = _factory.read()
    let (local amounts : Uint256*) = StarkDefiLib.get_amounts_in(factory, amountOut, path_len, path)
    return (path_len, amounts)
end

#
# Externals
#

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
) -> (amountA : felt, amountB : felt, liquidity : felt):
    # TODO: implement add liquidity
    return (amountA=0, amountB=0, liquidity=0)
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
) -> (amountA : felt, amountB : felt):
    # TODO: implement remove liquidity

    return (amountA=0, amountB=0)
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
) -> (amounts_len : felt, amounts : felt*):
    # TODO: implement swap exact tokens for tokens
    return (amounts_len=0, amounts=0)
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
) -> (amounts_len : felt, amounts : felt*):
    # TODO: implement swap exact tokens for tokens
    return (amounts_len=0, amounts=0)
end
