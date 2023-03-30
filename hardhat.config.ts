import * as dotenv from "dotenv";
import "@shardlabs/starknet-hardhat-plugin";

dotenv.config();

module.exports = {
  starknet: {
    venv: 'active',
    network: process.env.STARKNET_NETWORK || "testnet1",
  },
  networks: {
    testnet1: {
      url: "https://starknet-goerli.infura.io/v3/cbb22bf12189415fa681e88cfba15829",
    },
    mainnet: {
      url: "https://starknet-mainnet.infura.io/v3/cbb22bf12189415fa681e88cfba15829",
    }
  },
  mocha: {
    starknetNetwork: process.env.STARKNET_NETWORK || "integrated-devnet",
  },
};
