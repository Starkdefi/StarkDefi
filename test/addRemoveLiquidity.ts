import { assert, expect } from "chai";
import { ethers } from "ethers";
import { starknet } from "hardhat";
import { Account, StarknetContract } from "hardhat/types/runtime";
import {
  deployToken,
  deployFactory,
  deployRouter,
  TIMEOUT,
  addLiquidity,
  mintTokens,
  approve,
  getEventData,
  uintToBigInt,
  MINIMUM_LIQUIDITY,
  removeLiquidity,
  BURN_ADDRESS,
  addressToFelt,
  tokenDecimals,
  // eslint-disable-next-line node/no-missing-import
} from "./utils";

describe("Add and Remove Liquidity Test", function () {
  this.timeout(TIMEOUT); // 15 mins

  let user1Account: Account;
  let randomAccount: Account;
  let token0Contract: StarknetContract;
  let token1Contract: StarknetContract;
  let factoryContract: StarknetContract;
  let routerContract: StarknetContract;

  before(async () => {
    const preDeployedAccounts = await starknet.devnet.getPredeployedAccounts();

    console.log("Started deployment");

    user1Account = await starknet.getAccountFromAddress(
      preDeployedAccounts[0].address,
      preDeployedAccounts[0].private_key,
      "OpenZeppelin"
    );

    console.log("User 1 Account", user1Account.address);

    randomAccount = await starknet.getAccountFromAddress(
      preDeployedAccounts[1].address,
      preDeployedAccounts[1].private_key,
      "OpenZeppelin"
    );

    console.log("Random Account", randomAccount.address);

    token0Contract = await deployToken(randomAccount, "Token 0", "TKN0");
    token1Contract = await deployToken(randomAccount, "Token 1", "TKN1");
    factoryContract = await deployFactory(randomAccount.address);
    routerContract = await deployRouter(factoryContract.address);
  });

  it("Should fail when adding liquidity with an expired deadline", async () => {
    try {
      await addLiquidity(
        randomAccount,
        routerContract,
        token0Contract,
        token1Contract,
        2,
        4,
        randomAccount.address,
        0
      );
      expect.fail("Should have failed on passing an expired deadline.");
    } catch (err: any) {
      expect(String(err.message).indexOf("expired")).to.not.equal(-1);
    }
  });

  it("Should successfully add liquidity to both new and existing pairs and remove liquidity completely", async () => {
    // Mint tokens to user 1
    const tokenMintAmount = 100;
    await mintTokens(
      randomAccount,
      token0Contract,
      tokenMintAmount,
      user1Account.address
    );
    await mintTokens(
      randomAccount,
      token1Contract,
      tokenMintAmount,
      user1Account.address
    );

    // Approve required tokens to be spent by router
    let token0Amount = ethers.utils.parseUnits(
      "11",
      await tokenDecimals(user1Account, token0Contract)
    );
    let token1Amount = ethers.utils.parseUnits(
      "23",
      await tokenDecimals(user1Account, token1Contract)
    );
    await approve(
      user1Account,
      token0Contract,
      token0Amount,
      routerContract.address
    );
    await approve(
      user1Account,
      token1Contract,
      token1Amount,
      routerContract.address
    );

    // Add liquidity to a new pair
    let txHash = await addLiquidity(
      user1Account,
      routerContract,
      token0Contract,
      token1Contract,
      11,
      23,
      user1Account.address,
      Math.round(Date.now() / 1000) + 60 * 15
    );

    const { token0, token1 } = await user1Account.call(
      routerContract,
      "sort_tokens",
      {
        tokenA: token0Contract.address,
        tokenB: token1Contract.address,
      }
    );

    const pairFactory = await starknet.getContractFactory(
      "contracts/dex/StarkDPair.cairo"
    );
    const { pair: pairAddress } = await user1Account.call(
      factoryContract,
      "get_pair",
      {
        tokenA: token0,
        tokenB: token1,
      }
    );
    const pairContract = pairFactory.getContractAt(pairAddress);

    // Check events are emitted
    // let eventData = await getEventData(txHash, pairContract, "Mint");
    // assert(eventData.length !== 0);

    // Check reserves and total supply conform to the expected values
    let reserves = await user1Account.call(pairContract, "get_reserves");
    let reserve0, reserve1;

    if (token0 === addressToFelt(token0Contract.address)) {
      reserve0 = uintToBigInt(reserves.reserve0);
      reserve1 = uintToBigInt(reserves.reserve1);
    } else {
      reserve0 = uintToBigInt(reserves.reserve1);
      reserve1 = uintToBigInt(reserves.reserve0);
    }

    let res = await user1Account.call(pairContract, "totalSupply");
    let totalSupply = uintToBigInt(res.totalSupply);

    assert(totalSupply * totalSupply <= reserve0 * reserve1);
    assert((totalSupply + 1n) * (totalSupply + 1n) > reserve0 * reserve1);

    // Approve more tokens to be spent by router
    token0Amount = ethers.utils.parseUnits(
      "38",
      await tokenDecimals(user1Account, token0Contract)
    );
    token1Amount = ethers.utils.parseUnits(
      "22",
      await tokenDecimals(user1Account, token1Contract)
    );
    await approve(
      user1Account,
      token0Contract,
      token0Amount,
      routerContract.address
    );
    await approve(
      user1Account,
      token1Contract,
      token1Amount,
      routerContract.address
    );

    // Add liquidity to an existing pair
    txHash = await addLiquidity(
      user1Account,
      routerContract,
      token0Contract,
      token1Contract,
      38,
      22,
      user1Account.address,
      Math.round(Date.now() / 1000) + 60 * 15
    );

    // Check events are emitted
    let eventData = await getEventData(txHash, pairContract, "Mint");
    assert(eventData.length !== 0);

    // Check reserves and total supply conform to the expected values
    reserves = await user1Account.call(pairContract, "get_reserves");

    if (token0 === addressToFelt(token0Contract.address)) {
      reserve0 = uintToBigInt(reserves.reserve0);
      reserve1 = uintToBigInt(reserves.reserve1);
    } else {
      reserve0 = uintToBigInt(reserves.reserve1);
      reserve1 = uintToBigInt(reserves.reserve0);
    }

    res = await user1Account.call(pairContract, "totalSupply");
    totalSupply = uintToBigInt(res.totalSupply);

    assert(totalSupply * totalSupply <= reserve0 * reserve1);

    // Check depleted user balance for token0 and token1
    let userTokenBalance = await user1Account.call(
      token0Contract,
      "balanceOf",
      {
        account: user1Account.address,
      }
    );
    assert(
      ethers.utils.parseUnits(tokenMintAmount.toString(), 18).toBigInt() -
        uintToBigInt(userTokenBalance.balance) ===
        reserve0
    );

    userTokenBalance = await user1Account.call(token1Contract, "balanceOf", {
      account: user1Account.address,
    });
    assert(
      ethers.utils.parseUnits(tokenMintAmount.toString(), 18).toBigInt() -
        uintToBigInt(userTokenBalance.balance) ===
        reserve1
    );

    // Check user's liquidity and locked liquidity match total supply
    let userLPBalance = await user1Account.call(pairContract, "balanceOf", {
      account: user1Account.address,
    });
    assert(
      totalSupply ===
        uintToBigInt(userLPBalance.balance) + BigInt(MINIMUM_LIQUIDITY)
    );

    // Approve LP tokens to be spent by router
    await approve(
      user1Account,
      pairContract,
      uintToBigInt(userLPBalance.balance),
      routerContract.address
    );

    // Remove all liquidity
    txHash = await removeLiquidity(
      user1Account,
      routerContract,
      token0Contract,
      token1Contract,
      uintToBigInt(userLPBalance.balance),
      user1Account.address,
      Math.round(Date.now() / 1000) + 60 * 15
    );

    // Check events are emitted
    eventData = await getEventData(txHash, pairContract, "Burn");
    assert(eventData.length !== 0);

    // Check user's LP balance is 0
    userLPBalance = await user1Account.call(pairContract, "balanceOf", {
      account: user1Account.address,
    });
    assert(uintToBigInt(userLPBalance.balance) === 0n);

    // Check total supply is at minimum liquidity
    res = await user1Account.call(pairContract, "totalSupply");
    totalSupply = uintToBigInt(res.totalSupply);
    assert(totalSupply === BigInt(MINIMUM_LIQUIDITY));

    // Check total supply is in burn address
    const burnAddressLPBalance = await user1Account.call(
      pairContract,
      "balanceOf",
      {
        account: BURN_ADDRESS,
      }
    );
    assert(uintToBigInt(burnAddressLPBalance.balance) === totalSupply);

    // Check reserves and total supply conform to the expected values
    reserves = await user1Account.call(pairContract, "get_reserves");

    if (token0 === addressToFelt(token0Contract.address)) {
      reserve0 = uintToBigInt(reserves.reserve0);
      reserve1 = uintToBigInt(reserves.reserve1);
    } else {
      reserve0 = uintToBigInt(reserves.reserve1);
      reserve1 = uintToBigInt(reserves.reserve0);
    }
    assert(totalSupply * totalSupply <= reserve0 * reserve1);
  });
});
