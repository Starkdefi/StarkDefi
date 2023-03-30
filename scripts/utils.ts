import { FeeEstimation } from "@shardlabs/starknet-hardhat-plugin/dist/src/starknet-types";
import { BigNumber, ethers } from "ethers";
import { starknet } from "hardhat";
import { Account, StarknetContract, StringMap } from "hardhat/types/runtime";
import * as dotenv from "dotenv";
import { AccountImplementationType } from "@shardlabs/starknet-hardhat-plugin/dist/src/types";

dotenv.config();

const DEFAULT_SALT = process.env.DEPLOYMENT_SALT ?? "0x42";

export const TIMEOUT = 900_000;
export const MINIMUM_LIQUIDITY = 1000;
export const BURN_ADDRESS = 1;
export const MAX_INT = BigInt("340282366920938463463374607431768211455");
export const WETH = {
  address: "insert_weth_address_here",
};
export const USDT = {
  address: "insert_usdt_address_here",
};
export const USDC = {
  address: "insert_usdc_address_here",
};
export const DAI = {
  address: "insert_dai_address_here",
};

export async function getAccount(): Promise<Account> {
  if (!process.env.DEPLOYER_PKEY || !process.env.DEPLOYER_ADDRESS) {
    throw new Error("Invalid DEPLOYER_ADDRESS or DEPLOYER_PKEY");
  }

  if (!process.env.DEPLOYER_ACCOUNT_TYPE) {
    throw new Error("DEPLOYER_ACCOUNT_TYPE not set");
  }

  let deployerAccount: Account;
  const accountType = process.env
    .DEPLOYER_ACCOUNT_TYPE as AccountImplementationType;
  try {
    deployerAccount = await starknet.getAccountFromAddress(
      process.env.DEPLOYER_ADDRESS,
      process.env.DEPLOYER_PKEY,
      accountType
    );
  } catch {
    deployerAccount = await starknet.deployAccount(accountType, {
      privateKey: process.env.DEPLOYER_PKEY,
    });
  }

  return deployerAccount;
}

export type CairoUint = {
  low: bigint | number | BigNumber;
  high: bigint;
};

export function uint(x: bigint | number | BigNumber): CairoUint {
  return { low: x, high: 0n };
}

export function uintToBigInt(x: any): bigint {
  return x.low;
}

export function feltToAddress(x: bigint): string {
  return BigNumber.from(x).toHexString();
}

export function addressToFelt(x: string): bigint {
  return BigInt(x);
}

export function bigintToHex(x: bigint | BigInt): string {
  return BigNumber.from(x).toHexString();
}

export async function deployToken(
  deployerAccount: Account,
  name: string,
  symbol: string
): Promise<StarknetContract> {
  const tokenContractFactory = await starknet.getContractFactory(
    "contracts/token/ERC20.cairo"
  );

  const tokenContract = await tokenContractFactory.deploy(
    {
      name: starknet.shortStringToBigInt(name),
      symbol: starknet.shortStringToBigInt(symbol),
      decimals: 18,
      recipient: deployerAccount.address,
    },
    { salt: DEFAULT_SALT }
  );
  console.log(name, "deployed at", tokenContract.address);
  return tokenContract;
}

export async function deployFactory(
  feeToAddress: string
): Promise<StarknetContract> {
  const pairContractFactory = await starknet.getContractFactory(
    "contracts/dex/StarkDPair.cairo"
  );
  const declaredPairClass = await pairContractFactory.declare();
  const factory = await starknet.getContractFactory(
    "contracts/dex/StarkDFactory.cairo"
  );
  const factoryContract = await factory.deploy(
    {
      class_hash_pair_contract: declaredPairClass,
      fee_to_setter: feeToAddress,
    },
    { salt: DEFAULT_SALT }
  );
  console.log("Factory deployed at", factoryContract.address);
  return factoryContract;
}

export async function deployRouter(
  factoryAddress: string
): Promise<StarknetContract> {
  const routerContractFactory = await starknet.getContractFactory(
    "contracts/dex/StarkDRouter.cairo"
  );
  const routerContract = await routerContractFactory.deploy(
    { factory: factoryAddress },
    { salt: DEFAULT_SALT }
  );
  console.log("Router deployed at", routerContract.address);
  return routerContract;
}

