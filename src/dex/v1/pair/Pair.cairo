/// @title StarkDefi Stable Pair Contract
/// @author StarkDefi Labs
/// @license MIT
/// @description Implements uniV2 (x*y=k) volatile pair and Solidly stableswap (x*y(x^2 + y^2) =k) curve
use starknet::{ContractAddress};

#[derive(Copy, Drop, Serde, starknet::Store)]
struct Config {
    token0: ContractAddress,
    token1: ContractAddress,
    factory: ContractAddress,
    vault: ContractAddress,
    stable: bool,
    fee_tier: u8,
    decimal0: u256,
    decimal1: u256,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
struct PairInfo {
    reserve0: u256,
    reserve1: u256,
    block_timestamp_last: u64,
    price_0_cumulative_last: u256,
    price_1_cumulative_last: u256,
    klast: u256,
}

const FEE_DENOMINATOR: u256 = 10000;
const MINIMUM_LIQUIDITY: u256 = 1000;
const PRECISION: u256 = 1_000_000_000_000_000_000; // 1e18
const MINIMUM_K: u256 = 10_000_000_000; //1e10

#[starknet::contract]
mod StarkDPair {
    use starkdefi::dex::v1::factory::{
        IStarkDFactoryABIDispatcher, IStarkDFactoryABIDispatcherTrait
    };
    use starkdefi::dex::v1::pair::interface::{
        IStarkDPair, IStarkDPairCamelOnly, IFeesVaultDispatcherTrait, IFeesVaultDispatcher
    };
    use starkdefi::dex::v1::pair::interface::{
        IStarkDCalleeDispatcherTrait, IStarkDCalleeDispatcher, Snapshot, GlobalFeesAccum,
        RelativeFeesAccum,
    };
    use starkdefi::utils::{pow};

    use traits::Into;

    use starkdefi::token::erc20::{ERC20, ERC20ABIDispatcherTrait, ERC20ABIDispatcher};
    use zeroable::Zeroable;
    use array::ArrayTrait;
    use option::OptionTrait;

    use starknet::{
        ClassHash, contract_address_const, get_caller_address, get_block_timestamp,
        get_contract_address, contract_address_to_felt252
    };
    use starknet::syscalls::deploy_syscall;
    use starkdefi::utils::call_contract_with_selector_fallback;
    use starkdefi::utils::selectors;
    use starkdefi::utils::callFallback::UnwrapAndCast;
    use starkdefi::utils::upgradable::{Upgradable, IUpgradable};


    use integer::u128_try_from_felt252;
    use super::{
        ContractAddress, Config, PairInfo, FEE_DENOMINATOR, MINIMUM_LIQUIDITY, PRECISION, MINIMUM_K
    };

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Mint: Mint,
        Burn: Burn,
        Swap: Swap,
        Sync: Sync,
        Claim: Claim,
    }

