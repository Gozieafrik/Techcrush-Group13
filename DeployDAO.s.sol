// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {GovernanceToken} from "../src/GovernanceToken.sol";
import {DAOTimelockController} from "../src/TimelockController.sol";
import {DAOGovernor} from "../src/DAOGoverner.sol";
import {DAOTreasury} from "../src/DAOTreasury.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract DeployDAO is Script {
    GovernanceToken public token;
    DAOTimelockController public timelock;
    DAOGovernor public governor;
    DAOTreasury public treasury;
    
    uint256 public constant MIN_DELAY = 2 days;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying DAO System...");
        console.log("Deployer address:", deployer);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Step 1: Deploy Governance Token
        console.log("\n1. Deploying Governance Token...");
        token = new GovernanceToken();
        console.log("Governance Token deployed to:", address(token));
        
        // Step 2: Setup Timelock
        console.log("\n2. Setting up Timelock Controller...");
        address[] memory proposers = new address[](1);
        proposers[0] = address(token); // Will be replaced by governor
        address[] memory executors = new address[](1);
        executors[0] = address(0); // Zero address allows anyone to execute after delay
        
        timelock = new DAOTimelockController(
            MIN_DELAY,
            proposers,
            executors,
            deployer
        );
        console.log("Timelock Controller deployed to:", address(timelock));
        
        // Step 3: Deploy Governor
        console.log("\n3. Deploying DAO Governor...");
        governor = new DAOGovernor(
            IVotes(address(token)),
            TimelockController(address(timelock))
        );
        console.log("DAO Governor deployed to:", address(governor));
        
        // Step 4: Deploy Treasury
        console.log("\n4. Deploying DAO Treasury...");
        treasury = new DAOTreasury(address(governor), deployer);
        console.log("DAO Treasury deployed to:", address(treasury));
        
        // Step 5: Grant Roles
        console.log("\n5. Granting roles...");
        
        // Grant proposer role to governor
        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        timelock.grantRole(proposerRole, address(governor));
        
        // Grant executor role to governor
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        timelock.grantRole(executorRole, address(governor));
        
        // Revoke admin role from deployer (security)
        bytes32 adminRole = timelock.DEFAULT_ADMIN_ROLE();
        timelock.revokeRole(adminRole, deployer);
        
        console.log("\nDAO System Deployed Successfully!");
        console.log("=========================================");
        console.log("Token Address:", address(token));
        console.log("Timelock Address:", address(timelock));
        console.log("Governor Address:", address(governor));
        console.log("Treasury Address:", address(treasury));
        console.log("=========================================");
        
        // Step 6: Transfer some tokens to users for testing
        console.log("\n6. Distributing initial tokens...");
        
        // Transfer tokens to test addresses (for demonstration)
        address testUser1 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
        address testUser2 = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
        
        token.transfer(testUser1, 10000 * 10**18);
        token.transfer(testUser2, 5000 * 10**18);
        
        console.log("Transferred 10,000 GOV to test user 1");
        console.log("Transferred 5,000 GOV to test user 2");
        
        vm.stopBroadcast();
        
        // Save deployment info
        _saveDeploymentInfo();
    }
    
    function _saveDeploymentInfo() internal {
        string memory output = string(
            abi.encodePacked(
                "DAO Deployment Info:\n",
                "Token: ", vm.toString(address(token)), "\n",
                "Timelock: ", vm.toString(address(timelock)), "\n",
                "Governor: ", vm.toString(address(governor)), "\n",
                "Treasury: ", vm.toString(address(treasury)), "\n"
            )
        );
        
        vm.writeFile("deployment-info.txt", output);
    }
}