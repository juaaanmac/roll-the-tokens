// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ChipToken} from "../../src/ChipToken.sol";

contract ChipTokenHarness is ChipToken {
    constructor(address priceFeed, string memory name, string memory symbol) ChipToken(priceFeed, name, symbol) {}

    function getPriceFeed() external view returns (address) {
        return address(_priceFeed);
    }

    function getBalance() external view returns (uint256) {
        return _balance;
    }
}
