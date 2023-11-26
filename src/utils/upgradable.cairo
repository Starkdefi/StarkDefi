/// OpenZeppelin upgradeable contract.
use starknet::ClassHash;

#[starknet::interface]
trait IUpgradable<TState> {
    fn upgrade(ref self: TState, new_class_hash: ClassHash);
}

#[starknet::contract]
mod Upgradable {
    use starknet::ClassHash;
    use core::zeroable::Zeroable;


    #[storage]
    struct Storage {}

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Upgraded: Upgraded
    }

    #[derive(Drop, starknet::Event)]
    struct Upgraded {
        class_hash: ClassHash
    }

    #[generate_trait]
    impl InternalImpl of InternalState {
        fn _upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            assert(new_class_hash.is_non_zero(), 'Class hash cannot be zero');
            starknet::replace_class_syscall(new_class_hash).unwrap_syscall();
            self.emit(Upgraded { class_hash: new_class_hash });
        }
    }
}
