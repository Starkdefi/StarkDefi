import { expect } from "chai";
import { starknet } from "hardhat";
import { Account, StarknetContract } from "hardhat/types/runtime";
// eslint-disable-next-line node/no-missing-import

describe("Deployment Test", function () {
  this.timeout(900_000); // 15 mins

  let deployerAccount: Account;
  let randomAccount: Account;
  let token0Contract: StarknetContract;
  let token1Contract: StarknetContract;
  let token2Contract: StarknetContract;
  let token3Contract: StarknetContract;
  let factoryContract: StarknetContract;
  let routerContract: StarknetContract;

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
    const token0ContractFactory = await starknet.getContractFactory(
      "contracts/token/ERC20.cairo"
    );

    token0Contract = await token0ContractFactory.deploy(
      {
        name: starknet.shortStringToBigInt("Token 0"),
        symbol: starknet.shortStringToBigInt("TKN0"),
        decimals: 18,
        recipient: randomAccount.address,
      },
      { salt: "0x42" }
    );
    console.log("Token 0 deployed at", token0Contract.address);
    const res = await randomAccount.call(token0Contract, "name");
    const nameString = starknet.bigIntToShortString(res.name);

    expect(nameString === "Token 0");
  });

  it("Should deploy token 1 contract", async () => {
    const token1ContractFactory = await starknet.getContractFactory(
      "contracts/token/ERC20.cairo"
    );

    token1Contract = await token1ContractFactory.deploy(
      {
        name: starknet.shortStringToBigInt("Token 1"),
        symbol: starknet.shortStringToBigInt("TKN1"),
        decimals: 18,
        recipient: randomAccount.address,
      },
      { salt: "0x42" }
    );
    console.log("Token 1 deployed at", token1Contract.address);
    const res = await randomAccount.call(token1Contract, "name");
    const nameString = starknet.bigIntToShortString(res.name);

    expect(nameString === "Token 1");
  });

  it("Should deploy token 2 contract", async () => {
    const token2ContractFactory = await starknet.getContractFactory(
      "contracts/token/ERC20.cairo"
    );

    token2Contract = await token2ContractFactory.deploy(
      {
        name: starknet.shortStringToBigInt("Token 2"),
        symbol: starknet.shortStringToBigInt("TKN2"),
        decimals: 18,
        recipient: randomAccount.address,
      },
      { salt: "0x42" }
    );
    console.log("Token 0 deployed at", token2Contract.address);
    const res = await randomAccount.call(token2Contract, "name");
    const nameString = starknet.bigIntToShortString(res.name);

    expect(nameString === "Token 2");
  });

  it("Should deploy token 3 contract", async () => {
    const token3ContractFactory = await starknet.getContractFactory(
      "contracts/token/ERC20.cairo"
    );

    token3Contract = await token3ContractFactory.deploy(
      {
        name: starknet.shortStringToBigInt("Token 3"),
        symbol: starknet.shortStringToBigInt("TKN3"),
        decimals: 18,
        recipient: randomAccount.address,
      },
      { salt: "0x42" }
    );
    console.log("Token 0 deployed at", token3Contract.address);
    const res = await randomAccount.call(token3Contract, "name");
    const nameString = starknet.bigIntToShortString(res.name);

    expect(nameString === "Token 3");
  });

  it("Should deploy factory contract", async () => {
    const pairContractFactory = await starknet.getContractFactory(
      "contracts/dex/Pair.cairo"
    );
    const declaredPairClass = await pairContractFactory.declare();
    const factory = await starknet.getContractFactory(
      "contracts/dex/Factory.cairo"
    );
    factoryContract = await factory.deploy(
      {
        pair_contract_class_hash: declaredPairClass,
        fee_to_setter: deployerAccount.address,
      },
      { salt: "0x42" }
    );

    console.log("Factory deployed at", factoryContract.address);

    const feeToSetter = await deployerAccount.call(
      factoryContract,
      "get_fee_to_setter"
    );
    expect(deployerAccount.address === feeToSetter.address);
  });

  it("Should deploy router contract", async () => {
    const routerContractFactory = await starknet.getContractFactory(
      "contracts/dex/Router.cairo"
    );
    routerContract = await routerContractFactory.deploy(
      { factory: factoryContract.address },
      { salt: "0x42" }
    );

    console.log("Router deployed at", routerContract.address);

    const factoryAddy = await deployerAccount.call(routerContract, "factory");
    expect(factoryContract.address === factoryAddy.address);
  });

  it("Should create pairs successfully", async () => {
    console.log("Creating Pair for Token 0 and Token 1");
    const pairFactory = await starknet.getContractFactory(
      "contracts/dex/Pair.cairo"
    );

    const executionInfo0 = await deployerAccount.call(
      routerContract,
      "sort_tokens",
      {
        tokenA: token0Contract.address,
        tokenB: token1Contract.address,
      }
    );
    const estimatedFee0 = await deployerAccount.estimateFee(
      factoryContract,
      "create_pair",
      {
        tokenA: executionInfo0.token0,
        tokenB: executionInfo0.token1,
      }
    );
    console.log("Estimated fee to create pair", estimatedFee0);
    const pair0 = await deployerAccount.invoke(factoryContract, "create_pair", {
      tokenA: executionInfo0.token0,
      tokenB: executionInfo0.token1,
    });
    console.log("Pair deployed at", pair0);

    const pair0Contract = pairFactory.getContractAt(pair0);

    const res0 = await deployerAccount.call(pair0Contract, "token0");

    expect(res0.address === executionInfo0.token0);
  });
});
