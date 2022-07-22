import * as dotenv from "dotenv";
import "@shardlabs/starknet-hardhat-plugin";

dotenv.config();

module.exports = {
  starknet: {
    network: process.env.STARKNET_NETWORK || "integrated-devnet",
  },
  mocha: {
    starknetNetwork: process.env.STARKNET_NETWORK || "integrated-devnet",
  },
};
