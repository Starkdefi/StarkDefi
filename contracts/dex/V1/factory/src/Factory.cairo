// @title StarkDefi Factory Contract
// @author StarkDefi Labs
// @license MIT
// @description Based on UniswapV2 Factory Contract

#[contract]
mod StarkDFactory {
    use array::ArrayTrait;
    use traits::PartialOrd;
    use starknet::ClassHash;
    use zeroable::Zeroable;
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use starknet::get_contract_address;
    use starknet::syscalls::deploy_syscall;
    use starknet::contract_address_to_felt252;
    use starkDefi::utils::ContractAddressPartialOrd; // implentation of PartialOrd for ContractAddress

    //
    // Events
    //

    #[event]
    fn PairCreated(
        tokenA: ContractAddress, tokenB: ContractAddress, pair: ContractAddress, pair_count: u32, 
    ) {}

    //
    // Storage
    // 

    struct Storage {
        _fee_to: ContractAddress,
        _fee_to_setter: ContractAddress,
        _pair: LegacyMap::<(ContractAddress, ContractAddress), ContractAddress>,
        _all_pairs: LegacyMap::<u32, ContractAddress>,
        _all_pairs_length: u32,
        _class_hash_for_pair_contract: ClassHash,
    }

    // 
    // Constructor
    // 

    #[constructor]
    fn constructor(fee_to_setter: ContractAddress, class_hash_pair_contract: ClassHash) {
        assert(fee_to_setter.is_non_zero(), 'invalid fee to setter');
        assert(class_hash_pair_contract.is_non_zero(), 'invalid classhash');

        _all_pairs_length::write(0);
        _class_hash_for_pair_contract::write(class_hash_pair_contract);
        _fee_to_setter::write(fee_to_setter);
    }

    //
    // Getters
    //

    // @notice Get pair contract address given tokenA and tokenB
    // @returns  address of pair
    #[view]
    fn get_pair(tokenA: ContractAddress, tokenB: ContractAddress) -> ContractAddress {
        let sorted_tokens = sort_tokens(tokenA, tokenB);
        let pair = _pair::read(sorted_tokens);
        assert(pair.is_non_zero(), 'StarkDefi: PAIR_NOT_FOUND');
        pair
    }

    // @notice Get all pairs
    // @returns  pair_counts (length of all the pairs) and pairs (addresses of all pairs addresses)
    #[view]
    fn all_pairs() -> (u32, Array::<ContractAddress>) {
        let pair_counts = _all_pairs_length::read();
        let mut pairs = ArrayTrait::<ContractAddress>::new();

        let mut index = 0;
        loop {
            if index == pair_counts {
                break true;
            }
            pairs.append(_all_pairs::read(index));
            index += 1;
        };

        (pair_counts, pairs)
    }

    // @notice Get total number of pairs
    // @returns  pair_counts
    #[view]
    fn all_pairs_length() -> u32 {
        _all_pairs_length::read()
    }

    // @notice Get fee to address
    // @returns  address
    #[view]
    fn fee_to() -> ContractAddress {
        _fee_to::read()
    }

    // @notice Get fee to setter address
    // @returns  address
    #[view]
    fn fee_to_setter() -> ContractAddress {
        _fee_to_setter::read()
    }

    // @notice Get class hash for pair contract
    // @returns  class hash
    #[view]
    fn class_hash_for_pair_contract() -> ClassHash {
        _class_hash_for_pair_contract::read()
    }
    //
    // Setters
    //

    // @notice Set fee to address
    // @param  fee_to_address ContractAddress of fee_to
    #[external]
    fn set_fee_to(fee_to_address: ContractAddress) {
        let caller = get_caller_address();
        let allowed_setter = fee_to_setter();
        assert(caller == allowed_setter, 'not allowed');
        _fee_to::write(fee_to_address);
    }

    // @notice Set fee to setter address
    // @param  fee_to_setter_address ContractAddress of fee_to_setter
    #[external]
    fn set_fee_to_setter(fee_to_setter_address: ContractAddress) {
        let caller = get_caller_address();
        let allowed_setter = fee_to_setter();
        assert(caller == allowed_setter, 'not allowed');
        assert(fee_to_setter_address.is_non_zero(), 'invalid fee to setter');
        _fee_to_setter::write(fee_to_setter_address);
    }

    // @notice Create pair with `tokenA` and `tokenB` if it does not exist.
    // @param tokenA ContractAddress of tokenA
    // @param tokenB ContractAddress of tokenB
    // @return pair ContractAddress of the new pair
    #[external]
    fn create_pair(tokenA: ContractAddress, tokenB: ContractAddress) -> ContractAddress {
        assert(tokenA.is_non_zero() & tokenB.is_non_zero(), 'invalid token address');
        assert(tokenA != tokenB, 'identical addresses');

        let found_pair = get_pair(tokenA, tokenB);
        assert(found_pair.is_zero(), 'pair exists');

        let (token0, token1) = sort_tokens(tokenA, tokenB);
        let pair_class_hash = _class_hash_for_pair_contract::read();
        let this_address = get_contract_address();

        let mut pair_constructor_calldata = ArrayTrait::new();
        pair_constructor_calldata.append(contract_address_to_felt252(token0));
        pair_constructor_calldata.append(contract_address_to_felt252(token1));
        pair_constructor_calldata.append(contract_address_to_felt252(this_address));

        let address_salt = pedersen(
            contract_address_to_felt252(token0), contract_address_to_felt252(token1)
        );

        let (pair, _) = deploy_syscall(
            pair_class_hash, address_salt, pair_constructor_calldata.span(), false
        )
            .unwrap_syscall(); // deploy_syscall never panics

        _pair::write((token0, token1), pair);
        let pair_count = _all_pairs_length::read();
        _all_pairs::write(pair_count, pair);
        _all_pairs_length::write(pair_count + 1);

        PairCreated(token0, token1, pair, pair_count + 1);

        pair
    }

    // 
    // libs
    //

    // @notice Sort tokens by address
    // @param tokenA ContractAddress of tokenA
    // @param tokenB ContractAddress of tokenB
    // @return (token0, token1)
    fn sort_tokens(
        tokenA: ContractAddress, tokenB: ContractAddress
    ) -> (ContractAddress, ContractAddress) {
        assert(tokenA != tokenB, 'identical addresses');
        let mut token0: ContractAddress  = Zeroable::zero();
        let mut token1: ContractAddress = Zeroable::zero();

        if tokenA < tokenB {
            token0 = tokenA;
            token1 = tokenB;
        } else {
            token0 = tokenB;
            token1 = tokenA;
        }
        assert(token0.is_non_zero(), 'invalid token0');
        (token0, token1)
    }
}

