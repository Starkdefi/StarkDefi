import { starknet } from "hardhat";

async function main() {
  const contractFactory = await starknet.getContractFactory("contract");
  const contract = await contractFactory.deploy({ initial_balance: 0 });
  console.log("Deployed to:", contract.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
