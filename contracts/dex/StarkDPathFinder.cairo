%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.math import assert_le, assert_nn_le, unsigned_div_rem, sqrt, assert_not_zero
from starkware.cairo.common.math_cmp import is_le_felt
from starkware.cairo.common.bitwise import bitwise_or
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_le,
    uint256_eq,
    uint256_add,
    uint256_sub,
    uint256_mul,
    uint256_signed_div_rem,
    uint256_unsigned_div_rem
)
from dex.libraries.array import Array
from dex.libraries.utils import Utils
from dex.interfaces.IStarkDRouterAggregator import IStarkDRouterAggregator

const Vertices = 6
const Edges = 21
const LARGE_VALUE = 850705917302346000000000000000000000000000000 

const base = 1000000000000000000 # 1e18
const extra_base = 100000000000000000000 # We use this to artificialy increase the weight of each edge, so that we can subtract the last edges without causeing underflows

@storage_var
func _router_aggregator() -> (address : felt):
end

@storage_var
func _USDT() -> (address : felt):
end

@storage_var
func _USDC() -> (address : felt):
end

@storage_var
func _DAI() -> (address : felt):
end

@storage_var
func _WETH() -> (address : felt):
end


struct Source:
    member start : felt
    member stop : felt
end

#
# Constructor
#

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    routerAggregator : felt, usdtAddress : felt, usdcAddress : felt, daiAddress : felt, wethAddress : felt
):
    with_attr error_message("invalid router aggregator"):
        assert_not_zero(routerAggregator)
    end
    with_attr error_message("invalid USDT address"):
        assert_not_zero(usdtAddress)
    end
    with_attr error_message("invalid USDC address"):
        assert_not_zero(usdcAddress)
    end
    with_attr error_message("invalid DAI address"):
        assert_not_zero(daiAddress)
    end
    with_attr error_message("invalid WETH address"):
        assert_not_zero(wethAddress)
    end

    _router_aggregator.write(routerAggregator)

    _USDT.write(usdtAddress)
    _USDC.write(usdcAddress)
    _DAI.write(daiAddress)
    _WETH.write(wethAddress)
    return ()
end

#
#Views
#

@view
func get_results{syscall_ptr : felt*, bitwise_ptr : BitwiseBuiltin*, pedersen_ptr : HashBuiltin*,range_check_ptr}(
    amountIn : Uint256, tokenIn : felt, tokenOut : felt
) -> (path_len : felt, path : felt*):
    alloc_locals
    
    let (tokens : felt*) = alloc()
    let (local wethAddress) = _WETH.read()
    let (local usdtAddress) = _USDT.read()
    let (local daiAddress) = _DAI.read()
    let (local usdcAddress) = _USDC.read()

    assert tokens[0] = tokenIn

    assert tokens[1] = wethAddress
    assert tokens[2] = usdtAddress
    assert tokens[3] = daiAddress
    assert tokens[4] = usdcAddress

    assert tokens[5] = tokenOut

    #Edge, this is not a Struct because we cannot pass structs that have pointers in them.
    let (src : Source*) = alloc()
    let (dst : felt*) = alloc()
    let (weight : felt*) = alloc()
    let (pool : felt*) = alloc()

    #transform input amount to USD amount
    # let (local router_aggregator_address) = _router_aggregator.read()
    # let (price : Uint256) = IStarkDRouterAggregator.get_global_price(router_aggregator_address, tokens[0])
    # let (amount_in : Uint256) = Utils.fmul(price, amountIn, Uint256(base, 0))

    #We use dst_len to count the number of legit source to destination edges
    set_edges(
        amountIn,
        6,
        tokens,
        Vertices,
        src,
        0,
        dst,
        0,
        weight,
        0,
        pool=pool,
        dstCounter=1,
        srcCounter=0,
        totalCounter=0
    )

    #Initialize inQueue Array to false
    let (distances : felt*) = alloc()
    let (predecessors : felt*) = alloc()
    let (is_in_queue : felt*) = alloc()
    let (queue : felt*) = alloc()
    init_arrays(6, distances, 6, predecessors, 6, is_in_queue, queue)

    #Getting each tokens best predecessor
    let (new_predecessors : felt*) = shortest_path_faster(
        6,
        distances,
        6,
        is_in_queue,
        1,
        queue,
        Vertices,
        src,
        5,
        dst,
        0,
        weight,
        6,
        predecessors
    )

    #Determining the Final path we should be taking for the trade
    let (path : felt*) = alloc()
    assert path[0] = new_predecessors[5]
    if path[0] == 0:
        assert path[1] = 0
        assert path[2] = 0
        assert path[3] = 0
        return(4,path)
    end
    assert path[1] = new_predecessors[path[0]]
    if path[1] == 0:
        assert path[2] = 0
        assert path[3] = 0
        return(4,path)
    end
    assert path[2] = new_predecessors[path[1]]
    if path[2] == 0:
        assert path[3] = 0
        return(4,path)
    end
    assert path[3] = new_predecessors[path[2]]
    if path[3] == 0:
        return(4,path)
    end
    #Should never happen
    assert 0 = 1
    return(0,path)
    
