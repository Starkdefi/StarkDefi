// @title StarkDefi Pair fee's vault
// @author StarkDefi Labs
// @license MIT
// @notice This stores the fee's collected by bonded the StarkDefi Pair
// @notice Eliminates the need to modify curve for shares

use starknet::ContractAddress;

#[derive(Copy, Drop, Serde, starknet::Store)]
struct ProtocolFees {
    // protocol's token0 balance
    token0: u256,
    // protocol's token1 balance
    token1: u256,
    // timestamp of last protocol fee claim
    timestamp: u64
}

#[starknet::contract]
mod PairFees {
    use starkDefi::dex::v1::factory::{IStarkDFactoryDispatcherTrait, IStarkDFactoryDispatcher};
    use starkDefi::token::erc20::{ERC20ABIDispatcherTrait, ERC20ABIDispatcher};
    use starkDefi::dex::v1::pair::interface::IPairFees;
    use super::{ContractAddress, ProtocolFees};
    use starknet::{get_caller_address, get_block_timestamp};

    #[storage]
    struct Storage {
        pair: ContractAddress,
        token0: ContractAddress,
        token1: ContractAddress,
        factory: ContractAddress,
        protocol: ProtocolFees
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        token0: ContractAddress,
        token1: ContractAddress,
        factory: ContractAddress
    ) {
        self.pair.write(get_caller_address());
        self.token0.write(token0);
        self.token1.write(token1);
        self.factory.write(factory);

        self.protocol.write(ProtocolFees { token0: 0, token1: 0, timestamp: 0 });
    }

    #[external(v0)]
    impl PairFeesImpl of IPairFees<ContractState> {
        fn claim_lp_fees(
            ref self: ContractState, user: ContractAddress, amount0: u256, amount1: u256
        ) {
            assert(get_caller_address() == self.pair.read(), 'not authorized');
            if amount0 > 0 {
                ERC20ABIDispatcher { contract_address: self.token0.read() }.transfer(user, amount0);
            }
            if amount1 > 0 {
                ERC20ABIDispatcher { contract_address: self.token1.read() }.transfer(user, amount1);
            }

            PairFeesImpl::claim_protocol_fees(ref self);
        }

        fn get_protocol_fees(ref self: ContractState) -> (u256, u256) {
            let protocol = self.protocol.read();
            (protocol.token0, protocol.token1)
        }

        fn update_protocol_fees(ref self: ContractState, amount0: u256, amount1: u256) {
            assert(get_caller_address() == self.pair.read(), 'not authorized');

            let mut protocol = self.protocol.read();
            protocol.token0 += amount0;
            protocol.token1 += amount1;
            protocol.timestamp = get_block_timestamp();
            self.protocol.write(protocol);
        }

        fn claim_protocol_fees(ref self: ContractState) {
            let factory = IStarkDFactoryDispatcher { contract_address: self.factory.read() };
            let fee_handler = factory.fee_handler();
            let caller = get_caller_address();
            assert(caller == fee_handler || caller == self.pair.read(), 'not authorized');

            let protocol = self.protocol.read();
            let (token0, token1) = (protocol.token0, protocol.token1);

            if (token0 > 0 || token1 > 0) {
                let fee_to = factory.fee_to();

                self
                    .protocol
                    .write(ProtocolFees { token0: 0, token1: 0, timestamp: get_block_timestamp() });

                if token0 > 0 {
                    ERC20ABIDispatcher {
                        contract_address: self.token0.read()
                    }.transfer(fee_to, protocol.token0);
                }
                if token1 > 0 {
                    ERC20ABIDispatcher {
                        contract_address: self.token1.read()
                    }.transfer(fee_to, protocol.token1);
                }
            }
        }
    }
}
