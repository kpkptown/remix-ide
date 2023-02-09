// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import {Operable} from "./Operable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import {DefaultOperatorFilterer} from "./DefaultOperatorFilterer.sol";

contract Objectron1155 is  DefaultOperatorFilterer, Ownable, Operable, ERC2981, ERC1155URIStorage{

    using Strings for string;

    string public name = "0bjectr0n";
    string public symbol = "0bjectr0n";
    mapping(address => bool) bondedAddress;

    constructor() ERC1155("") {
        _grantOperatorRole(msg.sender);
        _setDefaultRoyalty(msg.sender, 1000);
        _setBaseURI("ipfs://QmRoQtYEM6wkEXmL9PGf7qwWHR8Jrzc2oBN7snTgfFAjFB/");
        initializeNFT(1, "1.json");
    }

    function setApprovalForAll(address operator, bool approved) public override onlyAllowedOperatorApproval(operator) {
        super.setApprovalForAll(operator, approved);
    }

    function setBaseURI(string memory uri_) external onlyOperator {
        _setBaseURI(uri_);
    }

    function setTokenURI(uint256 tokenId, string memory _tokenURI)
        external
        onlyOperator
    {
        _setURI(tokenId, _tokenURI);
    }

    function initializeNFT(uint256 tokenId, string memory _tokenURI)
        public
        onlyOperator
    {
        require(bytes(uri(tokenId)).length == 0, "NFT already exists");
        _mint(msg.sender, tokenId, 1, "");
        _setURI(tokenId, _tokenURI);
    }

    /**
        @dev Mint
    */
    function mint(
        address to,
        uint256 id,
        uint256 amount
    ) public onlyOperator {
        require(bytes(uri(id)).length != 0, "Not initialized");
        _mint(to, id, amount, "");
    }

    function batchMintTo(
        address[] memory list,
        uint256 id,
        uint256[] memory amount
    ) public onlyOperator {
        for (uint256 i = 0; i < list.length; i++) {
            _mint(list[i], id, amount[i], "");
        }
    }

    /**
        @dev Burn
     */
    function burnAdmin(
        address to,
        uint256 id,
        uint256 amount
    ) public onlyOperator {
        _burn(to, id, amount);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, uint256 amount, bytes memory data)
        public
        override
        onlyAllowedOperator(from)
    {
        super.safeTransferFrom(from, to, tokenId, amount, data);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override onlyAllowedOperator(from) {
        super.safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    // function supportsInterface(bytes4 interfaceId) public view virtual override(ERC2981, ERC1155) returns (bool) {
    //     return 
    //         // interfaceId == type(ERC1155).interfaceId ||
    //         // interfaceId == type(ERC1155URIStorage).interfaceId ||
    //         // interfaceId == type(ERC2981).interfaceId ||
    //         Objectron1155.supportsInterface(interfaceId);
    // }

    // function supportsInterface(bytes4 interfaceId) public view virtual override(ERC2981, ERC1155) returns (bool) {
    //     return ERC165.supportsInterface(interfaceId);
    // }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC2981, ERC1155) returns (bool) {
        if (
            interfaceId == 0x780e9d63 ||
            interfaceId == 0x20b4c838 ||
            interfaceId == 0x9a20463a ||
            interfaceId == 0x01ffc9a7
        )
        return true;
            // interfaceId == type(IERC1155).interfaceId ||
            // interfaceId == type(ERC1155URIStorage).interfaceId ||
            // interfaceId == type(ERC2981).interfaceId ||
            // super.supportsInterface(interfaceId);
    }

    /**
     *  @dev Operable Role
     */
    
    function grantOperatorRole(address _candidate) external onlyOwner {
        _grantOperatorRole(_candidate);
    }

    function revokeOperatorRole(address _candidate) external onlyOwner {
        _revokeOperatorRole(_candidate);
    }


    /**
     *  @dev Setting Royalties
     */

    function setDefaultRoyalty(address receiver, uint96 feeNumerator) external onlyOwner { 
        _setDefaultRoyalty( receiver, feeNumerator ); 
    }

    function deleteDefaultRoyalty() external onlyOwner {
        _deleteDefaultRoyalty(); 
    }

    function setTokenRoyalty(uint256 tokenId, address receiver, uint96 feeNumerator) external onlyOwner { 
        _setTokenRoyalty( tokenId, receiver, feeNumerator ); 
    }

    function resetTokenRoyalty(uint256 tokenId) external onlyOwner {
        _resetTokenRoyalty( tokenId );
    }
}