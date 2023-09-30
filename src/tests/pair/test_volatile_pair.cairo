use array::ArrayTrait;
use starknet::account::Call;
use starknet::ContractAddress;
use starknet::get_caller_address;
use starknet::contract_address_const;
use starkDefi::tests::pair::test_pair_shared as Shared;
use Shared::{
    StarkDPair, StarkDPairImpl, STATE, IStarkDPairDispatcher, IStarkDPairDispatcherTrait,
    ERC20ABIDispatcher, ERC20ABIDispatcherTrait, AccountABIDispatcher, AccountABIDispatcherTrait,
    deploy_pair, token_at, transfer_erc20, add_initial_liquidity, add_more_liquidity, swap,
    remove_liqudity, with_decimals, deploy_erc20
};
use starkDefi::tests::utils::constants;
use starknet::testing;
use debug::PrintTrait;

