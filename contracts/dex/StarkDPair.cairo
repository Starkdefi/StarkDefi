%lang starknet

# @author StarkDefi
# @license MIT
# @description port of uniswap pair contract

from dex.interfaces.IERC20 import IERC20
from dex.interfaces.IStarkDFactory import IStarkDFactory
from dex.interfaces.IStarkDCallee import IStarkDCallee
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_check,
    uint256_le,
    uint256_not,
    uint256_eq,
    uint256_sqrt,
    uint256_unsigned_div_rem,
    uint256_lt,
)
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_not_zero, assert_not_equal
from dex.libraries.safemath import SafeUint256
from starkware.starknet.common.syscalls import (
    get_caller_address,
    get_contract_address,
    get_block_timestamp,
)
from starkware.cairo.common.bool import FALSE, TRUE
from starkware.cairo.common.math_cmp import is_not_zero, is_le
from starkware.cairo.common.pow import pow

const MINIMUM_LIQUIDITY = 1000

#
# Events
#

@event
func Transfer(event_name : felt, from_address : felt, to_address : felt, amount : Uint256):
end

@event
func Approval(event_name : felt, owner : felt, spender : felt, amount : Uint256):
end

@event
func Mint(event_name : felt, sender : felt, amount0 : Uint256, amount1 : Uint256):
end

@event
func Burn(event_name : felt, sender : felt, amount0 : Uint256, amount1 : Uint256, to : felt):
end

@event
func Swap(
    event_name : felt, 
    sender : felt,
    amount0In : Uint256,
    amount1In : Uint256,
    amount0Out : Uint256,
    amount1Out : Uint256,
    to : felt,
):
end

@event
func Sync(event_name : felt, reserve0 : Uint256, reserve1 : Uint256):
end

#
# Storage for ERC20
#

@storage_var
func _name() -> (res : felt):
end

@storage_var
func _symbol() -> (res : felt):
end

@storage_var
func _decimals() -> (res : felt):
end

@storage_var
func total_supply() -> (res : Uint256):
end

@storage_var
func balances(account : felt) -> (res : Uint256):
end

@storage_var
func allowances(owner : felt, spender : felt) -> (res : Uint256):
end

#
# Storage
#

@storage_var
func _token0() -> (address : felt):
end

@storage_var
func _token1() -> (address : felt):
end

@storage_var
func _reserve0() -> (reserve : Uint256):
end

@storage_var
func _reserve1() -> (reserve : Uint256):
end

@storage_var
func _block_timestamp_last() -> (timestamp : felt):
end

@storage_var
func _price_0_cumulative_last() -> (price : Uint256):
end

@storage_var
func _price_1_cumulative_last() -> (price : Uint256):
end

@storage_var
func _klast() -> (reserve : Uint256):
end

@storage_var
func _factory() -> (address : felt):
end

@storage_var
func _entry_locked() -> (res : felt):
end

#
# Constructor
#

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    tokenA : felt, tokenB : felt, factory : felt
):
    with_attr error_message("token0 and token1 must not be zero"):
        assert_not_zero(tokenA)
        assert_not_zero(tokenB)
    end
    _name.write('StarkDefi Pair')
    _symbol.write('STARKD-LP')
    _decimals.write(18)
    _token0.write(tokenA)
    _token1.write(tokenB)
    _factory.write(factory)
    _entry_locked.write(FALSE)
    return ()
end

#
# Getters
#

@view
func name{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (name : felt):
    let (name) = _name.read()
    return (name)
end

@view
func symbol{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (symbol : felt):
    let (symbol) = _symbol.read()
    return (symbol)
end

@view
func totalSupply{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    totalSupply : Uint256
):
    let (totalSupply : Uint256) = total_supply.read()
    return (totalSupply)
end

@view
func decimals{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    decimals : felt
):
    let (decimals) = _decimals.read()
    return (decimals)
end

@view
func balanceOf{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account : felt
) -> (balance : Uint256):
    let (balance : Uint256) = balances.read(account=account)
    return (balance)
end

@view
func allowance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    owner : felt, spender : felt
) -> (remaining : Uint256):
    let (remaining : Uint256) = allowances.read(owner=owner, spender=spender)
    return (remaining)
end

@view
func factory{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    address : felt
):
    let (address) = _factory.read()
    return (address)
end

@view
func token0{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    address : felt
):
    let (address) = _token0.read()
    return (address)
end

@view
func token1{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    address : felt
):
    let (address) = _token1.read()
    return (address)
end

@view
func get_reserves{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    reserve0 : Uint256, reserve1 : Uint256, block_timestamp_last : felt
):
    return _get_reserves()
end

@view
func price_0_cumulative_last{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    ) -> (price : Uint256):
    let (price) = _price_0_cumulative_last.read()
    return (price)
end

@view
func price_1_cumulative_last{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    ) -> (price : Uint256):
    let (price) = _price_1_cumulative_last.read()
    return (price)
end

@view
func klast{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    reserve : Uint256
):
    let (reserve) = _klast.read()
    return (reserve)
end

#
# Externals
#

@external
func transfer{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    recipient : felt, amount : Uint256
) -> (success : felt):
    let (sender) = get_caller_address()
    _transfer(sender, recipient, amount)

    return (TRUE)
end

@external
func transfer_from{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    sender : felt, recipient : felt, amount : Uint256
) -> (success : felt):
    alloc_locals
    let (caller) = get_caller_address()
    # subtract allowance
    _spend_allowance(sender, caller, amount)

    # execute transfer
    _transfer(sender, recipient, amount)

    return (TRUE)
end

@external
func approve{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    spender : felt, amount : Uint256
) -> (success : felt):
    with_attr error_message("amount is not a valid Uint256"):
        uint256_check(amount)
    end

    let (caller) = get_caller_address()
    _approve(caller, spender, amount)
    return (TRUE)
end

@external
func increase_allowance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    spender : felt, added_value : Uint256
) -> (success : felt):
    with_attr error("ERC20: added_value is not a valid Uint256"):
        uint256_check(added_value)
    end

    let (caller) = get_caller_address()
    let (current_allowance : Uint256) = allowances.read(caller, spender)

    # add allowance
    with_attr error_message("ERC20: allowance overflow"):
        let (new_allowance : Uint256) = SafeUint256.add(current_allowance, added_value)
    end

    _approve(caller, spender, new_allowance)
    return (TRUE)
end

@external
func decrease_allowance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    spender : felt, subtracted_value : Uint256
) -> (success : felt):
    alloc_locals
    with_attr error_message("subtracted_value is not a valid Uint256"):
        uint256_check(subtracted_value)
    end

    let (caller) = get_caller_address()
    let (current_allowance : Uint256) = allowances.read(owner=caller, spender=spender)

    with_attr error_message("allowance below zero"):
        let (new_allowance : Uint256) = SafeUint256.sub_le(current_allowance, subtracted_value)
    end

    _approve(caller, spender, new_allowance)
    return (TRUE)
end

