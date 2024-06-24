// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/console.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract PriceFeed {
    AggregatorV3Interface internal immutable dataFeed;

    // sepolia 0x694AA1769357215DE4FAC081bf1f309aDC325306
    constructor(address dataFeed_) {
        dataFeed = AggregatorV3Interface(dataFeed_);
    }

    /**
     * Returns the latest answer.
     */
    function getChainlinkDataFeedLatestAnswer() public view returns (int256) {
        //slither-disable-next-line unused-return
        (, int256 answer,,,) = dataFeed.latestRoundData();
        return answer;
    }
}
