import { expect } from "chai";
import { starknet } from "hardhat";

describe("Contract", function () {
  it("should increase balance by amount inputted", async function () {
    const factory = await starknet.getContractFactory("contract");
    const contract = await factory.deploy();

    // Invoke increase balance twice
    await contract.invoke("increase_balance", { amount: 10n }); // if number use big int
    await contract.invoke("increase_balance", { amount: 20n });

    // Check the result of get_balance().
    const { res: balance } = await contract.call("get_balance");
    expect(balance).to.equal(30n);
  });
});
