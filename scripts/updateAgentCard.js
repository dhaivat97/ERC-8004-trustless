const hre = require("hardhat");

async function main() {
  console.log("Updating Agent Card URI...");

  const CONTRACT_ADDRESS = "0x1f6e834b22C8913A4AbC396264BC6082817a4DFf";
  const AGENT_ID = 0; // Your agent ID
  
  // Your actual GitHub Pages URL
  const NEW_AGENT_CARD_URI = "https://dhaivat97.github.io/agentA-card/.well-known/agent-card.json";

  // Get signer
  const [signer] = await hre.ethers.getSigners();
  console.log("Your address:", signer.address);

  // Get contract
  const TrustlessAgentRegistry = await hre.ethers.getContractFactory("TrustlessAgentRegistry");
  const registry = await TrustlessAgentRegistry.attach(CONTRACT_ADDRESS);

  // Check current card URI
  console.log("Current Agent Info:");
  const agent = await registry.agents(AGENT_ID);
  console.log("   Agent ID:", AGENT_ID);
  console.log("   Current Domain:", agent.agentDomain);
  console.log("   Current Card URI:", agent.agentCardURI);
  console.log("");

  console.log("New Card URI:", NEW_AGENT_CARD_URI);
  console.log("");

  console.log("Sending update transaction...");
  const tx = await registry.updateAgentCard(AGENT_ID, NEW_AGENT_CARD_URI);
  
  console.log("Waiting for confirmation...");
  console.log("   Transaction hash:", tx.hash);
  
  const receipt = await tx.wait();
  
  console.log("\n SUCCESS! Agent Card Updated!");
  console.log("================================================");
  console.log("Agent ID:", AGENT_ID);
  console.log("New Card URI:", NEW_AGENT_CARD_URI);
  console.log("Gas used:", receipt.gasUsed.toString());
  console.log("Transaction:", `https://sepolia.etherscan.io/tx/${tx.hash}`);
  console.log("================================================\n");

  // Verify update
  console.log("Verifying update...");
  const updatedAgent = await registry.agents(AGENT_ID);
  console.log("   Updated Card URI:", updatedAgent.agentCardURI);
  
  console.log("\n Your agent card is now live and linked on-chain!");
  console.log("   Anyone can discover your agent at:", NEW_AGENT_CARD_URI);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });