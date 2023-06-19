%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IStarkDPair:
    func name() -> (name : felt):
    end

    func symbol() -> (symbol : felt):
    end

    func decimals() -> (decimals : felt):
    end

    func totalSupply() -> (totalSupply : Uint256):
    end

    func balanceOf(account : felt) -> (balance : Uint256):
    end

    func allowance(owner : felt, spender : felt) -> (remaining : Uint256):
    end

    func transfer(recipient : felt, amount : Uint256) -> (success : felt):
    end

    func transferFrom(sender : felt, recipient : felt, amount : Uint256) -> (success : felt):
    end

    func approve(spender : felt, amount : Uint256) -> (success : felt):
    end

    func factory() -> (address : felt):
    end

    func token0() -> (address : felt):
    end

    func token1() -> (address : felt):
    end

    func price_0_cumulative_last() -> (price : Uint256):
    end

    func price_1_cumulative_last() -> (price : Uint256):
    end

    func klast() -> (reserve : Uint256):
    end

    func get_reserves() -> (reserve0 : Uint256, reserve1 : Uint256, block_timestamp_last : felt):
    end

    func mint(to : felt) -> (liquidity : Uint256):
    end

    func burn(to : felt) -> (amount0 : Uint256, amount1 : Uint256):
    end

    func swap(amount0Out : Uint256, amount1Out : Uint256, to : felt, data_len : felt):
    end

    func skim(to : felt):
    end

    func sync():
    end
end
