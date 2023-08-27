use starknet::ContractAddress;
use starknet::ClassHash;
use starknet::contract_address_const;
use starkDefi::dex::v1::pair::StarkDPair;
use option::OptionTrait;
use traits::TryInto;

fn PAIR_CLASS_HASH() -> ClassHash {
    StarkDPair::TEST_CLASS_HASH.try_into().unwrap()
}

fn ADDRESS_ZERO() -> ContractAddress {
    contract_address_const::<0>()
}

fn ADDRESS_ONE() -> ContractAddress {
    contract_address_const::<1>()
}

fn ADDRESS_TWO() -> ContractAddress {
    contract_address_const::<2>()
}

fn ADDRESS_THREE() -> ContractAddress {
    contract_address_const::<3>()
}

fn OWNER() -> ContractAddress {
    contract_address_const::<'OWNER'>()
}

fn CALLER() -> ContractAddress {
    contract_address_const::<'CALLER'>()
}

fn SPENDER() -> ContractAddress {
    contract_address_const::<'SPENDER'>()
}

fn RECIPIENT() -> ContractAddress {
    contract_address_const::<'RECIPIENT'>()
}

fn FEE_TO_SETTER() -> ContractAddress {
    contract_address_const::<'FEE_TO_SETTER'>()
}

fn FEE_TO() -> ContractAddress {
    contract_address_const::<'FEE_TO'>()
}