end

#
#Internals
#

#@notice 
#We use dst_len to track every src->dst edge that is not 0
#We use dstCounter to track the number of destinations we have checked for each source (We check vertices 1-5)
#We use srcCounter to track the number of sources we have checked (We check vertices 0-4)
func set_edges{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    amountIn : Uint256, 
    tokens_len : felt,
    tokens : felt*,
    src_len : felt,
    src : Source*,
    dst_len : felt,
    dst : felt*,
    weight_len : felt,
    weight : felt*,
    pool_len : felt,
    pool : felt*,
    dstCounter : felt,
    srcCounter : felt,
    totalCounter : felt
) -> ():
    alloc_locals
    
    if srcCounter == Vertices - 1:
	    return()
    end

    local is_same_token
    local we_are_not_advancing

    if dstCounter == srcCounter:
	    assert is_same_token = 1
    else:
        assert is_same_token = 0
    end

    #We don't need to set edges where the source is the last token
    if is_same_token == 1 :
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
        assert we_are_not_advancing = 0
    else:
        let (local router_aggregator_address) = _router_aggregator.read()
        let (amount_out : Uint256) = IStarkDRouterAggregator.get_single_best_pool(router_aggregator_address, amountIn, tokens[srcCounter], tokens[dstCounter])
	    let (amount_is_zero) = uint256_eq(amount_out, Uint256(0, 0))

        if amount_is_zero == 1 :
            #Edge(Destination_List(dst,dst,dst,dst,dst),Weight_List(weight,weight,weight,weight,weight),Pool_List(pool,pool,pool,pool,pool))
            tempvar syscall_ptr = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr
            tempvar range_check_ptr = range_check_ptr
            assert we_are_not_advancing = 1
        else:
            assert dst[0] = dstCounter
            let(_weight : felt) = IStarkDRouterAggregator.get_weight(router_aggregator_address , amountIn, tokens[srcCounter], tokens[dstCounter])
            if srcCounter == 0 :
                assert weight[0] = _weight + extra_base
            else:
                assert weight[0] = _weight
            end    
            # assert pool[0] = router_address
            assert we_are_not_advancing = 0
            tempvar syscall_ptr = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr
            tempvar range_check_ptr = range_check_ptr
        end
	    tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end

    
    if dstCounter == Vertices - 1:
        tempvar next_dst = we_are_not_advancing + is_same_token
        if next_dst != 0 :
            assert src[0] = Source(totalCounter, dst_len)
	        set_edges(
                amountIn,
                6,
                tokens,
                src_len,
                src+2, #+2 because our struct consists of 2 felts
                0, # dst_len
                dst,
                weight_len,
                weight,
                pool_len,
                pool,
                dstCounter=1,
                srcCounter=srcCounter+1,
                totalCounter=totalCounter+dst_len
            )    
            tempvar syscall_ptr = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr
            tempvar range_check_ptr = range_check_ptr
        else:
            assert src[0] = Source(totalCounter, dst_len+1)
            set_edges(
                amountIn,
                6,
                tokens,
                src_len,
                src+2, #+2 because our struct consists of 2 felts
                0, # dst_len
                dst+1,
                weight_len,
                weight+1,
                pool_len,
                pool+1,
                dstCounter=1,
                srcCounter=srcCounter+1,
                totalCounter=totalCounter+dst_len+1
            )
            tempvar syscall_ptr = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr
            tempvar range_check_ptr = range_check_ptr
        end
    else:
	    tempvar next_dst = we_are_not_advancing + is_same_token
        if next_dst != 0 :
            #We are not advancing the edge errays
            set_edges(
                amountIn,
                6,
                tokens,
                src_len,
                src,
                dst_len,
                dst,
                weight_len,
                weight,
                pool_len,
                pool,
                dstCounter=dstCounter+1,
                srcCounter=srcCounter,
                totalCounter=totalCounter
            )
            tempvar syscall_ptr = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr
            tempvar range_check_ptr = range_check_ptr
        else:
            #We are advancing the edge arrays
            set_edges(
                amountIn,
                6,
                tokens,
                src_len,
                src,
                dst_len+1,
                dst+1,
                weight_len,
                weight+1,
                pool_len,
                pool+1,
                dstCounter=dstCounter+1,
                srcCounter=srcCounter,
                totalCounter=totalCounter
            )
            tempvar syscall_ptr = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr
            tempvar range_check_ptr = range_check_ptr
        end
    	tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end

    return()
