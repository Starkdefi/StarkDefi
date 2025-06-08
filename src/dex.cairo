mod v1 {
    mod factory {
        mod factory;
        mod interface;
        use factory::StarkDFactory;
        use interface::{
            IStarkDFactoryABIDispatcher, IStarkDFactoryABIDispatcherTrait, IStarkDFactoryDispatcher,
            IStarkDFactoryDispatcherTrait,
        };
    }
    mod pair {
        mod Pair;
        mod interface;
        mod pairFeesVault;
        use Pair::StarkDPair;
        use interface::{IStarkDPairDispatcher, IStarkDPairDispatcherTrait};
        use pairFeesVault::FeesVault;
    }
    mod router {
        mod interface;
        mod router;
        use interface::{IStarkDRouterDispatcher, IStarkDRouterDispatcherTrait};
        use router::StarkDRouter;
    }
}
