// @title StarkDefi Factory Contract
// @author StarkDefi Labs
// @license MIT
// @description Based on UniswapV2 Factory Contract

#[contract]
mod Factory {
    use array::ArrayTrait;
    use starknet::ClassHash;
    use zeroable::Zeroable;
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use starknet::contract_address_const;
    use starknet::syscalls::deploy_syscall;


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
        assert(!fee_to_setter.is_zero(), 'invalid fee to setter');
        assert(!class_hash_pair_contract.is_zero(), 'invalid classhash');

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
        let pair = _pair::read((tokenA, tokenB));
        assert(!pair.is_zero(), 'StarkDefi: PAIR_NOT_FOUND');
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
        assert(!fee_to_setter_address.is_zero(), 'invalid fee to setter');
        _fee_to_setter::write(fee_to_setter_address);
    }

    // @notice Create pair with `tokenA` and `tokenB` if it does not exist.
    // @param tokenA ContractAddress of tokenA
    // @param tokenB ContractAddress of tokenB
    // @return pair ContractAddress of the new pair
    #[external]
    fn create_pair(tokenA: ContractAddress, tokenB: ContractAddress) -> ContractAddress {
        // TODO: sort tokens, create pair using pair class_hash
        contract_address_const::<0>()
    }
}

