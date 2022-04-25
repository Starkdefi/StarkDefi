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
from starkware.cairo.common.math import assert_not_zero

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
    with_attr error_message("token0 and token1 must not be zero"):
        assert_not_zero(token0)
        assert_not_zero(token1)
    end
    _name.write('StarkDefi Pair')
    _symbol.write('STARKD-LP')
    _decimals.write(18)
    _token0.write(token0)
    _token1.write(token1)
    _factory.write(factory)
    return ()
end

#
# Getters
#

@view
func name{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (name : felt):
    let (name) = _name.read()
    return (name)
end

@view
func symbol{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (symbol : felt):
    let (symbol) = _symbol.read()
    return (symbol)
end

@view
func totalSupply{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    totalSupply : Uint256
):
    let (totalSupply : Uint256) = total_supply.read()
    return (totalSupply)
end

@view
func decimals{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    decimals : felt
):
    let (decimals) = _decimals.read()
    return (decimals)
end

@view
func balanceOf{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account : felt
) -> (balance : Uint256):
    let (balance : Uint256) = balances.read(account=account)
    return (balance)
end

@view
func allowance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    owner : felt, spender : felt
) -> (remaining : Uint256):
    let (remaining : Uint256) = allowances.read(owner=owner, spender=spender)
    return (remaining)
end

@view
func token0{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    address : felt
):
    let (address) = _token0.read()
    return (address)
end

@view
func token1{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    address : felt
):
    let (address) = _token1.read()
    return (address)
end

@view
func get_reserves{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    reserve0 : Uint256, reserve1 : Uint256, block_timestamp_last : felt
):
    let (reserve0) = _reserve0.read()
    let (reserve1) = _reserve1.read()
    let (block_timestamp_last) = _block_timestamp_last.read()
    return (reserve0, reserve1, block_timestamp_last)
end

@view
func price_0_cumulative_last{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    ) -> (res : Uint256):
    let (res) = _price_0_cumulative_last.read()
    return (res)
end

@view
func price_1_cumulative_last{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    ) -> (res : Uint256):
    let (res) = _price_1_cumulative_last.read()
    return (res)
end

@view
func klast{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (res : Uint256):
    let (res) = _klast.read()
    return (res)
end
