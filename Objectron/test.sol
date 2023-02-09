// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import {DefaultOperatorFilterer} from "./DefaultOperatorFilterer.sol";

contract ObjectronTest is DefaultOperatorFilterer, AccessControl, ERC1155URIStorage {

    using Strings for string;

    string public name = "0bjectr0n";
    string public symbol = "0bjectr0n";

    bytes32 public constant URI_SETTER_ROLE = keccak256("URI_SETTER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor() ERC1155("") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(URI_SETTER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        // _setBaseURI("ipfs://QmRoQtYEM6wkEXmL9PGf7qwWHR8Jrzc2oBN7snTgfFAjFB/");
        _setURI("ipfs://QmRoQtYEM6wkEXmL9PGf7qwWHR8Jrzc2oBN7snTgfFAjFB/2.json");
        mint(msg.sender, 2, 2, "");
    }

    function setApprovalForAll(address operator, bool approved) public override onlyAllowedOperatorApproval(operator) {
        super.setApprovalForAll(operator, approved);
    }

    // function uri(uint256 id) external view virtual override(ERC1155) returns (string memory) {
    //     return super.uri(id);
    // }

    function setBaseURI(string memory uri_) external onlyRole(URI_SETTER_ROLE) {
        _setBaseURI(uri_);
    }

    function setURI(string memory newuri) public onlyRole(URI_SETTER_ROLE) {
        _setURI(newuri);
    }

    function mint(address account, uint256 id, uint256 amount, bytes memory data)
        public
        onlyRole(MINTER_ROLE)
    {
        _mint(account, id, amount, data);
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        public
        onlyRole(MINTER_ROLE)
    {
        _mintBatch(to, ids, amounts, data);
    }

    // The following functions are overrides required by Solidity.


    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155, AccessControl)
        returns (bool)
    {
        // if(interfaceId == 0xfa72c5f5) {}
        return ERC1155.supportsInterface(interfaceId);
    }
}