    #[derive(Drop, starknet::Event)]
    struct Mint {
        #[key]
        sender: ContractAddress,
        amount0: u256,
        amount1: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct Burn {
        #[key]
        sender: ContractAddress,
        amount0: u256,
        amount1: u256,
        #[key]
        to: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct Swap {
        #[key]
        sender: ContractAddress,
        amount0In: u256,
        amount1In: u256,
        amount0Out: u256,
        amount1Out: u256,
        #[key]
        to: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct Sync {
        reserve0: u256,
        reserve1: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct Claim {
        #[key]
        sender: ContractAddress,
        amount0: u256,
        amount1: u256,
        #[key]
        to: ContractAddress,
    }

    #[storage]
    struct Storage {
        config: Config,
        pair_data: PairInfo,
        global_fees: GlobalFeesAccum,
        users_fee: LegacyMap::<ContractAddress, RelativeFeesAccum>,
        _entry_locked: bool,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        tokenA: ContractAddress,
        tokenB: ContractAddress,
        stable: bool,
        fee_tier: u8,
        vault_class_hash: ClassHash
    ) {
        assert(tokenA.is_non_zero() && tokenB.is_non_zero(), 'invalid address');
        let mut erc20_state = ERC20::unsafe_new_contract_state();
        if (stable) {
            ERC20::InternalImpl::initializer(ref erc20_state, 'sStarkDefi Pair', 'sSTARKD-P');
        } else {
            ERC20::InternalImpl::initializer(ref erc20_state, 'vStarkDefi Pair', 'vSTARKD-P');
        }

        let decimal0: u128 = ERC20ABIDispatcher { contract_address: tokenA }.decimals().into();
        let decimal1: u128 = ERC20ABIDispatcher { contract_address: tokenB }.decimals().into();

        let factory = get_caller_address();
        let vault = self._initialise_fee_vault(vault_class_hash, @tokenA, @tokenB, @factory);
        self
            .config
            .write(
                Config {
                    token0: tokenA,
                    token1: tokenB,
                    factory: factory,
                    vault: vault,
                    stable: stable,
                    fee_tier: fee_tier,
                    decimal0: u256 {
                        low: pow(10, decimal0), high: 0
                        }, decimal1: u256 {
                        low: pow(10, decimal1), high: 0
                    },
                }
            );

        self._entry_locked.write(false);
    }

    #[external(v0)]
    impl StarkDPairImpl of IStarkDPair<ContractState> {
        fn name(self: @ContractState) -> felt252 {
            let erc20_state = ERC20::unsafe_new_contract_state();
            ERC20::ERC20Impl::name(@erc20_state)
        }

        fn symbol(self: @ContractState) -> felt252 {
            let erc20_state = ERC20::unsafe_new_contract_state();
            ERC20::ERC20Impl::symbol(@erc20_state)
        }

        fn decimals(self: @ContractState) -> u8 {
            let erc20_state = ERC20::unsafe_new_contract_state();
            ERC20::ERC20Impl::decimals(@erc20_state)
        }

        fn total_supply(self: @ContractState) -> u256 {
            let erc20_state = ERC20::unsafe_new_contract_state();
            ERC20::ERC20Impl::total_supply(@erc20_state)
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            let erc20_state = ERC20::unsafe_new_contract_state();
            ERC20::ERC20Impl::balance_of(@erc20_state, account)
        }

        fn allowance(
            self: @ContractState, owner: ContractAddress, spender: ContractAddress
        ) -> u256 {
            let erc20_state = ERC20::unsafe_new_contract_state();
            ERC20::ERC20Impl::allowance(@erc20_state, owner, spender)
        }

        fn factory(self: @ContractState) -> ContractAddress {
            self.config.read().factory
        }

        fn token0(self: @ContractState) -> ContractAddress {
            self.config.read().token0
        }

        fn token1(self: @ContractState) -> ContractAddress {
            self.config.read().token1
        }

        fn fee_tier(self: @ContractState) -> u8 {
            self.config.read().fee_tier
        }


        /// @notice Returns the address of the fee vault.
        /// @return the address of the fee vault.
        fn fee_vault(self: @ContractState) -> ContractAddress {
            self.config.read().vault
        }

        /// @notice Returns a snapshot of the current state of the contract.
        /// @return an instance of the Snapshot struct.
        fn snapshot(self: @ContractState) -> Snapshot {
            let config = self.config.read();
            let data = self.pair_data.read();

            Snapshot {
                token0: config.token0,
                token1: config.token1,
                decimal0: config.decimal0,
                decimal1: config.decimal1,
                reserve0: data.reserve0,
                reserve1: data.reserve1,
                is_stable: config.stable,
                fee_tier: config.fee_tier,
            }
        }

        fn get_reserves(self: @ContractState) -> (u256, u256, u64) {
            let data = self.pair_data.read();
            (data.reserve0, data.reserve1, data.block_timestamp_last)
        }

        fn price0_cumulative_last(self: @ContractState) -> u256 {
            self.pair_data.read().price_0_cumulative_last
        }

        fn price1_cumulative_last(self: @ContractState) -> u256 {
            self.pair_data.read().price_1_cumulative_last
        }

        /// @notice Returns the invariant K value of the pair.
        /// @return the invariant K value.
        fn invariant_k(self: @ContractState) -> u256 {
            let data = self.pair_data.read();
            self._k(data.reserve0, data.reserve1)
        }

        fn is_stable(self: @ContractState) -> bool {
            self.config.read().stable
        }


        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            InternalFunctions::_before_transfer(
                ref self, get_caller_address(), recipient, amount
            ); // called before any transfers to keep fees up to date
            let mut erc20_state = ERC20::unsafe_new_contract_state();
            ERC20::ERC20Impl::transfer(ref erc20_state, recipient, amount);
            true
        }

        fn transfer_from(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) -> bool {
            InternalFunctions::_before_transfer(ref self, sender, recipient, amount);
            let mut erc20_state = ERC20::unsafe_new_contract_state();
            ERC20::ERC20Impl::transfer_from(ref erc20_state, sender, recipient, amount);
            true
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            let mut erc20_state = ERC20::unsafe_new_contract_state();
            ERC20::ERC20Impl::approve(ref erc20_state, spender, amount);
            true
        }

        fn increase_allowance(
            ref self: ContractState, spender: ContractAddress, addedValue: u256
        ) -> bool {
            let mut erc20_state = ERC20::unsafe_new_contract_state();
            ERC20::increase_allowance(ref erc20_state, spender, addedValue);
            true
        }

        fn decrease_allowance(
            ref self: ContractState, spender: ContractAddress, subtractedValue: u256
        ) -> bool {
            let mut erc20_state = ERC20::unsafe_new_contract_state();
            ERC20::decreaseAllowance(ref erc20_state, spender, subtractedValue);
            true
        }

        /// @notice Low-level function, importantant safety checks must be handled by the caller
        /// @dev This function mints lp tokens for the given amount of tokens to the caller.
        /// @param to the address to transfer to.
        /// @return the amount of tokens transferred.
        fn mint(ref self: ContractState, to: ContractAddress) -> u256 {
            Modifiers::_lock(ref self);
            Modifiers::_assert_not_paused(@self);
            InternalFunctions::_update_user_fee(ref self, to);

            let config = self.config.read();
            let (reserve0, reserve1, _) = self.get_reserves();
            let this_address = get_contract_address();
            let balance0 = InternalFunctions::_balance_of(config.token0, this_address);
            let balance1 = InternalFunctions::_balance_of(config.token1, this_address);
            let amount0 = balance0 - reserve0;
            let amount1 = balance1 - reserve1;

            let totalSupply = self.total_supply();

            let liquidity = if (totalSupply == 0) {
                u256 { low: u256_sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY.low, high: 0 }
            } else {
                let liquidity0 = (amount0 * totalSupply) / reserve0;
                let liquidity1 = (amount1 * totalSupply) / reserve1;
                cmp::min(liquidity0, liquidity1)
            };

            assert(liquidity > 0, 'insufficient liquidity minted');
            let mut erc20_state = ERC20::unsafe_new_contract_state();

            if totalSupply == 0 {
                ERC20::InternalImpl::_mint(
                    ref erc20_state, contract_address_const::<'deAd'>(), MINIMUM_LIQUIDITY
                );
                if (config.stable) {
                    assert(
                        (amount0 * PRECISION)
                            / config.decimal0 == (amount1 * PRECISION)
                            / config.decimal1,
                        'unequal amounts'
                    );
                    assert(self._k(amount0, amount1) > MINIMUM_K, 'K too low');
                }
            }
            ERC20::InternalImpl::_mint(ref erc20_state, to, liquidity);

            InternalFunctions::_update(ref self, balance0, balance1, reserve0, reserve1);

            self.emit(Mint { sender: get_caller_address(), amount0, amount1 });
            Modifiers::_unlock(ref self);
            liquidity
        }

        /// @notice Low-level function, importantant safety checks must be handled by the caller
        /// @dev This function burns the given amount of liquidity and transfers the underlying tokens to the caller.
        /// @param to the address to transfer to.
        /// @return the amount of tokens transferred.
        fn burn(ref self: ContractState, to: ContractAddress) -> (u256, u256) {
            Modifiers::_lock(ref self);

            //Claim fees for the user, must ensure `to` is the user to prevent losss of fees
            InternalFunctions::_claim_fees(ref self, to);

            let config = self.config.read();
            let (reserve0, reserve1, _) = self.get_reserves();
            let this_address = get_contract_address();
            let token0Dispatcher = ERC20ABIDispatcher { contract_address: config.token0 };
            let token1Dispatcher = ERC20ABIDispatcher { contract_address: config.token1 };

            let mut balance0 = InternalFunctions::_balance_of(config.token0, this_address);
            let mut balance1 = InternalFunctions::_balance_of(config.token1, this_address);
            let liquidity = self.balance_of(this_address);

            let totalSupply = self.total_supply();
            let amount0 = (liquidity * balance0) / totalSupply;
            let amount1 = (liquidity * balance1) / totalSupply;
            assert(amount0 > 0 && amount1 > 0, 'insufficient liquidity burned');

            let mut erc20_state = ERC20::unsafe_new_contract_state();
            ERC20::InternalImpl::_burn(ref erc20_state, get_contract_address(), liquidity);

            token0Dispatcher.transfer(to, amount0);
            token1Dispatcher.transfer(to, amount1);

            balance0 = InternalFunctions::_balance_of(config.token0, this_address);
            balance1 = InternalFunctions::_balance_of(config.token1, this_address);

            self._update(balance0, balance1, reserve0, reserve1);

            self.emit(Burn { sender: get_caller_address(), amount0, amount1, to });

            Modifiers::_unlock(ref self);
            (amount0, amount1)
        }

        fn swap(
            ref self: ContractState,
            amount0Out: u256,
            amount1Out: u256,
            to: ContractAddress,
            data: Array::<felt252>
        ) {
            Modifiers::_lock(ref self);
            Modifiers::_assert_not_paused(@self);

            assert(amount0Out > 0 || amount1Out > 0, 'insufficient output amount');
            let (reserve0, reserve1, _) = self.get_reserves();
            assert(amount0Out < reserve0 && amount1Out < reserve1, 'insufficient liquidity');

            let config = self.config.read();
            let token0 = config.token0;
            let token1 = config.token1;
            assert(to != token0 && to != token1, 'invalid to');

            let this_address = get_contract_address();

            let token0Dispatcher = ERC20ABIDispatcher { contract_address: token0 };
            let token1Dispatcher = ERC20ABIDispatcher { contract_address: token1 };

            if amount0Out > 0 {
                token0Dispatcher.transfer(to, amount0Out);
            }
            if amount1Out > 0 {
                token1Dispatcher.transfer(to, amount1Out);
            }
            if data.len() > 0 {
                IStarkDCalleeDispatcher {
                    contract_address: to
                }
                    .hook(
                        get_caller_address(), amount0Out, amount1Out, data
                    ); // callback for flash loans
            }

            let mut balance0 = InternalFunctions::_balance_of(config.token0, this_address);
            let mut balance1 = InternalFunctions::_balance_of(config.token1, this_address);

            let amount0In = if balance0 > reserve0 - amount0Out {
                balance0 - (reserve0 - amount0Out)
            } else {
                0
            };

            let amount1In = if balance1 > reserve1 - amount1Out {
                balance1 - (reserve1 - amount1Out)
            } else {
                0
            };

            assert(amount0In > 0 || amount1In > 0, 'insufficient input amount');
            InternalFunctions::_update_global_fees(
                ref self, amount0In, amount1In
            ); // accumulate and transfer fees to vault

            // recalculate balance after fees are taken
            balance0 = InternalFunctions::_balance_of(config.token0, this_address);
            balance1 = InternalFunctions::_balance_of(config.token1, this_address);

            assert(
                self._k(balance0, balance1) >= self._k(reserve0, reserve1), 'invariant K'
            ); // stable: x^3y+xy^3, volatile: x*y 

            InternalFunctions::_update(ref self, balance0, balance1, reserve0, reserve1);

            self
                .emit(
                    Swap {
                        sender: get_caller_address(),
                        amount0In,
                        amount1In,
                        amount0Out,
                        amount1Out,
                        to
                    }
                );

            Modifiers::_unlock(ref self);
        }

        fn skim(ref self: ContractState, to: ContractAddress) {
            Modifiers::_lock(ref self);
            Modifiers::_assert_not_paused(@self);

            let (reserve0, reserve1, _) = self.get_reserves();
            let this_address = get_contract_address();

            let config = self.config.read();
            let token0Dispatcher = ERC20ABIDispatcher { contract_address: config.token0 };
            let token1Dispatcher = ERC20ABIDispatcher { contract_address: config.token1 };

            let balance0 = InternalFunctions::_balance_of(config.token0, this_address);
            let balance1 = InternalFunctions::_balance_of(config.token1, this_address);

            token0Dispatcher.transfer(to, balance0 - reserve0);
            token1Dispatcher.transfer(to, balance1 - reserve1);

            Modifiers::_unlock(ref self);
        }

        fn sync(ref self: ContractState) {
            Modifiers::_lock(ref self);
            Modifiers::_assert_not_paused(@self);

            let this_address = get_contract_address();

            let config = self.config.read();
            let balance0 = InternalFunctions::_balance_of(config.token0, this_address);

            let balance1 = InternalFunctions::_balance_of(config.token1, this_address);

            let (reserve0, reserve1, _) = self.get_reserves();

            InternalFunctions::_update(ref self, balance0, balance1, reserve0, reserve1);

            Modifiers::_unlock(ref self);
        }

        fn claim_fees(ref self: ContractState) {
            Modifiers::_lock(ref self);
            Modifiers::_assert_not_paused(@self);
            let user = get_caller_address();

            InternalFunctions::_claim_fees(ref self, user);
            Modifiers::_unlock(ref self);
        }

        fn get_amount_out(
            ref self: ContractState, tokenIn: ContractAddress, amountIn: u256
        ) -> u256 {
            assert(amountIn > 0, 'insufficient input amount');
            let (reserve0, reserve1, _) = self.get_reserves();
            assert(reserve0 > 0 && reserve1 > 0, 'insufficient liquidity');
            let pool_fee = IStarkDFactoryABIDispatcher {
                contract_address: self.factory()
            }.get_fee(get_contract_address()).into();

            let _amount_in = amountIn - ((amountIn * pool_fee) / FEE_DENOMINATOR);

            InternalFunctions::_calculate_amount_out(@self, tokenIn, _amount_in, reserve0, reserve1)
        }
    }

    #[external(v0)]
    impl StarkDPairCamelOnlyImpl of IStarkDPairCamelOnly<ContractState> {
        fn totalSupply(self: @ContractState) -> u256 {
            self.total_supply()
        }

        fn balanceOf(self: @ContractState, account: ContractAddress) -> u256 {
            self.balance_of(account)
        }

        fn increaseAllowance(
            ref self: ContractState, spender: ContractAddress, addedValue: u256
        ) -> bool {
            StarkDPairImpl::increase_allowance(ref self, spender, addedValue)
        }

        fn decreaseAllowance(
            ref self: ContractState, spender: ContractAddress, subtractedValue: u256
        ) -> bool {
            StarkDPairImpl::decrease_allowance(ref self, spender, subtractedValue)
        }

        fn transferFrom(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) -> bool {
            StarkDPairImpl::transfer_from(ref self, sender, recipient, amount)
        }

        fn getReserves(self: @ContractState) -> (u256, u256, u64) {
            self.get_reserves()
        }

        fn price0CumulativeLast(self: @ContractState) -> u256 {
            self.price0_cumulative_last()
        }

        fn price1CumulativeLast(self: @ContractState) -> u256 {
            self.price1_cumulative_last()
        }

        fn getAmountOut(ref self: ContractState, tokenIn: ContractAddress, amountIn: u256) -> u256 {
            self.get_amount_out(tokenIn, amountIn)
        }
    }

    #[external(v0)]
    fn fee_state(
        self: @ContractState, user: ContractAddress
    ) -> (u256, RelativeFeesAccum, GlobalFeesAccum) {
        let global_fees = self.global_fees.read();
        let user_fees = self.users_fee.read(user);
        let balance = self.balance_of(user);
        (balance, user_fees, global_fees)
    }

    #[external(v0)]
    fn feeState(
        self: @ContractState, user: ContractAddress
    ) -> (u256, RelativeFeesAccum, GlobalFeesAccum) {
        fee_state(self, user)
    }

    #[external(v0)]
    fn recover_orphaned_fees(ref self: ContractState) {
        Modifiers::assert_only_handler(@self);

        let this_address = get_contract_address();
        let config = self.config.read();

        // Get current vault balance
        let vault_balance0 = InternalFunctions::_balance_of(config.token0, config.vault);
        let vault_balance1 = InternalFunctions::_balance_of(config.token1, config.vault);

        // Calculate how much should be claimable by current LP holders
        let global_fees = self.global_fees.read();
        let total_supply = self.total_supply();
        let claimable0 = (global_fees.token0 * total_supply) / PRECISION;
        let claimable1 = (global_fees.token1 * total_supply) / PRECISION;

        // Calculate orphaned fees (vault balance - claimable fees)
        let orphaned0 = vault_balance0 - claimable0;
        let orphaned1 = vault_balance1 - claimable1;

        if (orphaned0 > 0 || orphaned1 > 0) {
            // Move orphaned fees to protocol fees
            IFeesVaultDispatcher {
                contract_address: config.vault
            }.update_protocol_fees(orphaned0, orphaned1);
        }
    }

    /// @notice upgradable at moment, a future implementation will drop this
    #[external(v0)]
    impl UpgradableImpl of IUpgradable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            Modifiers::assert_only_handler(@self);
            let mut state = Upgradable::unsafe_new_contract_state();
            Upgradable::InternalImpl::_upgrade(ref state, new_class_hash);
        }
    }


    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _update(
            ref self: ContractState, balance0: u256, balance1: u256, reserve0: u256, reserve1: u256
        ) {
            assert(balance0.high == 0 && balance1.high == 0, 'overflow');
            let mut data = self.pair_data.read();

            let block_timestamp = get_block_timestamp();
            let timeElapsed = block_timestamp - data.block_timestamp_last;

            if (timeElapsed > 0 && reserve0 != 0 && reserve1 != 0) {
                data.price_0_cumulative_last += (reserve1 / reserve0) * u256 {
                    low: u128_try_from_felt252(timeElapsed.into()).unwrap(), high: 0
                };

                data.price_1_cumulative_last += (reserve0 / reserve1) * u256 {
                    low: u128_try_from_felt252(timeElapsed.into()).unwrap(), high: 0
                };
            }

            data.reserve0 = balance0;
            data.reserve1 = balance1;
            data.block_timestamp_last = block_timestamp;

            self.pair_data.write(data);

            self.emit(Sync { reserve0, reserve1 });
        }

