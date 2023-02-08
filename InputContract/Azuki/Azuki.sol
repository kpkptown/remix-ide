// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// 契約の所有権の管理を行うライブラリ　例）所有者の設定と移転、所有者だけが実行できる特定の操作の制限等
import "@openzeppelin/contracts/access/Ownable.sol";
// リレントランシー攻撃からの保護を行うライブラリ（コントラクトが他のコントラクトを呼び出すことを一時的に無効にする）
// nonReentrantという修飾子を関数に適用することで保護を強制することができる
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
// AzikiオリジナルのERC721
import "./ERC721A.sol";
// 文字列を扱うためのライブラリ（文字列の連結、比較、部分文字列の抽出などの機能あり）
import "@openzeppelin/contracts/utils/Strings.sol";

contract Azuki is Ownable, ERC721A, ReentrancyGuard {
  // 変数の定義,immutableのため宣言後は変更できない
  // アドレスに対してmintできるトークンの最大量
    uint256 public immutable maxPerAddressDuringMint;
    // 開発者のために予約されたトークンの量
    uint256 public immutable amountForDevs;
    // オークションと開発者たちのために予約されたトークンの量
    uint256 public immutable amountForAuctionAndDev;

    // セールのための構造体の作成
    struct SaleConfig {
        // オークションセールの開始時間
        uint32 auctionSaleStartTime;
        // パブリックセールの開始時間
        uint32 publicSaleStartTime;
        // ミントリスト価格？
        uint64 mintlistPrice;
        // 一般価格
        uint64 publicPrice;
        uint32 publicSaleKey;
    }

    // 上記で定義した構造体型の変数を定義
    SaleConfig public saleConfig;

    // addressをkeyにして数値を値とする変数を定義
    mapping(address => uint256) public allowlist;

    // 初期実行関数
    constructor(
        // アドレスに対してmintできるトークンの最大量
        uint256 maxBatchSize_,
        // 最大供給量
        uint256 collectionSize_,
        // オークションと開発者たちのために予約されたトークンの量
        uint256 amountForAuctionAndDev_,
        // 開発者のために予約されたトークンの量
        uint256 amountForDevs_
    ) ERC721A("Azuki", "AZUKI", maxBatchSize_, collectionSize_) {
        // アドレス当たりの最大mint量を定義（引数の値をセット）
        maxPerAddressDuringMint = maxBatchSize_;
        // オークションと開発者たちのために予約されたトークンの量を定義（引数の値をセット）
        amountForAuctionAndDev = amountForAuctionAndDev_;
        // 開発者のために予約されたトークンの量を定義（引数の値をセット）
        amountForDevs = amountForDevs_;
        // オークションと開発者たちのために予約されたトークンの量が最大供給量以下なことを確認
        require(
        amountForAuctionAndDev_ <= collectionSize_,
        "larger collection size needed"
        );
    }

    // トランザクションの送信者が、呼び出し元のアドレスと同一かどうかを確認するモディファイア
    modifier callerIsUser() {
        require(tx.origin == msg.sender, "The caller is another contract");
        _;
    }

    // トランザクションの送信者が、呼び出し元のアドレスと同一かどうかを確認している
    // 外部呼び出し可能、Etherの受け取り可能なトークン発行のための関数
    function auctionMint(uint256 quantity) external payable callerIsUser {
        // 構造体から、セールの開始時間を定義する
        uint256 _saleStartTime = uint256(saleConfig.auctionSaleStartTime);
        // セールの開始時間が0ではなく、現在の時間がセール開始時間を過ぎていることを確認する
        require(
        _saleStartTime != 0 && block.timestamp >= _saleStartTime,
        "sale has not started yet"
        );
        // 現在の供給量に引数で渡されたトークン発行量を加算して、オークションと開発者たちのために予約されたトークンの量を超えていないか確認
        require(
        totalSupply() + quantity <= amountForAuctionAndDev,
        "not enough remaining reserved for auction to support desired mint amount"
        );
        // 呼び出し元のアカウントによって作られたトークン数に、引数で渡されたトークン発行量を加算してアドレス当たりの最大mint量を超えていないかの確認
        require(
        numberMinted(msg.sender) + quantity <= maxPerAddressDuringMint,
        "can not mint this many"
        );
        // 合計金額の定義
        uint256 totalCost = getAuctionPrice(_saleStartTime) * quantity;
        // mintの実行
        _safeMint(msg.sender, quantity);
        // 関数refundIfOverに上記で算出して合計金額を引数として渡して実行
        refundIfOver(totalCost);
    }

    // AL保有者用のmint関数
    // 外部呼び出し可能、Etherの受け取り可能なトークン発行のための関数
    function allowlistMint() external payable callerIsUser {
        // セールのための構造体で定義された価格を宣言
        uint256 price = uint256(saleConfig.mintlistPrice);
        // 価格が0ではないことを確認（ALのセールが始まっていることを確認）
        require(price != 0, "allowlist sale has not begun yet");
        // tx実行者のallowlistが0より大きいことを確認（ALを持っているかの確認）
        require(allowlist[msg.sender] > 0, "not eligible for allowlist mint");
        // 現在の供給量に1を加算した際に、最大供給量を超えないか確認
        require(totalSupply() + 1 <= collectionSize, "reached max supply");
        // tx実行者のallowlistに対して-1を行う
        allowlist[msg.sender]--;
        // トークン量1でmintを実行
        _safeMint(msg.sender, 1);
        // 関数refundIfOverに価格を引数として渡して実行
        refundIfOver(price);
    }

    // 公開セール用のmint関数
    // 外部呼び出し可能、Etherの受け取り可能なトークン発行のための関数、txアドレスとmessage.senderが同一であることを保証する
    function publicSaleMint(uint256 quantity, uint256 callerPublicSaleKey)
        external
        payable
        callerIsUser
    {
        // 上記で定義した構造体型の変数を定義
        SaleConfig memory config = saleConfig;
        // 構造体から変数を宣言
        // publicSaleKey
        uint256 publicSaleKey = uint256(config.publicSaleKey);
        // 公開価格
        uint256 publicPrice = uint256(config.publicPrice);
        // 公開セールの開始日時
        uint256 publicSaleStartTime = uint256(config.publicSaleStartTime);
        // 呼び出し元が提供したキーの値と販売設定内に保存されている公開キーが一致することを確認
        require(
        publicSaleKey == callerPublicSaleKey,
        "called with incorrect public sale key"
        );
        // isPublicSaleOn関数を呼び出し、公開セールが開始されていることを確認
        require(
        isPublicSaleOn(publicPrice, publicSaleKey, publicSaleStartTime),
        "public sale has not begun yet"
        );
        // 現状の供給量に引数で渡されたmint量を加算し、最大供給量を超えないことを確認
        require(totalSupply() + quantity <= collectionSize, "reached max supply");
        // 呼び出し元のアカウントによって作られたトークン数に、引数で渡されたトークン発行量を加算してアドレス当たりの最大mint量を超えていないかの確認
        require(
        numberMinted(msg.sender) + quantity <= maxPerAddressDuringMint,
        "can not mint this many"
        );
        // mintの実行
        _safeMint(msg.sender, quantity);
        // 関数refundIfOverに上記で算出して合計金額を引数として渡して実行
        refundIfOver(publicPrice * quantity);
    }

    // 呼び出し元が支払ったEtherの金額が要求額よりも多い場合、余分なEtherの金額を呼び出し元に返金するための関数
    function refundIfOver(uint256 price) private {
        // 支払い金額が価格以上であることを確認
        require(msg.value >= price, "Need to send more ETH.");
        // 支払い金額が価格より大きい場合に実行
        if (msg.value > price) {
        // 支払額から価格を引いた額（あまりの金額）を送金（返金）する
        payable(msg.sender).transfer(msg.value - price);
        }
    }

    // 公開セールが開始されているかを判定する関数、true or falseで返却する
    function isPublicSaleOn(
        // 公開セールの金額(wei単位)
        uint256 publicPriceWei,
        // 公開セールのキー
        uint256 publicSaleKey,
        // 公開セールの開始日時
        uint256 publicSaleStartTime
    ) public view returns (bool) {
        // 下記3点の条件を満たした場合にtrueを返す
        return
        // 公開セールの価格が0ではない
        publicPriceWei != 0 &&
        // 公開セールのキーが0ではない
        publicSaleKey != 0 &&
        // 現在のブロックタイムスタンプが公開セール開始時刻を過ぎている
        block.timestamp >= publicSaleStartTime;
    }

    // オークションスタート価格を定数として、1Etherに設定
    uint256 public constant AUCTION_START_PRICE = 1 ether;
    // オークション終了価格を定数として、0.15Etherに設定
    uint256 public constant AUCTION_END_PRICE = 0.15 ether;
    // オークションの価格曲線の長さを定数として、340分に設定
    uint256 public constant AUCTION_PRICE_CURVE_LENGTH = 340 minutes;
    // オークション価格の下落間隔を定数として、20分に設定
    uint256 public constant AUCTION_DROP_INTERVAL = 20 minutes;
    // 各ステップにおけるオークション価格の下落量
    uint256 public constant AUCTION_DROP_PER_STEP =
        // オークションスタート価格とオークション終了価格の差額をオークション価格の下落間隔を各ステップにおけるオークション価格の下落量で割った値で計算
        (AUCTION_START_PRICE - AUCTION_END_PRICE) /
        (AUCTION_PRICE_CURVE_LENGTH / AUCTION_DROP_INTERVAL);

    // オークションの価格を計算する関数
    function getAuctionPrice(uint256 _saleStartTime)
        public
        view
        returns (uint256)
    {
        // 現在のブロックタイムスタンプが、公開セール開始日時より前の場合に実行
        if (block.timestamp < _saleStartTime) {
        // オークション開始価格を返却する
        return AUCTION_START_PRICE;
        }
        // 現在のブロックタイムスタンプから、引数として渡された公開セール開始時間を減算し、オークションの価格曲線の長さより大きい場合に実行
        if (block.timestamp - _saleStartTime >= AUCTION_PRICE_CURVE_LENGTH) {
        // オークション終了価格を返却する
        return AUCTION_END_PRICE;
        } else {
        // 上記以外の場合、現在のブロックタイムスタンプから、引数として渡された公開セール開始時間を減算し、オークション価格の下落間隔で割った値を変数に格納
        uint256 steps = (block.timestamp - _saleStartTime) /　AUCTION_DROP_INTERVAL;
        // オークション開始時刻から、上記変数に各ステップにおけるオークション価格の下落量をかけた値を返却する
        return AUCTION_START_PRICE - (steps * AUCTION_DROP_PER_STEP);
        }
    }

    // セール情報を含む構造体に新しいインスタンスを作成する関数（コントラクト所有者のみ実行可能）
    function endAuctionAndSetupNonAuctionSaleInfo(
        uint64 mintlistPriceWei,
        uint64 publicPriceWei,
        uint32 publicSaleStartTime
    ) external onlyOwner {
        saleConfig = SaleConfig(
        // オークションの開始時間
        0,
        // セールスタート時間
        publicSaleStartTime,
        // mint価格
        mintlistPriceWei,
        // 一般価格（wei単位）
        publicPriceWei,
        // 公開セールキー
        saleConfig.publicSaleKey
        );
    }

    // オークションの開始時間を設定する関数（コントラクト所有者のみ実行可能）
    function setAuctionSaleStartTime(uint32 timestamp) external onlyOwner {
        saleConfig.auctionSaleStartTime = timestamp;
    }

    // 公開セールキーを設定する関数（コントラクト所有者のみ実行可能）
    function setPublicSaleKey(uint32 key) external onlyOwner {
        saleConfig.publicSaleKey = key;
    }

    // ALを作成するための関数
    // 指定されたアドレスと数のスロットを含む配列を受け取り、各アドレスに対応するスロット数を格納するallowlistマップに追加するもの（コントラクト所有者のみ実行可能）
    function seedAllowlist(address[] memory addresses, uint256[] memory numSlots)
        external
        onlyOwner
    {
        // アドレス配列の長さとnumSlots配列の長さが同じかどうかを確認
        require(
        addresses.length == numSlots.length,
        "addresses does not match numSlots length"
        );
        // アドレスの長さ分繰り返し処理を実行する
        for (uint256 i = 0; i < addresses.length; i++) {
        // 配列に値を格納
        allowlist[addresses[i]] = numSlots[i];
        }
    }

    // For marketing etc.
    //開発用のmint用関数（コントラクト所有者のみ実行可能）
    function devMint(uint256 quantity) external onlyOwner {
        // 現状の発行量に引数で渡された発行しようとしているトークン量を加算し、開発者のために予約されたトークンの量以下であることを確認する
        require(
        totalSupply() + quantity <= amountForDevs,
        "too many already minted before dev mint"
        );
        // 引数で渡された発行しようとしているトークン量をアドレスに対してmintできるトークンの最大量で割ったあまりが0の場合
        require(
        quantity % maxBatchSize == 0,
        "can only mint a multiple of the maxBatchSize"
        );
        // 引数で渡された発行しようとしているトークン量をアドレスに対してmintできるトークンの最大量で割った値を変数に格納する
        uint256 numChunks = quantity / maxBatchSize;
        // 上記変数分繰り返し処理を実行する
        for (uint256 i = 0; i < numChunks; i++) {
        // mintを実行する
        _safeMint(msg.sender, maxBatchSize);
        }
    }

    // // metadata URI
    // 文字列型の変数を定義
    string private _baseTokenURI;

    // メタデータのURLを返却する関数
    // 内部から呼び出され、仮想的にオーバーライドできる読み取り専用関数
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    // メタデータのURLを設定する関数（コントラクト所有者のみ実行可能）
    // calldata：関数呼び出し時に渡されるデータを表す
    function setBaseURI(string calldata baseURI) external onlyOwner {
        // 引数を設定する
        _baseTokenURI = baseURI;
    }

    // 売上金を別のアカウントに移行するための関数（コントラクト所有者のみ実行可能、リレントランシー攻撃を防ぐ）
    function withdrawMoney() external onlyOwner nonReentrant {
        // 現在のコントラクトの残高を送信者のアドレスに送金し、結果(true or false)を変数に格納する
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        // 送金が正しく行われたかどうかを判定
        require(success, "Transfer failed.");
    }

    // _setOwnersExplicit（コントラクト所有者のみ実行可能、リレントランシー攻撃を防ぐ）を実行する
    function setOwnersExplicit(uint256 quantity) external onlyOwner nonReentrant {
        // @dev 下記コントラクトの役割不明
        _setOwnersExplicit(quantity);
    }

    // _numberMintedという内部関数を呼び出す閲覧用関数
    function numberMinted(address owner) public view returns (uint256) {
        // ERC721Aの_numberMinted関数を実行する
        // 所有者によってmintされたトークンの数を返す
        return _numberMinted(owner);
    }

    // トークン所有者の情報を呼び出す閲覧用関数
    function getOwnershipData(uint256 tokenId)
        external
        view
        returns (TokenOwnership memory)
    {
        // ERC721AのownershipOf関数を実行する
        return ownershipOf(tokenId);
    }
}