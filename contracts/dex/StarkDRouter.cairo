%lang starknet

# @author StarkDefi
# @license MIT
# @description port of uniswap router

# TODO: Port uniswap router to cairo

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_eq, uint256_le
from dex.interfaces.IERC20 import IERC20
from dex.interfaces.IStarkDFactory import IStarkDFactory
from dex.interfaces.IStarkDPair import IStarkDPair
from dex.libraries.StarkDefiLib import StarkDefiLib
from starkware.cairo.common.math import assert_not_zero, assert_le
from starkware.cairo.common.alloc import alloc
from starkware.starknet.common.syscalls import get_block_timestamp, get_caller_address
from dex.libraries.safemath import SafeUint256
from starkware.cairo.common.bool import TRUE, FALSE

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
    alloc_locals
    _ensure(deadline)

    let (local factory) = _factory.read()
    let (local amountA : Uint256, local amountB : Uint256) = _add_liquidity(
        tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin
    )

    let (local pair) = _pair_for(factory, tokenA, tokenB)
    let (sender) = get_caller_address()

    IERC20.transferFrom(contract_address=tokenA, sender=sender, recipient=pair, amount=amountA)
    IERC20.transferFrom(contract_address=tokenB, sender=sender, recipient=pair, amount=amountB)

    let (local liquidity : Uint256) = IStarkDPair.mint(contract_address=pair, to=to)
    return (amountA, amountB, liquidity)
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
    alloc_locals
    _ensure(deadline)

    let (local factory) = _factory.read()
    let (local pair) = _pair_for(factory, tokenA, tokenB)
    let (sender) = get_caller_address()

    IERC20.transferFrom(contract_address=pair, sender=sender, recipient=pair, amount=liquidity)

    let (local amount0 : Uint256, local amount1 : Uint256) = IStarkDPair.burn(
        contract_address=pair, to=to
    )
    let (local token0, _) = StarkDefiLib.sort_tokens(tokenA, tokenB)
    local amountA : Uint256
    local amountB : Uint256

    if tokenA == token0:
        assert amountA = amount0
        assert amountB = amount1
    else:
        assert amountA = amount1
        assert amountB = amount0
    end

    let (is_amountA_ge_amountAMin) = uint256_le(amountAMin, amountA)

    # require(amountA >= amountAMin, 'UniswapV2Router: INSUFFICIENT_A_AMOUNT');
    with_attr error_message("insufficient A amount"):
        assert is_amountA_ge_amountAMin = TRUE
    end

    let (is_amountB_ge_amountBMin) = uint256_le(amountBMin, amountB)

    # require(amountB >= amountBMin, 'UniswapV2Router: INSUFFICIENT_B_AMOUNT');
    with_attr error_message("insufficient B amount"):
        assert is_amountB_ge_amountBMin = TRUE
    end

    return (amountA, amountB)
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
    alloc_locals

    let (local factory) = _factory.read()
    let (local pair) = IStarkDFactory.get_pair(
        contract_address=factory, token0=tokenA, token1=tokenB
    )

    if pair == FALSE:
        let (new_pair) = IStarkDFactory.create_pair(
            contract_address=factory, token0=tokenA, token1=tokenB
        )
    end

    let (local reserveA : Uint256, local reserveB : Uint256) = _get_reserves(
        factory, tokenA, tokenB
    )
    let (reserveA_x_reserveB : Uint256) = SafeUint256.mul(reserveA, reserveB)
    let (is_reserveA_x_reserveB_zero) = uint256_eq(reserveA_x_reserveB, Uint256(0, 0))

    if is_reserveA_x_reserveB_zero == TRUE:
        return (amountADesired, amountBDesired)
    else:
        let (local amountBOptimal : Uint256) = StarkDefiLib.quote(
            amountADesired, reserveA, reserveB
        )
        let (is_amountBOptimal_le_amountBDesired) = uint256_le(amountBOptimal, amountBDesired)

        if is_amountBOptimal_le_amountBDesired == TRUE:
            let (is_amountBOptimal_ge_amountBMin) = uint256_le(amountBMin, amountBOptimal)

            # require(amountBOptimal >= amountBMin, 'UniswapV2Router: INSUFFICIENT_B_AMOUNT');
            with_attr error_message("insufficient B amount"):
                assert is_amountBOptimal_ge_amountBMin = TRUE
            end

            return (amountADesired, amountBOptimal)
        else:
            let (local amountAOptimal : Uint256) = StarkDefiLib.quote(
                amountBDesired, reserveB, reserveA
            )
            let (is_amountAOptimal_le_amountADesired) = uint256_le(amountAOptimal, amountADesired)
            assert is_amountAOptimal_le_amountADesired = TRUE
            let (is_amountAOptimal_ge_amountAMin) = uint256_le(amountAMin, amountAOptimal)

            # require(amountAOptimal >= amountAMin, 'UniswapV2Router: INSUFFICIENT_A_AMOUNT');
            with_attr error_message("insufficient A amount"):
                assert is_amountAOptimal_ge_amountAMin = TRUE
            end

            return (amountAOptimal, amountBDesired)
        end
    end
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
    alloc_locals
    let (local pair : felt) = StarkDefiLib.pair_for(factory=factory, tokenA=tokenA, tokenB=tokenB)
    return (pair=0)
end

func _get_reserves{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    factory : felt, tokenA : felt, tokenB : felt
) -> (reserveA : Uint256, reserveB : Uint256):
    alloc_locals
    let (local reserveA : Uint256, local reserveB : Uint256) = StarkDefiLib.get_reserves(
        factory=factory, tokenA=tokenA, tokenB=tokenB
    )
    return (reserveA=reserveA, reserveB=reserveB)
end
