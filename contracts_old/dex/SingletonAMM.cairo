%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.registers import get_fp_and_pc

struct Pair:
    reserve0: felt
    reserve1: felt
end

struct SingletonAMM:
    pairs: DictAccess
end

func SingletonAMM__init__():
    let (pairs : DictAccess*) = DictAccess_new()
    return (pairs=pairs)
end

func SingletonAMM__addLiquidity(
        self: SingletonAMM*, 
        pair: Pair*, 
        amount0: felt, 
        amount1: felt):
    let pair = DictAccess_find_or_new(self.pairs, pair)
    pair.reserve0 += amount0
    pair.reserve1 += amount1
    return ()
end

func SingletonAMM__removeLiquidity(
        self: SingletonAMM*, 
        pair: Pair*, 
        amount0: felt, 
        amount1: felt):
    let pair = DictAccess_find_or_new(self.pairs, pair)
    pair.reserve0 -= amount0
    pair.reserve1 -= amount1
    return ()
end

func SingletonAMM__swap(
        self: SingletonAMM*, 
        pair: Pair*, 
        amount0In: felt, 
        amount1In: felt, 
        amount0Out: felt, 
        amount1Out: felt):
    let pair = DictAccess_find_or_new(self.pairs, pair)
    pair.reserve0 = pair.reserve0 + amount0In - amount0Out
    pair.reserve1 = pair.reserve1 + amount1In - amount1Out
    return ()
end
