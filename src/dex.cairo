mod v1 {
    mod factory {
        mod factory;
        mod interface;

        use factory::StarkDFactory;
        use interface::IStarkDFactoryDispatcher;
        use interface::IStarkDFactoryDispatcherTrait;
        use interface::IStarkDFactoryABIDispatcher;
        use interface::IStarkDFactoryABIDispatcherTrait;
    }
    mod pair {
        mod Pair;
        mod pairFeesVault;
        mod interface;

        use Pair::StarkDPair;
        use pairFeesVault::FeesVault;
        use interface::IStarkDPairDispatcher;
        use interface::IStarkDPairDispatcherTrait;
    }
    mod router {
        mod router;
        mod interface;

        use router::StarkDRouter;
        use interface::IStarkDRouterDispatcher;
        use interface::IStarkDRouterDispatcherTrait;
    }
}