        /// @notice Initialises the fee vault for the pair contract
        /// @param self The state of the contract
        /// @param vault_class_hash The class hash of the vault contract
        /// @param token0 The address of the first token in the pair
        /// @param token1 The address of the second token in the pair
        /// @param factory The address of the factory contract
        /// @return The address of the newly created fee vault contract
        fn _initialise_fee_vault(
            self: @ContractState,
            vault_class_hash: ClassHash,
            token0: @ContractAddress,
            token1: @ContractAddress,
            factory: @ContractAddress
        ) -> ContractAddress {
            let mut calldata = array![];

            Serde::serialize(token0, ref calldata);
            Serde::serialize(token1, ref calldata);
            Serde::serialize(factory, ref calldata);

            let token0_felt252 = contract_address_to_felt252(*token0);
            let token1_felt252 = contract_address_to_felt252(*token1);

            let salt = pedersen(token0_felt252, token1_felt252);
            let (vault, _) = deploy_syscall(vault_class_hash, salt, calldata.span(), false)
                .unwrap_syscall();
            vault
        }

        /// @notice Updates the global fees for the pair contract
        /// @dev This function calculates the fees for token0 and token1, transfers the fees to the fee vault,
        ///      updates the protocol fees, and updates the share rate for LP providers.
        /// @param self The state of the contract
        /// @param amount0In The amount of token0 being swapped
        /// @param amount1In The amount of token1 being swapped
        fn _update_global_fees(ref self: ContractState, amount0In: u256, amount1In: u256) {
            let mut global_fees = self.global_fees.read();
            let pair = get_contract_address();
            let factory = IStarkDFactoryABIDispatcher { contract_address: self.factory() };

            let swap_fee = factory.get_fee(pair).into();
            let protocol_fee_on = factory.protocol_fee_on();

            if (amount0In > 0) {
                let fee0 = (amount0In * swap_fee) / FEE_DENOMINATOR;
                ERC20ABIDispatcher {
                    contract_address: self.token0()
                }.transfer(self.fee_vault(), fee0); // transfer the fees to the fee vault

                if (protocol_fee_on) {
                    let pfee0 = (fee0 * 3000) / FEE_DENOMINATOR; // 30% of fee0 to the protocol
                    IFeesVaultDispatcher {
                        contract_address: self.fee_vault()
                    }.update_protocol_fees(pfee0, 0); // update the protocol fees

                    let ufee0 = fee0 - pfee0; // 70% of fee0 to LP providers
                    global_fees.token0 += (ufee0 * PRECISION) / self.total_supply();
                } else {
                    global_fees.token0 += (fee0 * PRECISION) / self.total_supply();
                }
            }

            if (amount1In > 0) {
                let fee1 = (amount1In * swap_fee) / FEE_DENOMINATOR;
                ERC20ABIDispatcher {
                    contract_address: self.token1()
                }.transfer(self.fee_vault(), fee1);

                if (protocol_fee_on) {
                    let pfee1 = (fee1 * 3000) / FEE_DENOMINATOR;
                    IFeesVaultDispatcher {
                        contract_address: self.fee_vault()
                    }.update_protocol_fees(0, pfee1);

                    let ufee1 = fee1 - pfee1;
                    global_fees.token1 += (ufee1 * PRECISION) / self.total_supply();
                } else {
                    global_fees.token1 += (fee1 * PRECISION) / self.total_supply();
                }
            }

            self.global_fees.write(global_fees);
        }

