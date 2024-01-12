use starknet::ContractAddress;
use starknet::ClassHash;
use starknet::contract_address_const;
use starkdefi::dex::v1::pair::StarkDPair;
use starkdefi::dex::v1::pair::FeesVault;
use starkdefi::utils::{pow};

fn TOTAL_SUPPLY(total: u128) -> u256 {
    u256 { low: total * pow(10, 18), high: 0, }
}

fn PAIR_CLASS_HASH() -> ClassHash {
    StarkDPair::TEST_CLASS_HASH.try_into().unwrap()
}

fn PAIR_FEES_CLASS_HASH() -> ClassHash {
    FeesVault::TEST_CLASS_HASH.try_into().unwrap()
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

fn ADDRESS_FOUR() -> ContractAddress {
    contract_address_const::<4>()
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

fn TOKEN_0() -> ContractAddress {
    contract_address_const::<'token0'>()
}

fn TOKEN_1() -> ContractAddress {
    contract_address_const::<'token1'>()
}

fn FACTORY() -> ContractAddress {
    contract_address_const::<'factory'>()
}

fn PAIR() -> ContractAddress {
    contract_address_const::<'pair'>()
}

fn ROUTER() -> ContractAddress {
    contract_address_const::<'router'>()
}
