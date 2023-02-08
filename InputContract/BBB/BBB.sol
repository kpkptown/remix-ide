// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

// ERC721Aの使用
import "erc721a/contracts/ERC721A.sol";
// リソースベースのアクセスをコントロールするコントラクト
// 特定の機能やリソースへのアクセスを許可する人のルールを設定・変更することができる
import "@openzeppelin/contracts/access/AccessControl.sol";
// 所有権を持つアドレスを管理するためのコントラクト
// スマートコントラクト内の資源のアクセス権限を持つアドレスを簡単に設定、管理することができる
import "@openzeppelin/contracts/access/Ownable.sol";
// 同階層にある、DefaultOperatorFilterer.solというスマートコントラクトからDefaultOperatorFiltererというオブジェクトをインポート
// 特定の操作者に対してアクセス許可を与える、または拒否するためのフィルターを実装するためのスマートコントラクト
import {DefaultOperatorFilterer} from "./DefaultOperatorFilterer.sol";

//tokenURI interface
// トークンのURIを取得するための仕様を定義
interface iTokenURI {
    // tokenIdを受け取り、そのトークンに関連付けられたURIを返す
    function tokenURI(uint256 _tokenId) external view returns (string memory);
}

contract BabyBucketBear is DefaultOperatorFilterer, Ownable, AccessControl , ERC721A{

    // コントラクトがインスタンス化される際に自動的に呼び出される
    constructor(
    ) ERC721A("BabyBucketBear", "BBB") {
        // AccessControl.solの_setupRole関数を実行
        // _grantRole関数を使用した方が良い
        // 関数を呼び出したスマートコントラクトのアドレスを、DEFAULT_ADMIN_ROLEに設定
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        // 関数を呼び出したスマートコントラクトのアドレスを、MINTER_ROLEに設定
        _setupRole(MINTER_ROLE       , msg.sender);
        // 関数を呼び出したスマートコントラクトのアドレスを、AIRDROP_ROLEに設定
        _setupRole(AIRDROP_ROLE      , msg.sender);
        // setBaseURI関数を実行し、メタデータのURIを設定
        setBaseURI("ipfs://QmZDtjnA528ZsvajLJfe5CgjerqiUKwVE4ZK8qpmit7z4H/");
        //　ERC721Aの_safeMint関数を実行し、指定のアドレスに1つmintする
        _safeMint(0x7B3391d586808329F218cBAe72E50941f697FECE, 1); 
    }


    //
    //withdraw section
    //

    // withdrawAddressという名前の定数(constant)を定義
    // トークンの引き出し先アドレス（PBADAOアドレス）
    address public constant withdrawAddress = 0x7B3391d586808329F218cBAe72E50941f697FECE; 

    // balance（残高）を定数として指定したアドレスに送金する関数
    function withdraw() public onlyOwner {
        // payable = 送金を受け取る関数
        (bool os, ) = payable(withdrawAddress).call{value: address(this).balance}('');
        // 送金結果を変数osに格納し、その値を返す
        require(os);
    }


    //
    //mint section
    //

    // mint価格を0に設定
    uint256 public cost = 0;
    // 最大供給量を5000に設定
    uint256 public maxSupply = 5000;
    // トランザクションあたりの最大mint量を10に設定
    uint256 public maxMintAmountPerTransaction = 10;
    // パブリックセールでの、アドレスあたりの最大mint量を300に設定
    uint256 public publicSaleMaxMintAmountPerAddress = 300;
    // トークンの発行が一時停止されているかどうか（デフォルトtrue）
    bool public paused = true;
    // トークンの発行がホワイトリストのみに限定されているかどうか（デフォルトtrue）
    bool public onlyWhitelisted = true;
    // トークンの発行数カウント（デフォルトtrue）
    // mint数の制限の有無をしているflag
    bool public mintCount = true;
    // ホワイトリストアドレスによって発行されたトークン量
    mapping(address => uint256) public whitelistMintedAmount;
    // パブリックセールによって発行されたトークン量
    mapping(address => uint256) public publicSaleMintedAmount;
    // エアドロ用の定数？
    bytes32 public constant AIRDROP_ROLE = keccak256("AIRDROP_ROLE");

    // callerIsUserという修飾子の定義
    modifier callerIsUser() {
        // 現在の呼び出し元がCA(コントラクトアカウント)ではなくEOAであることを確認する
        require(tx.origin == msg.sender, "The caller is another contract.");
        _;
    }
 
 

    //mint with mapping

    // whitelistUserAmountという変数の宣言
    mapping(address => uint256) public whitelistUserAmount;

    // 入力したmint量をmintする関数、関数の呼び出しもとが」EOAであるかの確認を行う
    function mint(uint256 _mintAmount ) public payable callerIsUser{
        // 一時停止されていないかの確認
        require(!paused, "the contract is paused");
        // 入力したmint量が1以上かの確認
        require(0 < _mintAmount, "need to mint at least 1 NFT");
        // 入力したmint量ががトランザクションあたりの最大mint量を超えていないかの確認
        require(_mintAmount <= maxMintAmountPerTransaction, "max mint amount per session exceeded");
        // すでに供給されている量と入力したmint量を足した際に、最大供給量を超えていないかの確認
        require(totalSupply() + _mintAmount <= maxSupply, "max NFT limit exceeded");
        // mint価格×mint量で費用を計算し、トランザクションで送信されたetherの量が足りるのか確認
        require(cost * _mintAmount <= msg.value, "insufficient funds");

        // トークンの発行がホワイトリストのみに限定されている場合
        if(onlyWhitelisted == true) {
            // 現在のtx送信者が、ホワイトリスト内に含まれているかどうかを確認
            require( whitelistUserAmount[msg.sender] != 0 , "user is not whitelisted");
            // mintCountがtrueの場合
            if(mintCount == true){
                // 入力されたmint数が、現在のtx送信者のホワイトリストアドレスによって発行されたトークン数
                // 入力されたmint数が、ホワイトリスト内のアドレス（msg.sender）に対応する最大数　- ホワイトリスト内のアドレス（msg.sender）に対応する既に発行された数の値を超えていないか確認
                require(_mintAmount <= whitelistUserAmount[msg.sender] - whitelistMintedAmount[msg.sender] , "max NFT per address exceeded");
                // ホワイトリスト内のアドレス（msg.sender）に対応する既に発行された数の値の更新（新規にmintした量を追加）
                whitelistMintedAmount[msg.sender] += _mintAmount;
            }
        // トークンの発行がホワイトリストのみに限定されていない場合
        }else{
            // mintCountがtrueの場合
            if(mintCount == true){
                // 入力されたmint数が、パブリックセールでのアドレスあたりの最大mint量(デフォルト300) - tx実行のアドレス（msg.sender）によってパブリックセールで発行されたトークン量を超えていないか確認
                require(_mintAmount <= publicSaleMaxMintAmountPerAddress - publicSaleMintedAmount[msg.sender] , "max NFT per address exceeded");
                // tx実行のアドレス（msg.sender）によってパブリックセールで発行されたトークン量の更新（新規にmintした量を追加）
                publicSaleMintedAmount[msg.sender] += _mintAmount;
            }
        }
        //　ERC721Aの_safeMint関数を実行し、tx実行のアドレス（msg.sender）に入力された量をmintする
        _safeMint(msg.sender, _mintAmount);
    }

    // 指定されたアドレスとそのアドレスに対応する数量を、ホワイトリストを追加するための関数（オーナーのみ実行可能）
    function setWhitelist(address[] memory addresses, uint256[] memory saleSupplies) public onlyOwner {
        // 配列addressesとsaleSuppliesの要素数が同じであることを確認
        require(addresses.length == saleSupplies.length);
        // 配列addressesの要素数分、処理を繰り返し実行する
        for (uint256 i = 0; i < addresses.length; i++) {
            //　ホワイトリスト内のアドレス（addresses[i]）に対応する最大数（saleSupplies[i]）を設定する
            whitelistUserAmount[addresses[i]] = saleSupplies[i];
        }
    }    

    // txアドレスがエアドロの権限があるかを確認し、mintする関数
    function airdropMint(address[] calldata _airdropAddresses , uint256[] memory _UserMintAmount) public {
        // AccessControl.solのhasRole関数を実行
        // txアドレス（msg.sender）がAIRDROP_ROLEを持っているかの確認
        require(hasRole(AIRDROP_ROLE, msg.sender), "Caller is not a air dropper");
        // mint量を初期化
        uint256 _mintAmount = 0;
        // 入力された_UserMintAmount配列の要素分、繰り返し処理を実行
        for (uint256 i = 0; i < _UserMintAmount.length; i++) {
            // ユーザーのmint量を更新する
            _mintAmount += _UserMintAmount[i];
        }
        // mint量が1以上かどうかの確認
        require(0 < _mintAmount , "need to mint at least 1 NFT");
        // 現在の供給量とmint量（これからmintしようとしている量）を合計し、最大供給量を超えていないかの確認
        require(totalSupply() + _mintAmount <= maxSupply, "max NFT limit exceeded");
        // 入力されたmint量分（入力された配列の要素分）繰り返し処理を実行
        for (uint256 i = 0; i < _UserMintAmount.length; i++) {
            //　ERC721Aの_safeMint関数を実行し、エアドロ許可されたアドレスに入力された量をmintする
            _safeMint(_airdropAddresses[i], _UserMintAmount[i] );
        }
    }

    // 最大供給量を更新するための関数(コントラクトオーナーのみ実行可能)
    function setMaxSupply(uint256 _maxSupply) public onlyOwner() {
        maxSupply = _maxSupply;
    }

    // パブリックセールでの、アドレスあたりの最大mint量を更新するための関数(コントラクトオーナーのみ実行可能)
    function setPublicSaleMaxMintAmountPerAddress(uint256 _publicSaleMaxMintAmountPerAddress) public onlyOwner() {
        publicSaleMaxMintAmountPerAddress = _publicSaleMaxMintAmountPerAddress;
    }

    // mint価格を更新するための関数(コントラクトオーナーのみ実行可能)
    function setCost(uint256 _newCost) public onlyOwner {
        cost = _newCost;
    }

    // トークンの発行をホワイトリストのみに限定するためのフラグの更新用関数(コントラクトオーナーのみ実行可能)
    function setOnlyWhitelisted(bool _state) public onlyOwner {
        onlyWhitelisted = _state;
    }

    // トランザクションあたりの最大mint量を更新するための関数(コントラクトオーナーのみ実行可能)
    function setMaxMintAmountPerTransaction(uint256 _maxMintAmountPerTransaction) public onlyOwner {
        maxMintAmountPerTransaction = _maxMintAmountPerTransaction;
    }
  
    // トークンの発行を一時停止するためのフラグを更新する関数(コントラクトオーナーのみ実行可能)
    function pause(bool _state) public onlyOwner {
        paused = _state;
    }

    　// トークンの発行数カウントをするためのフラグを更新する関数(コントラクトオーナーのみ実行可能)
    function setMintCount(bool _state) public onlyOwner {
        mintCount = _state;
    }
 


    //
    //URI section
    //

    // URIの文字列用変数を定義
    string public baseURI;
    // URIの拡張子用の変数を定義
    string public baseExtension = ".json";

    // メタデータのURLを返却するための関数 （同一コントラクトないからのみ呼び出し可能、他のコントラクトから継承さsれたものをオーバーライドする）
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;        
    }

    // メタデータのURIを更新するための関数（オーナーのみ実行可能）
    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    // メタデータのURLの拡張子を更新するための変数（オーナーのみ実行可能）
    function setBaseExtension(string memory _newBaseExtension) public onlyOwner {
        baseExtension = _newBaseExtension;
    }



    //
    //interface metadata
    //

    // iTokenURIという型で、interfaceOfTokenURIという名前のグローバル変数の宣言をする
    // iTokenURI型は。iTokenURIというインターフェースで定義された型
    iTokenURI public interfaceOfTokenURI;
    // useInterfaceMetadataという変数に、デフォルト値falseを格納
    bool public useInterfaceMetadata = false;

    // メタデータのURIを取得する関数
    function setInterfaceOfTokenURI(address _address) public onlyOwner() {
        // 入力されたアドレスを、iTokenURIというインターフェースにキャスト、URIを取得する(コントラクトオーナーのみ実行可能)
        interfaceOfTokenURI = iTokenURI(_address);
    }

    // useInterfaceMetadataというフラグ変数の設定を変更するための関数（オーナーのみ実行可能）
    function setUseInterfaceMetadata(bool _useInterfaceMetadata) public onlyOwner() {
        useInterfaceMetadata = _useInterfaceMetadata;
    }


    //
    //token URI
    //

    // tokenIdを渡してtokenURIを返却する関数
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        // useInterfaceMetadataというフラグの変数がtrueの場合
        if (useInterfaceMetadata == true) {
            // interfaceOfTokenURIのtokenURI関数を呼び出し、トークンに関連づけられたURIを返却する
            return interfaceOfTokenURI.tokenURI(tokenId);
        }
        // useInterfaceMetadataというフラグの変数がfalseの場合
        // ERC721AトークンのtokenIdに対応するトークンURIを生成する
        // ERC721AトークンのtokenURI関数が返す値とbaseExtension変数の値を結合して、bytesに変換する
        // このbytes値がstring関数に渡され、文字列に変換される
        return string(abi.encodePacked(ERC721A.tokenURI(tokenId), baseExtension));
    }


    //
    //burnin' section
    //

    // 定数MINTER_ROLEを定義(文字列"MINTER_ROLE"のkeccak256ハッシュ値が値)
    bytes32 public constant MINTER_ROLE  = keccak256("MINTER_ROLE");
    // （外部から呼び出され、Ethereumのペイメントが受け取れる関数）
    function externalMint(address _address , uint256 _amount ) external payable {
        // txアドレス(msg.sender)がMINTER_ROLEを持っているかの確認
        require(hasRole(MINTER_ROLE, msg.sender), "Caller is not a minter");
        // ERC721Aの関数_nextTokenIdを実行
        // 次にmintされるトークンのIDから1を減算し、現在のtokenIDにmint予定の数量を加算した値が、最大供給量を超えていないか確認
        require( _nextTokenId() -1 + _amount <= maxSupply , "max NFT limit exceeded");
        // mint実行
        _safeMint( _address, _amount );
    }



    //
    //viewer section
    //

    // 指定されたオーナーアドレスを持つトークンのトークンIDの一覧を返却する関数
    function tokensOfOwner(address owner) public view returns (uint256[] memory) {
        // unchecked は Solidity 0.8.0 から導入された算術計算のアンダーフロー・オーバーフローの対応
        // Solidity 0.8.0以降は、アンダフロー・オーバーフローが発生した場合 revert になるのがデフォルトだが、revertにしたくない場合にuncheckedを使う
        unchecked {
            uint256 tokenIdsIdx;
            address currOwnershipAddr;
            // ownerが所有しているERC721Aのトークンの数を取得し、変数tokenIdsLengthに代入する
            uint256 tokenIdsLength = balanceOf(owner);
            // トークンIDを保存するための配列「tokenIds」を作成する
            // new uint256は、「tokenIds」配列を「tokenIdsLength」のサイズで作成することを示す
            uint256[] memory tokenIds = new uint256[](tokenIdsLength);
            // ERC721A TokenOwnershipはトークンの所有者表す構造体（memoryのため、ownership変数が一時的であることを表す）
            TokenOwnership memory ownership;
            // uint256 i = _startTokenId()でトークンのIDを初期化
            // 「tokenIdsIdx != tokenIdsLength」は、すでに探索したトークンの数が、所有者が持っているトークン数に達していないかどうかを確認する条件式
            // このfor文によって、所有者が持っているトークンのIDの一覧が作成される
            for (uint256 i = _startTokenId(); tokenIdsIdx != tokenIdsLength; ++i) {
                // 「i」というトークンIDに対応するトークンの所有権情報を取得
                ownership = _ownershipAt(i);
                // トークンが焼却されているかどうかを確認
                if (ownership.burned) {
                    // 焼却されている場合は、continueでループをスキップ
                    continue;
                }
                // トークンの所有者アドレスが0でないことを確認
                if (ownership.addr != address(0)) {
                    // currOwnershipAddrにトークンの所有者アドレスを代入する
                    currOwnershipAddr = ownership.addr;
                }
                // currOwnershipAddrが引数のownerと同じかどうかを確認
                if (currOwnershipAddr == owner) {
                    // 一致する場合は、tokenIds配列にトークンID「i」を追加する
                    tokenIds[tokenIdsIdx++] = i;
                }
            }
            // tokenIds配列を返却する
            return tokenIds;
        }
    }

    //
    //sbt section
    //

    // SBTかどうかのフラグ変数
    bool public isSBT = false;

    // SBTかどうかのフラグを更新するための関数（オーナーのみ実行可能）
    function setIsSBT(bool _state) public onlyOwner {
        isSBT = _state;
    }

    // transferの前に呼び出される、内部仮想関数
    function _beforeTokenTransfers( address from, address to, uint256 startTokenId, uint256 quantity) internal virtual override{
        //isSBTフラグがfalseである、引数fromがアドレス0である、引数toが下記アドレスであるのどれかの条件を満たした場合は処理を進める
        require( isSBT == false || from == address(0) || to == address(0x000000000000000000000000000000000000dEaD), "transfer is prohibited");
        // ERC721Aの_beforeTokenTransfers関数を実行する（superを使用して、親コントラクトの関数拡張している）
        super._beforeTokenTransfers(from, to, startTokenId, quantity);
    }

    // トークンオーナーが別のアドレス（operator）に自分の持つトークンの代理転送を許可するために使用する関数
    function setApprovalForAll(address operator, bool approved) public virtual override {
        // SBTかどうかのフラグがfalseの場合
        require( isSBT == false , "setApprovalForAll is prohibited");
        // ERC721AのsetApprovalForAll関数を拡張実行する
        super.setApprovalForAll(operator, approved);
    }

    // トークン所有者が特定のトークンを他のアドレスに承認するために使用する関数
    function approve(address to, uint256 tokenId) public payable virtual override {
        // SBTかどうかのフラグがfalseの場合
        require( isSBT == false , "approve is prohibited");
        // ERC721Aのapprove関数を拡張実行する
        super.approve(to, tokenId);
    }



    //
    //override
    //

    // 入力されたinterfaceIdと一致するインターフェイスが含まれているかどうかを確認する関数
    function supportsInterface(bytes4 interfaceId) public view override(ERC721A , AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    // トークンIDの範囲の最初の数字を返す関数
    function _startTokenId() internal view virtual override returns (uint256) {
        // 1を返すことを保証する　
        return 1;
    }

    // トークンを転送するための関数
    // IOperatorFilterRegistry.solで定義されている、onlyAllowedOperator修飾子があるため、fromアドレスから許可されたオペレーターから確認している
    function transferFrom(address from, address to, uint256 tokenId) public payable override onlyAllowedOperator(from) {
        // ERC721AのtransferFrom関数を拡張実行する
        super.transferFrom(from, to, tokenId);
    }

    // トークンの所有権を他のアカウントに安全かつ取り消せない方法で転送するための関数
    // safeTransferFromはtransferFromと同じような動作をするが、呼び出す前に呼び出し先アドレスがERC721トークンに対応しているかどうかを確認する安全なメカニズムが内部に含まれている
    function safeTransferFrom(address from, address to, uint256 tokenId) public payable override onlyAllowedOperator(from) {
        // ERC721AのsafeTransferFrom関数を拡張実行する
        super.safeTransferFrom(from, to, tokenId);
    }

    // トークンの所有権を他のアカウントに安全かつ取り消せない方法で転送するための関数
    // data」はオプションのバイト配列で、トランスファーに関連する追加情報を提供することができる
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data)
        public
        payable
        override
        onlyAllowedOperator(from)
    {
        // ERC721AのsafeTransferFrom関数を拡張実行する
        super.safeTransferFrom(from, to, tokenId, data);
    }

}