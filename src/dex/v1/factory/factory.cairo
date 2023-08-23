// @title StarkDefi Factory Contract
// @author StarkDefi Labs
// @license MIT
// @description Based on UniswapV2 Factory Contract

#[starknet::contract]
mod StarkDFactory {
    use starkDefi::dex::v1::factory::interface::IStarkDFactory;
    use array::ArrayTrait;
    use traits::Into;
    use starknet::{ClassHash, ContractAddress, get_caller_address, contract_address_to_felt252};
    use zeroable::Zeroable;
    use starknet::syscalls::deploy_syscall;

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        PairCreated: PairCreated
    }

    #[derive(Drop, starknet::Event)]
    struct PairCreated {
        #[key]
        tokenA: ContractAddress,
        #[key]
        tokenB: ContractAddress,
        pair: ContractAddress,
        pair_count: u32,
    }

    #[storage]
    struct Storage {
        _fee_to: ContractAddress,
        _fee_to_setter: ContractAddress,
        _pair: LegacyMap::<(ContractAddress, ContractAddress), ContractAddress>,
        _all_pairs: LegacyMap::<u32, ContractAddress>,
        _all_pairs_length: u32,
        _class_hash_for_pair_contract: ClassHash,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, fee_to_setter: ContractAddress, class_hash_pair_contract: ClassHash
    ) {
        assert(fee_to_setter.is_non_zero(), 'invalid fee to setter');
        assert(class_hash_pair_contract.is_non_zero(), 'invalid classhash');

        self._all_pairs_length.write(0);
        self._class_hash_for_pair_contract.write(class_hash_pair_contract);
        self._fee_to_setter.write(fee_to_setter);
    }


    #[external(v0)]
    impl StarkDFactory of IStarkDFactory<ContractState> {
        // @notice Get fee to address
        // @returns  address
        fn fee_to(self: @ContractState) -> ContractAddress {
            self._fee_to.read()
        }

        // @notice Get fee to setter address
        // @returns  address
        fn fee_to_setter(self: @ContractState) -> ContractAddress {
            self._fee_to_setter.read()
        }

        // @notice Get pair contract address given tokenA and tokenB
        // @returns  address of pair
        fn get_pair(
            self: @ContractState, tokenA: ContractAddress, tokenB: ContractAddress
        ) -> ContractAddress {
            let sorted_tokens = self.sort_tokens(tokenA, tokenB);
            let pair = self._pair.read(sorted_tokens);
            assert(pair.is_non_zero(), 'StarkDefi: PAIR_NOT_FOUND');
            pair
        }

        // @notice Get all pairs
        // @returns  pair_counts (length of all the pairs) and pairs (addresses of all pairs addresses)
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

        // @notice Get total number of pairs
        // @returns  pair_counts
        #[view]
        fn all_pairs_length(self: @ContractState) -> u32 {
            self._all_pairs_length.read()
        }

        // @notice Get class hash for pair contract
        fn class_hash_for_pair_contract(self: @ContractState) -> ClassHash {
            self._class_hash_for_pair_contract.read()
        }


        // @notice Create pair with `tokenA` and `tokenB` if it does not exist.
        // @param tokenA ContractAddress of tokenA
        // @param tokenB ContractAddress of tokenB
        // @return pair ContractAddress of the new pair
        fn create_pair(
            ref self: ContractState, tokenA: ContractAddress, tokenB: ContractAddress
        ) -> ContractAddress {
            assert(tokenA.is_non_zero() & tokenB.is_non_zero(), 'invalid token address');
            assert(tokenA != tokenB, 'identical addresses');

            let found_pair = self._pair.read((tokenA, tokenB));
            assert(found_pair.is_zero(), 'pair exists');

            let (token0, token1) = self.sort_tokens(tokenA, tokenB);
            let pair_class_hash = self._class_hash_for_pair_contract.read();

            let mut pair_constructor_calldata = ArrayTrait::new();
            pair_constructor_calldata.append(contract_address_to_felt252(token0));
            pair_constructor_calldata.append(contract_address_to_felt252(token1));

            let address_salt = pedersen(
                contract_address_to_felt252(token0), contract_address_to_felt252(token1)
            );

            let (pair, _) = deploy_syscall(
                pair_class_hash, address_salt, pair_constructor_calldata.span(), false
            )
                .unwrap_syscall(); // deploy_syscall never panics

            self._pair.write((token0, token1), pair);
            let pair_count = self._all_pairs_length.read();
            self._all_pairs.write(pair_count, pair);
            self._all_pairs_length.write(pair_count + 1);

            self
                .emit(
                    PairCreated { tokenA: token0, tokenB: token1, pair, pair_count: pair_count + 1 }
                );

            pair
        }

        // @notice Set fee to address
        // @param  fee_to_address ContractAddress of fee_to

        fn set_fee_to(ref self: ContractState, fee_to_address: ContractAddress) {
            let caller = get_caller_address();
            let allowed_setter = self._fee_to_setter.read();
            assert(caller == allowed_setter, 'not allowed');
            self._fee_to.write(fee_to_address);
        }

        // @notice Set fee to setter address
        // @param  fee_to_setter_address ContractAddress of fee_to_setter

        fn set_fee_to_setter(ref self: ContractState, fee_to_setter_address: ContractAddress) {
            let caller = get_caller_address();
            let allowed_setter = self._fee_to_setter.read();
            assert(caller == allowed_setter, 'not allowed');
            assert(fee_to_setter_address.is_non_zero(), 'invalid fee to setter');
            self._fee_to_setter.write(fee_to_setter_address);
        }
    }


    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        // @notice Sort tokens by address
        // @param tokenA ContractAddress of tokenA
        // @param tokenB ContractAddress of tokenB
        // @return (token0, token1)
        fn sort_tokens(
            self: @ContractState, tokenA: ContractAddress, tokenB: ContractAddress
        ) -> (ContractAddress, ContractAddress) {
            assert(tokenA != tokenB, 'identical addresses');
            let lhs_token: u256 = contract_address_to_felt252(tokenA).into();
            let rhs_token: u256 = contract_address_to_felt252(tokenB).into();
            let (token0, token1) = if lhs_token < rhs_token {
                (tokenA, tokenB)
            } else {
                (tokenB, tokenA)
            };
            assert(token0.is_non_zero(), 'invalid token0');
            (token0, token1)
        }
    }
}

