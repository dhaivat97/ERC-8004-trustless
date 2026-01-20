const hre = require("hardhat");

async function main() {
  const IdentityRegistry = await hre.ethers.getContractFactory("IdentityRegistry");
  const registry = await IdentityRegistry.deploy();

  await registry.deployed(); // <-- ethers v5 method

  console.log("IdentityRegistry deployed at:", registry.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });