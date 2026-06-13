// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {GovernanceToken} from "../src/GovernanceToken.sol";
import {DAOTimelockController} from "../src/TimelockController.sol";
import {DAOGovernor} from "../src/DAOGoverner.sol";
import {DAOTreasury} from "../src/Treasury.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";

contract DAOGovernorTest is Test {
    GovernanceToken public token;
    DAOTimelockController public timelock;
    DAOGovernor public governor;
    DAOTreasury public treasury;
    
    address public admin = address(0x1);
    address public member1 = address(0x2);
    address public member2 = address(0x3);
    address public member3 = address(0x4);
    address public nonMember = address(0x5);
    
    uint256 public constant MIN_DELAY = 2 days;
    uint256 public constant VOTING_DELAY = 1 days;
    uint256 public constant VOTING_PERIOD = 5 days;
    
    // Test proposal data
    address[] public targets;
    uint256[] public values;
    bytes[] public calldatas;
    string public description = "Test Proposal: Transfer 100 ETH to Treasury";
    
    function setUp() public {
        vm.startPrank(admin);
        
        // Deploy token
        token = new GovernanceToken();
        
        // Setup timelock
        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](0);
        timelock = new DAOTimelockController(MIN_DELAY, proposers, executors, admin);
        
        // Deploy governor
        governor = new DAOGovernor(
            IVotes(address(token)),
            TimelockController(address(timelock))
        );
        
        // Deploy treasury
        treasury = new DAOTreasury(address(governor), admin);
        
        // Grant roles
        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        
        timelock.grantRole(proposerRole, address(governor));
        timelock.grantRole(executorRole, address(governor));
        timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), admin);
        
        // Distribute tokens with voting power
        token.transfer(member1, 10000 * 10**18);
        token.transfer(member2, 5000 * 10**18);
        token.transfer(member3, 2000 * 10**18);
        
        // Delegate voting power
        vm.stopPrank();
        
        vm.prank(member1);
        token.delegate(member1);
        
        vm.prank(member2);
        token.delegate(member2);
        
        vm.prank(member3);
        token.delegate(member3);
        
        // Setup test proposal
        targets = new address[](1);
        targets[0] = address(treasury);
        values = new uint256[](1);
        values[0] = 0;
        calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature(
            "withdrawETH(address,uint256)",
            admin,
            1 ether
        );
    }
    
    function test_InitialState() public view {
        assertEq(token.totalSupply(), 1_000_000 * 10**18);
        assertEq(token.balanceOf(member1), 10000 * 10**18);
        assertEq(token.getVotes(member1), 10000 * 10**18);
        assertEq(address(governor), address(governor));
    }
    
    function test_CreateProposal() public {
        vm.prank(member1);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);
        
        assertTrue(proposalId != 0);
        
        IGovernor.ProposalState state = governor.state(proposalId);
        assertEq(uint256(state), uint256(IGovernor.ProposalState.Pending));
    }
    
    function test_CannotCreateProposalWithoutEnoughTokens() public {
        vm.prank(nonMember);
        vm.expectRevert("Governor: proposer votes below proposal threshold");
        governor.propose(targets, values, calldatas, description);
    }
    
    function test_CastVote() public {
        vm.prank(member1);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);
        
        // Move to voting period
        vm.warp(block.timestamp + VOTING_DELAY + 1);
        
        vm.prank(member1);
        governor.castVote(proposalId, 1); // Vote For
        
        (, uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) = governor.proposalVotes(proposalId);
        
        assertEq(forVotes, 10000 * 10**18);
        assertEq(againstVotes, 0);
        assertEq(abstainVotes, 0);
    }
    
    function test_MultipleVotes() public {
        vm.prank(member1);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);
        
        vm.warp(block.timestamp + VOTING_DELAY + 1);
        
        // Member1 votes For
        vm.prank(member1);
        governor.castVote(proposalId, 1);
        
        // Member2 votes Against
        vm.prank(member2);
        governor.castVote(proposalId, 0);
        
        (, uint256 againstVotes, uint256 forVotes, ) = governor.proposalVotes(proposalId);
        
        assertEq(forVotes, 10000 * 10**18);
        assertEq(againstVotes, 5000 * 10**18);
    }
    
    function test_QueueAndExecuteProposal() public {
        // Create proposal
        vm.prank(member1);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);
        
        // Move to voting period
        vm.warp(block.timestamp + VOTING_DELAY + 1);
        
        // Cast votes (enough for quorum)
        vm.prank(member1);
        governor.castVote(proposalId, 1);
        
        vm.prank(member2);
        governor.castVote(proposalId, 1);
        
        vm.prank(member3);
        governor.castVote(proposalId, 1);
        
        // Move to after voting period
        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        
        // Queue proposal
        bytes32 descriptionHash = keccak256(bytes(description));
        governor.queue(targets, values, calldatas, descriptionHash);
        
        // Move past timelock delay
        vm.warp(block.timestamp + MIN_DELAY + 1);
        
        // Execute proposal
        vm.prank(admin);
        governor.execute(targets, values, calldatas, descriptionHash);
        
        // Verify execution
        IGovernor.ProposalState state = governor.state(proposalId);
        assertEq(uint256(state), uint256(IGovernor.ProposalState.Executed));
    }
    
    function test_ProposalFailsWithoutQuorum() public {
        vm.prank(member3); // Only 2000 votes (2% of supply, less than 4% quorum)
        uint256 proposalId = governor.propose(targets, values, calldatas, description);
        
        vm.warp(block.timestamp + VOTING_DELAY + 1);
        
        vm.prank(member3);
        governor.castVote(proposalId, 1);
        
        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        
        IGovernor.ProposalState state = governor.state(proposalId);
        assertEq(uint256(state), uint256(IGovernor.ProposalState.Defeated));
    }
    
    function test_CancelProposal() public {
        vm.prank(member1);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);
        
        // Cancel before voting starts
        bytes32 descriptionHash = keccak256(bytes(description));
        governor.cancel(targets, values, calldatas, descriptionHash);
        
        IGovernor.ProposalState state = governor.state(proposalId);
        assertEq(uint256(state), uint256(IGovernor.ProposalState.Canceled));
    }
    
    function test_DelegateVotingPower() public {
        vm.prank(member1);
        token.delegate(member2);
        
        uint256 votes = token.getVotes(member2);
        assertEq(votes, 10000 * 10**18);
    }
    
    function test_TransferTokensReducesVotingPower() public {
        uint256 initialVotes = token.getVotes(member1);
        
        vm.prank(member1);
        token.transfer(member2, 5000 * 10**18);
        
        // Voting power updates after next block
        vm.roll(block.number + 1);
        
        uint256 newVotes = token.getVotes(member1);
        assertEq(newVotes, initialVotes - 5000 * 10**18);
    }
    
    function test_TreasuryDepositAndWithdraw() public {
        // Deposit ETH to treasury
        vm.deal(admin, 10 ether);
        vm.prank(admin);
        payable(address(treasury)).transfer(5 ether);
        
        assertEq(treasury.getBalance(), 5 ether);
        
        // Withdraw via governance (would need proposal)
        vm.prank(address(governor));
        treasury.withdrawETH(payable(admin), 2 ether);
        
        assertEq(treasury.getBalance(), 3 ether);
    }
    
    function test_OnlyExecutorCanWithdrawFromTreasury() public {
        vm.deal(admin, 10 ether);
        vm.prank(admin);
        payable(address(treasury)).transfer(5 ether);
        
        vm.prank(nonMember);
        vm.expectRevert();
        treasury.withdrawETH(payable(admin), 1 ether);
    }
    
    function test_VoteWeightCalculation() public {
        uint256 votes1 = token.getVotes(member1);
        uint256 votes2 = token.getVotes(member2);
        
        assertEq(votes1, 10000 * 10**18);
        assertEq(votes2, 5000 * 10**18);
    }
    
    function test_ProposalThreshold() public {
        uint256 threshold = governor.proposalThreshold();
        assertEq(threshold, 1000 * 10**18);
        
        // Member with 500 tokens should not be able to propose
        address lowBalanceUser = address(0x6);
        token.transfer(lowBalanceUser, 500 * 10**18);
        
        vm.prank(lowBalanceUser);
        vm.expectRevert("Governor: proposer votes below proposal threshold");
        governor.propose(targets, values, calldatas, description);
    }
}