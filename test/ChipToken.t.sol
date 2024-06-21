// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import {ChipToken} from "../src/ChipToken.sol";
import {PriceFeed} from "../src/PriceFeed.sol";

contract ChipTokenTest is Test {
    ChipToken public chipToken;
    PriceFeed public priceFeed;
    MockV3Aggregator public mockAggregator;
    uint8 constant DECIMALS = 0;
    int256 constant INITIAL_ANSWER = 1000;
    address constant USER = address(1);

    event PlayerEntered(address player, uint256 amount);

    function setUp() public {
        mockAggregator = new MockV3Aggregator(DECIMALS, INITIAL_ANSWER);
        priceFeed = new PriceFeed(address(mockAggregator));
        chipToken = new ChipToken(address(priceFeed));
    }

    function testEnter(uint256 value_) public {
        vm.assume(value_ > 0);
        vm.deal(USER, value_);
        vm.prank(USER);
        chipToken.enter{value: value_}();

        int256 price = priceFeed.getChainlinkDataFeedLatestAnswer();
        require(price > 0, "invalid price");

        uint256 amount = value_ / uint256(price);
        assertEq(chipToken.balanceOf(USER), amount);
    }

    function testEnterRevertIfValueIsZero() public {
        vm.prank(USER);
        vm.expectRevert("send weis");
        chipToken.enter{value: 0}();
    }

    function testEnterEvent(uint256 value_) public {
        vm.assume(value_ > 0);
        vm.deal(USER, value_);

        int256 price = priceFeed.getChainlinkDataFeedLatestAnswer();
        require(price > 0, "invalid price");

        uint256 amount = value_ / uint256(price);

        vm.prank(USER);
        vm.expectEmit(true, true, false, false);
        emit PlayerEntered(USER, amount);
        chipToken.enter{value: value_}();
    }
}
