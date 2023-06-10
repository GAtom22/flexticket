// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

// This is a smart contract that inherits from ERC721 and Ownable
// and represents the event tickets as NFTs
contract EventTicket is ERC721, Ownable {
  using Counters for Counters.Counter;
  Counters.Counter private _tokenIdCounter; // Counter for assigning unique token ids
  uint256 public maxSupply; // Maximum supply of tickets that can be minted
  string public baseURI; // Base URI for generating metadata for each token

  constructor(
    string memory name,
    string memory symbol,
    uint256 _maxSupply,
    string memory _uri
  ) ERC721(name, symbol) {
    maxSupply = _maxSupply;
    baseURI = _uri;
  }

  // Function for minting a new token and assigning it to a specified address (the buyer)
  function mint(address to) public onlyOwner returns (uint256) {
    require(_tokenIdCounter.current() < maxSupply, "Maximum supply reached");
    _tokenIdCounter.increment();
    uint256 newTokenId = _tokenIdCounter.current();
    _safeMint(to, newTokenId);
    return newTokenId;
  }

  // Function for updating the base URI used for generating metadata for each token
  function updateBaseURI(string memory _newURI) public onlyOwner returns (string memory) {
    baseURI = _newURI;
    return baseURI;
  }

  // Internal function to get the base URI used for generating metadata for each token
  function _baseURI() internal view virtual override returns (string memory) {
    return baseURI;
  }
}
