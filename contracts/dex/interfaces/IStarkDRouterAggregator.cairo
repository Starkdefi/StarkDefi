%lang starknet

from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.cairo_builtins import HashBuiltin

@contract_interface
namespace IStarkDRouterAggregator:
    func get_single_best_pool(amountIn : Uint256, tokenIn : felt, tokenOut : felt) -> (amountOut : Uint256):
    end

    func get_weight(amountIn : Uint256, tokenIn : felt, tokenOut : felt) -> (weight : felt):  
    end

    # func get_global_price(token: felt)->(price: Uint256):
    # end

    func get_liquidity_weight(amountIn : Uint256, tokenIn : felt, tokenOut : felt) -> (weight : felt):
    end
end
