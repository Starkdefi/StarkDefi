%lang starknet

# @author StarkDefi
# @license MIT
# @description port of uniswap pair contract

# TODO: Port uniswap pair contract to cairo

from dex.interfaces.IERC20 import IERC20
from dex.interfaces.IStarkDFactory import IStarkDFactory
from dex.interfaces.IStarkDCallee import IStarkDCallee
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.cairo_builtins import HashBuiltin

const MINIMUM_LIQUIDITY = 1000

#
# Events
#

@event
func Transfer(from_address : felt, to_address : felt, amount : Uint256):
end

@event
func Approval(owner : felt, spender : felt, amount : Uint256):
end

@event
func Mint(sender : felt, amount0 : Uint256, amount1 : Uint256):
end

@event
func Burn(sender : felt, amount0 : Uint256, amount1 : Uint256, to : felt):
end

@event
func Swap(
    sender : felt,
    amount0In : Uint256,
    amount1In : Uint256,
    amount0Out : Uint256,
    amount1Out : Uint256,
    to : felt,
):
end

@event
func Sync(reserve0 : Uint256, reserve1 : Uint256):
end

#
# Storage for ERC20
#

@storage_var
func _name() -> (res : felt):
end

@storage_var
func _symbol() -> (res : felt):
end

@storage_var
func _decimals() -> (res : felt):
end

@storage_var
func total_supply() -> (res : Uint256):
end

@storage_var
func balances(account : felt) -> (res : Uint256):
end

@storage_var
func allowances(owner : felt, spender : felt) -> (res : Uint256):
end

#
# Storage
#

@storage_var
func _token0() -> (address : felt):
end

@storage_var
func _token1() -> (address : felt):
end

@storage_var
func _reserve0() -> (reserve : Uint256):
end

@storage_var
func _reserve1() -> (reserve : Uint256):
end

@storage_var
func _block_timestamp_last() -> (timestamp : felt):
end

@storage_var
func _price_0_cumulative_last() -> (price : Uint256):
end

@storage_var
func _price_1_cumulative_last() -> (price : Uint256):
end

@storage_var
func _klast() -> (reserve : Uint256):
end

@storage_var
func _factory() -> (address : felt):
end

#
# Constructor
#

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token0 : felt, token1 : felt, factory : felt
):
    _name.write('StarkDefi Pair')
    _symbol.write('STARKD-LP')
    _decimals.write(18)
    _token0.write(token0)
    _token1.write(token1)
    _factory.write(factory)
    return ()
end
