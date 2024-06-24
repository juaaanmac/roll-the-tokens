// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ChipToken} from "../src/ChipToken.sol";
import {PriceFeed} from "../src/PriceFeed.sol";
import {RandomRewards} from "../src/RandomRewards.sol";

contract DeployScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("ADMIN_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address priceFeedAddress = vm.envAddress("PRICE_FEED");
        PriceFeed priceFeed = new PriceFeed(priceFeedAddress);

        ChipToken chipToken = new ChipToken(address(priceFeed), "ChipToken", "CHT");

        uint64 vrfSuscriptionId = uint64(vm.envUint("VRF_SUSCRIPTION_ID"));
        address vrfCoordinatorV2 = vm.envAddress("VRF_COORDINATORV2_ADDRESS");
        int8 randomMin = -5;
        int8 randomMax = 10;

        new RandomRewards(vrfSuscriptionId, vrfCoordinatorV2, address(chipToken), randomMin, randomMax);

        vm.stopBroadcast();
    }
}
