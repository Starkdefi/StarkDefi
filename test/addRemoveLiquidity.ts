import { assert, expect } from "chai";
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
  feltToAddress,
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
        0
      );
      expect.fail("Should have failed on passing an expired deadline.");
    } catch (err: any) {
      expect(String(err.message).indexOf("expired")).to.not.equal(-1);
    }
  });

  it("Should add liquidity successfully", async () => {
    // Mint tokens to user 1
    await mintTokens(randomAccount, token0Contract, 100, user1Account.address);
    await mintTokens(randomAccount, token1Contract, 100, user1Account.address);

    // Approve required tokens to be spent by router
    await approve(user1Account, token0Contract, 2, routerContract.address);
    await approve(user1Account, token1Contract, 4, routerContract.address);

    // Add liquidity to a new pair
    const txHash = await addLiquidity(
      user1Account,
      routerContract,
      token0Contract,
      token1Contract,
      2,
      4,
      Math.round(Date.now() / 1000) + 60 * 15
    );

    // Check events are emitted
    const eventData = await getEventData(txHash, "Mint");
    assert(eventData.length !== 0);

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

    // Check reserves and total supply conform to the expected values
    const reserves = await user1Account.call(pairContract, "get_reserves");
    let reserve0, reserve1;

    if (feltToAddress(token0) === token0Contract.address) {
      reserve0 = uintToBigInt(reserves.reserve0);
      reserve1 = uintToBigInt(reserves.reserve1);
    } else {
      reserve0 = uintToBigInt(reserves.reserve1);
      reserve1 = uintToBigInt(reserves.reserve0);
    }

    const res = await user1Account.call(pairContract, "totalSupply");
    const totalSupply = uintToBigInt(res.totalSupply);

    assert(totalSupply * totalSupply <= reserve0 * reserve1);
    assert((totalSupply + 1n) * (totalSupply + 1n) > reserve0 * reserve1);
  });
});
