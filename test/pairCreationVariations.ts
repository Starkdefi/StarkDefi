import { expect } from "chai";
import { starknet } from "hardhat";
import { Account, StarknetContract } from "hardhat/types/runtime";
import {
  deployToken,
  deployFactory,
  deployRouter,
  TIMEOUT,
  deployPair,
  // eslint-disable-next-line node/no-missing-import
} from "./utils";

describe("Pair Creation Variations Test", function () {
  this.timeout(TIMEOUT); // 15 mins

  let deployerAccount: Account;
  let token0Contract: StarknetContract;
  let token1Contract: StarknetContract;
  let factoryContract: StarknetContract;
  let routerContract: StarknetContract;

  before(async () => {
    const preDeployedAccounts = await starknet.devnet.getPredeployedAccounts();

    console.log("Started deployment");

    deployerAccount = await starknet.getAccountFromAddress(
      preDeployedAccounts[0].address,
      preDeployedAccounts[0].private_key,
      "OpenZeppelin"
    );

    console.log("Deployer Account", deployerAccount.address);

    token0Contract = await deployToken(deployerAccount, "Token 0", "TKN0");
    token1Contract = await deployToken(deployerAccount, "Token 1", "TKN1");
    factoryContract = await deployFactory(deployerAccount.address);
    routerContract = await deployRouter(factoryContract.address);
  });

  it("Should fail when creating pair using zero address for both tokens", async () => {
    try {
      await deployPair(
        deployerAccount,
        "0",
        "0",
        routerContract,
        factoryContract
      );
      expect.fail("Should have failed on passing wrong token address");
    } catch (err: any) {
      expect(
        String(err.message).indexOf("invalid tokenA and tokenB")
      ).to.not.equal(-1);
    }
  });

  it("Should fail when creating pair using zero address for one token", async () => {
    try {
      await deployPair(
        deployerAccount,
        "0",
        token1Contract.address,
        routerContract,
        factoryContract
      );
      expect.fail("Should have failed on passing wrong token address");
    } catch (err: any) {
      expect(
        String(err.message).indexOf("invalid tokenA and tokenB")
      ).to.not.equal(-1);
    }
    try {
      await deployPair(
        deployerAccount,
        token0Contract.address,
        "0",
        routerContract,
        factoryContract
      );
      expect.fail("Should have failed on passing wrong token address");
    } catch (err: any) {
      expect(
        String(err.message).indexOf("invalid tokenA and tokenB")
      ).to.not.equal(-1);
    }
  });

  it("Should fail when creating pair using same token address", async () => {
    try {
      await deployPair(
        deployerAccount,
        token0Contract.address,
        token0Contract.address,
        routerContract,
        factoryContract
      );
      expect.fail("Should have failed on passing same token address twice");
    } catch (err: any) {
      expect(
        String(err.message).indexOf("same token provided for tokenA and tokenB")
      ).to.not.equal(-1);
    }
  });

  it("Should fail when creating pair that already exists", async () => {
    await deployPair(
      deployerAccount,
      token0Contract.address,
      token1Contract.address,
      routerContract,
      factoryContract
    );
    try {
      await deployPair(
        deployerAccount,
        token0Contract.address,
        token1Contract.address,
        routerContract,
        factoryContract
      );
      expect.fail(
        "Should have failed on passing token address pair which already exists"
      );
    } catch (err: any) {
      expect(
        String(err.message).indexOf("can't create pair, pair already exists")
      ).to.not.equal(-1);
    }

    // checking with different order
    try {
      await deployPair(
        deployerAccount,
        token1Contract.address,
        token0Contract.address,
        routerContract,
        factoryContract
      );
      expect.fail(
        "Should have failed on passing token address pair which already exists"
      );
    } catch (err: any) {
      expect(
        String(err.message).indexOf("can't create pair, pair already exists")
      ).to.not.equal(-1);
    }
  });
});
