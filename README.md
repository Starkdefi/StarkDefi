# StarkDefi

This is the official contract repository for StarkDefi, a decentralized finance (DeFi) project built on the StarkNet network. The repository contains the source code for the smart contracts that power the StarkDefi platform.

[![Run Test on PRs](https://github.com/Starkdefi/StarkDefi/actions/workflows/unit-test.yaml/badge.svg)](https://github.com/Starkdefi/StarkDefi/actions/workflows/unit-test.yaml)

## Repository Structure

The repository is organized into several directories, each serving a specific purpose:

- [src](src/): Contains the Cairo source code for the StarkDefi contracts. The contracts are organized into modules such as [dex](src/dex.cairo) for decentralized exchange functionality, [token](src/token.cairo) for token-related contracts, and [utils](src/utils.cairo) for utility functions and contracts. The structure will be expanded on as the project grows.

- [tests](src/tests/): Contains Cairo code for testing the StarkDefi contracts.

## Key Components (WIP)

- [StarkDFactory](src/dex/v1/factory/factory.cairo): This is the factory contract responsible for creating new trading pairs on the StarkDefi platform. The factory contract's Interface   can be found in [here](src/dex/v1/factory/interface.cairo).

- [StarkDPair](src/dex/v1/pair/pair.cairo)`: This contract represents a liquidity pool for a pair of tokens. The pair contract's source code can be found in [here](src/dex/v1/pair/interface.cairo).

- [StarkDRouter](src/dex/v1/router/router.cairo)`: This contract provides functions for adding and removing liquidity, as well as swapping tokens. The router contract's source code can be found in [here](src/dex/v1/router/interface.cairo).

## Development

The repository uses Scarb for building and testing the StarkDefi contracts. Scarb is a build toolchain and package manager for Cairo and Starknet ecosystems.

To install Scarb, you can use the installation script provided in the Scarb documentation [1](https://docs.swmansion.com/scarb/download.html). Here is how you can install the latest stable release of Scarb:

```bash
curl --proto '=https' --tlsv1.2 -sSf https://docs.swmansion.com/scarb/install.sh | sh
```

This will install Scarb as well as the Cairo compiler and the language server.

To build the StarkDefi contracts, run the following command:

```bash
scarb build
```

## Testing

The repository uses GitHub Actions for continuous integration. The workflow is specified in the unit-test.yaml file and it runs tests on every pull request.

To run the tests directly, run the following command:

```bash
scarb test
```

You can filter the tests by using the `--filter` flag. For example, to run only test with `pair` in the test name, you can run the following command:

```bash
scarb test --filter pair
```

## Contributing

Contributions to the StarkDefi repository are welcome. Please make sure to read the [contributing guidelines](./CONTRIBUTING.md) before making a pull request.
License

The StarkDefi contracts are released under the MIT License.
