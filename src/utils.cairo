mod PartialOrdContractAddress;
mod array_ext;

use PartialOrdContractAddress::ContractAddressPartialOrd;
use array_ext::ArrayTraitExt;

fn pow(base: u128, mut exp: u128) -> u128 {
    if exp == 0 {
        1
    } else {
        base * pow(base, exp - 1)
    }
}