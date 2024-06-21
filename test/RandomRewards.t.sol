// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {ChipToken} from "../src/ChipToken.sol";
import {PriceFeed} from "../src/PriceFeed.sol";
import {RandomRewards} from "../src/RandomRewards.sol";

contract RandomRewardsTest is Test {
    ChipToken public chipToken;
    PriceFeed public priceFeed;
    MockV3Aggregator public aggregatorMock;
    RandomRewards public randomRewards;
    VRFCoordinatorV2Mock public vrfCoordinatorMock;
    uint8 constant DECIMALS = 0;
    int8 constant RANDOM_MIN = -5;
    int8 constant RANDOM_MAX = 10;
    int256 constant INITIAL_ANSWER = 1000;
    address constant USER = address(1);
    uint64 constant SUSCRIPTION_ID = 1;

    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);

    function setUp() public {
        aggregatorMock = new MockV3Aggregator(DECIMALS, INITIAL_ANSWER);
        priceFeed = new PriceFeed(address(aggregatorMock));
        chipToken = new ChipToken(address(priceFeed));
        vrfCoordinatorMock = new VRFCoordinatorV2Mock(1, 1);
        randomRewards = new RandomRewards(
            SUSCRIPTION_ID,
            address(vrfCoordinatorMock),
            address(chipToken),
            RANDOM_MIN,
            RANDOM_MAX
        );

        vrfCoordinatorMock.createSubscription();
        vrfCoordinatorMock.addConsumer(SUSCRIPTION_ID, address(randomRewards));
        vrfCoordinatorMock.fundSubscription(SUSCRIPTION_ID, 1000000000000000000);
    }

    function testDeposit(uint256 value) public {
        vm.assume(value > 0);
        uint256 chipTokensAmount = _enter(value);

        assertEq(chipToken.balanceOf(USER), chipTokensAmount);
        assertEq(chipToken.balanceOf(address(randomRewards)), 0);

        vm.prank(USER);
        chipToken.approve(address(randomRewards), chipTokensAmount);

        vm.prank(USER);
        randomRewards.deposit(chipTokensAmount);

        assertEq(chipToken.balanceOf(USER), 0);
        assertEq(chipToken.balanceOf(address(randomRewards)), chipTokensAmount);
    }

    function testRoll() public {
        uint256 value = 1000000000;

        vm.assume(value > 0);
        uint256 chipTokensAmount = _enter(value);

        vm.startPrank(USER);
        chipToken.approve(address(randomRewards), chipTokensAmount);

        randomRewards.deposit(chipTokensAmount);

        uint256 requestId = randomRewards.roll();
        
        vrfCoordinatorMock.fulfillRandomWords(requestId, address(randomRewards));

        randomRewards.withdraw(requestId);

        console.log(chipToken.balanceOf(USER));
        console.log(chipToken.balanceOf(address(randomRewards)));
    }

    function _enter(uint256 value_) internal returns (uint256 amount) {
        vm.deal(USER, value_);
        vm.prank(USER);
        chipToken.enter{value: value_}();

        int256 price = priceFeed.getChainlinkDataFeedLatestAnswer();
        require(price > 0, "invalid price");

        amount = value_ / uint256(price);
    }

    // function testEnterRevertIfValueIsZero() public {
    //     vm.prank(USER);
    //     vm.expectRevert("send weis");
    //     chipToken.enter{value: 0}();
    // }

    // function testEnterEvent(uint256 value_) public {
    //     vm.assume(value_ > 0);
    //     vm.deal(USER, value_);

    //     int256 price = priceFeed.getChainlinkDataFeedLatestAnswer();
    //     require(price > 0, "invalid price");

    //     uint256 amount = value_ / uint256(price);

    //     vm.prank(USER);
    //     vm.expectEmit(true, true, false, false);
    //     emit PlayerEntered(USER, amount);
    //     chipToken.enter{value: value_}();
    // }
}
