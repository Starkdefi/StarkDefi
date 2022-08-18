import { assert } from "chai";
import { ethers } from "ethers";
import { starknet } from "hardhat";
import { Account, StarknetContract } from "hardhat/types/runtime";
import {
  deployToken,
  deployFactory,
  deployRouter,
  TIMEOUT,
  initializePairs,
  mintTokensToRandomUser,
  uintToBigInt,
  approve,
  tokenDecimals,
  getEventData,
  swapExactTokensForTokens,
  setFeeTo,
  removeLiquidity,
  // eslint-disable-next-line node/no-missing-import
} from "./utils";

describe("Protocol Fee Test", function () {
  this.timeout(TIMEOUT); // 15 mins

  let user1Account: Account;
  let user2Account: Account;
  let deployerAccount: Account;
  let feeRecipientAccount: Account;
  let token0Contract: StarknetContract;
  let token1Contract: StarknetContract;
  let token2Contract: StarknetContract;
  let factoryContract: StarknetContract;
  let routerContract: StarknetContract;
  let pair0Contract: StarknetContract;

  before(async () => {
    const preDeployedAccounts = await starknet.devnet.getPredeployedAccounts();

    console.log("Started deployment");

    user1Account = await starknet.getAccountFromAddress(
      preDeployedAccounts[0].address,
      preDeployedAccounts[0].private_key,
      "OpenZeppelin"
    );

    console.log("User 1 Account", user1Account.address);

    user2Account = await starknet.getAccountFromAddress(
      preDeployedAccounts[1].address,
      preDeployedAccounts[1].private_key,
      "OpenZeppelin"
    );

    console.log("User 2 Account", user2Account.address);

    deployerAccount = await starknet.getAccountFromAddress(
      preDeployedAccounts[2].address,
      preDeployedAccounts[2].private_key,
      "OpenZeppelin"
    );

    console.log("Deployer Account", deployerAccount.address);

    feeRecipientAccount = await starknet.getAccountFromAddress(
      preDeployedAccounts[4].address,
      preDeployedAccounts[4].private_key,
      "OpenZeppelin"
    );

    console.log("Fee Recipient Account", feeRecipientAccount.address);

    token0Contract = await deployToken(deployerAccount, "Token 0", "TKN0");
    token1Contract = await deployToken(deployerAccount, "Token 1", "TKN1");
    token2Contract = await deployToken(deployerAccount, "Token 2", "TKN2");
    factoryContract = await deployFactory(deployerAccount.address);
    routerContract = await deployRouter(factoryContract.address);
    await setFeeTo(
      deployerAccount,
      factoryContract,
      feeRecipientAccount.address
    );
    const { pair0 } = await initializePairs(
      factoryContract,
      routerContract,
      token0Contract,
      token1Contract,
      token2Contract,
      deployerAccount,
      user1Account
    );
    pair0Contract = pair0;
    await mintTokensToRandomUser(
      deployerAccount,
      token0Contract,
      token1Contract,
      token2Contract,
      100,
      user1Account,
      routerContract
    );
    await mintTokensToRandomUser(
      deployerAccount,
      token0Contract,
      token1Contract,
      token2Contract,
      100,
      user2Account,
      routerContract
    );
  });

  it("Should successfully process protocol fee", async () => {
    // Approve required tokens to be spent by router
    const token0Amount = ethers.utils.parseUnits(
      "2",
      await tokenDecimals(user2Account, token0Contract)
    );
    await approve(
      user2Account,
      token0Contract,
      token0Amount,
      routerContract.address
    );

    // Swap
    let txHash = await swapExactTokensForTokens(
      user2Account,
      routerContract,
      token0Amount,
      0n,
      [token0Contract.address, token1Contract.address],
      user2Account.address,
      Math.round(Date.now() / 1000) + 60 * 15
    );

    // Check events are emitted
    let eventData = await getEventData(txHash, pair0Contract, "Swap");
    assert(eventData.length !== 0);

    console.log(
      "Swap event data:",
      uintToBigInt(eventData[0].amount0In),
      uintToBigInt(eventData[0].amount0Out),
      uintToBigInt(eventData[0].amount1In),
      uintToBigInt(eventData[0].amount1Out)
    );

    const { balance: user1Pair0Balance } = await user1Account.call(
      pair0Contract,
      "balanceOf",
      {
        account: user1Account.address,
      }
    );

    console.log("User 1 Pair 0 Balance", uintToBigInt(user1Pair0Balance));

    // Approve pair tokens to be spent by router
    await approve(
      user1Account,
      pair0Contract,
      uintToBigInt(user1Pair0Balance),
      routerContract.address
    );

    // Remove liquidity completely
    txHash = await removeLiquidity(
      user1Account,
      routerContract,
      token0Contract,
      token1Contract,
      uintToBigInt(user1Pair0Balance),
      user1Account.address,
      Math.round(Date.now() / 1000) + 60 * 15
    );

    // Check events are emitted
    eventData = await getEventData(txHash, pair0Contract, "Burn");
    assert(eventData.length !== 0);

    console.log(
      "Burn event data:",
      uintToBigInt(eventData[0].amount0),
      uintToBigInt(eventData[0].amount1)
    );

    const { balance: feeRecipientPair0Balance } =
      await feeRecipientAccount.call(pair0Contract, "balanceOf", {
        account: feeRecipientAccount.address,
      });
    console.log(
      "Fee Recipient Pair 0 Balance",
      uintToBigInt(feeRecipientPair0Balance)
    );

    assert(uintToBigInt(feeRecipientPair0Balance) > 0n);
  });
});
