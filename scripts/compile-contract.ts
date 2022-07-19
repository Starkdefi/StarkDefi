import hardhat from "hardhat";

async function main() {
  await hardhat.run("starknet-compile", {
    paths: ["contracts"],
  });
}

main()
  .then(() => {
    console.log("Successfully compiled contracts");
    process.exitCode = 0;
  })
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
