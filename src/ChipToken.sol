// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/console.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {PriceFeed} from "./PriceFeed.sol";

/**
 * @title   ERC20 smart contract
 * @author  Juan Macri
 * @notice  this smart contract allows to send weis and get tokens to participate
 *          in RollTheTokens staking pool
 */
contract ChipToken is ERC20, Ownable {
    PriceFeed internal immutable _priceFeed;
    uint256 internal _balance;

    event PlayerEntered(address player, uint256 amount);
    event BalanceWithdrawn(uint256 amount);

    constructor(address priceFeed, string memory name, string memory symbol) ERC20(name, symbol) Ownable(msg.sender) {
        _priceFeed = PriceFeed(priceFeed);
    }

    function enter() external payable {
        require(msg.value > 0, "send weis");

        _balance += msg.value;

        int256 price = _priceFeed.getChainlinkDataFeedLatestAnswer();
        require(price > 0, "invalid price");

        uint256 amount = msg.value / uint256(price);
        address player = _msgSender();

        _mint(player, amount);

        emit PlayerEntered(player, amount);
    }

    function withdraw(uint256 value) external onlyOwner {
        require(value <= _balance, "not enough balance");

        // at this point amount is lower than balance
        unchecked {
            _balance -= value;
        }

        emit BalanceWithdrawn(value);

        //slither-disable-next-line low-level-calls
        (bool success,) = payable(msg.sender).call{value: value}("");
        require(success, "failed to withdraw");
    }
}
