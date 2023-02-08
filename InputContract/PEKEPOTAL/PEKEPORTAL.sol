// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import {Operable} from "./Operable.sol";

contract PEKEPORTAL is ERC1155URIStorage, Ownable, Operable {
    using Strings for string;

    string public name = "PEKEPORTAL";
    string public symbol = "P-PORTAL";
    //address型のキーに対してbool型の値を持つbondedAddress いうマッピング変数を定義
    mapping(address => bool) bondedAddress;

    //デプロイ時、初期実行
    constructor() ERC1155("") {
        // txの実行者（msg.sender）にgrantOperatorRoleの権限を付与
        _grantOperatorRole(msg.sender);
        //BaseURLを設定
        _setBaseURI("ipfs://QmdiYiPVjXXnyPJUxwVNgvRhXjCT7JCmHFBeWjZ21mjyrV/");
        //
        initializeSBT(0, "0.json");
    }

    // すべてのトークンの移転に対する承認を設定する関数
    function setApprovalForAll(address operator, bool approved)
        public
        virtual
        override
    {
        require(
            // 承認を設定するアドレス（operator）がownerと同じか、または、bondedAddress[operator]がtrueの場合は許可
            operator == owner() || bondedAddress[operator] == true,
            "Cannot approve, transferring not allowed"
        );
        // 承認設定を行うために、_setApprovalForAll関数を呼び出す
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    // 指定されたアドレスのロック状態を返却する関数
    function locked(address to) external view returns (bool) {
        // bondedAddressという　mapping変数からロック状態をbool値で返却する
        return bondedAddress[to];
    }

    // 引数で渡されたアドレスとbool値を、bondedAddressというmappinng変数に設定するための関数（実行にはonlyOperatorの権限が必要）
    function bound(address to, bool flag) public onlyOperator {
        bondedAddress[to] = flag;
    }

    // BaseURIを更新するための関数（実行にはonlyOperatorの権限が必要）
    function setBaseURI(string memory uri_) external onlyOperator {
        _setBaseURI(uri_);
    }

    // 外部から呼び出され、指定されたトークンIDに対応するトークンURIを設定するための関数（実行にはonlyOperatorの権限が必要）
    function setTokenURI(uint256 tokenId, string memory _tokenURI)
        external
        onlyOperator
    {
        // _setURIが呼び出され、トークンIDとトークンURIを関連付ける
        _setURI(tokenId, _tokenURI);
    }

    // SBTを初期化する関数（新しいSBTを発行す、実行にはonlyOperatorの権限が必要）
    function initializeSBT(uint256 tokenId, string memory _tokenURI)
        public
        onlyOperator
    {
        // tokenIDが以前に使用されていないことを確認する
        require(bytes(uri(tokenId)).length == 0, "SBT already exists");
        // 新しくトークンを発行する(msg.senderがオーナー、引数で渡されたtokenID,数量=1,トークンのメタデータは空文字)
        _mint(msg.sender, tokenId, 1, "");
        // トークンのIDを元にトークンのURIを設定する関数_setURIの呼び出し
        _setURI(tokenId, _tokenURI);
    }

    // 新しくトークンを生み出すための関数（実行にはonlyOperatorの権限が必要）
    function mint(
        // トークンを送信するアドレス
        address to,
        // トークンの識別番号
        uint256 id,
        // トークンの量
        uint256 amount
    ) public onlyOperator {
        // idに対応するトークンのuriの長さが0でないことを検証
        require(bytes(uri(id)).length != 0, "Not initialized");
        // 
        _mint(to, id, amount, "");
    }

    // 複数のアドレスに対してトークンを一括で配布するための関数（実行にはonlyOperatorの権限が必要）
    function batchMintTo(
        // トークンを配布するアドレス（配列）
        address[] memory list,
        // 配布するトークンのID
        uint256 id,
        // 配布するトークンの量（配列）
        uint256[] memory amount
    ) public onlyOperator {
        //  トークンを配布するアドレスの配列の要素数分だけ繰り返し処理を実行
        for (uint256 i = 0; i < list.length; i++) {
            // mint関数を実行する
            _mint(list[i], id, amount[i], "");
        }
    }

    // トークンをburnするための関数（実行にはonlyOperatorの権限が必要）
    // 指定されたアドレスtoが所有するトークンID(id)の数量をamount分燃やす
    function burnAdmin(
        // burnするトークンの所有者アドレス
        address to,
        // burnするトークンのID
        uint256 id,
        // burnするトークンの量
        uint256 amount
    ) public onlyOperator {
        //　トークン焼却の関数実行
        _burn(to, id, amount);
    }

    // SBTにするため（トークンを転送不可能にするため）の関数
    // トークンを他のアドレスに送信する前に呼び出される関数
    function _beforeTokenTransfer(
        // トランスファーを実行する操作者のアドレス
        address operator,
        // NFTを送信するアドレス
        address from,
        // NFTを受信するアドレス
        address to,
        // 送信するNFTのトークンID(配列)
        uint256[] memory ids,
        // 送信する各トークンの数量(配列)
        uint256[] memory amounts,
        // NFTトランスファーに関連する任意のデータ(トランスファーの承認に必要な鍵やトランスファーに関連する注釈などを格納することができる)
        bytes memory data
    ) internal virtual override {
        // 承認を設定するアドレス（operator）がownerと同じか、または、bondedAddress[operator]がtrueの場合は許可
        // 許可されていないアドレスはtransferができない=SBTにしている
        require(
            operator == owner() || bondedAddress[operator] == true,
            "Send NFT not allowed"
        );
        // 継承元（親）のトークントランスファー関数を呼び出し
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    /**
        @dev Operable Role
     */
    
    // 操作者ロールを設定する関数（実行にはonlyOperatorの権限が必要）
    function grantOperatorRole(address _candidate) external onlyOwner {
        _grantOperatorRole(_candidate);
    }

    // 操作者ロールを削除する関数（実行にはonlyOperatorの権限が必要）
    function revokeOperatorRole(address _candidate) external onlyOwner {
        // _grantOperatorRole(_candidate);
        // 正しくは下記↓
        _revokeOperatorRole(_candidate);
    }
}