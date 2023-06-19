%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IStarkDPathFinder:
    func get_results(amountIn : Uint256, tokenIn : felt, tokenOut : felt) -> (path_len : felt, path : felt*):
    end

    func set_router_aggregator(_new_router_aggregator_address : felt):
    end
end