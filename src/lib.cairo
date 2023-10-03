mod dex;
mod utils;
mod token {
    mod erc20 {
        mod erc20;
        mod interface;

        use erc20::ERC20;
        use interface::ERC20ABIDispatcher;
        use interface::ERC20ABIDispatcherTrait;
    }
}


#[cfg(test)]
mod tests {
    mod factory {
        mod test_factory;
        use test_factory::deploy_factory;
        use test_factory::setup as factory_setup;
    }
    mod pair {
        mod test_pair_shared;
        mod test_stable_pair;
        mod test_volatile_pair;
    }

    mod router {
        mod test_router;
    }

    mod helper_account {
        mod account;
        mod interface;
        mod introspection;

        use account::Account;
        use account::QUERY_VERSION;
        use account::TRANSACTION_VERSION;
        use interface::AccountABIDispatcher;
        use interface::AccountABIDispatcherTrait;
        use interface::AccountCamelABIDispatcher;
        use interface::AccountCamelABIDispatcherTrait;
    }

    mod utils {
        mod constants;
        mod functions;
        mod account;

        use functions::deploy_erc20;
        use functions::token_at;
    }
}
