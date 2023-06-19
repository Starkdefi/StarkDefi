%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_not_zero
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_lt,
    uint256_le,
    uint256_add,
    uint256_sub,
    uint256_mul,
    uint256_unsigned_div_rem
)
from starkware.cairo.common.alloc import alloc
from dex.libraries.StarkDefiLib import StarkDefiLib
from dex.libraries.utils import Utils

const base = 1000000000000000000 
const StarkD_fee = 3000000000000000 # 0.3% fee 

#
# Storage
#

@storage_var
func _factory() -> (address : felt):
end

@storage_var
func price_feed(asset : felt) -> (oracle_address : felt):
end

#
# Constructor
#

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    factory : felt
):
    with_attr error_message("invalid factory"):
        assert_not_zero(factory)
    end

    _factory.write(factory)
    return ()
end

#
#Views
#

@view
func factory{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    address : felt
):
    let (address) = _factory.read()
    return (address)
end


@view
func get_single_best_pool{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    amountIn : Uint256, tokenIn : felt, tokenOut : felt
) -> (amountOut : Uint256):
    alloc_locals

    let (local factory) = _factory.read()
    let (local pair) = StarkDefiLib.pair_for(factory, tokenIn, tokenOut)

    if pair == 0:
        return (Uint256(0, 0))
    else:
        let (local reserveIn : Uint256, local reserveOut : Uint256) = StarkDefiLib.get_reserves(factory, tokenIn, tokenOut)  
        return StarkDefiLib.get_amount_out(amountIn, reserveIn, reserveOut)
    end    
end

#Calculates weights from liquidity + fees alone (no global prices required)
#Appears to not be feasible
@view
func get_liquidity_weight{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    amountIn : Uint256, tokenIn : felt, tokenOut : felt
) -> (weight : felt):
    alloc_locals

    let (local factory) = _factory.read()
    local weight : felt

    let (local reserve1 : Uint256, local reserve2 : Uint256) = StarkDefiLib.get_reserves(factory, tokenIn, tokenOut)

    let (exchangeRate : Uint256) = Utils.fdiv(reserve1, reserve2, Uint256(base, 0))
    let (optimalAmountOut : Uint256) = Utils.fmul(amountIn, exchangeRate, Uint256(base,0))
    let (local amountOut : Uint256) = StarkDefiLib.get_amount_out(amountIn, reserve1, reserve2)
    let (slippage : Uint256) = Utils.fdiv(amountOut, optimalAmountOut, Uint256(base, 0))
    let (slippageWeight : Uint256) = uint256_sub(Uint256(base, 0), slippage)
    assert weight = slippageWeight.low + StarkD_fee

    tempvar syscall_ptr = syscall_ptr
    tempvar pedersen_ptr = pedersen_ptr
    tempvar range_check_ptr = range_check_ptr

    return(weight)
end

@view
func get_weight{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    amountIn : Uint256, tokenIn : felt, tokenOut : felt, 
) -> (weight : felt):
    alloc_locals

    let (local factory) = _factory.read()
    let (local reserve1 : Uint256, local reserve2 : Uint256) = StarkDefiLib.get_reserves(factory, tokenIn, tokenOut)
    let (local amountOut : Uint256) = StarkDefiLib.get_amount_out(amountIn, reserve1, reserve2)

    let (tradeCost) = uint256_sub(amountIn, amountOut)
    let (routeCost) = Utils.fdiv(tradeCost, amountIn, Uint256(base, 0))

    return(routeCost.low)
end    
