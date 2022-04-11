%lang starknet

# @author StarkDefi
# @license MIT
# @description port of uniswap router

# TODO: Port uniswap router to cairo

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IERC20:
    func transferFrom(sender : felt, recipient : felt, amount : Uint256) -> (success : felt):
    end
end

#
# Storage
#

@storage_var
func _factory() -> (address : felt):
end

@view
func factory{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    address : felt
):
    let (address) = _factory.read()
    return (address)
end


@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(factory : felt):
    _factory.write(factory)
    return ()
end

