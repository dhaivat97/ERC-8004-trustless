const hre = require("hardhat");

async function main() {
  console.log("Registering Your First Agent...");

  // Your deployed contract address
  const CONTRACT_ADDRESS = "0x1f6e834b22C8913A4AbC396264BC6082817a4DFf";
  
  // Agent information
  const AGENT_DOMAIN = "test-agent.example.com";
  const AGENT_CARD_URI = "https://test-agent.example.com/.well-known/agent-card.json"; // Change this to your domain

  // Get signer
  const [signer] = await hre.ethers.getSigners();
  console.log("Your address:", signer.address);
  console.log("Balance:", hre.ethers.utils.formatEther(await signer.getBalance()), "ETH\n");

  // Get contract instance
  const TrustlessAgentRegistry = await hre.ethers.getContractFactory("TrustlessAgentRegistry");
  const registry = await TrustlessAgentRegistry.attach(CONTRACT_ADDRESS);

  // Check if already registered
  console.log("Checking if you're already registered...");
  const isRegistered = await registry.isRegistered(signer.address);
  
  if (isRegistered) {
    const agentId = await registry.addressToAgentId(signer.address);
    console.log("You're already registered!");
    console.log("Your Agent ID:", agentId.toString());
    
    const agent = await registry.agents(agentId);
    console.log("   Domain:", agent.agentDomain);
    console.log("   Card URI:", agent.agentCardURI);
    console.log("Use this Agent ID for future interactions!");
    return;
  }

  console.log("Not registered yet. Proceeding with registration...\n");

  // Register agent
  console.log("Registration Details:");
  console.log("   Domain:", AGENT_DOMAIN);
  console.log("   Card URI:", AGENT_CARD_URI);
  console.log("");

  console.log("Sending registration transaction...");
  const tx = await registry.registerAgent(AGENT_DOMAIN, AGENT_CARD_URI);
  
  console.log("Waiting for confirmation...");
  console.log("   Transaction hash:", tx.hash);
  
  const receipt = await tx.wait();
  
  // Get agent ID from event
  const event = receipt.events.find(e => e.event === "AgentRegistered");
  const agentId = event.args.agentId;
  
  console.log("SUCCESS! Agent Registered!");
  console.log("Your Agent ID:", agentId.toString());
  console.log("Domain:", AGENT_DOMAIN);
  console.log("Card URI:", AGENT_CARD_URI);
  console.log("Gas used:", receipt.gasUsed.toString());
  console.log("Transaction:", `https://sepolia.etherscan.io/tx/${tx.hash}`);

  console.log("Next Steps:");
  console.log("1. Your NFT (Agent ID", agentId.toString() + ") has been minted to your address");
  console.log("2. Update your agent card with this Agent ID");
  console.log("3. You can now receive feedback and validations");
  console.log("4. Other agents can discover you via the registry");
  
  console.log("To view your agent:");
  console.log(`registry.getAgent(${agentId.toString()})`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });