// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Script, console } from "forge-std/Script.sol";
import { HelperConfig, CodeConstants } from "./HelperConfig.s.sol";
import { VRFCoordinatorV2_5Mock } 
from 
"lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

import { LinkToken } from "test/mocks/LinkToken.sol";
import { DevOpsTools } from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns(uint256, address){
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        address account = helperConfig.getConfig().account;
        // create subscription
        (uint256 subId, ) = createSubscription(vrfCoordinator, account);
        return(subId, vrfCoordinator);
    }

    function createSubscription(address _vrfCoordinator, address _account) public returns (uint256, address) {
        console.log("Creating subscription on chainId: ", block.chainid);

        vm.startBroadcast(_account);
        uint256 subId = VRFCoordinatorV2_5Mock(_vrfCoordinator).createSubscription();
        vm.stopBroadcast();

        console.log("Your subscription Id is: ", subId);
        console.log("Please update the subscriptionId in HelperConfig.s.sol");
        console.log("This is the VRF cordinator creating subscription", _vrfCoordinator);

        return (subId, _vrfCoordinator);
    }

    function run() public {
        createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script, CodeConstants{

    uint256 public constant FUND_AMOUNT = 3 ether; // 3 LINK

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        address linkToken = helperConfig.getConfig().link;
        address account = helperConfig.getConfig().account;

        fundSubscription(vrfCoordinator, subscriptionId, linkToken, account);
    }

    function fundSubscription(
        address _vrfCoordinator, uint256 _subscriptionId, address _linkToken, address _account 
        )  
        public {
        console.log("Funding subscription : ", _subscriptionId);
        console.log("Using vrfCoordinator :", _vrfCoordinator);
        console.log("On chainid: ", block.chainid);
        console.log("Using link token :", _linkToken);

        if(block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(_vrfCoordinator).fundSubscription(_subscriptionId, FUND_AMOUNT * 100);
            vm.stopBroadcast();
            console.log("Funded with:", FUND_AMOUNT);
        } else {
            vm.startBroadcast(_account);
            LinkToken(_linkToken).transferAndCall(_vrfCoordinator, FUND_AMOUNT, abi.encode(_subscriptionId));
            vm.stopBroadcast();
        }
    }

    function run() public {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {

    function addConsumerUsingConfig(address _mostRecentlyDeployed) public {
        HelperConfig helperConfig = new HelperConfig();
        uint256 subId = helperConfig.getConfig().subscriptionId; 
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        address account = helperConfig.getConfig().account;
        addConsumer(_mostRecentlyDeployed, vrfCoordinator, subId, account);
    }

    function addConsumer(address _contractToAddToVrf, address _vrfCoordinator, uint256 _subId, address _account) public {
        console.log("Adding contract :", _contractToAddToVrf);
        console.log("to the VRF Coordinator", _vrfCoordinator);
        console.log("On chaid Id :", block.chainid);

        vm.startBroadcast(_account);
        VRFCoordinatorV2_5Mock(_vrfCoordinator).addConsumer(_subId, _contractToAddToVrf);
        vm.stopBroadcast();
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Raffled", block.chainid);
        addConsumerUsingConfig(mostRecentlyDeployed);
    }
}
