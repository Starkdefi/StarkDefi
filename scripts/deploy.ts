import { starknet } from "hardhat";
import * as dotenv from "dotenv";
import {
  deployFactory,
  deployPair,
  deployRouter,
  getAccount,
  TIMEOUT,
} from "./utils";

dotenv.config();

const FEE_TO_SETTER = process.env.FEE_TO_SETTER;
const FEE_TO = process.env.FEE_TO;

async function main() {}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
