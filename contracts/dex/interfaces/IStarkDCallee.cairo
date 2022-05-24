%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IStarkDCallee:
    func starkd_call(
        sender : felt, amount0Out : Uint256, amount1Out : Uint256, data_len : felt, data : felt*
    ):
    end
end
