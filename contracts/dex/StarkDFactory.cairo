%lang starknet

# @author StarkDefi
# @license MIT
# @description port of uniswap factory

# TODO: Port uniswap factory to cairo

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address, deploy
from starkware.cairo.common.math import assert_not_zero, assert_not_equal
from dex.libraries.StarkDefiLib import StarkDefiLib
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.bool import FALSE

#
# Events
#

# Pair created event
@event
func Pair_Created(token0 : felt, token1 : felt, pair : felt, pair_count : felt):
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
    fee_to_setter : felt, class_hash_pair_contract : felt
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
    let (pair_count) = _all_pairs_length.read()
    let (local pairs : felt*) = alloc()  # allocate an array for pairs
    let (pairs_end) = _populate_all_pairs(0, pair_count, pairs)
    return (pair_count, pairs)
end

func _populate_all_pairs{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    index : felt, pair_count : felt, pairs : felt*
) -> (pairs : felt*):
    alloc_locals
    if index == pair_count:
        return (pairs)
    end
    let (pair) = _all_pairs.read(index)
    assert [pairs] = pair
    return _populate_all_pairs(index + 1, pair_count, pairs + 1)
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
    tokenA : felt, tokenB : felt
) -> (pair : felt):
    alloc_locals
    with_attr error_message("invalid tokenA and tokenB"):
        assert_not_zero(tokenA)
        assert_not_zero(tokenB)
    end

    with_attr error_message("same token provided for tokenA and tokenB"):
        assert_not_equal(tokenA, tokenB)
    end

    let (pair_found) = _get_pair.read(tokenA, tokenB)
    with_attr error_message("can't create pair, pair already exists"):
        assert pair_found = 0
    end

    let (token0, token1) = StarkDefiLib.sort_tokens(tokenA, tokenB)
    let (class_hash : felt) = _class_hash_for_pair_contract.read()
    let (this_address : felt) = get_contract_address()
    let pair_constructor_calldata : felt* = alloc()

    assert [pair_constructor_calldata] = token0
    assert [pair_constructor_calldata + 1] = token1
    assert [pair_constructor_calldata + 2] = this_address

    tempvar pedersen_ptr = pedersen_ptr

    let (address_salt) = hash2{hash_ptr=pedersen_ptr}(token0, token1)

    let (pair : felt) = deploy(
        class_hash=class_hash,
        contract_address_salt=address_salt,
        constructor_calldata_size=3,
        constructor_calldata=pair_constructor_calldata,
        deploy_from_zero=FALSE,
    )

    _get_pair.write(token0, token1, pair)
    _get_pair.write(token1, token0, pair)  # pair is symmetric

    # update all pairs length and all pairs array
    let (pair_count) = _all_pairs_length.read()
    _all_pairs_length.write(pair_count + 1)
    _all_pairs.write(pair_count, pair)

    # Emit event
    Pair_Created.emit(token0=token0, token1=token1, pair=pair, pair_count=pair_count + 1)
    return (pair)
end
