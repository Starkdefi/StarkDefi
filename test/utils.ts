import { FeeEstimation } from "@shardlabs/starknet-hardhat-plugin/dist/src/starknet-types";
import { BigNumber, ethers } from "ethers";
import { starknet } from "hardhat";
import { Account, StarknetContract, StringMap } from "hardhat/types/runtime";

export const TIMEOUT = 900_000;
export const MINIMUM_LIQUIDITY = 1000;
export const BURN_ADDRESS = 1;
export const MAX_INT = BigInt("340282366920938463463374607431768211455");

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
    { salt: "0x42" }
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
    { salt: "0x42" }
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
    { salt: "0x42" }
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
  const res0 = await deployerAccount.call(factoryContract, "get_pair", {
    tokenA: addressToFelt(token0Address),
    tokenB: addressToFelt(token1Address),
  });

  console.log("Pair deployed at", feltToAddress(res0.pair));
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
  const { decimals: token0Decimals } = await caller.call(
    token0Contract,
    "decimals"
  );

  const { decimals: token1Decimals } = await caller.call(
    token1Contract,
    "decimals"
  );

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
  const { decimals: tokenDecimals } = await caller.call(
    tokenContract,
    "decimals"
  );

  const tokenAmount = ethers.utils.parseUnits(amount.toString(), tokenDecimals);

  const txHash = await caller.invoke(tokenContract, "mint", {
    recipient: recipient,
    amount: uint(tokenAmount),
  });

  console.log("Minted", amount, "tokens to", recipient, "\nTx Hash:", txHash);
  return txHash;
}

export async function tokenDecimals(
  caller: Account,
  tokenContract: StarknetContract
) {
  const { decimals } = await caller.call(tokenContract, "decimals");
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
    await tokenDecimals(userAccount, token0Contract)
  );
  let token1Amount = ethers.utils.parseUnits(
    "40",
    await tokenDecimals(userAccount, token1Contract)
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
  const { pair: pair0Address } = await userAccount.call(
    factoryContract,
    "get_pair",
    {
      tokenA: addressToFelt(token0Contract.address),
      tokenB: addressToFelt(token1Contract.address),
    }
  );
  const pair0 = pairFactory.getContractAt(pair0Address);

  console.log("Initialized 1st pair");

  // Approve required tokens to be spent by router
  token1Amount = ethers.utils.parseUnits(
    "20",
    await tokenDecimals(userAccount, token1Contract)
  );
  const token2Amount = ethers.utils.parseUnits(
    "4",
    await tokenDecimals(userAccount, token2Contract)
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

  const { pair: pair1Address } = await userAccount.call(
    factoryContract,
    "get_pair",
    {
      tokenA: addressToFelt(token1Contract.address),
      tokenB: addressToFelt(token2Contract.address),
    }
  );
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
