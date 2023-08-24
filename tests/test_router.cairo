use snforge_std::{declare, PreparedContract, deploy, PrintTrait};

use array::ArrayTrait;
use starknet::contract_address_const;
use result::ResultTrait;

#[test]
fn deploy_router() {
    let address_0 = contract_address_const::<0>();
    let factory = contract_address_const::<1>();

    let router_class_hash = declare('StarkDRouter');

    let mut callData = Default::default();
    Serde::serialize(@factory, ref callData);

    let prepared = PreparedContract {
        class_hash: router_class_hash, constructor_calldata: @callData
    };

    let factory = deploy(prepared).unwrap();
    factory.print();
// assert(factory != address_0, 'address 0');
}
