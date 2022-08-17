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
  addressToFelt,
  uintToBigInt,
  approve,
  tokenDecimals,
  swapTokensForExactTokens,
  getEventData,
  swapExactTokensForTokens,
  MAX_INT,
  // eslint-disable-next-line node/no-missing-import
} from "./utils";

describe("Swap Tokens Test", function () {
  this.timeout(TIMEOUT); // 15 mins

  let user1Account: Account;
  let user2Account: Account;
  let randomAccount: Account;
  let token0Contract: StarknetContract;
  let token1Contract: StarknetContract;
  let token2Contract: StarknetContract;
  let factoryContract: StarknetContract;
  let routerContract: StarknetContract;
  let pair0Contract: StarknetContract;
  let pair1Contract: StarknetContract;

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

    randomAccount = await starknet.getAccountFromAddress(
      preDeployedAccounts[2].address,
      preDeployedAccounts[2].private_key,
      "OpenZeppelin"
    );

    console.log("Random Account", randomAccount.address);

    token0Contract = await deployToken(randomAccount, "Token 0", "TKN0");
    token1Contract = await deployToken(randomAccount, "Token 1", "TKN1");
    token2Contract = await deployToken(randomAccount, "Token 2", "TKN2");
    factoryContract = await deployFactory(randomAccount.address);
    routerContract = await deployRouter(factoryContract.address);
    const { pair0, pair1 } = await initializePairs(
      factoryContract,
      routerContract,
      token0Contract,
      token1Contract,
      token2Contract,
      randomAccount,
      user1Account
    );
    pair0Contract = pair0;
    pair1Contract = pair1;
    await mintTokensToRandomUser(
      randomAccount,
      token0Contract,
      token1Contract,
      token2Contract,
      100,
      user2Account,
      routerContract
    );
  });

  it("Should swap exact tokens (0) for tokens (1)", async () => {
    const { balance: user2Token0InitialBalance } = await user2Account.call(
      token0Contract,
      "balanceOf",
      {
        account: user2Account.address,
      }
    );

    const { balance: user2Token1InitialBalance } = await user2Account.call(
      token1Contract,
      "balanceOf",
      {
        account: user2Account.address,
      }
    );

    const { token0 } = await user2Account.call(routerContract, "sort_tokens", {
      tokenA: token0Contract.address,
      tokenB: token1Contract.address,
    });

    let reserves = await user1Account.call(pair0Contract, "get_reserves");
    let reserve0Initial, reserve1Initial;

    if (token0 === addressToFelt(token0Contract.address)) {
      reserve0Initial = uintToBigInt(reserves.reserve0);
      reserve1Initial = uintToBigInt(reserves.reserve1);
    } else {
      reserve0Initial = uintToBigInt(reserves.reserve1);
      reserve1Initial = uintToBigInt(reserves.reserve0);
    }

    console.log(
      "Initial balances: ",
      uintToBigInt(user2Token0InitialBalance),
      uintToBigInt(user2Token1InitialBalance),
      reserve0Initial,
      reserve1Initial
    );

    // Approve required tokens to be spent by router
    const token0Amount = ethers.utils.parseUnits(
      "12",
      await tokenDecimals(user2Account, token0Contract)
    );
    await approve(
      user2Account,
      token0Contract,
      token0Amount,
      routerContract.address
    );

    // Swap
    const txHash = await swapExactTokensForTokens(
      user2Account,
      routerContract,
      token0Amount,
      0n,
      [token0Contract.address, token1Contract.address],
      user2Account.address,
      Math.round(Date.now() / 1000) + 60 * 15
    );

    // Check events are emitted
    const eventData = await getEventData(txHash, pair0Contract, "Swap");
    assert(eventData.length !== 0);

    const { balance: user2Token0FinalBalance } = await user2Account.call(
      token0Contract,
      "balanceOf",
      {
        account: user2Account.address,
      }
    );

    const { balance: user2Token1FinalBalance } = await user2Account.call(
      token1Contract,
      "balanceOf",
      {
        account: user2Account.address,
      }
    );

    reserves = await user1Account.call(pair0Contract, "get_reserves");
    let reserve0Final, reserve1Final;

    if (token0 === addressToFelt(token0Contract.address)) {
      reserve0Final = uintToBigInt(reserves.reserve0);
      reserve1Final = uintToBigInt(reserves.reserve1);
    } else {
      reserve0Final = uintToBigInt(reserves.reserve1);
      reserve1Final = uintToBigInt(reserves.reserve0);
    }

    console.log(
      "Final balances: ",
      uintToBigInt(user2Token0FinalBalance),
      uintToBigInt(user2Token1FinalBalance),
      reserve0Final,
      reserve1Final
    );

    const expectedAmount =
      (token0Amount.toBigInt() * reserve1Initial) /
      (token0Amount.toBigInt() + reserve0Initial);
    console.log("Expected amount for token 1:", expectedAmount);

    console.log(
      "Swap event data:",
      uintToBigInt(eventData[0].amount0In),
      uintToBigInt(eventData[0].amount0Out),
      uintToBigInt(eventData[0].amount1In),
      uintToBigInt(eventData[0].amount1Out)
    );

    const token1AmountOut =
      uintToBigInt(eventData[0].amount1Out) !== 0n
        ? uintToBigInt(eventData[0].amount1Out)
        : uintToBigInt(eventData[0].amount0Out);

    // console.log("Fee taken:", ((expectedAmount * 100000n) / token1AmountOut) - 100000n);

    assert(
      uintToBigInt(user2Token0InitialBalance) -
        uintToBigInt(user2Token0FinalBalance) ===
        token0Amount.toBigInt()
    );

    assert(
      uintToBigInt(user2Token1FinalBalance) -
        uintToBigInt(user2Token1InitialBalance) ===
        token1AmountOut
    );

    // assert(
    //   uintToBigInt(user2Token1FinalBalance) -
    //     uintToBigInt(user2Token1InitialBalance) ===
    //     (BigInt(expectedAmount) * 997n) / 1000n
    // );
  });

  it("Should swap tokens (0) for exact tokens (1)", async () => {
    const { balance: user2Token0InitialBalance } = await user2Account.call(
      token0Contract,
      "balanceOf",
      {
        account: user2Account.address,
      }
    );

    const { balance: user2Token1InitialBalance } = await user2Account.call(
      token1Contract,
      "balanceOf",
      {
        account: user2Account.address,
      }
    );

    const { token0 } = await user2Account.call(routerContract, "sort_tokens", {
      tokenA: token0Contract.address,
      tokenB: token1Contract.address,
    });

    let reserves = await user1Account.call(pair0Contract, "get_reserves");
    let reserve0Initial, reserve1Initial;

    if (token0 === addressToFelt(token0Contract.address)) {
      reserve0Initial = uintToBigInt(reserves.reserve0);
      reserve1Initial = uintToBigInt(reserves.reserve1);
    } else {
      reserve0Initial = uintToBigInt(reserves.reserve1);
      reserve1Initial = uintToBigInt(reserves.reserve0);
    }

    console.log(
      "Initial balances: ",
      uintToBigInt(user2Token0InitialBalance),
      uintToBigInt(user2Token1InitialBalance),
      reserve0Initial,
      reserve1Initial
    );

    // Approve required tokens to be spent by router
    await approve(
      user2Account,
      token0Contract,
      MAX_INT,
      routerContract.address
    );

    const token1Amount = ethers.utils.parseUnits(
      "2",
      await tokenDecimals(user2Account, token1Contract)
    );

    // Swap
    const txHash = await swapTokensForExactTokens(
      user2Account,
      routerContract,
      token1Amount,
      MAX_INT,
      [token0Contract.address, token1Contract.address],
      user2Account.address,
      Math.round(Date.now() / 1000) + 60 * 15
    );

    // Check events are emitted
    const eventData = await getEventData(txHash, pair0Contract, "Swap");
    assert(eventData.length !== 0);

    const { balance: user2Token0FinalBalance } = await user2Account.call(
      token0Contract,
      "balanceOf",
      {
        account: user2Account.address,
      }
    );

    const { balance: user2Token1FinalBalance } = await user2Account.call(
      token1Contract,
      "balanceOf",
      {
        account: user2Account.address,
      }
    );

    reserves = await user1Account.call(pair0Contract, "get_reserves");
    let reserve0Final, reserve1Final;

    if (token0 === addressToFelt(token0Contract.address)) {
      reserve0Final = uintToBigInt(reserves.reserve0);
      reserve1Final = uintToBigInt(reserves.reserve1);
    } else {
      reserve0Final = uintToBigInt(reserves.reserve1);
      reserve1Final = uintToBigInt(reserves.reserve0);
    }

    console.log(
      "Final balances: ",
      uintToBigInt(user2Token0FinalBalance),
      uintToBigInt(user2Token1FinalBalance),
      reserve0Final,
      reserve1Final
    );

    const expectedAmount =
      (token1Amount.toBigInt() * reserve0Initial) /
      (reserve1Initial - token1Amount.toBigInt());
    console.log("Expected amount for token 0:", expectedAmount);

    console.log(
      "Swap event data:",
      uintToBigInt(eventData[0].amount0In),
      uintToBigInt(eventData[0].amount0Out),
      uintToBigInt(eventData[0].amount1In),
      uintToBigInt(eventData[0].amount1Out)
    );

    const token0AmountIn =
      uintToBigInt(eventData[0].amount0In) !== 0n
        ? uintToBigInt(eventData[0].amount0In)
        : uintToBigInt(eventData[0].amount1In);

    // console.log("Fee taken:", ((token0AmountIn * 100000n) / expectedAmount) - 100000n);

    assert(
      uintToBigInt(user2Token0InitialBalance) -
        uintToBigInt(user2Token0FinalBalance) ===
        token0AmountIn
    );

    assert(
      uintToBigInt(user2Token1FinalBalance) -
        uintToBigInt(user2Token1InitialBalance) ===
        token1Amount.toBigInt()
    );

    // assert(
    //   uintToBigInt(user2Token1FinalBalance) -
    //     uintToBigInt(user2Token1InitialBalance) ===
    //     (BigInt(expectedAmount) * 997n) / 1000n
    // );
  });

  it("Should swap exact tokens (0) for tokens (2)", async () => {
    const { balance: user2Token0InitialBalance } = await user2Account.call(
      token0Contract,
      "balanceOf",
      {
        account: user2Account.address,
      }
    );

    const { balance: user2Token2InitialBalance } = await user2Account.call(
      token2Contract,
      "balanceOf",
      {
        account: user2Account.address,
      }
    );

    const { token0: token00 } = await user2Account.call(
      routerContract,
      "sort_tokens",
      {
        tokenA: token0Contract.address,
        tokenB: token1Contract.address,
      }
    );

    let reserves = await user1Account.call(pair0Contract, "get_reserves");
    let reserve00Initial, reserve10Initial;

    if (token00 === addressToFelt(token0Contract.address)) {
      reserve00Initial = uintToBigInt(reserves.reserve0);
      reserve10Initial = uintToBigInt(reserves.reserve1);
    } else {
      reserve00Initial = uintToBigInt(reserves.reserve1);
      reserve10Initial = uintToBigInt(reserves.reserve0);
    }

    const { token0: token01 } = await user2Account.call(
      routerContract,
      "sort_tokens",
      {
        tokenA: token1Contract.address,
        tokenB: token2Contract.address,
      }
    );

    reserves = await user1Account.call(pair1Contract, "get_reserves");
    let reserve01Initial, reserve11Initial;

    if (token01 === addressToFelt(token1Contract.address)) {
      reserve01Initial = uintToBigInt(reserves.reserve0);
      reserve11Initial = uintToBigInt(reserves.reserve1);
    } else {
      reserve01Initial = uintToBigInt(reserves.reserve1);
      reserve11Initial = uintToBigInt(reserves.reserve0);
    }

    console.log(
      "Initial balances: ",
      uintToBigInt(user2Token0InitialBalance),
      uintToBigInt(user2Token2InitialBalance),
      reserve00Initial,
      reserve10Initial,
      reserve01Initial,
      reserve11Initial
    );

    // Approve required tokens to be spent by router
    const token0Amount = ethers.utils.parseUnits(
      "5",
      await tokenDecimals(user2Account, token0Contract)
    );
    await approve(
      user2Account,
      token0Contract,
      token0Amount,
      routerContract.address
    );

    // Swap
    const txHash = await swapExactTokensForTokens(
      user2Account,
      routerContract,
      token0Amount,
      0n,
      [token0Contract.address, token1Contract.address, token2Contract.address],
      user2Account.address,
      Math.round(Date.now() / 1000) + 60 * 15
    );

    // Check events are emitted
    const eventData = await getEventData(txHash, pair0Contract, "Swap");
    assert(eventData.length !== 0);

    const { balance: user2Token0FinalBalance } = await user2Account.call(
      token0Contract,
      "balanceOf",
      {
        account: user2Account.address,
      }
    );

    const { balance: user2Token2FinalBalance } = await user2Account.call(
      token2Contract,
      "balanceOf",
      {
        account: user2Account.address,
      }
    );

    reserves = await user1Account.call(pair0Contract, "get_reserves");
    let reserve00Final, reserve10Final;

    if (token00 === addressToFelt(token0Contract.address)) {
      reserve00Final = uintToBigInt(reserves.reserve0);
      reserve10Final = uintToBigInt(reserves.reserve1);
    } else {
      reserve00Final = uintToBigInt(reserves.reserve1);
      reserve10Final = uintToBigInt(reserves.reserve0);
    }

    reserves = await user1Account.call(pair1Contract, "get_reserves");
    let reserve01Final, reserve11Final;

    if (token01 === addressToFelt(token1Contract.address)) {
      reserve01Final = uintToBigInt(reserves.reserve0);
      reserve11Final = uintToBigInt(reserves.reserve1);
    } else {
      reserve01Final = uintToBigInt(reserves.reserve1);
      reserve11Final = uintToBigInt(reserves.reserve0);
    }

    console.log(
      "Final balances: ",
      uintToBigInt(user2Token0FinalBalance),
      uintToBigInt(user2Token2FinalBalance),
      reserve00Final,
      reserve10Final,
      reserve01Final,
      reserve11Final
    );

    const expectedAmount1 =
      (token0Amount.toBigInt() * reserve10Initial) /
      (token0Amount.toBigInt() + reserve00Initial);
    console.log("Expected amount for token 1:", expectedAmount1);

    const expectedAmount2 =
      (expectedAmount1 * reserve11Initial) /
      (expectedAmount1 + reserve01Initial);
    console.log("Expected amount for token 2:", expectedAmount2);

    for (let i = 0; i < eventData.length; i++) {
      console.log(
        "Swap event data",
        i + 1,
        ":",
        uintToBigInt(eventData[i].amount0In),
        uintToBigInt(eventData[i].amount0Out),
        uintToBigInt(eventData[i].amount1In),
        uintToBigInt(eventData[i].amount1Out)
      );
    }

    // const token1AmountOut =
    //   uintToBigInt(eventData[0].amount1Out) !== 0n
    //     ? uintToBigInt(eventData[0].amount1Out)
    //     : uintToBigInt(eventData[0].amount0Out);

    const token2AmountOut =
      uintToBigInt(eventData[1].amount1Out) !== 0n
        ? uintToBigInt(eventData[1].amount1Out)
        : uintToBigInt(eventData[1].amount0Out);

    // console.log("Fee 1 taken:", ((expectedAmount1 * 100000n) / token1AmountOut) - 100000n);
    // console.log("Fee 2 taken:", ((expectedAmount2 * 100000n) / token2AmountOut) - 100000n);

    assert(
      uintToBigInt(user2Token0InitialBalance) -
        uintToBigInt(user2Token0FinalBalance) ===
        token0Amount.toBigInt()
    );

    assert(
      uintToBigInt(user2Token2FinalBalance) -
        uintToBigInt(user2Token2InitialBalance) ===
        token2AmountOut
    );

    // assert(
    //   uintToBigInt(user2Token1FinalBalance) -
    //     uintToBigInt(user2Token1InitialBalance) ===
    //     (BigInt(expectedAmount) * 997n) / 1000n
    // );
  });

  it("Should swap exact tokens (1) for tokens (0)", async () => {
    const { balance: user2Token0InitialBalance } = await user2Account.call(
      token0Contract,
      "balanceOf",
      {
        account: user2Account.address,
      }
    );

    const { balance: user2Token1InitialBalance } = await user2Account.call(
      token1Contract,
      "balanceOf",
      {
        account: user2Account.address,
      }
    );

    const { token0 } = await user2Account.call(routerContract, "sort_tokens", {
      tokenA: token0Contract.address,
      tokenB: token1Contract.address,
    });

    let reserves = await user1Account.call(pair0Contract, "get_reserves");
    let reserve0Initial, reserve1Initial;

    if (token0 === addressToFelt(token0Contract.address)) {
      reserve0Initial = uintToBigInt(reserves.reserve0);
      reserve1Initial = uintToBigInt(reserves.reserve1);
    } else {
      reserve0Initial = uintToBigInt(reserves.reserve1);
      reserve1Initial = uintToBigInt(reserves.reserve0);
    }

    console.log(
      "Initial balances: ",
      uintToBigInt(user2Token0InitialBalance),
      uintToBigInt(user2Token1InitialBalance),
      reserve0Initial,
      reserve1Initial
    );

    // Approve required tokens to be spent by router
    const token1Amount = ethers.utils.parseUnits(
      "7",
      await tokenDecimals(user2Account, token1Contract)
    );
    await approve(
      user2Account,
      token1Contract,
      token1Amount,
      routerContract.address
    );

    // Swap
    const txHash = await swapExactTokensForTokens(
      user2Account,
      routerContract,
      token1Amount,
      0n,
      [token1Contract.address, token0Contract.address],
      user2Account.address,
      Math.round(Date.now() / 1000) + 60 * 15
    );

    // Check events are emitted
    const eventData = await getEventData(txHash, pair0Contract, "Swap");
    assert(eventData.length !== 0);

    const { balance: user2Token0FinalBalance } = await user2Account.call(
      token0Contract,
      "balanceOf",
      {
        account: user2Account.address,
      }
    );

    const { balance: user2Token1FinalBalance } = await user2Account.call(
      token1Contract,
      "balanceOf",
      {
        account: user2Account.address,
      }
    );

    reserves = await user1Account.call(pair0Contract, "get_reserves");
    let reserve0Final, reserve1Final;

    if (token0 === addressToFelt(token0Contract.address)) {
      reserve0Final = uintToBigInt(reserves.reserve0);
      reserve1Final = uintToBigInt(reserves.reserve1);
    } else {
      reserve0Final = uintToBigInt(reserves.reserve1);
      reserve1Final = uintToBigInt(reserves.reserve0);
    }

    console.log(
      "Final balances: ",
      uintToBigInt(user2Token0FinalBalance),
      uintToBigInt(user2Token1FinalBalance),
      reserve0Final,
      reserve1Final
    );

    const expectedAmount =
      (token1Amount.toBigInt() * reserve0Initial) /
      (token1Amount.toBigInt() + reserve1Initial);
    console.log("Expected amount for token 0:", expectedAmount);

    console.log(
      "Swap event data:",
      uintToBigInt(eventData[0].amount0In),
      uintToBigInt(eventData[0].amount0Out),
      uintToBigInt(eventData[0].amount1In),
      uintToBigInt(eventData[0].amount1Out)
    );

    const token0AmountOut =
      uintToBigInt(eventData[0].amount1Out) !== 0n
        ? uintToBigInt(eventData[0].amount1Out)
        : uintToBigInt(eventData[0].amount0Out);

    // console.log("Fee taken:", ((expectedAmount * 100000n) / token0AmountOut) - 100000n);

    assert(
      uintToBigInt(user2Token1InitialBalance) -
        uintToBigInt(user2Token1FinalBalance) ===
        token1Amount.toBigInt()
    );

    assert(
      uintToBigInt(user2Token0FinalBalance) -
        uintToBigInt(user2Token0InitialBalance) ===
        token0AmountOut
    );

    // assert(
    //   uintToBigInt(user2Token1FinalBalance) -
    //     uintToBigInt(user2Token1InitialBalance) ===
    //     (BigInt(expectedAmount) * 997n) / 1000n
    // );
  });
});
