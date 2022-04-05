%lang starknet

# @author StarkDefi
# @license MIT
# @description port of uniswap factory

# TODO: Port uniswap factory to cairo

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.math import assert_not_zero

#
# Events
#

# Pair created event
@event
func pair_created(token0 : felt, token1 : felt, pair : felt, pair_count : felt):
end

#
# Storage
#

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

# class has for pair contract, required for `deploy` function
@storage_var
func _class_hash_for_pair_contract() -> (class_hash : felt):
end

#
# Constructor
#

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    fee_to_setter : felt, class_hash_pair_contract : felt, 
):
    with_attr error_message("invalid fee to setter"):
        assert_not_zero(fee_to_setter)
    end

    with_attr error_message("invalid class hash for pair contract"):
        assert_not_zero(class_hash_pair_contract)
    end

    _all_pairs_length.write(0)
    _class_hash_for_pair_contract.write(class_hash_pair_contract)
    _fee_to_setter.write(fee_to_setter)
    return ()
end

#
# Getters
#

# get pair contract address given token0 and token1
# returns  address of pair
@view
func get_pair{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token0 : felt, token1 : felt
) -> (pair : felt):
    return _get_pair.read(token0, token1)
end

# get all pairs
@view
func all_pairs{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    pairs_len : felt, pairs : felt*
):
    alloc_locals
    let (num_pairs) = _all_pairs_length.read()
    let (local pairs : felt*) = alloc()  # allocate an array for pairs
    # TODO: create populate the pairs array
    return (num_pairs, pairs)
end

# get total numbe of pairs
@view
func all_pairs_length{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    len : felt
):
    return _all_pairs_length.read()
end

# get fee to address
@view
func fee_to{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    address : felt
):
    return _fee_to.read()
end

# get fee to setter address
@view
func fee_to_setter{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    address : felt
):
    return _fee_to_setter.read()
end

# get class hash for pair contract
@view
func class_hash_for_pair_contract{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}() -> (class_hash : felt):
    return _class_hash_for_pair_contract.read()
end

#
# Setters
#

# set fee to address
@external
func set_fee_to{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    fee_to_address : felt
):
    let (fee_to_settor) = fee_to_setter()
    let (caller) = get_caller_address()
    with_attr error_message("only fee to setter can set fee to address"):
        assert caller = fee_to_settor
    end
    _fee_to.write(fee_to_address)
    return ()
end

# set fee to setter address
@external
func set_fee_to_setter{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    fee_to_setter_address : felt
):
    let (fee_to_settor) = fee_to_setter()
    let (caller) = get_caller_address()
    with_attr error_message("only current fee to setter can update fee to setter"):
        assert caller = fee_to_settor
    end
    with_attr error_message("invalid fee to setter"):
        assert_not_zero(fee_to_setter_address)
    end

    _fee_to_setter.write(fee_to_setter_address)
    return ()
end

# create pair
@external
func create_pair{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token0 : felt, token1 : felt
) -> (pair : felt):
    # TODO: create pair business logic
    return (pair=0)
end