        /// @notice Updates the user fees for a given user
        /// @dev This function reads the global fees and the user's balance, and calculates the claimable fees for the user.
        ///      If the user's balance is greater than 0, it updates the user's accumulators to the current global accumulators,
        ///      and calculates the claimable fees based on the difference between the global and user's last accumulators.
        ///      If the user's balance is 0, it sets the user's accumulators to the global accumulators and the claimable fees to 0.
        /// @param self The state of the contract
        /// @param user The address of the user
        fn _update_user_fee(ref self: ContractState, user: ContractAddress) {
            let mut user_fees = self.users_fee.read(user);
            let global_fees = self.global_fees.read();

            let balance = self.balance_of(user);

            if (balance > 0) {
                let last_token0_accum = user_fees.token0;
                let last_token1_accum = user_fees.token1;

                let global_token0_accum = global_fees.token0;
                let global_token1_accum = global_fees.token1;

                // update accumulators to the current global accumulators
                user_fees.token0 = global_token0_accum;
                user_fees.token1 = global_token1_accum;

                // calculate the claimable fees
                let delta0 = global_token0_accum - last_token0_accum;

                if (delta0 > 0) {
                    let claimable0 = (balance * delta0) / PRECISION;
                    user_fees.claimable0 += claimable0;
                }

                let delta1 = global_token1_accum - last_token1_accum;
                if (delta1 > 0) {
                    let claimable1 = (balance * delta1) / PRECISION;
                    user_fees.claimable1 += claimable1;
                }
            } else {
                user_fees.token0 = global_fees.token0;
                user_fees.token1 = global_fees.token1;
                user_fees.claimable0 = 0;
                user_fees.claimable1 = 0;
            }

            self.users_fee.write(user, user_fees);
        }

