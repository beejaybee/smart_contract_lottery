// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { VRFConsumerBaseV2Plus } from
    "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
/**
 * @title Foundry Smart Contract | Lottery Project
 * @author BOLAJI OYEWO
 * @notice This contract is for creating a sample raffle
 * @dev Implements Chainlink VRFv2.5
*/

contract Raffle is VRFConsumerBaseV2Plus {
    /**
     * Custom Errors
     */
    error Raffle__SendMoreToEnterRaffle();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpened();
    error Raffle__UpKeepNotNeeded(uint256 balance, uint256 PlayersLength, uint256 state);

    /* Type Declarations */

    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /**
     * State Variables
     */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_OF_WORDS = 1;
    uint32 private immutable i_callbackGasLimit;
    uint256 private immutable i_entranceFee;
    uint256 private immutable i_subscriptionId;
    bytes32 private immutable i_keyHash;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner; 
    RaffleState private s_raffleState;
    // @dev duration of the lottery in seconds
    uint256 private immutable i_interval;

    /* EVENTS  */

    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
    event RaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subsrciptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_keyHash = gasLane;
        i_subscriptionId = subsrciptionId;
        i_callbackGasLimit = callbackGasLimit;
        
        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
    }

    /**
     * Raffle functions
     */

    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__SendMoreToEnterRaffle();
        }

        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpened();
        }

        s_players.push(payable(msg.sender));

        emit RaffleEntered(msg.sender);
    }

    // When should the winner be picked
    /**
     * @dev This is the function that the chainlink nodes will call to see
     * IF the lottery is ready to have a winner picked
     * The following should be true in order for upKeepNeeded to be true
     * 1. The time interval has passed between raffle runs
     * 2. The lottery is opened
     * 3. The contract has ETH
     * 4. Implicitly, your subcription has link
     * @param - ignored
     * @return upKeepNeeded - true if it's time to restart the lottery
     * @return - ignored
     */
    function checkUpKeep(bytes memory /*check Data */) 
    public
    view 
    returns (bool upKeepNeeded, bytes memory /*performData */){
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool isLotteryOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;

        upKeepNeeded = timeHasPassed && isLotteryOpen && hasBalance && hasPlayers;

        return (upKeepNeeded, "");

    }

    // get a random number
    // Use random number to pick a player
    // Be automatically called
    function performUpkeep(bytes calldata /* performData */) external {
        // 1. check to see if enough time had passed

        (bool upKeepNeeded,) = checkUpKeep("");
        if (!upKeepNeeded) {
            revert Raffle__UpKeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }
        
        // puting the raffle state to not be opened

        s_raffleState = RaffleState.CALCULATING;

        // 2. get random number from chainlink vrf

        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: i_keyHash,
            subId: i_subscriptionId,
            requestConfirmations: REQUEST_CONFIRMATIONS,
            callbackGasLimit: i_callbackGasLimit,
            numWords: NUM_OF_WORDS,
            extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false})) // new parameter
        });

        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
        emit RaffleWinner(requestId);
    }

    function fulfillRandomWords(uint256 /*requestId*/, uint256[] calldata randomWords) internal override {
        // checks

        // Effects (Internal contract state);
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit WinnerPicked(s_recentWinner);

        // Interaction (External contract interaction)
        (bool success,) = recentWinner.call{value: address(this).balance}("");
        if(!success) revert Raffle__TransferFailed();

    }

    /*/////////////////////////////////////////////////////////////////////////////////////
                                    Gettter Functions
     *////////////////////////////////////////////////////////////////////////////////////


    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns(RaffleState) {
        return s_raffleState;
    }
    function getPlayer(uint256 indexOfPlayer) external view returns(address) {
        return s_players[indexOfPlayer];
    }

    function getLastTimeStamp() external view returns(uint256) {
        return s_lastTimeStamp;
    }

    function getRecentWinner() external view returns(address) {
        return s_recentWinner;
    }

}
