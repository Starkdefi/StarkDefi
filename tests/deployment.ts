import { expect } from "chai";
import { starknet } from "hardhat";
import { Account, StarknetContract } from "hardhat/types/runtime";
import {
  deployFactory,
  deployPair,
  deployRouter,
  deployToken,
  TIMEOUT,
  // eslint-disable-next-line node/no-missing-import
} from "./utils";

describe("Deployment Test", function () {
  this.timeout(TIMEOUT); // 15 mins

  let deployerAccount: Account;
  let randomAccount: Account;
  let token0Contract: StarknetContract;
  let token1Contract: StarknetContract;
  let token2Contract: StarknetContract;
  let token3Contract: StarknetContract;
  let factoryContract: StarknetContract;
  let routerContract: StarknetContract;
  let pair01Contract: StarknetContract;

  before(async () => {
    const preDeployedAccounts = await starknet.devnet.getPredeployedAccounts();

    console.log("Started deployment");

    console.log("Assigning accounts...");

    deployerAccount = await starknet.getAccountFromAddress(
      preDeployedAccounts[0].address,
      preDeployedAccounts[0].private_key,
      "OpenZeppelin"
    );

    console.log("Deployer Account", deployerAccount.address);

    randomAccount = await starknet.getAccountFromAddress(
      preDeployedAccounts[1].address,
      preDeployedAccounts[1].private_key,
      "OpenZeppelin"
    );

    console.log("Random Account", randomAccount.address);
  });

  it("Should deploy token 0 contract", async () => {
    token0Contract = await deployToken(randomAccount, "Token 0", "TKN0");
    const res = await randomAccount.call(token0Contract, "name");
    const nameString = starknet.bigIntToShortString(res.name);
    expect(nameString === "Token 0");
  });

  it("Should deploy token 1 contract", async () => {
    token1Contract = await deployToken(randomAccount, "Token 1", "TKN1");
    const res = await randomAccount.call(token1Contract, "name");
    const nameString = starknet.bigIntToShortString(res.name);
    expect(nameString === "Token 1");
  });

  it("Should deploy token 2 contract", async () => {
    token2Contract = await deployToken(randomAccount, "Token 2", "TKN2");
    const res = await randomAccount.call(token2Contract, "name");
    const nameString = starknet.bigIntToShortString(res.name);
    expect(nameString === "Token 2");
  });

  it("Should deploy token 3 contract", async () => {
    token3Contract = await deployToken(randomAccount, "Token 3", "TKN3");
    const res = await randomAccount.call(token3Contract, "name");
    const nameString = starknet.bigIntToShortString(res.name);
    expect(nameString === "Token 3");
  });

  it("Should deploy factory contract", async () => {
    factoryContract = await deployFactory(deployerAccount.address);
    const feeToSetter = await deployerAccount.call(
      factoryContract,
      "get_fee_to_setter"
    );
    expect(deployerAccount.address === feeToSetter.address);
  });

  it("Should deploy router contract", async () => {
    routerContract = await deployRouter(factoryContract.address);
    const factory = await deployerAccount.call(routerContract, "factory");
    expect(factoryContract.address === factory.address);
  });

  it("Should create pair successfully", async () => {
    pair01Contract = await deployPair(
      deployerAccount,
      token0Contract.address,
      token1Contract.address,
      routerContract,
      factoryContract
    );

    const executionInfo = await deployerAccount.call(
      routerContract,
      "sort_tokens",
      {
        tokenA: token0Contract.address,
        tokenB: token1Contract.address,
      }
    );

    const res1 = await deployerAccount.call(pair01Contract, "token0");
    expect(res1.address === executionInfo.token0);
  });
});