        /// @notice Claim fees for a given user
        fn _claim_fees(ref self: ContractState, user: ContractAddress) {
            InternalFunctions::_update_user_fee(ref self, user);
            let mut user_fees = self.users_fee.read(user);

            let claimable0 = user_fees.claimable0;
            let claimable1 = user_fees.claimable1;

            if (claimable0 > 0 || claimable1 > 0) {
                user_fees.claimable0 = 0;
                user_fees.claimable1 = 0;

                IFeesVaultDispatcher {
                    contract_address: self.fee_vault()
                }.claim_lp_fees(user, claimable0, claimable1);
                self.users_fee.write(user, user_fees);
            }

            self
                .emit(
                    Claim {
                        sender: self.fee_vault(), amount0: claimable0, amount1: claimable1, to: user
                    }
                );
        }

        /// @notice Calculates the amount of tokenOut received for a given amount of tokenIn
        /// @param self The state of the contract
        /// @param tokenIn The address of the token being swapped
        /// @param amountIn The amount of tokenIn being swapped
        /// @param reserve0 The amount of token0 in the pair
        /// @param reserve1 The amount of token1 in the pair
        /// @return The amount of tokenOut received
        fn _calculate_amount_out(
            self: @ContractState,
            tokenIn: ContractAddress,
            amountIn: u256,
            reserve0: u256,
            reserve1: u256
        ) -> u256 {
            let config = self.config.read();
            if (self.is_stable()) {
                let k0 = self._k(reserve0, reserve1);
                let res0_normalized = (reserve0 * PRECISION) / config.decimal0;
                let res1_normalized = (reserve1 * PRECISION) / config.decimal1;

                let (resA, resB) = if (tokenIn == config.token0) {
                    (res0_normalized, res1_normalized)
                } else {
                    (res1_normalized, res0_normalized)
                };

                let _amount_in = if (tokenIn == config.token0) {
                    (amountIn * PRECISION) / config.decimal0
                } else {
                    (amountIn * PRECISION) / config.decimal1
                };

                let y = resB - self._solve_y(_amount_in + resA, k0, resB);
                let tokenIn_decimal = if (tokenIn == config.token0) {
                    config.decimal1
                } else {
                    config.decimal0
                };

                (y * tokenIn_decimal) / PRECISION
            } else {
                let (resA, resB) = if (tokenIn == config.token0) {
                    (reserve0, reserve1)
                } else {
                    (reserve1, reserve0)
                };
                (amountIn * resB) / (resA + amountIn)
            }
        }

