%lang starknet

@contract_interface
namespace IStarkDFactory:
    func fee_to() -> (address : felt):
    end

    func fee_to_setter() -> (address : felt):
    end

    func class_hash_for_pair_contract() -> (class_hash : felt):
    end

    func get_pair(token0 : felt, token1 : felt) -> (pair : felt):
    end

    func all_pairs() -> (pairs_len : felt, pairs : felt*):
    end

    func all_pairs_length() -> (len : felt):
    end

    func create_pair(token0 : felt, token1 : felt) -> (pair : felt):
    end

    func set_fee_to(fee_to_address : felt):
    end

    func set_fee_to_setter(fee_to_setter_address : felt):
    end
end
