// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import {ChipTokenHarness} from "./contracts/ChipTokenHarness.sol";
import {PriceFeed} from "../src/PriceFeed.sol";

contract ChipTokenTest is Test {
    ChipTokenHarness public chipToken;
    PriceFeed public priceFeed;
    MockV3Aggregator public mockAggregator;
    uint8 constant DECIMALS = 0;
    int256 constant INITIAL_ANSWER = 1000;
    address constant USER = address(1);
    address constant OWNER = address(2);

    event PlayerEntered(address player, uint256 amount);
    event BalanceWithdrawn(uint256 amount);

    function setUp() public {
        mockAggregator = new MockV3Aggregator(DECIMALS, INITIAL_ANSWER);
        priceFeed = new PriceFeed(address(mockAggregator));
        vm.prank(OWNER);
        chipToken = new ChipTokenHarness(address(priceFeed), "ChipTokens", "CHT");
    }

    function testConstructor() public view {
        assertEq(chipToken.symbol(), "CHT");
        assertEq(chipToken.name(), "ChipTokens");
        assertEq(chipToken.getPriceFeed(), address(priceFeed));
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
        assertEq(chipToken.getBalance(), value_);
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

    function testWithdrawBalance(uint256 value) public {
        vm.assume(value > 1000000);

        vm.deal(USER, value);
        vm.prank(USER);
        chipToken.enter{value: value}();

        vm.prank(OWNER);
        chipToken.withdraw(value);

        assertEq(payable(OWNER).balance, value);
        assertEq(chipToken.getBalance(), 0);
    }

    function testWithdrawEvent(uint256 value) public {
        vm.assume(value > 1000000);

        vm.deal(USER, value);
        vm.prank(USER);
        chipToken.enter{value: value}();

        vm.expectEmit(true, false, false, false);
        emit BalanceWithdrawn(value);
        vm.prank(OWNER);
        chipToken.withdraw(value);
    }

    function testWithdrawRevertIfCallerIsNotTheOwner(address notOwner) public {
        uint256 value = 1000000;
        bytes4 selector = bytes4(keccak256("OwnableUnauthorizedAccount(address)"));

        vm.deal(USER, value);
        vm.prank(USER);
        chipToken.enter{value: value}();

        vm.prank(notOwner);
        vm.expectRevert(abi.encodeWithSelector(selector, notOwner));
        chipToken.withdraw(value);
    }

    function _enterChipTokensAmount(uint256 value) internal view returns (uint256) {
        int256 price = priceFeed.getChainlinkDataFeedLatestAnswer();
        require(price > 0, "invalid price");
        uint256 amount = value / uint256(price);
        return amount;
    }
}
