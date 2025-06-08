/// @title StarkDefi Factory Contract
/// @author StarkDefi Labs
/// @license MIT
/// @dev StarkDefi Pair Factory, responsible for creating pairs and setting fees
use starknet::{ClassHash, ContractAddress};

/// @dev Configuration structure for the factory contract
#[derive(Copy, Drop, Serde, starknet::Store)]
struct Config {
    fee_to: ContractAddress,
    fee_handler: ContractAddress,
    pair_class_hash: ClassHash,
    vault_class_hash: ClassHash,
}

/// @dev Structure for holding fee information
#[derive(Copy, Drop, Serde, starknet::Store)]
struct Fees {
    stable: u8,
    volatile: u8,
}

/// @dev Structure for validating a pair
#[derive(Copy, Drop, Serde, starknet::Store)]
struct ValidPair {
    is_valid: bool,
    is_stable: bool,
    custom_fee: u8,
}

const MAX_FEE: u8 = 100; // 1%

#[starknet::contract]
mod StarkDFactory {
    use array::ArrayTrait;
    use starkdefi::dex::v1::factory::interface::IStarkDFactory;
    use starkdefi::utils::ContractAddressPartialOrd;
    use starkdefi::utils::upgradable::{IUpgradable, Upgradable};
    use starknet::syscalls::deploy_syscall;
    use starknet::{contract_address_to_felt252, get_caller_address, replace_class_syscall};
    use traits::Into;
    use zeroable::Zeroable;
    use super::{ClassHash, Config, ContractAddress, Fees, MAX_FEE, ValidPair};


    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        PairCreated: PairCreated,
        SetPairFee: SetPairFee,
        Paused: Paused,
        Unpaused: Unpaused,
    }

    #[derive(Drop, starknet::Event)]
    struct PairCreated {
        #[key]
        tokenA: ContractAddress,
        #[key]
        tokenB: ContractAddress,
        pair: ContractAddress,
        pair_count: u32,
        stable: bool,
    }

    #[derive(Drop, starknet::Event)]
    struct SetPairFee {
        #[key]
        pair: ContractAddress,
        #[key]
        stable: bool,
        fee: u8,
    }

    #[derive(Drop, starknet::Event)]
    struct Paused {
        account: ContractAddress, 
    }

    #[derive(Drop, starknet::Event)]
    struct Unpaused {
        account: ContractAddress, 
    }

    #[storage]
    struct Storage {
        config: Config,
        fees: Fees,
        paused: bool,
        protocol_fee_on: bool,
        _pair: LegacyMap<(ContractAddress, ContractAddress, bool, u8), ContractAddress>,
        _all_pairs: LegacyMap<u32, ContractAddress>,
        valid_pairs: LegacyMap<ContractAddress, ValidPair>,
        _all_pairs_length: u32,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        fee_handler: ContractAddress,
        class_hash_pair_contract: ClassHash,
        vault_class_hash: ClassHash,
    ) {
        assert(fee_handler.is_non_zero(), 'invalid fee to setter');
        assert(class_hash_pair_contract.is_non_zero(), 'invalid class hash');
        assert(vault_class_hash.is_non_zero(), 'invalid vault class hash');

        self._all_pairs_length.write(0);
        self.fees.write(Fees { stable: 4, volatile: 30 }); // 0.04% and 0.3%
        self.protocol_fee_on.write(true);

        self
            .config
            .write(
                Config {
                    fee_to: fee_handler,
                    fee_handler,
                    pair_class_hash: class_hash_pair_contract,
                    vault_class_hash,
                },
            );
    }


    #[external(v0)]
    impl StarkDFactoryImpl of IStarkDFactory<ContractState> {
        /// @notice Get fee to address
        /// @returns  address
        fn fee_to(self: @ContractState) -> ContractAddress {
            self.config.read().fee_to
        }

        /// @notice Get fee handler address
        /// @returns  address
        fn fee_handler(self: @ContractState) -> ContractAddress {
            self.config.read().fee_handler
        }

        /// @notice Get pair contract address given tokenA, tokenB and a bool representing stable or
        /// volatile @returns  address of the pair
        fn get_pair(
            self: @ContractState,
            tokenA: ContractAddress,
            tokenB: ContractAddress,
            stable: bool,
            fee: u8,
        ) -> ContractAddress {
            let (token0, token1) = self.sort_tokens(tokenA, tokenB);
            let pair = self._pair.read((token0, token1, stable, fee));
            pair
        }

        /// @notice Get global fees
        /// @returns  stable u8 and volatile u8 fees
        fn get_fees(self: @ContractState) -> (u8, u8) {
            let fees = self.fees.read();
            (fees.stable, fees.volatile)
        }

        /// @notice Get protocol fee status
        /// @returns  bool
        fn protocol_fee_on(self: @ContractState) -> bool {
            self.protocol_fee_on.read()
        }

        /// @notice Get fee for a pair
        /// @returns  fee
        fn get_fee(self: @ContractState, pair: ContractAddress) -> u8 {
            let pair_info = self.valid_pairs.read(pair);
            assert(pair_info.is_valid, 'invalid pair');
            let is_stable = pair_info.is_stable;

            if pair_info.custom_fee > 0 {
                return pair_info.custom_fee;
            }
            if is_stable {
                return self.fees.read().stable;
            }
            self.fees.read().volatile
        }

        /// @notice Check if pair exists
        /// @returns  bool
        fn valid_pair(self: @ContractState, pair: ContractAddress) -> bool {
            self.valid_pairs.read(pair).is_valid
        }

        /// @notice Get all pairs
        /// @returns  pair_counts (length of all the pairs) and pairs (addresses of all pairs
        /// addresses)
        fn all_pairs(self: @ContractState) -> (u32, Array::<ContractAddress>) {
            let pair_counts = self._all_pairs_length.read();
            let mut pairs = ArrayTrait::<ContractAddress>::new();

            let mut index = 0;
            loop {
                if index == pair_counts {
                    break true;
                }
                pairs.append(self._all_pairs.read(index));
                index += 1;
            };

            (pair_counts, pairs)
        }

        /// @notice Get total number of pairs
        /// @returns  pair_counts
        fn all_pairs_length(self: @ContractState) -> u32 {
            self._all_pairs_length.read()
        }

        /// @notice Get class hash for pair contract
        fn class_hash_for_pair_contract(self: @ContractState) -> ClassHash {
            self.config.read().pair_class_hash
        }

        /// @notice Create pair with `tokenA` and `tokenB` if it does not exist.
        /// @param tokenA ContractAddress of tokenA
        /// @param tokenB ContractAddress of tokenB
        /// @return pair ContractAddress of the new pair
        fn create_pair(
            ref self: ContractState,
            tokenA: ContractAddress,
            tokenB: ContractAddress,
            stable: bool,
            fee: u8,
        ) -> ContractAddress {
            assert(tokenA.is_non_zero() && tokenB.is_non_zero(), 'invalid token address');
            assert(tokenA != tokenB, 'identical addresses');
            assert(fee.into() <= MAX_FEE, 'fee too high');

            let config = self.config.read();
            let vault_class_hash = config.vault_class_hash;

            let found_pair = self.get_pair(tokenA, tokenB, stable, fee);
            assert(found_pair.is_zero(), 'pair exists');

            let (token0, token1) = self.sort_tokens(tokenA, tokenB);

            let mut pair_constructor_calldata = Default::default();
            Serde::serialize(@token0, ref pair_constructor_calldata);
            Serde::serialize(@token1, ref pair_constructor_calldata);
            Serde::serialize(@stable, ref pair_constructor_calldata);
            Serde::serialize(@fee, ref pair_constructor_calldata);
            Serde::serialize(@vault_class_hash, ref pair_constructor_calldata);

            let token0_felt252 = contract_address_to_felt252(token0)
                + if (fee > 0) {
                    fee.into()
                } else {
                    0
                };
            let token1_stable_felt252 = contract_address_to_felt252(token1)
                + if stable {
                    1
                } else {
                    0
                }; // add stable bool as well since pedersen takes 2 args

            let address_salt = pedersen(token0_felt252, token1_stable_felt252);

            let (pair, _) = deploy_syscall(
                config.pair_class_hash, address_salt, pair_constructor_calldata.span(), false, 
            )
                .unwrap_syscall(); // deploy_syscall never panics

            self._pair.write((token0, token1, stable, fee), pair);
            let pair_count = self._all_pairs_length.read();
            self._all_pairs.write(pair_count, pair);
            self
                .valid_pairs
                .write(pair, ValidPair { is_valid: true, is_stable: stable, custom_fee: fee });
            self._all_pairs_length.write(pair_count + 1);

            self
                .emit(
                    PairCreated {
                        tokenA: token0, tokenB: token1, pair, pair_count: pair_count + 1, stable, 
                    },
                );

            pair
        }

        /// @notice Set fee to address
        /// @param  fee_to ContractAddress of fee_to
        fn set_fee_to(ref self: ContractState, fee_to: ContractAddress) {
            Modifiers::assert_only_handler(@self);
            let mut config = self.config.read();
            assert(fee_to.is_non_zero(), 'invalid fee to');
            config.fee_to = fee_to;
            self.config.write(config);
        }

        /// @notice Set universal fee
        /// @param fee u256, must be less than MAX_FEE
        /// @param stable bool
        fn set_fee(ref self: ContractState, fee: u8, stable: bool) {
            Modifiers::assert_only_handler(@self);
            assert(fee <= MAX_FEE && fee > 0, 'invalid fee');
            let mut fees = self.fees.read();
            if stable {
                fees.stable = fee;
            } else {
                fees.volatile = fee;
            }
            self.fees.write(fees);
        }

        /// @notice Set custom fee for a pair
        /// @param pair ContractAddress of pair
        /// @param fee u256, must be less than MAX_FEE
        /// @param stable bool
        fn set_custom_pair_fee(ref self: ContractState, pair: ContractAddress, fee: u8) {
            Modifiers::assert_only_handler(@self);
            assert(fee <= MAX_FEE, 'fee too high');
            let mut pair_info = self.valid_pairs.read(pair);
            assert(pair_info.is_valid, 'invalid pair');
            pair_info.custom_fee = fee;
            self.valid_pairs.write(pair, pair_info);
            self.emit(SetPairFee { pair, stable: pair_info.is_stable, fee });
        }

        /// @notice Set fee handler  address
        /// @param  handler_address ContractAddress of fee_handler
        fn set_fee_handler(ref self: ContractState, handler_address: ContractAddress) {
            Modifiers::assert_only_handler(@self);
            let mut config = self.config.read();
            assert(handler_address.is_non_zero(), 'invalid handler address');
            config.fee_handler = handler_address;
            self.config.write(config);
        }
    }

    /// @notice Set class hash for pair contract
    /// @param  class_hash_pair_contract ClassHash of pair contract
    #[external(v0)]
    fn set_pair_contract_class(ref self: ContractState, class_hash_pair_contract: ClassHash) {
        Modifiers::assert_only_handler(@self);
        assert(class_hash_pair_contract.is_non_zero(), 'invalid class hash');
        let mut config = self.config.read();
        config.pair_class_hash = class_hash_pair_contract;
        self.config.write(config);
    }

    /// @notice Set class hash for vault contract
    /// @param  vault_class_hash ClassHash of vault contract
    #[external(v0)]
    fn set_vault_contract_class(ref self: ContractState, vault_class_hash: ClassHash) {
        Modifiers::assert_only_handler(@self);
        let mut config = self.config.read();
        assert(vault_class_hash.is_non_zero(), 'invalid class hash');
        config.vault_class_hash = vault_class_hash;
        self.config.write(config);
    }

    /// @notice Callable when contract is paused
    // @dev reverts if not paused
    #[external(v0)]
    fn assert_paused(self: @ContractState) {
        assert(self.paused.read(), 'not paused');
    }

    /// @notice Callable when contract is not paused
    // @dev reverts if paused
    #[external(v0)]
    fn assert_not_paused(self: @ContractState) {
        assert(!self.paused.read(), 'paused');
    }

    /// @notice Pause contract in case of emergency
    /// @dev only callable when contract is not paused
    #[external(v0)]
    fn pause(ref self: ContractState) {
        Modifiers::assert_only_handler(@self);
        assert_not_paused(@self);
        self.paused.write(true);
        self.emit(Paused { account: get_caller_address() });
    }

    /// @notice Unpause contract
    /// @dev only callable when contract is paused
    #[external(v0)]
    fn unpause(ref self: ContractState) {
        Modifiers::assert_only_handler(@self);
        assert_paused(@self);
        self.paused.write(false);
        self.emit(Unpaused { account: get_caller_address() });
    }

    #[external(v0)]
    fn toggle_protocol_fee(ref self: ContractState) {
        Modifiers::assert_only_handler(@self);
        self.protocol_fee_on.write(!self.protocol_fee_on.read());
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
        /// @notice Sort tokens by address
        /// @param tokenA ContractAddress of tokenA
        /// @param tokenB ContractAddress of tokenB
        /// @return (token0, token1)
        fn sort_tokens(
            self: @ContractState, tokenA: ContractAddress, tokenB: ContractAddress, 
        ) -> (ContractAddress, ContractAddress) {
            assert(tokenA != tokenB, 'identical addresses');
            let (token0, token1) = if tokenA < tokenB {
                (tokenA, tokenB)
            } else {
                (tokenB, tokenA)
            };
            assert(token0.is_non_zero(), 'invalid token0');
            (token0, token1)
        }
    }

    #[generate_trait]
    impl Modifiers of ModifiersTrait {
        /// @dev reverts if not handler
        fn assert_only_handler(self: @ContractState) {
            let caller = get_caller_address();
            let handler = self.config.read().fee_handler;
            assert(caller == handler, 'not allowed');
        }
    }
}