end

func shortest_path_faster{syscall_ptr : felt*, bitwise_ptr : BitwiseBuiltin*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    distances_len:felt,
    distances:felt*,
    isInQueue_len:felt,
    isInQueue:felt*,
    queue_len:felt,
    queue:felt*,
    src_len: felt,
    src: Source*,
    dst_len: felt,
    dst: felt*,
    weight_len: felt,
    weight: felt*,
    predecessors_len: felt,
    predecessors: felt*
) -> (finalDistances: felt*):

    alloc_locals

    #If there is no destination left in the queue we can stop the procedure
    if queue_len == 0 :
        return(predecessors)
    end    

    #Get first entry from queue
    let (new_queue : felt*) = alloc()
    let (src_nr : felt) = Array.shift(queue_len-1, new_queue, queue_len, queue, 0, 0)
    tempvar new_queue_len = queue_len - 1

    #Mark the removed entry as not being in the queue anymore
    let (new_is_in_queue : felt*) = alloc()
    Array.update(isInQueue_len, new_is_in_queue, isInQueue_len, isInQueue, 1, 0, 0)

    #Get Source from queue Nr
    let current_source : Source* = src + (src_nr * 2) 
    tempvar offset = current_source[0].start

    let (current_distance : felt) = Array.get_at_index(distances_len, distances, src_nr, 0)

    #Determine if there is a shorter distance to its different destinations
    let (
        _,
        new_distances : felt*,
        new_new_queue_len,
        new_new_queue : felt*,
        _,
        new_new_is_in_queue : felt*,
        _,
        new_predecessors : felt*
    ) = determine_distances(
        distances_len, 
        distances, 
        new_queue_len, 
        new_queue, 
        isInQueue_len, 
        new_is_in_queue, 
        0, 
        dst + offset, 
        0,
        weight + offset, 
        predecessors_len, 
        predecessors, 
        current_source[0].stop,
        src_nr,
        current_distance
    )
    
    let (_predecessors) = shortest_path_faster(
        distances_len,
        new_distances,
        isInQueue_len,
        new_new_is_in_queue,
        new_new_queue_len,
        new_new_queue,Vertices,
        src,
        5,
        dst,
        0,
        weight,
        predecessors_len,
        new_predecessors
    )

    return(_predecessors)
end     

