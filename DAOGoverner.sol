// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";

/**
 * @title DAOGovernor
 * @dev Complete DAO governance system with voting, timelock, and quorum
 */
contract DAOGovernor is 
    Governor, 
    GovernorSettings, 
    GovernorCountingSimple, 
    GovernorVotes, 
    GovernorVotesQuorumFraction,
    GovernorTimelockControl
{
    uint256 public constant VOTING_DELAY = 1 days;     // 1 day after proposal created
    uint256 public constant VOTING_PERIOD = 5 days;    // 5 days to vote
    uint256 public constant QUORUM_PERCENTAGE = 4;     // 4% quorum required
    uint256 public constant PROPOSAL_THRESHOLD = 1000 * 10**18; // 1000 tokens to create proposal
    
    event ProposalCreatedExtended(
        uint256 proposalId,
        address proposer,
        string description,
        uint256 votingStart,
        uint256 votingEnd
    );
    
    constructor(
        IVotes _token,
        TimelockController _timelock
    ) 
        Governor("DAOGovernor")
        GovernorSettings(VOTING_DELAY, VOTING_PERIOD, PROPOSAL_THRESHOLD)
        GovernorVotes(_token)
        GovernorVotesQuorumFraction(QUORUM_PERCENTAGE)
        GovernorTimelockControl(_timelock)
    {}
    
    /**
     * @dev Create a new proposal
     * @param targets Target contracts to call
     * @param values ETH values to send
     * @param calldatas Function calldata
     * @param description Description of proposal
     */
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public override(Governor, IGovernor) returns (uint256) {
        uint256 proposalId = super.propose(targets, values, calldatas, description);
        
        emit ProposalCreatedExtended(
            proposalId,
            msg.sender,
            description,
            proposalSnapshot(proposalId),
            proposalDeadline(proposalId)
        );
        
        return proposalId;
    }
    
    /**
     * @dev Cancel a proposal (only if not executed yet)
     */
    function cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public override returns (uint256) {
        return super.cancel(targets, values, calldatas, descriptionHash);
    }
    
    // Required overrides
    function votingDelay()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.votingDelay();
    }
    
    function votingPeriod()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.votingPeriod();
    }
    
    function proposalThreshold()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.proposalThreshold();
    }
    
    function quorum(uint256 blockNumber)
        public
        view
        override(GovernorVotesQuorumFraction)
        returns (uint256)
    {
        return super.quorum(blockNumber);
    }
    
    function state(uint256 proposalId)
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (ProposalState)
    {
        return super.state(proposalId);
    }
    
    function _execute(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        super._execute(proposalId, targets, values, calldatas, descriptionHash);
    }
    
    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }
    
    function _executor()
        internal
        view
        override(Governor, GovernorTimelockControl)
        returns (address)
    {
        return super._executor();
    }
    
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}