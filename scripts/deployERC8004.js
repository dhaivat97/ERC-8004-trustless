const hre = require("hardhat");

async function main() {
  console.log("Deploying ERC-8004 Trustless Agent Registry...");

  const TrustlessAgentRegistry = await hre.ethers.getContractFactory("TrustlessAgentRegistry");
  const registry = await TrustlessAgentRegistry.deploy();

  await registry.deployed();

  console.log("✅ ERC-8004 Registry deployed to:", registry.address);
  console.log("Save this address!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });