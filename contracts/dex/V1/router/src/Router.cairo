// @title StarkDefi Router Contract
// @author StarkDefi Labs
// @license MIT
// @description Based on UniswapV2 Router Contract

#[contract]
mod StarkDRouter {
    use array::ArrayTrait;
    use zeroable::Zeroable;
    use option::OptionTrait;
    use starknet::ContractAddress;
    use starkDefi::utils::ContractAddressPartialOrd;

    // 
    // Internals
    //

    fn _sort_tokens(
        tokenA: ContractAddress, tokenB: ContractAddress
    ) -> (ContractAddress, ContractAddress) {
        assert(tokenA != tokenB, 'identical addresses');
        let (token0, token1) = if tokenA < tokenB {
            (tokenA, tokenB)
        } else {
            (tokenB, tokenA)
        };
        assert(token0.is_non_zero(), 'invalid token0');
        (token0, token1)
    }
}
