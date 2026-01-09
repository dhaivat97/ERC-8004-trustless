// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title ERC-8004 Trustless Agent Registry
 * @notice Complete implementation with Identity, Reputation, and Validation registries
 * @dev Extends your existing contract to be ERC-8004 compliant
 */
contract TrustlessAgentRegistry is ERC721URIStorage, Ownable {
    using MessageHashUtils for bytes32;

    // ============ State Variables ============
    
    uint256 private lastId = 0;
    
    // Identity Registry: Maps AgentID to Agent metadata
    struct AgentIdentity {
        uint256 agentId;
        address agentAddress;
        string agentDomain;
        string agentCardURI; // Points to /.well-known/agent-card.json
        uint256 registeredAt;
        bool active;
    }
    
    mapping(uint256 => AgentIdentity) public agents;
    mapping(address => uint256) public addressToAgentId;
    
    // Reputation Registry: Feedback system
    struct FeedbackEntry {
        uint256 feedbackId;
        uint256 serverAgentId;  // The agent being reviewed
        uint256 clientAgentId;  // The agent giving feedback
        string dataHash;        // Hash of the full feedback data (stored off-chain)
        string feedbackURI;     // Link to full feedback (IPFS, etc.)
        uint256 timestamp;
        bytes signature;        // Server's authorization signature
        bool revoked;
    }
    
    uint256 private lastFeedbackId = 0;
    mapping(uint256 => FeedbackEntry) public feedbacks;
    mapping(uint256 => uint256[]) public agentFeedbacks; // AgentID -> Feedback IDs
    
    // Validation Registry: Third-party validation results
    struct ValidationEntry {
        uint256 validationId;
        uint256 agentId;        // Agent being validated
        address validator;      // Who validated
        string requestHash;     // Reference to the task being validated
        uint8 resultCode;       // 0=pass, 1=fail, 2=disputed, etc.
        string evidenceURI;     // Link to proof (zkML, TEE attestation, etc.)
        string tag;             // Optional category/type
        uint256 timestamp;
    }
    
    uint256 private lastValidationId = 0;
    mapping(uint256 => ValidationEntry) public validations;
    mapping(uint256 => uint256[]) public agentValidations; // AgentID -> Validation IDs
    
    // ============ Events ============
    
    event AgentRegistered(
        uint256 indexed agentId,
        address indexed agentAddress,
        string agentDomain,
        string agentCardURI
    );
    
    event AgentUpdated(
        uint256 indexed agentId,
        string agentCardURI
    );
    
    event FeedbackSubmitted(
        uint256 indexed feedbackId,
        uint256 indexed serverAgentId,
        uint256 indexed clientAgentId,
        string dataHash,
        string feedbackURI
    );
    
    event FeedbackRevoked(
        uint256 indexed feedbackId
    );
    
    event ValidationSubmitted(
        uint256 indexed validationId,
        uint256 indexed agentId,
        address indexed validator,
        uint8 resultCode,
        string evidenceURI
    );

    // ============ Constructor ============
    
    constructor() ERC721("TrustlessAgent", "TAG") Ownable(msg.sender) {}

    // ============ Identity Registry Functions ============
    
    /**
     * @notice Register a new agent with identity
     * @param agentDomain The domain where agent card is hosted
     * @param agentCardURI URI to the agent's card (/.well-known/agent-card.json)
     * @return agentId The unique ID assigned to this agent
     */
    function registerAgent(
        string memory agentDomain,
        string memory agentCardURI
    ) external returns (uint256 agentId) {
        require(addressToAgentId[msg.sender] == 0, "Address already registered");
        require(bytes(agentDomain).length > 0, "Domain required");
        
        agentId = lastId++;
        
        // Mint NFT as identity token
        _safeMint(msg.sender, agentId);
        _setTokenURI(agentId, agentCardURI);
        
        // Store identity
        agents[agentId] = AgentIdentity({
            agentId: agentId,
            agentAddress: msg.sender,
            agentDomain: agentDomain,
            agentCardURI: agentCardURI,
            registeredAt: block.timestamp,
            active: true
        });
        
        addressToAgentId[msg.sender] = agentId;
        
        emit AgentRegistered(agentId, msg.sender, agentDomain, agentCardURI);
    }
    
    /**
     * @notice Update agent's card URI
     * @param agentId The agent to update
     * @param newAgentCardURI New URI for the agent card
     */
    function updateAgentCard(uint256 agentId, string memory newAgentCardURI) external {
        require(agents[agentId].agentAddress == msg.sender, "Not agent owner");
        require(agents[agentId].active, "Agent not active");
        
        agents[agentId].agentCardURI = newAgentCardURI;
        _setTokenURI(agentId, newAgentCardURI);
        
        emit AgentUpdated(agentId, newAgentCardURI);
    }
    
    /**
     * @notice Get agent identity by ID
     */
    function getAgent(uint256 agentId) external view returns (AgentIdentity memory) {
        require(agents[agentId].active, "Agent not found");
        return agents[agentId];
    }

    // ============ Reputation Registry Functions ============
    
    /**
     * @notice Submit feedback for an agent (with server authorization)
     * @param serverAgentId The agent being reviewed
     * @param dataHash Hash of the complete feedback data
     * @param feedbackURI Link to full feedback (IPFS, etc.)
     * @param signature Server agent's signature authorizing this feedback
     */
    function submitFeedback(
        uint256 serverAgentId,
        string memory dataHash,
        string memory feedbackURI,
        bytes memory signature
    ) external returns (uint256 feedbackId) {
        uint256 clientAgentId = addressToAgentId[msg.sender];
        require(clientAgentId != 0, "Client not registered");
        require(agents[serverAgentId].active, "Server agent not found");
        
        // Verify signature (simplified - in production, verify proper EIP-191 format)
        bytes32 messageHash = keccak256(abi.encodePacked(
            serverAgentId,
            clientAgentId,
            dataHash
        ));
        bytes32 ethSignedHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        address signer = recoverSigner(ethSignedHash, signature);
        require(signer == agents[serverAgentId].agentAddress, "Invalid signature");
        
        feedbackId = lastFeedbackId++;
        
        feedbacks[feedbackId] = FeedbackEntry({
            feedbackId: feedbackId,
            serverAgentId: serverAgentId,
            clientAgentId: clientAgentId,
            dataHash: dataHash,
            feedbackURI: feedbackURI,
            timestamp: block.timestamp,
            signature: signature,
            revoked: false
        });
        
        agentFeedbacks[serverAgentId].push(feedbackId);
        
        emit FeedbackSubmitted(feedbackId, serverAgentId, clientAgentId, dataHash, feedbackURI);
    }
    
    /**
     * @notice Revoke feedback (can only be done by client who submitted it)
     * @param feedbackId The feedback to revoke
     */
    function revokeFeedback(uint256 feedbackId) external {
        FeedbackEntry storage feedback = feedbacks[feedbackId];
        require(
            agents[feedback.clientAgentId].agentAddress == msg.sender,
            "Not feedback author"
        );
        require(!feedback.revoked, "Already revoked");
        
        feedback.revoked = true;
        emit FeedbackRevoked(feedbackId);
    }
    
    /**
     * @notice Get all feedback for an agent
     * @param agentId The agent to query
     * @return Array of feedback IDs
     */
    function getAgentFeedback(uint256 agentId) external view returns (uint256[] memory) {
        return agentFeedbacks[agentId];
    }
    
    /**
     * @notice Get specific feedback entry
     */
    function getFeedback(uint256 feedbackId) external view returns (FeedbackEntry memory) {
        return feedbacks[feedbackId];
    }

    // ============ Validation Registry Functions ============
    
    /**
     * @notice Submit validation result for an agent's task
     * @param agentId The agent whose task was validated
     * @param requestHash Hash/ID of the request being validated
     * @param resultCode Result: 0=pass, 1=fail, 2=disputed
     * @param evidenceURI Link to proof (zkML, TEE attestation, re-execution trace)
     * @param tag Optional category/type of validation
     */
    function submitValidation(
        uint256 agentId,
        string memory requestHash,
        uint8 resultCode,
        string memory evidenceURI,
        string memory tag
    ) external returns (uint256 validationId) {
        require(agents[agentId].active, "Agent not found");
        require(resultCode <= 2, "Invalid result code");
        
        validationId = lastValidationId++;
        
        validations[validationId] = ValidationEntry({
            validationId: validationId,
            agentId: agentId,
            validator: msg.sender,
            requestHash: requestHash,
            resultCode: resultCode,
            evidenceURI: evidenceURI,
            tag: tag,
            timestamp: block.timestamp
        });
        
        agentValidations[agentId].push(validationId);
        
        emit ValidationSubmitted(validationId, agentId, msg.sender, resultCode, evidenceURI);
    }
    
    /**
     * @notice Get all validations for an agent
     * @param agentId The agent to query
     * @return Array of validation IDs
     */
    function getAgentValidations(uint256 agentId) external view returns (uint256[] memory) {
        return agentValidations[agentId];
    }
    
    /**
     * @notice Get specific validation entry
     */
    function getValidation(uint256 validationId) external view returns (ValidationEntry memory) {
        return validations[validationId];
    }
    
    // ============ Helper Functions ============
    
    /**
     * @notice Get total number of registered agents
     */
    function getTotalAgents() external view returns (uint256) {
        return lastId;
    }
    
    /**
     * @notice Check if an address is registered as an agent
     */
    function isRegistered(address account) external view returns (bool) {
        return addressToAgentId[account] != 0;
    }
    
    /**
     * @notice Recover signer from signature
     * @dev Internal helper function for signature verification
     */
    function recoverSigner(bytes32 ethSignedHash, bytes memory signature) internal pure returns (address) {
        require(signature.length == 65, "Invalid signature length");
        
        bytes32 r;
        bytes32 s;
        uint8 v;
        
        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }
        
        return ecrecover(ethSignedHash, v, r, s);
    }
}