        /// @notice called before any transfers to keep fees up to date
        fn _before_transfer(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, amount: u256
        ) {
            InternalFunctions::_update_user_fee(ref self, from);
            InternalFunctions::_update_user_fee(ref self, to);
        }

        /// @notice try balanceOf & balance_of
        fn _balance_of(token: ContractAddress, account: ContractAddress) -> u256 {
            let mut call_data = array![];
            Serde::serialize(@account, ref call_data);

            call_contract_with_selector_fallback(
                token, selectors::balanceOf, selectors::balance_of, call_data.span()
            )
                .unwrap_and_cast()
        }
    }

    #[generate_trait]
    impl PairMath of PairMathTraits {
        /// @notice Calculates the equation f(x,y)=x*y(x^2 + y^2)
        /// @param self The state of the contract
        /// @param x Initial value of x
        /// @param y The second parameter of the equation
        /// @return The result of the equation 
        fn _f(self: @ContractState, x0: u256, y: u256) -> u256 {
            let lhs = (x0 * y) / PRECISION; // x*y
            let rhs = ((x0 * x0) / PRECISION + (y * y) / PRECISION); // x^2 + y^2
            (lhs * rhs) / PRECISION
        }

        /// @notice Implements the invariant k (stable = x*y(x^2 + y^2), volatile = x*y)
        /// @param self The state of the contract
        /// @param x The first parameter of the invariant function
        /// @param y The second parameter of the invariant function
        /// @return The result of the invariant (stable or volatile) function
        fn _k(self: @ContractState, x: u256, y: u256) -> u256 {
            let config = self.config.read();
            if (config.stable) {
                let _x = (x * PRECISION) / config.decimal0;
                let _y = (y * PRECISION) / config.decimal1;

                self._f(_x, _y)
            } else {
                x * y // x*y >= k
            }
        }

