// import { assert } from "chai";
import { assert } from "chai";
import { starknet } from "hardhat";
import { Account, StarknetContract } from "hardhat/types/runtime";
import {
  deployToken,
  deployFactory,
  deployRouter,
  deployRouterAggregator,
  deployPathFinder,
  TIMEOUT,
  initializePathFinderPairs,
  findPath,
  addLiquidity,
  // eslint-disable-next-line node/no-missing-import
} from "../scripts/utils";

// Path array return in reverse synchronous order (from destination to source)
// so if multiple elements in path array, path is from source, path[len-1], ..., path[0], destination
// From contract, 1 = WETH, 2 = USDT, 3 = DAI, 4 = USDC

describe("Path Finder Test", function () {
  this.timeout(TIMEOUT); // 15 mins

  let user1Account: Account;
  let randomAccount: Account;

  let factoryContract: StarknetContract;
  let routerContract: StarknetContract;
  let routerAggregatorContract: StarknetContract;
  let pathFinderContract: StarknetContract;

  let token0: StarknetContract;
  let token1: StarknetContract;
  let token2: StarknetContract;
  let USDT: StarknetContract;
  let USDC: StarknetContract;
  let DAI: StarknetContract;
  let WETH: StarknetContract;

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
      preDeployedAccounts[2].address,
      preDeployedAccounts[2].private_key,
      "OpenZeppelin"
    );

    console.log("Random Account", randomAccount.address);

    WETH = await deployToken(randomAccount, "ETH", "ETH");
    DAI = await deployToken(randomAccount, "DAI", "DAI");
    USDT = await deployToken(randomAccount, "USDT", "USDT");
    USDC = await deployToken(randomAccount, "USDC", "USDC");
    token0 = await deployToken(randomAccount, "Token 0", "TKN0");
    token1 = await deployToken(randomAccount, "Token 1", "TKN1");
    token2 = await deployToken(randomAccount, "Token 2", "TKN2");

    factoryContract = await deployFactory(randomAccount.address);
    routerContract = await deployRouter(factoryContract.address);
    routerAggregatorContract = await deployRouterAggregator(
      factoryContract.address
    );
    pathFinderContract = await deployPathFinder(
      routerAggregatorContract.address,
      USDT.address,
      USDC.address,
      DAI.address,
      WETH.address
    );

    await initializePathFinderPairs(
      factoryContract,
      routerContract,
      token0,
      token1,
      USDT,
      USDC,
      DAI,
      WETH,
      randomAccount,
      user1Account
    );
  });

  it("Should find non direct paths successfully", async () => {
    const path = await findPath(
      pathFinderContract,
      routerAggregatorContract,
      2,
      token0,
      token1
    );
    console.log("Non Direct Path Found:", path);
    assert(path.length > 2);
  });

  it("Should find direct paths successfully", async () => {
    await addLiquidity(
      user1Account,
      routerContract,
      token0,
      token1,
      20,
      40,
      user1Account.address,
      Math.round(Date.now() / 1000) + 60 * 15
    );

    const path = await findPath(
      pathFinderContract,
      routerAggregatorContract,
      2,
      token0,
      token1
    );
    console.log("Direct Path Found:", path);
    assert(path.length === 2);
  });

  it("Should fail to find path if it does not have liquidity", async () => {
    const path = await findPath(
      pathFinderContract,
      routerAggregatorContract,
      2,
      token0,
      token2
    );
    console.log("No Path Found:", path);
    assert(path.length === 0);
  });
});
