# StarkDefi

This official contract repository for StarkDefi. This project uses hardhat (TypeScript) alongside the **starknet-hardhat-plugin** to run compile, run, deploy and test cairo/starknet contracts. 

Try running some of the following tasks:

```shell
npx hardhat check                         Check whatever you need
npx hardhat clean                         Clears the cache and deletes all artifacts
npx hardhat compile                       Compiles the entire project, building all artifacts
npx hardhat console                       Opens a hardhat console
npx hardhat flatten                       Flattens and prints contracts and their dependencies
npx hardhat help                          Prints this message
npx hardhat node                          Starts a JSON-RPC server on top of Hardhat Network
npx hardhat run                           Runs a user-defined script after compiling the project
npx hardhat starknet-call                 Invokes a function on a contract in the provided address.
npx hardhat starknet-compile              Compiles Starknet contracts
npx hardhat starknet-deploy               Deploys Starknet contracts which have been compiled.
npx hardhat starknet-deploy-account       Deploys a new account according to the parameters.
npx hardhat starknet-estimate-fee         Estimates the gas fee of a function execution.
npx hardhat starknet-invoke               Invokes a function on a contract in the provided address.
npx hardhat starknet-verify               Verifies a contract on a Starknet network.
npx hardhat test                          Runs mocha tests
```

# FYI

Notice that this plugin relies on `--starknet-network` (or `STARKNET_NETWORK` environment variable) and not on Hardhat's `--network`. So if you define

```javascript
module.exports = {
    networks: {
        myNetwork: {
            url: "http://127.0.0.1:5050"
        }
    }
};
```

You can use it by calling `npx hardhat starknet-deploy --starknet-network myNetwork`.

The Alpha networks and integrated Devnet are available by default, you don't need to define them in the config file; just pass:

-   `--starknet-network alpha` or `--starknet-network alpha-goerli` for Alpha Testnet (on Goerli)
-   `--starknet-network alpha-mainnet` for Alpha Mainnet
-   `--starknet-network integrated-devnet` for integrated Devnet

By default the integrated Devnet, it will spawn Devnet using its Docker image and listening on http://127.0.0.1:5050. **To use this, you must have Docker installed on your machine**.