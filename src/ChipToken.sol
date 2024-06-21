// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/console.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {PriceFeed} from "./PriceFeed.sol";

/**
 * @title   ERC20 smart contract
 * @author  Juan Macri
 * @notice  this smart contract allows to send weis and get tokens to participate
 *          in RollTheTokens staking pool
 */
contract ChipToken is ERC20 {
    PriceFeed internal _priceFeed;

    event PlayerEntered(address player, uint256 amount);

    constructor(address priceFeed) ERC20("ChipTokens", "CHT") {
        _priceFeed = PriceFeed(priceFeed);
    }

    function enter() external payable {
        require(msg.value > 0, "send weis");

        int256 price = _priceFeed.getChainlinkDataFeedLatestAnswer();
        require(price > 0, "invalid price");

        uint256 amount = msg.value / uint256(price);
        address player = _msgSender();

        _mint(player, amount);

        emit PlayerEntered(player, amount);
    }
}