func determine_distances{syscall_ptr : felt*, bitwise_ptr : BitwiseBuiltin*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    distances_len : felt,
    distances : felt*, 
    queue_len : felt, 
    queue : felt*, 
    isInQueue_len : felt, 
    isInQueue : felt*, 
    dst_len : felt, 
    dst : felt*, 
    weight_len : felt, 
    weight : felt*, 
    predecessors_len : felt,
    predecessors : felt*,
    dstStop :felt,
    srcNr : felt, 
    currentDistance : felt
) -> (
    distances_len : felt,
    distances : felt*,
    queue_len : felt,
    queue : felt*,
    isInQueue_len : felt,
    isInQueue : felt*,
    res_predecessors_len : felt,
    res_predecessors : felt*
):
    
    alloc_locals

    if dstStop == 0:
        #We end the procedure if all destinations have been evaluated
        return(distances_len, distances, queue_len, queue, isInQueue_len, isInQueue, predecessors_len, predecessors)
    end
   
    let (new_distances : felt*) = alloc()
    local new_queue_len : felt
    local new_distance : felt
    let (new_queue : felt*) = alloc()
    let (new_is_in_queue : felt*) = alloc()

    # tempvar _dst = dst[0]
    #%{ print("src: ",ids.srcNr) %}
    #%{ print("dst: ",ids.dst) %}

    let (local is_dst_end) = is_le_felt(Vertices - 1, dst[0])

    if is_dst_end == 1 :
        #Moving towards the goal token should always improve the distance
        assert new_distance = currentDistance - extra_base + weight[0]
    else:
        assert new_distance = currentDistance + weight[0]
    end

    let (is_old_distance_better) = is_le_felt(distances[dst[0]], new_distance)

    if is_old_distance_better == 0:
        #destination vertex weight = origin vertex + edge weight
        Array.update(distances_len, new_distances, distances_len, distances, dst[0], new_distance, 0)

        let (new_predecessors : felt*) = alloc()
        Array.update(predecessors_len, new_predecessors, predecessors_len, predecessors, dst[0], srcNr, 0)

        let (already_in_queue_or_last_dst) = bitwise_or(isInQueue[dst[0]], is_dst_end)

        if already_in_queue_or_last_dst == 0 :
            #Add new vertex with better weight to queue
            Array.push(queue_len + 1,new_queue, queue_len, queue, dst[0])
            assert new_queue_len = queue_len + 1

            Array.update(isInQueue_len, new_is_in_queue, isInQueue_len, isInQueue, dst[0], 1, 0)

            let (
                res_distance_len,
                res_distance,
                res_queue_len,
                res_queue,
                res_is_in_queue_len,
                res_is_in_queue,
                res_predecessors_len,
                res_predecessors
            ) = determine_distances(
                distances_len, 
                new_distances, 
                new_queue_len, 
                new_queue, 
                isInQueue_len, 
                new_is_in_queue, 
                dst_len, 
                dst + 1, 
                weight_len, 
                weight + 1, 
                predecessors_len,
                new_predecessors,
                dstStop - 1, 
                srcNr,
                currentDistance
            )
            return(res_distance_len, res_distance, res_queue_len, res_queue, res_is_in_queue_len, res_is_in_queue, res_predecessors_len, res_predecessors)
        else:
            let (
                res_distance_len,
                res_distance,
                res_queue_len,
                res_queue,
                res_is_in_queue_len,
                res_is_in_queue,
                res_predecessors_len,
                res_predecessors
            ) = determine_distances(
                distances_len, 
                new_distances, 
                queue_len, 
                queue, 
                isInQueue_len, 
                isInQueue, 
                dst_len, 
                dst + 1, 
                weight_len, 
                weight + 1, 
                predecessors_len,
                new_predecessors,
                dstStop - 1, 
                srcNr,
                currentDistance
            )
            return(res_distance_len, res_distance, res_queue_len, res_queue, res_is_in_queue_len, res_is_in_queue, res_predecessors_len, res_predecessors)
        end
    else:
        let (
            res_distance_len,
            res_distance,
            res_queue_len,
            res_queue,
            res_is_in_queue_len,
            res_is_in_queue,
            res_predecessors_len,
            res_predecessors
        ) = determine_distances(
            distances_len, 
            distances, 
            queue_len, 
            queue, 
            isInQueue_len, 
            isInQueue, 
            dst_len, 
            dst + 1, 
            weight_len, 
            weight + 1, 
            predecessors_len,
            predecessors,
            dstStop - 1,
            srcNr,
            currentDistance
        )

        return(res_distance_len, res_distance, res_queue_len, res_queue, res_is_in_queue_len, res_is_in_queue, res_predecessors_len, res_predecessors)
    end
end

func init_arrays{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    distances_len : felt,
    distances : felt*,
    predecessors_len : felt,
    predecessors : felt*,
    isInQueue_len : felt,
    isInQueue : felt*,
    queue : felt*
) -> ():
    
    #Always of length V
    assert distances[0] = 0 #Source Token 
    assert distances[1] = 850705917302346000000000000000000000000000000
    assert distances[2] = 850705917302346000000000000000000000000000000
    assert distances[3] = 850705917302346000000000000000000000000000000
    assert distances[4] = 850705917302346000000000000000000000000000000
    assert distances[5] = 850705917302346000000000000000000000000000000

    assert predecessors[0] = 0 
    assert predecessors[1] = 0
    assert predecessors[2] = 0
    assert predecessors[3] = 0
    assert predecessors[4] = 0
    assert predecessors[5] = 0

    assert isInQueue[0] = 0 # In_token will start in queue
    assert isInQueue[1] = 0 
    assert isInQueue[2] = 0
    assert isInQueue[3] = 0
    assert isInQueue[4] = 0
    assert isInQueue[5] = 0

    assert queue[0] = 0 # In token is only token in queue
    
    return()
end

#
#Admin
#

@external
func set_router_aggregator{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _new_router_aggregator_address: felt
):
    _router_aggregator.write(_new_router_aggregator_address)
    return()
end

@external
func set_usdt_address{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _new_usdt_address: felt
):
    _USDT.write(_new_usdt_address)
    return()
end

@external
func set_usdc_address{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _new_usdc_address: felt
):
    _USDC.write(_new_usdc_address)
    return()
end

@external
func set_dai_address{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _new_dai_address: felt
):
    _DAI.write(_new_dai_address)
    return()
end

@external
func set_weth_address{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _new_weth_address: felt
):
    _WETH.write(_new_weth_address)
    return()
end
