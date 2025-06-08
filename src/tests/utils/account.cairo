use array::ArrayTrait;
use option::OptionTrait;
use starkdefi::tests::helper_account::{Account, AccountABIDispatcher, TRANSACTION_VERSION};
use starkdefi::tests::utils::functions::deploy;
use starknet::testing;


//
// Constants
//

const PUBLIC_KEY: felt252 = 0x333333;
const NEW_PUBKEY: felt252 = 0x789789;
const SALT: felt252 = 123;

#[derive(Drop)]
struct SignedTransactionData {
    private_key: felt252,
    public_key: felt252,
    transaction_hash: felt252,
    r: felt252,
    s: felt252,
}
use starknet::ClassHash;
use traits::TryInto;

fn CLASS_HASH() -> ClassHash {
    Account::TEST_CLASS_HASH.try_into().unwrap()
}

fn SIGNED_TX_DATA() -> SignedTransactionData {
    SignedTransactionData {
        private_key: 1234,
        public_key: 883045738439352841478194533192765345509759306772397516907181243450667673002,
        transaction_hash: 2717105892474786771566982177444710571376803476229898722748888396642649184538,
        r: 3068558690657879390136740086327753007413919701043650133111397282816679110801,
        s: 3355728545224320878895493649495491771252432631648740019139167265522817576501,
    }
}

fn setup_account() -> AccountABIDispatcher {
    testing::set_version(TRANSACTION_VERSION);
    let data = Option::Some(@SIGNED_TX_DATA());
    let mut calldata = array![];
    if data.is_some() {
        let data = data.unwrap();
        testing::set_signature(array![*data.r, *data.s].span());
        testing::set_transaction_hash(*data.transaction_hash);

        calldata.append(*data.public_key);
    } else {
        calldata.append(PUBLIC_KEY);
    }
    let address = deploy(CLASS_HASH(), calldata);
    AccountABIDispatcher { contract_address: address }
}
