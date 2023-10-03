mod v1 {
    mod factory {
        mod factory;
        mod interface;

        use factory::StarkDFactory;
        use interface::IStarkDFactoryDispatcher;
        use interface::IStarkDFactoryDispatcherTrait;
    }
    mod pair {
        mod Pair;
        mod pairFees;
        mod interface;

        use Pair::StarkDPair;
        use pairFees::PairFees;
        use interface::IStarkDPairDispatcher;
        use interface::IStarkDPairDispatcherTrait;
    }
    mod router {
        mod utils;
        mod router;
        mod interface;

        use router::StarkDRouter;
        use interface::IStarkDRouterDispatcher;
        use interface::IStarkDRouterDispatcherTrait;
        use utils::call_contract_with_selector_fallback;
    }
}
