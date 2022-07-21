import { FeeEstimation } from "@shardlabs/starknet-hardhat-plugin/dist/src/starknet-types";
import { starknet } from "hardhat";
import { Account, StarknetContract } from "hardhat/types/runtime";

export const TIMEOUT = 900_000;
export const MINIMUM_LIQUIDITY = 1000;
export const BURN_ADDRESS = 1;

export async function deployToken(
  deployerAccount: Account,
  name: string,
  symbol: string
): Promise<StarknetContract> {
  const tokenContractFactory = await starknet.getContractFactory(
    "contracts/token/ERC20.cairo"
  );

  const token0Contract = await tokenContractFactory.deploy(
    {
      name: starknet.shortStringToBigInt(name),
      symbol: starknet.shortStringToBigInt(symbol),
      decimals: 18,
      recipient: deployerAccount.address,
    },
    { salt: "0x42" }
  );
  console.log(name, "deployed at", token0Contract.address);
  return token0Contract;
}

export async function deployFactory(
  feeToAddress: string
): Promise<StarknetContract> {
  const pairContractFactory = await starknet.getContractFactory(
    "contracts/dex/Pair.cairo"
  );
  const declaredPairClass = await pairContractFactory.declare();
  const factory = await starknet.getContractFactory(
    "contracts/dex/Factory.cairo"
  );
  const factoryContract = await factory.deploy(
    {
      pair_contract_class_hash: declaredPairClass,
      fee_to_setter: feeToAddress,
    },
    { salt: "0x42" }
  );
  console.log("Factory deployed at", factoryContract.address);
  return factoryContract;
}

export async function deployRouter(
  factoryAddress: string
): Promise<StarknetContract> {
  const routerContractFactory = await starknet.getContractFactory(
    "contracts/dex/Router.cairo"
  );
  const routerContract = await routerContractFactory.deploy(
    { factory: factoryAddress },
    { salt: "0x42" }
  );
  console.log("Router deployed at", routerContract.address);
  return routerContract;
}

export async function deployPair(
  deployerAccount: Account,
  token0Address: string,
  token1Address: string,
  routerContract: StarknetContract,
  factoryContract: StarknetContract
): Promise<StarknetContract> {
  const pairFactory = await starknet.getContractFactory(
    "contracts/dex/Pair.cairo"
  );

  const executionInfo = await deployerAccount.call(
    routerContract,
    "sort_tokens",
    {
      tokenA: token0Address,
      tokenB: token1Address,
    }
  );

  const pair = await deployerAccount.invoke(factoryContract, "create_pair", {
    tokenA: executionInfo.token0,
    tokenB: executionInfo.token1,
  });
  console.log("Pair deployed at", pair);

  // Does not deploy to network immediately after create_pair call so best to get pair from factory and rebuild contract
  // using result from get_pair. That way, 100% sure that the pair is deployed and ready to use.
  const res0 = await deployerAccount.call(factoryContract, "get_pair", {
    token0: executionInfo.token0,
    token1: executionInfo.token1,
  });
  return pairFactory.getContractAt(res0.pair);
}

export async function estimateFee(
  account: Account,
  contract: StarknetContract,
  functionName: string,
  params: Object
): Promise<FeeEstimation> {
  const estimatedFee = await account.estimateFee(
    contract,
    functionName,
    params
  );
  console.log("Estimated fee to create pair", estimatedFee);
  return estimatedFee;
}
