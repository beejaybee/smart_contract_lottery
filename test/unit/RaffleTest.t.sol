// SPDX-License-Identifier: MIT


pragma solidity ^0.8.19;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/Script.sol";
import { DeployRaffle } from "script/DeployRaffle.s.sol";
import { Raffle } from "src/Raffle.sol";
import { HelperConfig } from "script/HelperConfig.s.sol";
import { Vm } from "forge-std/Vm.sol";
import { VRFCoordinatorV2_5Mock } 
from 
"lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import { CodeConstants } from "script/Interaction.s.sol";


contract RaffleTest is Test, CodeConstants {
    Raffle public raffle;
    HelperConfig public helperConfig;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subsrciptionId;
    uint32 callbackGasLimit;

    event RaffleEntered(address indexed player);

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();

        (raffle, helperConfig) = deployRaffle.deployContract();

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
            entranceFee = config.entranceFee;
            interval = config.interval;
            vrfCoordinator = config.vrfCoordinator;
            gasLane = config.gasLane;
            subsrciptionId = config.subscriptionId;
            callbackGasLimit = config.callbackGasLimit;

            vm.deal(PLAYER, STARTING_PLAYER_BALANCE);

    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }


    /* ////////////////////////////////////////////////////////////////////
    
                                ENTER RAFLE         
    /////////////////////////////////////////////////////////////////////*/

    function testRaffleRevertWhenYouDontPayEnoughEth() public {
        // Arrange
        vm.prank(PLAYER);
        // Act / Assert
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayersWhenTheyEnter() public {
        // Arrange
        vm.prank(PLAYER);
        // Act
        raffle.enterRaffle{value: entranceFee}();

        // Assert
        address playerRecord = raffle.getPlayer(0);

        assert(playerRecord == PLAYER);

    }

    function testEnteringRaffleEmitsEvent() public {
        // Arrange
        vm.prank(PLAYER);
        // Act
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);
        // Assert
        raffle.enterRaffle{value: entranceFee}();
    }

    function testDontAllowPlayersToEnterWhileRaffleIsCalculaing() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        // Act / Assert
        vm.expectRevert(Raffle.Raffle__RaffleNotOpened.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

    }

    /*//////////////////////////////////////////////////////////////////////
                                CHECK-UPKEEP
    /////////////////////////////////////////////////////////////////////*/


    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        // Arrange

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        //Act

        (bool upkeepNeeded,) = raffle.checkUpKeep("");

        // Assert

        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleIsClosed() public {
        // Arrange

        vm.prank(PLAYER);

        raffle.enterRaffle{value: entranceFee}();

        vm.warp(block.timestamp + interval + 1);

        vm.roll(block.number + 1);

        raffle.performUpkeep("");

        // Act

        (bool upkeepNeeded,) = raffle.checkUpKeep("");

        // Assert

        assert(!upkeepNeeded);
    }

    // Challenge
    // test testCheckUpkeepReturnsFalseIfEnoughHasPassed

    function testCheckUpkeepReturnsFalseIfEnoughTimeHasNotPassed() public {
        // Arrange
        
        vm.prank(PLAYER);

        raffle.enterRaffle{value: entranceFee}();

        // Act

        (bool upkeepNeeded,) = raffle.checkUpKeep("");

        // Assert

        assert(!upkeepNeeded);
    }

    // CheckUpkeepReturnsTrueIfParamsAreGood
    function testCheckUpkeepReturnsTrueIfAllParamsAreGood() public raffleEntered {

        // Act
        
        (bool upkeepNeeded,) = raffle.checkUpKeep("");

        // Assert

        assert(upkeepNeeded);
    }


    /*////////////////////////////////////////////////////////////////////////
                                PERFOM UPKEEP
    */////////////////////////////////////////////////////////////////////////



    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public raffleEntered {

        // Act /Assert

        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsWhenCheckUpkeepIsFalse() public {
        // Arrange

        uint256 currentBalance = 0;
        uint256 numberOfPlayers = 0;

        Raffle.RaffleState rState = raffle.getRaffleState();


        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        currentBalance = currentBalance + entranceFee;
        numberOfPlayers = 1;

        // Act / Assert

        vm.expectRevert(
            abi.encodeWithSelector(
            Raffle.Raffle__UpKeepNotNeeded.selector, 
            currentBalance,
            numberOfPlayers, 
            rState
            ) 
        );

        raffle.performUpkeep("");
    }

    modifier raffleEntered {
         // Arrange 

        vm.prank(PLAYER);

        raffle.enterRaffle{value: entranceFee}();

        vm.warp(block.timestamp + interval + 1);

        vm.roll(block.number + 1);

        _;
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public raffleEntered {

        // Act

        vm.recordLogs();

        raffle.performUpkeep("");

        Vm.Log[] memory entries = vm.getRecordedLogs();

        bytes32 requestId = entries[1].topics[1];

        // Assert

        Raffle.RaffleState raffleState = raffle.getRaffleState();

        assert(uint256(requestId) > 0);

        assert(uint256(raffleState) == 1);

    }


    /*//////////////////////////////////////////////////////////////////
                            FUFILRANDOMWORDS
    //////////////////////////////////////////////////////////////////*/

    modifier skipFork() {
        if (block.chainid != LOCAL_CHAIN_ID) {
            return;
        }
        _;
    }

    function testFulfillRandomCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId) public skipFork raffleEntered {
        // Arrange / Act /assert

        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
    }

    function testRandomWordPicksAWinnerAResetsAndSensMoney() public skipFork raffleEntered {

        // Arrange

        uint256 additionalEntrants = 3; // 4 people Entered raffle in total
        uint256 startingIndex = 1;
        address expectedWinner = address(1);

        for(uint256 i = startingIndex; i < startingIndex + additionalEntrants; i++) {
            address newPlayer = address(uint160(i));

            hoax(newPlayer, STARTING_PLAYER_BALANCE);

            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 winnerStartingBalance = expectedWinner.balance;

        // Act

        vm.recordLogs();

        raffle.performUpkeep("");

        Vm.Log[] memory entries = vm.getRecordedLogs();

        bytes32 requestId = entries[1].topics[1];

        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        // Assert

        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();

        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = entranceFee * (additionalEntrants + 1);

        assert(recentWinner == expectedWinner);
        assert(uint256(raffleState) == 0);
        assert(winnerBalance == winnerStartingBalance + prize);
        assert(endingTimeStamp > startingTimeStamp);
    }  
}
