use snforge_std::{declare, PreparedContract, deploy};


use array::ArrayTrait;
// use traits::TryInto;
// use option::OptionTrait;
use result::ResultTrait;
// use starknet::ContractAddress;
use starknet::contract_address_const;
use starkDefi::dex::v1::factory::{IStarkDFactoryDispatcher, IStarkDFactoryDispatcherTrait};
// use cheatcodes::RevertedTransactionTrait;
// use debug::PrintTrait;

// fn get_factory() -> (felt252, @felt252) {
//     let pair_class_hash = declare('pair').unwrap();
//     let fee_to_setter = 1;
//     let mut call_data = ArrayTrait::new();
//     call_data.append(fee_to_setter);
//     call_data.append(pair_class_hash);

//     let factory = deploy_contract('factory', @call_data).unwrap();
//     (factory, @pair_class_hash)
// }

// fn creat_pair(_factory: @felt252, pair_class_hash: @felt252, _tokens: Span<felt252>) {
//     let mut pair_constructor_calldata = ArrayTrait::new();
//     let tokens = _tokens.snapshot;
//     pair_constructor_calldata.append(*tokens[0]);
//     pair_constructor_calldata.append(*tokens[1]);

//     let address_salt = pedersen(*tokens[0], *tokens[1]);
//     // let calculated_pair_address = some_function(*pair_class_hash, address_salt, tokens, false);
//     // TODO: calculate pair address

//     match call(*_factory, 'create_pair', tokens) {
//         Result::Ok(x) => assert(true, 'result'),
//         Result::Err(x) => x.first().print()
//     };
// }

// #[test]
// fn test_storage() {
//     let (factory, pair_class_hash) = get_factory();
//     let fee_to = call(factory, 'fee_to', @ArrayTrait::new()).unwrap();
//     let fee_to_setter = call(factory, 'fee_to_setter', @ArrayTrait::new()).unwrap();
//     let fee_to_setter = call(factory, 'fee_to_setter', @ArrayTrait::new()).unwrap();
//     let all_pairs_length = call(factory, 'all_pairs_length', @ArrayTrait::new()).unwrap();
//     let pair_class = call(factory, 'class_hash_for_pair_contract', @ArrayTrait::new()).unwrap();

//     assert(*fee_to[0_u32] == 0, 'fee_to');
//     assert(*fee_to_setter[0_u32] == 1, 'fee_to_setter');
//     assert(*all_pairs_length[0_u32] == 0, 'all_pairs_length');
//     assert(*pair_class[0_u32] == *pair_class_hash, 'pair_class_hash');
// }

// #[test]
// fn test_create_pair() {
//     let mut TOKEN_ADDRESSES = ArrayTrait::<felt252>::new();
//     TOKEN_ADDRESSES.append(5);
//     TOKEN_ADDRESSES.append(6);

//     let (factory, pair_class_hash) = get_factory();

//     let pair = creat_pair(@factory, pair_class_hash, TOKEN_ADDRESSES.span());
// }

#[test]
fn call_and_invoke() {
    let pair_class_hash = declare('StarkDPair');
    let class_hash = declare('StarkDFactory');
    let mut callData = Default::default();
    let address = contract_address_const::<1>();
    Serde::serialize(@address, ref callData);
    Serde::serialize(@pair_class_hash, ref callData);

    let prepared = PreparedContract { class_hash: class_hash, constructor_calldata: @callData };

    let factory_address = deploy(prepared).unwrap();

    let factory = IStarkDFactoryDispatcher { contract_address: factory_address };

    let feeToSetter = factory.fee_to_setter();
    assert(feeToSetter == address, 'feeTo == address 1');
}
