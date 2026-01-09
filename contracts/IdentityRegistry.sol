// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract IdentityRegistry is ERC721URIStorage, Ownable {

    uint256 private lastId = 0;

    event Registered(uint256 indexed agentId, string tokenURI, address indexed owner);

    constructor() ERC721("AgentIdentity", "AID") Ownable(msg.sender) {}

    function register(string memory tokenUri) external returns (uint256 agentId) {
        agentId = lastId++;
        _safeMint(msg.sender, agentId);
        _setTokenURI(agentId, tokenUri);
        emit Registered(agentId, tokenUri, msg.sender);
    }
}
