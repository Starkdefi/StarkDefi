import { assert, expect } from "chai";
import { starknet } from "hardhat";
import { Account, StarknetContract } from "hardhat/types/runtime";
import {
  deployFactory,
  TIMEOUT,
  addressToFelt,
  // eslint-disable-next-line node/no-missing-import
} from "./utils";

describe("Update Test", function () {
  this.timeout(TIMEOUT); // 15 mins

  let deployerAccount: Account;
  let randomAccount: Account;
  let factoryContract: StarknetContract;

  before(async () => {
    const preDeployedAccounts = await starknet.devnet.getPredeployedAccounts();

    console.log("Started deployment");

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

    factoryContract = await deployFactory(deployerAccount.address);
  });

  it("Should fail when unauthorized caller changes fee_to_address", async () => {
    try {
      await randomAccount.invoke(factoryContract, "set_fee_to", {
        fee_to_address: addressToFelt(randomAccount.address),
      });
      expect.fail(
        "Should have failed on using wrong caller to set fee_to_address"
      );
    } catch (err: any) {
      expect(
        String(err.message).indexOf("only fee to setter can set fee to address")
      ).to.not.equal(-1);
    }
  });

  it("Should allow changes to fee_to_address", async () => {
    await deployerAccount.invoke(factoryContract, "set_fee_to", {
      fee_to_address: addressToFelt(randomAccount.address),
    });

    const { address } = await deployerAccount.call(factoryContract, "fee_to");
    assert(address === addressToFelt(randomAccount.address));
  });

  it("Should fail when unauthorized caller changes fee_to_setter_address", async () => {
    try {
      await randomAccount.invoke(factoryContract, "set_fee_to_setter", {
        fee_to_setter_address: addressToFelt(randomAccount.address),
      });
      expect.fail(
        "Should have failed on using wrong caller to set fee_to_setter_address"
      );
    } catch (err: any) {
      expect(
        String(err.message).indexOf(
          "only current fee to setter can update fee to setter"
        )
      ).to.not.equal(-1);
    }
  });

  it("Should fail when fee_to_setter_address is set to zero address", async () => {
    try {
      await deployerAccount.invoke(factoryContract, "set_fee_to_setter", {
        fee_to_setter_address: 0n,
      });
      expect.fail(
        "Should have failed on changing fee_to_setter_address to zero address"
      );
    } catch (err: any) {
      expect(String(err.message).indexOf("invalid fee to setter")).to.not.equal(
        -1
      );
    }
  });

  it("Should allow changes to fee_to_setter_address", async () => {
    await deployerAccount.invoke(factoryContract, "set_fee_to_setter", {
      fee_to_setter_address: addressToFelt(randomAccount.address),
    });

    const { address } = await deployerAccount.call(
      factoryContract,
      "fee_to_setter"
    );
    assert(address === addressToFelt(randomAccount.address));
  });
});
