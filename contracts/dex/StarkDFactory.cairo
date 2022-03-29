%lang starknet


# @author StarkDefi
# @license MIT
# @description port of uniswap factory

# TODO: Port uniswap factory to cairo

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin

# Contract variables

# `address public feeTo;`
@storage_var
func _fee_to() -> (address : felt):
end

# `address public feeToSetter;`
@storage_var
func _fee_to_setter() -> (address : felt):
end

# mapping(address => mapping(address => address)) public getPair;
@storage_var
func _get_pair(token0 : felt, token1 : felt) -> (pair : felt):
end

# `address[] public allPairs;`
@storage_var
func _all_pairs(index : felt) -> (address : felt):
end

# `allPairsLength()`
@storage_var
func _all_pairs_length() -> (len : felt):
end

# Pair created event
@event
func pair_created(token0 : felt, token1 : felt, pair : felt, pair_count : felt):
end

# class has for pair contract, required for `deploy` function
@storage_var
func _class_hash_for_pair_contract() -> (class_hash : felt):
end