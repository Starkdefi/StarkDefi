use snforge_std::{declare, PreparedContract, deploy, PrintTrait};

use array::ArrayTrait;
use starknet::contract_address_const;
use result::ResultTrait;

#[test]
fn deploy_pair() {
    let address_0 = contract_address_const::<0>();
    let token0 = contract_address_const::<1>();
    let token1 = contract_address_const::<2>();

    let pair_class_hash = declare('StarkDPair');
    let mut callData = Default::default();
    Serde::serialize(@token0, ref callData);
    Serde::serialize(@token1, ref callData);

    let prepared = PreparedContract {
        class_hash: pair_class_hash, constructor_calldata: @callData
    };

    let pair = deploy(prepared).unwrap();
    pair.print();
    // assert(pair != address_0, 'address 0');
}
