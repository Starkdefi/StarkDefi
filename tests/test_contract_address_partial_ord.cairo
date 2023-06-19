use starknet::ContractAddress;
use starknet::contract_address_const;
use starkDefi::utils::ContractAddressPartialOrd;

#[test]
fn test_return_is_le() {
    let contract_address1: ContractAddress =
        contract_address_const::<0x695874cd8feed014ebe379df39aa0dcef861ff495cc5465e84927377fa8e7e6>();
    let contract_address2: ContractAddress =
        contract_address_const::<0x05ee939756c1a60b029c594da00e637bf5923bf04a86ff163e877e899c0840eb>();

    assert(contract_address2 <= contract_address1, 'le');
}

#[test]
fn test_return_is_ge() {
    let contract_address1: ContractAddress =
        contract_address_const::<0x695874cd8feed014ebe379df39aa0dcef861ff495cc5465e84927377fa8e7e6>();
    let contract_address2: ContractAddress =
        contract_address_const::<0x05ee939756c1a60b029c594da00e637bf5923bf04a86ff163e877e899c0840eb>();

    assert(contract_address1 >= contract_address2, 'ge');
}

#[test]
fn test_return_is_lt() {
    let contract_address1: ContractAddress =
        contract_address_const::<0x695874cd8feed014ebe379df39aa0dcef861ff495cc5465e84927377fa8e7e6>();
    let contract_address2: ContractAddress =
        contract_address_const::<0x05ee939756c1a60b029c594da00e637bf5923bf04a86ff163e877e899c0840eb>();

    assert(contract_address2 < contract_address1, 'lt');
}
#[test]
fn test_return_is_gt() {
    let contract_address1: ContractAddress =
        contract_address_const::<0x695874cd8feed014ebe379df39aa0dcef861ff495cc5465e84927377fa8e7e6>();
    let contract_address2: ContractAddress =
        contract_address_const::<0x05ee939756c1a60b029c594da00e637bf5923bf04a86ff163e877e899c0840eb>();

    assert(contract_address1 > contract_address2, 'gt');
}