@external
func mint{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(to : felt) -> (
    liquidity : Uint256
):
    alloc_locals
    _lock()

    local liquidity : Uint256
    let (local reserve0 : Uint256, local reserve1 : Uint256, _) = _get_reserves()
    let (token0) = _token0.read()
    let (token1) = _token1.read()
    let (this_address) = get_contract_address()

    let (local balance0 : Uint256) = IERC20.balanceOf(contract_address=token0, account=this_address)
    let (local balance1 : Uint256) = IERC20.balanceOf(contract_address=token1, account=this_address)

    let (local amount0 : Uint256) = SafeUint256.sub_lt(balance0, reserve0)
    let (local amount1 : Uint256) = SafeUint256.sub_lt(balance1, reserve1)

    let (fee_on) = _mint_fee(reserve0, reserve1)
    let (local _total_supply : Uint256) = total_supply.read()

    let (is_total_supply_zero) = uint256_eq(_total_supply, Uint256(0, 0))

    if is_total_supply_zero == TRUE:
        # liquidity = Math.sqrt(amount0.mul(amount1)).sub(MINIMUM_LIQUIDITY);
        let (amount0_x_amount1 : Uint256) = SafeUint256.mul(amount0, amount1)
        let (sqrt_amount0_x_amount1 : Uint256) = uint256_sqrt(amount0_x_amount1)

        let (actual_liquidity : Uint256) = SafeUint256.sub_lt(
            sqrt_amount0_x_amount1, Uint256(MINIMUM_LIQUIDITY, 0)
        )  # permanently lock the first MINIMUM_LIQUIDITY tokens

        assert liquidity = actual_liquidity

        _mint(1, Uint256(MINIMUM_LIQUIDITY, 0))  # mint minimum liquidity to burn address
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        # liquidity = Math.min(amount0.mul(_totalSupply) / _reserve0, amount1.mul(_totalSupply) / _reserve1);
        let (amount0_x_total_supply : Uint256) = SafeUint256.mul(amount0, _total_supply)
        let (liquidity_0 : Uint256, _) = uint256_unsigned_div_rem(amount0_x_total_supply, reserve0)

        let (amount1_x_total_supply : Uint256) = SafeUint256.mul(amount1, _total_supply)
        let (liquidity_1 : Uint256, _) = uint256_unsigned_div_rem(amount1_x_total_supply, reserve1)

        let (is_liquidity_0_less) = uint256_lt(liquidity_0, liquidity_1)

        if is_liquidity_0_less == TRUE:
            assert liquidity = liquidity_0
        else:
            assert liquidity = liquidity_1
        end

        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end

    local syscall_ptr : felt* = syscall_ptr
    local pedersen_ptr : HashBuiltin* = pedersen_ptr

    # require(liquidity > 0, 'UniswapV2: INSUFFICIENT_LIQUIDITY_MINTED');

    let (is_liquidity_greater_than_zero) = uint256_lt(Uint256(0, 0), liquidity)
    with_attr error_message("insufficient liquidity minted"):
        assert is_liquidity_greater_than_zero = TRUE
    end

    _mint(to, liquidity)

    _update(balance0, balance1, reserve0, reserve1)

    # if (feeOn) kLast = uint(reserve0).mul(reserve1); // reserve0 and reserve1 are up-to-date
    if fee_on == TRUE:
        let (klast : Uint256) = SafeUint256.mul(balance0, balance1)
        _klast.write(klast)
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end

    let (caller) = get_caller_address()
    Mint.emit(event_name=1298755188, sender=caller, amount0=amount0, amount1=amount1)

    _unlock()
    return (liquidity)
end

@external
func burn{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(to : felt) -> (
    amount0 : Uint256, amount1 : Uint256
):
    alloc_locals
    _lock()

    let (local reserve0 : Uint256, local reserve1 : Uint256, _) = _get_reserves()
    let (token0) = _token0.read()
    let (token1) = _token1.read()
    let (this_address) = get_contract_address()

    let (local balance0 : Uint256) = IERC20.balanceOf(contract_address=token0, account=this_address)
    let (local balance1 : Uint256) = IERC20.balanceOf(contract_address=token1, account=this_address)

    let (local liquidity : Uint256) = balances.read(this_address)

    let (fee_on) = _mint_fee(reserve0, reserve1)

    let (local _total_supply : Uint256) = total_supply.read()
    let (is_total_supply_above_zero) = uint256_lt(Uint256(0, 0), _total_supply)

    assert is_total_supply_above_zero = TRUE

    let (liquidity_x_balance0 : Uint256) = SafeUint256.mul(liquidity, balance0)
    let (local amount0 : Uint256, _) = uint256_unsigned_div_rem(liquidity_x_balance0, _total_supply)
    let (is_amount0_above_zero) = uint256_lt(Uint256(0, 0), amount0)

    let (liquidity_x_balance1 : Uint256) = SafeUint256.mul(liquidity, balance1)
    let (local amount1 : Uint256, _) = uint256_unsigned_div_rem(liquidity_x_balance1, _total_supply)
    let (is_amount1_above_zero) = uint256_lt(Uint256(0, 0), amount1)

    # require(amount0 > 0 && amount1 > 0, 'UniswapV2: INSUFFICIENT_LIQUIDITY_BURNED');
    with_attr error_message("insufficient liquidity burned"):
        assert is_amount0_above_zero = TRUE
        assert is_amount1_above_zero = TRUE
    end

    _burn(this_address, liquidity)

    IERC20.transfer(contract_address=token0, recipient=to, amount=amount0)
    IERC20.transfer(contract_address=token1, recipient=to, amount=amount1)

    let (local new_balance0 : Uint256) = IERC20.balanceOf(
        contract_address=token0, account=this_address
    )
    let (local new_balance1 : Uint256) = IERC20.balanceOf(
        contract_address=token1, account=this_address
    )

    _update(new_balance0, new_balance1, reserve0, reserve1)

    # if (feeOn) kLast = uint(reserve0).mul(reserve1); // reserve0 and reserve1 are up-to-date
    if fee_on == 1:
        let (klast : Uint256) = SafeUint256.mul(new_balance0, new_balance1)
        _klast.write(klast)
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end

    let (caller) = get_caller_address()
    Burn.emit(event_name=1114993262, sender=caller, amount0=amount0, amount1=amount1, to=to)

    _unlock()
    return (amount0, amount1)
end

@external
func swap{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    amount0Out : Uint256, amount1Out : Uint256, to : felt, data_len : felt, data : felt*
):
    alloc_locals
    _lock()

    let (local is_amount0out_greater_than_zero) = uint256_lt(Uint256(0, 0), amount0Out)
    let (local is_amount1out_greater_than_zero) = uint256_lt(Uint256(0, 0), amount1Out)
    local output_amount

    if is_amount0out_greater_than_zero == TRUE:
        assert output_amount = TRUE
    else:
        if is_amount1out_greater_than_zero == TRUE:
            assert output_amount = TRUE
        else:
            assert output_amount = FALSE
        end
    end

    # require(amount0Out > 0 || amount1Out > 0, 'UniswapV2: INSUFFICIENT_OUTPUT_AMOUNT');
    with_attr error_message("insufficient output amount"):
        assert output_amount = TRUE
    end

    let (local reserve0 : Uint256, local reserve1 : Uint256, _) = _get_reserves()
    let (is_amount0out_less_than_reserve0) = uint256_lt(amount0Out, reserve0)
    let (is_amount1out_less_than_reserve0) = uint256_lt(amount1Out, reserve1)

    # require(amount0Out < _reserve0 && amount1Out < _reserve1, 'UniswapV2: INSUFFICIENT_LIQUIDITY');
    with_attr error_message("insufficient liquidity"):
        assert is_amount0out_less_than_reserve0 = TRUE
        assert is_amount1out_less_than_reserve0 = TRUE
    end

    let (local token0) = _token0.read()
    let (local token1) = _token1.read()

    # require(to != _token0 && to != _token1, 'UniswapV2: INVALID_TO');
    with_attr error_message("invalid to"):
        assert_not_equal(token0, to)
        assert_not_equal(token1, to)
    end

    let (this_address) = get_contract_address()

    if is_amount0out_greater_than_zero == TRUE:
        IERC20.transfer(contract_address=token0, recipient=to, amount=amount0Out)
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end

    if is_amount1out_greater_than_zero == TRUE:
        IERC20.transfer(contract_address=token1, recipient=to, amount=amount1Out)
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end

    local syscall_ptr : felt* = syscall_ptr
    local pedersen_ptr : HashBuiltin* = pedersen_ptr

    let (caller) = get_caller_address()

    let (data_len_above_zero) = is_le(1, data_len)

    # if (data.length > 0) IUniswapV2Callee(to).uniswapV2Call(msg.sender, amount0Out, amount1Out, data);
    if data_len_above_zero == TRUE:
        IStarkDCallee.starkd_call(
            contract_address=to,
            sender=caller,
            amount0Out=amount0Out,
            amount1Out=amount1Out,
            data_len=data_len,
            data=data,
        )
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end

    let (local balance0 : Uint256) = IERC20.balanceOf(contract_address=token0, account=this_address)
    let (local balance1 : Uint256) = IERC20.balanceOf(contract_address=token1, account=this_address)

    let (local new_balance0 : Uint256) = SafeUint256.sub_le(reserve0, amount0Out)
    let (local new_balance1 : Uint256) = SafeUint256.sub_le(reserve1, amount1Out)

    local input_amount
    let (local is_balance0_greater_than_new_balance0) = uint256_lt(new_balance0, balance0)
    let (local is_balance1_greater_than_new_balance1) = uint256_lt(new_balance1, balance1)

    if is_balance0_greater_than_new_balance0 == TRUE:
        assert input_amount = TRUE
    else:
        if is_balance1_greater_than_new_balance1 == TRUE:
            assert input_amount = TRUE
        else:
            assert input_amount = FALSE
        end
    end

    # require(amount0In > 0 || amount1In > 0, 'UniswapV2: INSUFFICIENT_INPUT_AMOUNT');
    with_attr error_message("insufficient input amount"):
        assert input_amount = TRUE
    end

    let (local amount0In : Uint256) = SafeUint256.sub_le(balance0, new_balance0)
    let (local amount1In : Uint256) = SafeUint256.sub_le(balance1, new_balance1)

    let (balance0_x_1000 : Uint256) = SafeUint256.mul(balance0, Uint256(1000, 0))
    let (amount0In_x_3 : Uint256) = SafeUint256.mul(amount0In, Uint256(3, 0))
    let (local balance0Adjusted : Uint256) = SafeUint256.sub_lt(balance0_x_1000, amount0In_x_3)

    let (balance1_x_1000 : Uint256) = SafeUint256.mul(balance1, Uint256(1000, 0))
    let (amount1In_x_3 : Uint256) = SafeUint256.mul(amount1In, Uint256(3, 0))
    let (local balance1Adjusted : Uint256) = SafeUint256.sub_lt(balance1_x_1000, amount1In_x_3)

    let (balance0Adjusted_x_balance1Adjusted : Uint256) = SafeUint256.mul(
        balance0Adjusted, balance1Adjusted
    )

    let (reserve0_x_reserve1 : Uint256) = SafeUint256.mul(reserve0, reserve1)

    let (local multiplier) = pow(1000, 2)
    let (reserve0_mul_reserve1_mul_multiplier : Uint256) = SafeUint256.mul(
        reserve0_x_reserve1, Uint256(multiplier, 0)
    )

    let (is_adjusted_balance_prod_ge_reserve_prod) = uint256_le(
        reserve0_mul_reserve1_mul_multiplier, balance0Adjusted_x_balance1Adjusted
    )
    # require(balance0Adjusted.mul(balance1Adjusted) >= uint(_reserve0).mul(_reserve1).mul(1000**2), 'UniswapV2: K');
    with_attr error_message("invariant K"):
        assert is_adjusted_balance_prod_ge_reserve_prod = 1
    end

    _update(balance0, balance1, reserve0, reserve1)

    let (caller) = get_caller_address()
    Swap.emit(
        event_name=1400332656,
        sender=caller,
        amount0In=amount0In,
        amount1In=amount1In,
        amount0Out=amount0Out,
        amount1Out=amount1Out,
        to=to,
    )

    _unlock()
    return ()
end

@external
func skim{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(to : felt):
    alloc_locals
    _lock()

    let (local reserve0 : Uint256, local reserve1 : Uint256, _) = _get_reserves()
    let (token0) = _token0.read()
    let (token1) = _token1.read()
    let (this_address) = get_contract_address()

    let (local balance0 : Uint256) = IERC20.balanceOf(contract_address=token0, account=this_address)
    let (local balance1 : Uint256) = IERC20.balanceOf(contract_address=token1, account=this_address)

    let (local amount0 : Uint256) = SafeUint256.sub_lt(balance0, reserve0)
    let (local amount1 : Uint256) = SafeUint256.sub_lt(balance1, reserve1)

    IERC20.transfer(contract_address=token0, recipient=to, amount=amount0)
    IERC20.transfer(contract_address=token1, recipient=to, amount=amount1)

    _unlock()
    return ()
end

@external
func sync{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    alloc_locals
    _lock()

    let (token0) = _token0.read()
    let (token1) = _token1.read()
    let (this_address) = get_contract_address()

    let (local balance0 : Uint256) = IERC20.balanceOf(contract_address=token0, account=this_address)
    let (local balance1 : Uint256) = IERC20.balanceOf(contract_address=token1, account=this_address)

    let (local reserve0 : Uint256) = _reserve0.read()
    let (local reserve1 : Uint256) = _reserve1.read()

    _update(balance0, balance1, reserve0, reserve1)

    _unlock()
    return ()
end

#
# Internal
#
func _mint{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    recipient : felt, amount : Uint256
):
    with_attr error_message("amount is not a valid Uint256"):
        uint256_check(amount)
    end

    with_attr error_message("cannot mint to the zero address"):
        assert_not_zero(recipient)
    end

    let (supply : Uint256) = total_supply.read()
    with_attr error_message("mint overflow"):
        let (new_supply : Uint256) = SafeUint256.add(supply, amount)
    end
    total_supply.write(new_supply)

    let (balance : Uint256) = balances.read(account=recipient)
    # overflow is not possible because sum is guaranteed to be less than total supply
    # which we check for overflow below
    let (new_balance : Uint256) = SafeUint256.add(balance, amount)
    balances.write(recipient, new_balance)

    Transfer.emit(6085033173541348722, 0, recipient, amount)
    return ()
end

func _burn{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account : felt, amount : Uint256
):
    with_attr error_message("ERC20: amount is not a valid Uint256"):
        uint256_check(amount)
    end

    with_attr error_message("ERC20: cannot burn from the zero address"):
        assert_not_zero(account)
    end

    let (balance : Uint256) = balances.read(account)
    with_attr error_message("ERC20: burn amount exceeds balance"):
        let (new_balance : Uint256) = SafeUint256.sub_le(balance, amount)
    end

    balances.write(account, new_balance)

    let (supply : Uint256) = total_supply.read()
    let (new_supply : Uint256) = SafeUint256.sub_le(supply, amount)
    total_supply.write(new_supply)
    Transfer.emit(6085033173541348722, account, 0, amount)
    return ()
end

func _transfer{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    sender : felt, recipient : felt, amount : Uint256
):
    alloc_locals
    with_attr error_message("amount is not a valid Uint256"):
        uint256_check(amount)  # almost surely not needed, might remove after confirmation
    end
    with_attr error_message("cannot transfer from the zero address"):
        assert_not_zero(sender)
    end

    with_attr error_message("cannot transfer to the zero address"):
        assert_not_zero(recipient)
    end

    let (local sender_balance : Uint256) = balances.read(account=sender)
    with_attr error_message(" transfer amount exceeds balance"):
        let (new_sender_balance : Uint256) = SafeUint256.sub_le(sender_balance, amount)
    end

    balances.write(sender, new_sender_balance)

    # add to recipient
    let (recipient_balance : Uint256) = balances.read(account=recipient)
    # overflow is not possible because sum is guaranteed by mint to be less than total supply
    let (new_recipient_balance : Uint256) = SafeUint256.add(recipient_balance, amount)
    balances.write(recipient, new_recipient_balance)

    Transfer.emit(6085033173541348722, sender, recipient, amount)
    return ()
end

func _spend_allowance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    owner : felt, spender : felt, amount : Uint256
):
    alloc_locals
    with_attr error_message("amount is not a valid Uint256"):
        uint256_check(amount)  # almost surely not needed, might remove after confirmation
    end

    let (current_allowance : Uint256) = allowances.read(owner, spender)
    let (infinite : Uint256) = uint256_not(Uint256(0, 0))
    let (is_infinite : felt) = uint256_eq(current_allowance, infinite)

    if is_infinite == FALSE:
        with_attr error_message("insufficient allowance"):
            let (new_allowance : Uint256) = SafeUint256.sub_le(current_allowance, amount)
        end

        _approve(owner, spender, new_allowance)
        return ()
    end
    return ()
end

func _approve{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    owner : felt, spender : felt, amount : Uint256
):
    with_attr error_message("amount is not a valid Uint256"):
        uint256_check(amount)
    end

    with_attr error_message("cannot approve from the zero address"):
        assert_not_zero(owner)
    end

    with_attr error_message("cannot approve to the zero address"):
        assert_not_zero(spender)
    end

    allowances.write(owner, spender, amount)
    Approval.emit(4715392446655521132, owner, spender, amount)
    return ()
end

func _get_reserves{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    reserve0 : Uint256, reserve1 : Uint256, block_timestamp_last : felt
):
    let (reserve0) = _reserve0.read()
    let (reserve1) = _reserve1.read()
    let (block_timestamp_last) = _block_timestamp_last.read()
    return (reserve0, reserve1, block_timestamp_last)
end

func _mint_fee{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    reserve0 : Uint256, reserve1 : Uint256
) -> (fee_on : felt):
    alloc_locals
    let (local factory) = _factory.read()
    let (local fee_to) = IStarkDFactory.fee_to(contract_address=factory)
    let (local fee_on) = is_not_zero(fee_to)
    let (local klast : Uint256) = _klast.read()

    let (local is_klast_zero) = uint256_eq(klast, Uint256(0, 0))

    if fee_on == TRUE:
        if is_klast_zero == FALSE:
            let (reserve0_x_reserve1 : Uint256) = SafeUint256.mul(reserve0, reserve1)
            let (local rootk : Uint256) = uint256_sqrt(reserve0_x_reserve1)
            let (local rootklast : Uint256) = uint256_sqrt(klast)
            let (is_rootk_greater_than_rootklast) = uint256_lt(rootklast, rootk)
            if is_rootk_greater_than_rootklast == TRUE:
                let (local rootk_sub_rootklast : Uint256) = SafeUint256.sub_le(rootk, rootklast)
                let (local _total_supply : Uint256) = total_supply.read()

                let (numerator : Uint256) = SafeUint256.mul(rootk_sub_rootklast, _total_supply)
                let (rootk_x_5 : Uint256) = SafeUint256.mul(rootk, Uint256(5, 0))
                let (local denominator : Uint256) = SafeUint256.add(rootk_x_5, rootklast)

                let (liquidity : Uint256, _) = uint256_unsigned_div_rem(numerator, denominator)
                let (is_liquidity_greater_than_zero) = uint256_lt(Uint256(0, 0), liquidity)

                # if (liquidity > 0) _mint(feeTo, liquidity);
                if is_liquidity_greater_than_zero == TRUE:
                    _mint(fee_to, liquidity)
                    tempvar syscall_ptr = syscall_ptr
                    tempvar pedersen_ptr = pedersen_ptr
                    tempvar range_check_ptr = range_check_ptr
                else:
                    tempvar syscall_ptr = syscall_ptr
                    tempvar pedersen_ptr = pedersen_ptr
                    tempvar range_check_ptr = range_check_ptr
                end
            else:
                tempvar syscall_ptr = syscall_ptr
                tempvar pedersen_ptr = pedersen_ptr
                tempvar range_check_ptr = range_check_ptr
            end
        else:
            tempvar syscall_ptr = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr
            tempvar range_check_ptr = range_check_ptr
        end
    else:
        if is_klast_zero == FALSE:
            _klast.write(Uint256(0, 0))
            tempvar syscall_ptr = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr
            tempvar range_check_ptr = range_check_ptr
        else:
            tempvar syscall_ptr = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr
            tempvar range_check_ptr = range_check_ptr
        end
    end
    return (fee_on)
end

func _update{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    balance0 : Uint256, balance1 : Uint256, reserve0 : Uint256, reserve1 : Uint256
):
    alloc_locals
    # require(balance0 <= uint112(-1) && balance1 <= uint112(-1), 'UniswapV2: OVERFLOW');
    with_attr error_message("overflow"):
        assert balance0.high = 0
        assert balance1.high = 0
    end

    let (block_timestamp) = get_block_timestamp()
    let (block_timestamp_last) = _block_timestamp_last.read()
    # bt = block_timestamp
    let (is_bt_greater_than_equal_to_bt_last) = is_le(block_timestamp_last, block_timestamp)

    if is_bt_greater_than_equal_to_bt_last == TRUE:
        let (is_bt_not_equal_to_bt_last) = is_not_zero(block_timestamp - block_timestamp_last)

        if is_bt_not_equal_to_bt_last == TRUE:
            let (is_reserve0_zero) = uint256_eq(reserve0, Uint256(0, 0))

            if is_reserve0_zero == FALSE:
                let (is_reserve1_zero) = uint256_eq(reserve1, Uint256(0, 0))

                if is_reserve1_zero == FALSE:
                    # price0CumulativeLast += uint(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
                    # price1CumulativeLast += uint(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;

                    let (price_0_cumulative_last) = _price_0_cumulative_last.read()
                    let (reserve1_x_reserve0 : Uint256, _) = uint256_unsigned_div_rem(
                        reserve1, reserve0
                    )

                    let (res1_x_res0_x_time_diff : Uint256) = SafeUint256.mul(
                        reserve1_x_reserve0, Uint256(block_timestamp - block_timestamp_last, 0)
                    )

                    let (new_price_0_cumulative : Uint256) = SafeUint256.add(
                        price_0_cumulative_last, res1_x_res0_x_time_diff
                    )
                    _price_0_cumulative_last.write(new_price_0_cumulative)

                    let (price_1_cumulative_last) = _price_1_cumulative_last.read()
                    let (reserve0_x_reserve1 : Uint256, _) = uint256_unsigned_div_rem(
                        reserve0, reserve1
                    )
                    let (res0_x_res1_x_time_diff : Uint256) = SafeUint256.mul(
                        reserve0_x_reserve1, Uint256(block_timestamp - block_timestamp_last, 0)
                    )
                    let (new_price_1_cumulative : Uint256) = SafeUint256.add(
                        price_1_cumulative_last, res0_x_res1_x_time_diff
                    )
                    _price_1_cumulative_last.write(new_price_1_cumulative)

                    tempvar syscall_ptr = syscall_ptr
                    tempvar pedersen_ptr = pedersen_ptr
                    tempvar range_check_ptr = range_check_ptr
                else:
                    tempvar syscall_ptr = syscall_ptr
                    tempvar pedersen_ptr = pedersen_ptr
                    tempvar range_check_ptr = range_check_ptr
                end
                tempvar syscall_ptr = syscall_ptr
                tempvar pedersen_ptr = pedersen_ptr
                tempvar range_check_ptr = range_check_ptr
            else:
                tempvar syscall_ptr = syscall_ptr
                tempvar pedersen_ptr = pedersen_ptr
                tempvar range_check_ptr = range_check_ptr
            end
            tempvar syscall_ptr = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr
            tempvar range_check_ptr = range_check_ptr
        else:
            tempvar syscall_ptr = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr
            tempvar range_check_ptr = range_check_ptr
        end
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end
    _reserve0.write(balance0)
    _reserve1.write(balance1)
    _block_timestamp_last.write(block_timestamp)

    Sync.emit(event_name=1400467043, reserve0=balance0, reserve1=balance1)
    return ()
end

# lock it if entry is unlocked
func _lock{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    let (locked) = _entry_locked.read()
    with_attr error_message("locked"):
        assert locked = FALSE
    end
    _entry_locked.write(TRUE)
    return ()
end

# unlock entry
func _unlock{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    let (locked) = _entry_locked.read()
    with_attr error_message("not locked"):
        assert locked = TRUE
    end
    _entry_locked.write(FALSE)
    return ()
end