export async function deployPair(
  deployerAccount: Account,
  token0Address: string,
  token1Address: string,
  factoryContract: StarknetContract
): Promise<StarknetContract> {
  const pairFactory = await starknet.getContractFactory(
    "contracts/dex/StarkDPair.cairo"
  );

  await deployerAccount.invoke(factoryContract, "create_pair", {
    tokenA: addressToFelt(token0Address),
    tokenB: addressToFelt(token1Address),
  });

  // Does not deploy to network immediately after create_pair call so best to get pair from factory and rebuild contract
  // using result from get_pair. That way, 100% sure that the pair is deployed and ready to use.
  const res0 = await factoryContract.call("get_pair", {
    tokenA: addressToFelt(token0Address),
    tokenB: addressToFelt(token1Address),
  });

  console.log("Pair deployed at", feltToAddress(res0.pair));
  return pairFactory.getContractAt(res0.pair);
}

export async function deployRouterAggregator(
  factoryAddress: string
): Promise<StarknetContract> {
  const routerAggregatorContractFactory = await starknet.getContractFactory(
    "contracts/dex/StarkDRouterAggregator.cairo"
  );
  const routerAggregatorContract = await routerAggregatorContractFactory.deploy(
    { factory: factoryAddress },
    { salt: DEFAULT_SALT }
  );
  console.log(
    "Router Aggregator deployed at",
    routerAggregatorContract.address
  );
  return routerAggregatorContract;
}

