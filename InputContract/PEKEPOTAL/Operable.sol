// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

abstract contract Operable is Context {
    // 各アドレスを特定のオペレーターとして扱うかどうかを記録するためのマッピング型変数を定義
    mapping(address => bool) _operators;

    //  Solidity の修飾子を定義
    modifier onlyOperator() {
        // 呼び出し元アカウント（msg.senfer）が操作者ロールを持っているかどうかを確認
        _checkOperatorRole(_msgSender());
        _;
    }

    function isOperator(address _operator) public view returns (bool) {
        return _operators[_operator];
    }

    // 引数で渡されたアドレスに操作者ロールを付与する関数
    function _grantOperatorRole(address _candidate) internal {
        // 引数で渡されたアドレスが、操作者ロールを既に持っていないことを確認
        require(
            !_operators[_candidate],
            string(
                abi.encodePacked(
                    "account ",
                    Strings.toHexString(uint160(_msgSender()), 20),
                    " is already has an operator role"
                )
            )
        );
        // 操作者ロールを付与（フラグの更新）
        _operators[_candidate] = true;
    }

    // 引数で渡されたアドレスの操作者ロールを削除する関数
    function _revokeOperatorRole(address _candidate) internal {
        // _checkOperatorRole関数を呼び出し、操作者ロールを持っているかの確認
        _checkOperatorRole(_candidate);
        // _operatorsのマッピングから、引数で渡されたアドレス（_candidate）を削除する
        delete _operators[_candidate];
    }

    // 引数で渡されたアドレスの操作者ロールを確認する関数
    function _checkOperatorRole(address _operator) internal view {
        // 内部的に呼び出され、_operatorsマッピングに基づいて、指定されたアドレスがオペレーターであることを確認する
        require(
            _operators[_operator],
            // もし指定されたアドレスがオペレーターでない場合、"account [アドレスの16進数表現] is not an operator"というエラーメッセージが出力される
            string(
                abi.encodePacked(
                    "account ",
                    Strings.toHexString(uint160(_msgSender()), 20),
                    " is not an operator"
                )
            )
        );
    }
}