        /// @notice Calculates derivative of f(x,y) with respect to y;  x^3 + 3xy^2
        /// @dev used in the Newton-Raphson method to find the root of f(x,y)
        /// @param self The state of the contract
        /// @param x0 Initial value of x
        /// @param y The second param of the derivative
        /// @return The result of the derivative
        fn _dy(self: @ContractState, x0: u256, y: u256) -> u256 {
            let lhs = (x0 * x0 * x0) / (PRECISION * PRECISION);
            let rhs = 3 * x0 * (y * y) / (PRECISION * PRECISION);
            lhs + rhs
        }

        /// @notice Finds the value of y such that f(x,y) ~= k0
        /// @dev This function uses the Newton-Raphson method to approximate the root of f(x,y)
        ///      In each iteration, the value of y is adjusted such that f(x,y) is as close as possible to k0.
        ///      If f(x,y) is less than k0, the adjustment is added to y, otherwise it is subtracted.
        ///      The iterations continue until the function value is equal to k0 or the maximum number of iterations is reached.
        ///      If the function value is not exactly equal to k0, the closest approximation is returned.
        /// @param self The state of the contract
        /// @param x0 Initial value of x
        /// @param k0 The invariant value
        /// @param y The initial value of y
        /// @return The value of y such that f(x,y) ~= k0 or revert
        fn _solve_y(self: @ContractState, x0: u256, k0: u256, y: u256) -> u256 {
            let mut y0 = y;
            let mut i: u8 = 0;
            let max_iterations: u8 = 255;

            let res = loop {
                if (i >= max_iterations) {
                    assert(false, '!found y');
                }

                let f = self._f(x0, y0);
                // If the function value is less than the invariant value, we need to increase y.
                // This is because the function is increasing with respect to y.
                if (f < k0) {
                    // Calculate the adjustment for y using the derivative of the function.
                    // This is the Newton-Raphson method step.
                    let mut dy = ((k0 - f) * PRECISION) / self._dy(x0, y0);
                    // If the adjustment is zero, it means we have found an exact solution or we need to make a minimum step.
                    if (dy == 0) {
                        if (f == k0) {
                            break y0; // found exact solution
                        }
                        // If increasing y by 1 makes the function value greater than the invariant value,
                        // it means the current y is the closest approximation we can get.
                        if (self._k(x0, y0 + 1) > k0) {
                            break y0 + 1; // return closest approximation
                        }
                        // If none of the above conditions are met, make a minimum step.
                        dy = 1;
                    }
                    y0 += dy;
                } else {
                    // Calculate the adjustment for y using the derivative of the function.
                    // This is the Newton-Raphson method step.
                    let mut dy = ((f - k0) * PRECISION) / self._dy(x0, y0);
                    // If the adjustment is zero, it means we have found an exact solution or we need to make a minimum step.
                    if (dy == 0) {
                        // If the function value is equal to the invariant value, or if decreasing y by 1 makes the function value less than the invariant value,
                        // it means the current y is the closest approximation we can get.
                        if (f == k0 || self._f(x0, y0 - 1) < k0) {
                            break y0; // found exact solution; f(x,y) must be >= k0 hence y0-1 cannot be a solution
                        }
                        // If none of the above conditions are met, make a minimum step.
                        dy = 1;
                    }
                    y0 -= dy;
                }

                i += 1;
            };

            res
        }
    }

    #[generate_trait]
    impl Modifiers of ModifiersTrait {
        // @notice Locks the entry point to prevent reentrancy attacks
        fn _lock(ref self: ContractState) {
            assert(!self._entry_locked.read(), 'locked');
            self._entry_locked.write(true);
        }

        // @notice Unlocks the entry point
        fn _unlock(ref self: ContractState) {
            self._entry_locked.write(false);
        }

        fn _assert_not_paused(self: @ContractState) {
            let config = self.config.read();
            let factoryDipatcher = IStarkDFactoryABIDispatcher { contract_address: config.factory };
            factoryDipatcher.assert_not_paused();
        }

        /// @dev reverts if not handler 
        fn assert_only_handler(self: @ContractState) {
            let caller = get_caller_address();
            let factory = IStarkDFactoryABIDispatcher {
                contract_address: self.config.read().factory
            };
            assert(caller == factory.fee_handler(), 'not allowed');
        }
    }
}

