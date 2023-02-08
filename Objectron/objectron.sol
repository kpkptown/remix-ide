// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

interface iTokenURI {
    function tokenURI(uint256 _tokenId) external view returns (string memory);
}

contract objectron is Ownable, ERC721A, ReentrancyGuard, AccessControl {
    constructor(
    ) ERC721A("0bjectr0n", "0bjectr0n") {
        _setupRole(AIRDROP_ROLE      , msg.sender);
    }

    modifier callerIsUser() {
        require(tx.origin == msg.sender, "The caller is another contract.");
        _;
    }

    /** 
    * mint Section
    **/

    uint256 public cost = 0;
    uint256 public maxSupply = 1000;
    uint256 public maxMintAmountPerTransaction = 10;
    bool public paused = false;
    bool public mintCount = true;
    mapping(address => uint256) public publicSaleMintedAmount;
    bytes32 public constant AIRDROP_ROLE = keccak256("AIRDROP_ROLE"); 


    function devMint(uint256 _mintAmount, string memory _newBaseURI) public onlyOwner {
        require(!paused, "the contract is paused");
        require(0 < _mintAmount, "need to mint at least 1 NFT");
        require(_mintAmount <= maxMintAmountPerTransaction, "max mint amount per session exceeded");
        require(totalSupply() + _mintAmount <= maxSupply, "max NFT limit exceeded");
        if(mintCount == true){
            publicSaleMintedAmount[msg.sender] += _mintAmount;
        }
        setBaseURI(_newBaseURI);
        _safeMint(msg.sender, _mintAmount);
    }

    function mint(uint256 _mintAmount) public payable callerIsUser{
        require(!paused, "the contract is paused");
        require(0 < _mintAmount, "need to mint at least 1 NFT");
        require(_mintAmount <= maxMintAmountPerTransaction, "max mint amount per session exceeded");
        require(totalSupply() + _mintAmount <= maxSupply, "max NFT limit exceeded");
        require(cost * _mintAmount <= msg.value, "insufficient funds");
        if(mintCount == true){
            publicSaleMintedAmount[msg.sender] += _mintAmount;
        }
        _safeMint(msg.sender, _mintAmount);
    }  

    function airdropMint(address[] calldata _airdropAddresses , uint256[] memory _UserMintAmount) public {
        require(hasRole(AIRDROP_ROLE, msg.sender), "Caller is not a air dropper");
        uint256 _mintAmount = 0;
        for (uint256 i = 0; i < _UserMintAmount.length; i++) {
            _mintAmount += _UserMintAmount[i];
        }
        require(0 < _mintAmount , "need to mint at least 1 NFT");
        require(totalSupply() + _mintAmount <= maxSupply, "max NFT limit exceeded");
        for (uint256 i = 0; i < _UserMintAmount.length; i++) {
            _safeMint(_airdropAddresses[i], _UserMintAmount[i] );
        }
    }

    /** 
    * URL Section
    **/

    string public baseURI;
    string public baseExtension = ".json";

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;        
    }

    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    function setBaseExtension(string memory _newBaseExtension) public onlyOwner {
        baseExtension = _newBaseExtension;
    }

    /** 
    * Uinterface metadata Section
    **/

    iTokenURI public interfaceOfTokenURI;
    bool public useInterfaceMetadata = false;

    function setInterfaceOfTokenURI(address _address) public onlyOwner() {
        interfaceOfTokenURI = iTokenURI(_address);
    }

    function setUseInterfaceMetadata(bool _useInterfaceMetadata) public onlyOwner() {
        useInterfaceMetadata = _useInterfaceMetadata;
    }

    /** 
    * token URI Section
    **/

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if (useInterfaceMetadata == true) {
            return interfaceOfTokenURI.tokenURI(tokenId);
        }
        return string(abi.encodePacked(ERC721A.tokenURI(tokenId), baseExtension));
    }

    /** 
    * viewer Section
    **/

    function tokensOfOwner(address owner) public view returns (uint256[] memory) {
        unchecked {
            uint256 tokenIdsIdx;
            address currOwnershipAddr;
            uint256 tokenIdsLength = balanceOf(owner);
            uint256[] memory tokenIds = new uint256[](tokenIdsLength);
            TokenOwnership memory ownership;
            for (uint256 i = _startTokenId(); tokenIdsIdx != tokenIdsLength; ++i) {
                ownership = _ownershipAt(i);
                if (ownership.burned) {
                    continue;
                }
                if (ownership.addr != address(0)) {
                    currOwnershipAddr = ownership.addr;
                }
                if (currOwnershipAddr == owner) {
                    tokenIds[tokenIdsIdx++] = i;
                }
            }
            return tokenIds;
        }
    }

    /** 
    * override Section
    **/

    function supportsInterface(bytes4 interfaceId) public view override(ERC721A , AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _startTokenId() internal view virtual override returns (uint256) {
        return 1;
    }

    /** 
    * owner　Managed Section
    **/

    function setMaxSupply(uint256 _maxSupply) public onlyOwner() {
        maxSupply = _maxSupply;
    }

    function setCost(uint256 _newCost) public onlyOwner {
        cost = _newCost;
    }

    function setMaxMintAmountPerTransaction(uint256 _maxMintAmountPerTransaction) public onlyOwner {
        maxMintAmountPerTransaction = _maxMintAmountPerTransaction;
    }
  
    function pause(bool _state) public onlyOwner {
        paused = _state;
    }

    function setMintCount(bool _state) public onlyOwner {
        mintCount = _state;
    }

    address public constant withdrawAddress = 0x7B3391d586808329F218cBAe72E50941f697FECE; 

    function withdrawMoney() external onlyOwner nonReentrant {
        (bool success, ) = payable(withdrawAddress).call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }
}