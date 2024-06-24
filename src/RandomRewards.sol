// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/console.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import {ChipToken} from "./ChipToken.sol";

/**
 * @title Crazy staking rewards smart contract
 * @author Juan Macri
 * @notice this smart contract generates random reward tokens
 */
contract RandomRewards is Context, VRFConsumerBaseV2, ReentrancyGuard {
    using SafeERC20 for ChipToken;

    struct RequestStatus {
        bool exists;
        bool fulfilled;
        address player;
        uint256 randomResult;
    }

    // Contract Variables
    ChipToken internal immutable _chipToken;
    uint256 internal totalStaked = 0;
    int8 internal immutable randomMin;
    int8 internal immutable randomMax;

    // address --> balance
    mapping(address => uint256) internal _balances;

    // Chainlink Variables
    VRFCoordinatorV2Interface internal immutable _coordinator;
    uint64 internal immutable _suscriptionId;
    bytes32 internal constant KEY_HASK = 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;
    uint32 internal constant CALLBACK_GAS_LIMIT = 100000;
    uint16 internal constant REQUEST_CONFIRMATIONS = 3;
    uint32 internal constant NUM_WORDS = 1;

    /* requestId --> requestStatus */
    mapping(uint256 => RequestStatus) public requests;

    modifier requestExists(uint256 _requestId) {
        require(requests[_requestId].exists, "nonexistent request");
        _;
    }

    // Contract events
    event DepositMade(address account, uint256 amount);

    // Chainlink events
    event RequestSent(uint256 requestId);
    event RequestFulfilled(uint256 requestId, uint256 randomResult);

    //0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625
    constructor(
        uint64 subscriptionId,
        address vrfCoordinatorV2Address,
        address chipToken,
        int8 randomMin_,
        int8 randomMax_
    ) VRFConsumerBaseV2(vrfCoordinatorV2Address) {
        _chipToken = ChipToken(chipToken);
        _coordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2Address);
        _suscriptionId = subscriptionId;
        randomMin = randomMin_;
        randomMax = randomMax_;
    }

    function deposit(uint256 amount) external {
        address sender = _msgSender();
        _balances[sender] += amount;
        totalStaked += amount;

        emit DepositMade(sender, amount);

        _chipToken.safeTransferFrom(sender, address(this), amount);
    }

    function roll() external nonReentrant returns (uint256) {
        address player = _msgSender();
        require(_balances[player] > 0, "no balance");

        //Calling requestRandomWords from the coordinator contract
        uint256 requestId = _coordinator.requestRandomWords(
            KEY_HASK, _suscriptionId, REQUEST_CONFIRMATIONS, CALLBACK_GAS_LIMIT, NUM_WORDS
        );

        // store new request
        requests[requestId] = RequestStatus({randomResult: 0, player: player, exists: true, fulfilled: false});

        // increase allowance in ChipToken
        _chipToken.safeIncreaseAllowance(address(this), _balances[player]);

        emit RequestSent(requestId);

        return requestId;
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords)
        internal
        override
        requestExists(requestId)
    {
        // update request with random result generated by VRF
        requests[requestId].fulfilled = true;
        requests[requestId].randomResult = randomWords[0];

        emit RequestFulfilled(requestId, randomWords[0]);
    }

    function withdraw(uint256 requestId) external requestExists(requestId) {
        address player = _msgSender();

        require(requests[requestId].player == player, "invalid player");
        require(requests[requestId].fulfilled, "not fulfilled");

        RequestStatus memory request = requests[requestId];

        // To generate a random number between -5 and 10 inclusive
        int256 randomNumber = (int256(request.randomResult) % randomMax) + randomMin;

        uint256 balance = _balances[player];
        uint256 amount = 0;

        if (randomNumber > 0) {
            amount = balance + (balance * SignedMath.abs(randomNumber)) / 100;
        } else if (randomNumber < 0) {
            amount = balance - (balance * SignedMath.abs(randomNumber)) / 100;
        }

        _balances[player] = 0;

        _chipToken.safeTransferFrom(address(this), player, amount);
    }

    function getRequestStatus(uint256 requestId)
        external
        view
        requestExists(requestId)
        returns (bool fulfilled, uint256 randomResult)
    {
        RequestStatus memory request = requests[requestId];
        return (request.fulfilled, request.randomResult);
    }

    function balanceOf(address account) external view virtual returns (uint256) {
        return _balances[account];
    }
}