export async function deployPathFinder(
  routerAggregatorAddress: string,
  usdtAddress: string,
  usdcAddress: string,
  daiAddress: string,
  wethAddress: string
): Promise<StarknetContract> {
  const pathFinderContractFactory = await starknet.getContractFactory(
    "contracts/dex/StarkDPathFinder.cairo"
  );
  const pathFinderContract = await pathFinderContractFactory.deploy(
    {
      routerAggregator: routerAggregatorAddress,
      usdtAddress,
      usdcAddress,
      daiAddress,
      wethAddress,
    },
    { salt: DEFAULT_SALT }
  );
  console.log("Path Finder deployed at", pathFinderContract.address);
  return pathFinderContract;
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

export async function addLiquidity(
  caller: Account,
  routerContract: StarknetContract,
  token0Contract: StarknetContract,
  token1Contract: StarknetContract,
  amount0: number,
  amount1: number,
  recipient: string,
  deadline: number
) {
  const token0Decimals = await tokenDecimals(token0Contract);
  const token1Decimals = await tokenDecimals(token1Contract);

  const token0Amount = ethers.utils.parseUnits(
    amount0.toString(),
    token0Decimals
  );
  const token1Amount = ethers.utils.parseUnits(
    amount1.toString(),
    token1Decimals
  );

  const txHash = await caller.invoke(routerContract, "add_liquidity", {
    tokenA: token0Contract.address,
    tokenB: token1Contract.address,
    amountADesired: uint(token0Amount),
    amountBDesired: uint(token1Amount),
    amountAMin: uint(0n),
    amountBMin: uint(0n),
    to: recipient,
    deadline: BigInt(deadline),
  });

  console.log("Liquidity added:", txHash);
  return txHash;
}

export async function removeLiquidity(
  caller: Account,
  routerContract: StarknetContract,
  token0Contract: StarknetContract,
  token1Contract: StarknetContract,
  liquidity: number | bigint,
  recipient: string,
  deadline: number
) {
  const txHash = await caller.invoke(routerContract, "remove_liquidity", {
    tokenA: token0Contract.address,
    tokenB: token1Contract.address,
    liquidity: uint(liquidity),
    amountAMin: uint(0n),
    amountBMin: uint(0n),
    to: recipient,
    deadline: BigInt(deadline),
  });

  console.log("Liquidity removed:", txHash);
  return txHash;
}

export async function mintTokens(
  caller: Account,
  tokenContract: StarknetContract,
  amount: number | bigint,
  recipient: string
) {
  const tknDecimals = await tokenDecimals(tokenContract);

  const tokenAmount = ethers.utils.parseUnits(amount.toString(), tknDecimals);

  const txHash = await caller.invoke(tokenContract, "mint", {
    recipient: recipient,
    amount: uint(tokenAmount),
  });

  console.log("Minted", amount, "tokens to", recipient, "\nTx Hash:", txHash);
  return txHash;
}

export async function tokenDecimals(tokenContract: StarknetContract) {
  const { decimals } = await tokenContract.call("decimals");
  return decimals;
}

export async function approve(
  caller: Account,
  tokenContract: StarknetContract,
  amount: bigint | BigNumber,
  spender: string
) {
  const txHash = await caller.invoke(tokenContract, "approve", {
    spender,
    amount: uint(amount),
  });

  console.log(
    "Approved",
    amount.toString(),
    "tokens for",
    spender,
    "to spend",
    "\nTx Hash:",
    txHash
  );
  return txHash;
}

export async function getEventData(
  txHash: string,
  eventContract: StarknetContract,
  eventName: string
) {
  const data: StringMap[] = [];
  const txReceipts = await starknet.getTransactionReceipt(txHash);
  const decodedEvents = await eventContract.decodeEvents(txReceipts.events);
  for (const event of decodedEvents) {
    if (event.name === eventName) {
      data.push(event.data);
    }
  }
  return data;
}

export async function swapExactTokensForTokens(
  caller: Account,
  routerContract: StarknetContract,
  amountIn: bigint | BigNumber,
  amountOutMin: bigint | BigNumber,
  path: string[],
  to: string,
  deadline: number
) {
  const txHash = await caller.invoke(
    routerContract,
    "swap_exact_tokens_for_tokens",
    {
      amountIn: uint(amountIn),
      amountOutMin: uint(amountOutMin),
      path,
      to,
      deadline: BigInt(deadline),
    }
  );

  console.log(
    "Successfully Swapped",
    amountIn.toString(),
    "tokens to",
    to,
    "\nTx Hash:",
    txHash
  );
  return txHash;
}

export async function swapTokensForExactTokens(
  caller: Account,
  routerContract: StarknetContract,
  amountOut: bigint | BigNumber,
  amountInMax: bigint | BigNumber,
  path: string[],
  to: string,
  deadline: number
) {
  const txHash = await caller.invoke(
    routerContract,
    "swap_tokens_for_exact_tokens",
    {
      amountOut: uint(amountOut),
      amountInMax: uint(amountInMax),
      path,
      to,
      deadline: BigInt(deadline),
    }
  );

  console.log(
    "Successfully Swapped",
    amountOut.toString(),
    "tokens to",
    to,
    "\nTx Hash:",
    txHash
  );
  return txHash;
}

export async function setFeeTo(
  caller: Account,
  factoryContract: StarknetContract,
  recipient: string
) {
  const txHash = await caller.invoke(factoryContract, "set_fee_to", {
    fee_to_address: recipient,
  });

  console.log("New fee to address:", recipient, "\nTx Hash:", txHash);
  return txHash;
}

// Swap Test Utils
export async function initializePairs(
  factoryContract: StarknetContract,
  routerContract: StarknetContract,
  token0Contract: StarknetContract,
  token1Contract: StarknetContract,
  token2Contract: StarknetContract,
  deployerAccount: Account,
  userAccount: Account
) {
  // Mint tokens to user 1
  const tokenMintAmount = 100;
  await mintTokens(
    deployerAccount,
    token0Contract,
    tokenMintAmount,
    userAccount.address
  );
  await mintTokens(
    deployerAccount,
    token1Contract,
    tokenMintAmount,
    userAccount.address
  );
  await mintTokens(
    deployerAccount,
    token2Contract,
    tokenMintAmount,
    userAccount.address
  );

  // Approve required tokens to be spent by router
  const token0Amount = ethers.utils.parseUnits(
    "20",
    await tokenDecimals(token0Contract)
  );
  let token1Amount = ethers.utils.parseUnits(
    "40",
    await tokenDecimals(token1Contract)
  );
  await approve(
    userAccount,
    token0Contract,
    token0Amount,
    routerContract.address
  );
  await approve(
    userAccount,
    token1Contract,
    token1Amount,
    routerContract.address
  );

  // Add liquidity to a new pair
  await addLiquidity(
    userAccount,
    routerContract,
    token0Contract,
    token1Contract,
    20,
    40,
    userAccount.address,
    Math.round(Date.now() / 1000) + 60 * 15
  );

  const pairFactory = await starknet.getContractFactory(
    "contracts/dex/StarkDPair.cairo"
  );
  const { pair: pair0Address } = await factoryContract.call("get_pair", {
    tokenA: addressToFelt(token0Contract.address),
    tokenB: addressToFelt(token1Contract.address),
  });
  const pair0 = pairFactory.getContractAt(pair0Address);

  console.log("Initialized 1st pair");

  // Approve required tokens to be spent by router
  token1Amount = ethers.utils.parseUnits(
    "20",
    await tokenDecimals(token1Contract)
  );
  const token2Amount = ethers.utils.parseUnits(
    "4",
    await tokenDecimals(token2Contract)
  );
  await approve(
    userAccount,
    token1Contract,
    token1Amount,
    routerContract.address
  );
  await approve(
    userAccount,
    token2Contract,
    token2Amount,
    routerContract.address
  );

  // Add liquidity to a new pair
  await addLiquidity(
    userAccount,
    routerContract,
    token1Contract,
    token2Contract,
    20,
    4,
    userAccount.address,
    Math.round(Date.now() / 1000) + 60 * 15
  );

  const { pair: pair1Address } = await factoryContract.call("get_pair", {
    tokenA: addressToFelt(token1Contract.address),
    tokenB: addressToFelt(token2Contract.address),
  });
  const pair1 = pairFactory.getContractAt(pair1Address);

  console.log("Initialized 2nd pair");

  return { pair0, pair1 };
}

export async function mintTokensToRandomUser(
  caller: Account,
  token0Contract: StarknetContract,
  token1Contract: StarknetContract,
  token2Contract: StarknetContract,
  amount: number | bigint,
  userAccount: Account,
  routerContract: StarknetContract
) {
  // Mint tokens to random user
  await mintTokens(caller, token0Contract, amount, userAccount.address);
  await mintTokens(caller, token1Contract, amount, userAccount.address);
  await mintTokens(caller, token2Contract, amount, userAccount.address);

  // Approve tokens to be spent by router
  // let tokenAmount = ethers.utils.parseUnits(
  //   amount.toString(),
  //   await tokenDecimals(userAccount, token0Contract)
  // );
  // await approve(
  //   userAccount,
  //   token0Contract,
  //   tokenAmount,
  //   routerContract.address
  // );

  // tokenAmount = ethers.utils.parseUnits(
  //   amount.toString(),
  //   await tokenDecimals(userAccount, token1Contract)
  // );
  // await approve(
  //   userAccount,
  //   token1Contract,
  //   tokenAmount,
  //   routerContract.address
  // );

  // tokenAmount = ethers.utils.parseUnits(
  //   amount.toString(),
  //   await tokenDecimals(userAccount, token2Contract)
  // );
  // await approve(
  //   userAccount,
  //   token2Contract,
  //   tokenAmount,
  //   routerContract.address
  // );
}

// Path Finder Utils
export async function initializePathFinderPairs(
  factoryContract: StarknetContract,
  routerContract: StarknetContract,
  token0: StarknetContract,
  token1: StarknetContract,
  USDT: StarknetContract,
  USDC: StarknetContract,
  DAI: StarknetContract,
  ETH: StarknetContract,
  deployerAccount: Account,
  userAccount: Account
) {
  // Mint tokens to user 1
  const tokenMintAmount = 1000;
  await mintTokens(
    deployerAccount,
    token0,
    tokenMintAmount,
    userAccount.address
  );
  await mintTokens(
    deployerAccount,
    token1,
    tokenMintAmount,
    userAccount.address
  );
  await mintTokens(deployerAccount, USDT, tokenMintAmount, userAccount.address);
  await mintTokens(deployerAccount, USDC, tokenMintAmount, userAccount.address);
  await mintTokens(deployerAccount, DAI, tokenMintAmount, userAccount.address);
  await mintTokens(deployerAccount, ETH, tokenMintAmount, userAccount.address);

  // Approve required tokens to be spent by router
  const token0Amount = ethers.utils.parseUnits(
    "700",
    await tokenDecimals(token0)
  );
  const token1Amount = ethers.utils.parseUnits(
    "700",
    await tokenDecimals(token1)
  );
  const USDTAmount = ethers.utils.parseUnits("700", await tokenDecimals(USDT));
  const USDCAmount = ethers.utils.parseUnits("700", await tokenDecimals(USDC));
  const DAIAmount = ethers.utils.parseUnits("700", await tokenDecimals(DAI));
  const ETHAmount = ethers.utils.parseUnits("700", await tokenDecimals(ETH));

  await approve(userAccount, token0, token0Amount, routerContract.address);
  await approve(userAccount, token1, token1Amount, routerContract.address);
  await approve(userAccount, USDT, USDTAmount, routerContract.address);
  await approve(userAccount, USDC, USDCAmount, routerContract.address);
  await approve(userAccount, DAI, DAIAmount, routerContract.address);
  await approve(userAccount, ETH, ETHAmount, routerContract.address);

  // Add liquidity to a pairs
  await addLiquidity(
    userAccount,
    routerContract,
    token0,
    ETH,
    20,
    40,
    userAccount.address,
    Math.round(Date.now() / 1000) + 60 * 15
  );
  await addLiquidity(
    userAccount,
    routerContract,
    token0,
    USDT,
    55,
    73,
    userAccount.address,
    Math.round(Date.now() / 1000) + 60 * 15
  );
  await addLiquidity(
    userAccount,
    routerContract,
    token0,
    USDC,
    90,
    34,
    userAccount.address,
    Math.round(Date.now() / 1000) + 60 * 15
  );
  await addLiquidity(
    userAccount,
    routerContract,
    token0,
    DAI,
    15,
    58,
    userAccount.address,
    Math.round(Date.now() / 1000) + 60 * 15
  );
  await addLiquidity(
    userAccount,
    routerContract,
    ETH,
    token1,
    100,
    45,
    userAccount.address,
    Math.round(Date.now() / 1000) + 60 * 15
  );
  await addLiquidity(
    userAccount,
    routerContract,
    USDT,
    token1,
    24,
    58,
    userAccount.address,
    Math.round(Date.now() / 1000) + 60 * 15
  );
  await addLiquidity(
    userAccount,
    routerContract,
    USDC,
    token1,
    43,
    31,
    userAccount.address,
    Math.round(Date.now() / 1000) + 60 * 15
  );
  await addLiquidity(
    userAccount,
    routerContract,
    DAI,
    token1,
    86,
    22,
    userAccount.address,
    Math.round(Date.now() / 1000) + 60 * 15
  );
  await addLiquidity(
    userAccount,
    routerContract,
    ETH,
    USDT,
    68,
    71,
    userAccount.address,
    Math.round(Date.now() / 1000) + 60 * 15
  );
  await addLiquidity(
    userAccount,
    routerContract,
    ETH,
    USDC,
    20,
    40,
    userAccount.address,
    Math.round(Date.now() / 1000) + 60 * 15
  );
  await addLiquidity(
    userAccount,
    routerContract,
    ETH,
    DAI,
    33,
    56,
    userAccount.address,
    Math.round(Date.now() / 1000) + 60 * 15
  );
  await addLiquidity(
    userAccount,
    routerContract,
    USDT,
    USDC,
    50,
    50,
    userAccount.address,
    Math.round(Date.now() / 1000) + 60 * 15
  );
  await addLiquidity(
    userAccount,
    routerContract,
    USDT,
    DAI,
    30,
    30,
    userAccount.address,
    Math.round(Date.now() / 1000) + 60 * 15
  );
  await addLiquidity(
    userAccount,
    routerContract,
    USDC,
    DAI,
    60,
    60,
    userAccount.address,
    Math.round(Date.now() / 1000) + 60 * 15
  );

  console.log("Initialized all 14 pairs");
}

export async function findPath(
  pathFinderContract: StarknetContract,
  routerAggregatorContract: StarknetContract,
  amountIn: number,
  tokenIn: StarknetContract,
  tokenOut: StarknetContract
) {
  const pathArray: string[] = [];

  const tknInAmount = ethers.utils.parseUnits(
    amountIn.toString(),
    await tokenDecimals(tokenIn)
  );

  const { amountOut } = await routerAggregatorContract.call(
    "get_single_best_pool",
    {
      amountIn: uint(tknInAmount),
      tokenIn: tokenIn.address,
      tokenOut: tokenOut.address,
    }
  );

  if (uintToBigInt(amountOut) > 0n) {
    pathArray.push(tokenIn.address);
    pathArray.push(tokenOut.address);
    return pathArray;
  }

  // eslint-disable-next-line camelcase
  const { path_len, path } = await pathFinderContract.call("get_results", {
    amountIn: uint(tknInAmount),
    tokenIn: tokenIn.address,
    tokenOut: tokenOut.address,
  });

  if (path[0]) {
    pathArray.push(tokenIn.address);
    for (let i = Number(path_len) - 1; i >= 0; i--) {
      if (path[i] === 1n) {
        pathArray.push(WETH.address);
      } else if (path[i] === 2n) {
        pathArray.push(USDT.address);
      } else if (path[i] === 3n) {
        pathArray.push(DAI.address);
      } else if (path[i] === 4n) {
        pathArray.push(USDC.address);
      } else {
        continue;
      }
    }
    pathArray.push(tokenOut.address);
  }
  return pathArray;
}
