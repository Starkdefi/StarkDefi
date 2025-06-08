mod dex;
mod utils;
mod token {
    mod erc20 {
        mod erc20;
        mod interface;
        use erc20::ERC20;
        use interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    }
}


#[cfg(test)]
mod tests {
    mod factory {
        mod test_factory;
        use test_factory::{deploy_factory, setup as factory_setup};
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
        use account::{Account, QUERY_VERSION, TRANSACTION_VERSION};
        use interface::{
            AccountABIDispatcher, AccountABIDispatcherTrait, AccountCamelABIDispatcher,
            AccountCamelABIDispatcherTrait,
        };
    }

    mod utils {
        mod account;
        mod constants;
        mod functions;
        use functions::{deploy_erc20, token_at};
    }
}
