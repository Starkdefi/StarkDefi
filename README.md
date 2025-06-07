# StarkDefi

Welcome to the official contract repository for StarkDefi, a decentralized finance (DeFi) project built on the StarkNet network. This repository houses the source code for the smart contracts that power the StarkDefi platform.

[![Run Test on PRs](https://github.com/Starkdefi/StarkDefi/actions/workflows/unit-test.yaml/badge.svg)](https://github.com/Starkdefi/StarkDefi/actions/workflows/unit-test.yaml)

## Repository Structure

The repository is structured into several directories, each with a specific purpose:

- [src](src/): This directory contains the Cairo source code for the StarkDefi contracts. The contracts are organized into modules such as [dex](src/dex.cairo) for decentralized exchange functionality, [token](src/token/erc20/erc20.cairo.cairo) for token-related contracts, and [utils](src/utils.cairo) for utility functions and contracts. The structure will evolve as the project expands.

- [tests](src/tests/): This directory houses Cairo code for testing the StarkDefi contracts.

## Key Components (WIP)

- [StarkDFactory](src/dex/v1/factory/factory.cairo): This factory contract is responsible for creating new trading pairs on the StarkDefi platform. You can find the factory contract's Interface [here](src/dex/v1/factory/interface.cairo).

- [StarkDPair](src/dex/v1/pair/Pair.cairo): This contract represents a liquidity pool for a pair of tokens. You can find the pair contract's source code [here](src/dex/v1/pair/interface.cairo).

- [FeeVault](src/dex/v1/pair/FeesVault.cairo): This contract handles fees generated from the pair reserves. You can find it [here](src/dex/v1/pair/interface.cairo).

- [StarkDRouter](src/dex/v1/router/router.cairo): This contract provides functions for adding and removing liquidity, as well as swapping tokens. You can find the router contract's source code [here](src/dex/v1/router/interface.cairo).

## Development

Scarb ([v2.11.4](https://github.com/software-mansion/scarb/releases/tag/v2.11.4)), a build toolchain and package manager for Cairo and Starknet ecosystems, is used for building and testing the StarkDefi contracts.

A Dockerfile is provided for building the StarkDefi contracts. As of 6th Sept 2023, the Dockerfile uses Scarb v2.11.4. You can use the Dockerfile to build the StarkDefi contracts without installing Scarb on your local machine.

To build the StarkDefi contracts using the Dockerfile, use the following command:

```bash
docker build -t starkdefi .
```

To run the tests, use the following command:

```bash
docker run starkdefi test
```

You can access the Scarb CLI with the following command:

```bash
docker run starkdefi scarb <command>
```

To install Scarb, follow the installation script provided in the Scarb documentation [1](https://docs.swmansion.com/scarb/download.html). Here is how you can install the latest stable release of Scarb:

```bash
curl --proto '=https' --tlsv1.2 -sSf https://docs.swmansion.com/scarb/install.sh | bash -s -- -v 2.11.4
```

This will install Scarb, the Cairo compiler, and the language server.

To build the StarkDefi contracts, use the following command:

```bash
scarb build
```

## Testing

GitHub Actions is used for continuous integration. The workflow is specified in the unit-test.yaml file and tests are run on every pull request.

To run the tests directly, use the following command:

```bash
scarb test
```

You can filter the tests using the `--filter` flag. For example, to run only tests with `pair` in the test name, use the following command:

```bash
scarb test --filter pair
```

## Deployment

StarkDefi uses [sncast](https://foundry-rs.github.io/starknet-foundry/starknet/index.html) to deploy the contracts. For more information on how to use sncast, visit the [sncast documentation](https://foundry-rs.github.io/starknet-foundry/starknet/index.html).

The deployment sequence is as follows:

- Declare the following contracts (order is not important):
  - `StarkDFactory`
  - `StarkDPair`
  - `FeeVault`
  - `StarkDRouter`

- After declaring the contracts, deploy the following 2 contracts in this order:
  - `StarkDFactory`
  - `StarkDRouter`

Note: Ensure to pass the correct arguments to both `StarkDFactory` and `StarkDRouter`. The `StarkDPair` and `FeeVault` contracts are deployed automatically whenever a new pair instance is created.

## Contributing

Contributions to the StarkDefi repository are welcome. Please read the [contributing guidelines](./CONTRIBUTING.md) before making a pull request.

## License

The StarkDefi contracts are released under the MIT License.
