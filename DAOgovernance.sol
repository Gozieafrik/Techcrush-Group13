// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title DAO Governance System
 * @dev Decentralized Autonomous Organization for proposal voting and treasury management
 */
contract DAOGovernance {
    // ============ STRUCTS ============
    
    struct Proposal {
        uint256 id;
        string title;
        string description;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 votingEndTime;
        address proposer;
        bool executed;
        ProposalStatus status;
    }
    
    struct Member {
        bool isActive;
        uint256 votingPower;
        uint256 joinedAt;
        uint256 lastVoteTimestamp;
    }
    
    enum ProposalStatus {
        Pending,
        Active,
        Passed,
        Rejected,
        Executed
    }
    
    // ============ STATE VARIABLES ============
    
    string public title = "DAO Governance System";
    address public admin;
    uint256 public proposalCount;
    uint256 public votingDuration = 7 days;
    uint256 public minimumQuorum = 10; // Minimum voting power required (in percentage, 10 = 10%)
    
    mapping(uint256 => Proposal) public proposals;
    mapping(address => Member) public members;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(address => bool) public isWhitelisted;
    
    uint256 public totalVotingPower;
    uint256 public activeMembersCount;
    
    // ============ EVENTS ============
    
    event MemberAdded(address indexed member, uint256 votingPower);
    event MemberRemoved(address indexed member);
    event ProposalCreated(uint256 indexed proposalId, string title, address proposer);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 votingPower);
    event ProposalExecuted(uint256 indexed proposalId);
    event VotingDurationUpdated(uint256 newDuration);
    event WhitelistUpdated(address indexed account, bool isWhitelisted);
    
    // ============ MODIFIERS ============
    
    modifier onlyAdmin() {
        require(msg.sender == admin, "DAO: Only admin can call this");
        _;
    }
    
    modifier onlyActiveMember() {
        require(members[msg.sender].isActive, "DAO: Only active members can call this");
        _;
    }
    
    modifier proposalExists(uint256 _proposalId) {
        require(_proposalId > 0 && _proposalId <= proposalCount, "DAO: Proposal does not exist");
        _;
    }
    
    // ============ CONSTRUCTOR ============
    
    constructor() {
        admin = msg.sender;
        members[admin] = Member({
            isActive: true,
            votingPower: 100,
            joinedAt: block.timestamp,
            lastVoteTimestamp: 0
        });
        totalVotingPower = 100;
        activeMembersCount = 1;
        emit MemberAdded(admin, 100);
    }
    
    // ============ MEMBER MANAGEMENT FUNCTIONS ============
    
    function addMember(address _member, uint256 _votingPower) external onlyAdmin {
        require(_member != address(0), "DAO: Invalid address");
        require(!members[_member].isActive, "DAO: Member already exists");
        require(_votingPower > 0, "DAO: Voting power must be greater than 0");
        
        members[_member] = Member({
            isActive: true,
            votingPower: _votingPower,
            joinedAt: block.timestamp,
            lastVoteTimestamp: 0
        });
        
        totalVotingPower += _votingPower;
        activeMembersCount++;
        emit MemberAdded(_member, _votingPower);
    }
    
    function removeMember(address _member) external onlyAdmin {
        require(members[_member].isActive, "DAO: Member does not exist");
        require(_member != admin, "DAO: Cannot remove admin");
        
        totalVotingPower -= members[_member].votingPower;
        activeMembersCount--;
        delete members[_member];
        emit MemberRemoved(_member);
    }
    
    function updateVotingPower(address _member, uint256 _newVotingPower) external onlyAdmin {
        require(members[_member].isActive, "DAO: Member does not exist");
        require(_newVotingPower > 0, "DAO: Voting power must be greater than 0");
        
        totalVotingPower = totalVotingPower - members[_member].votingPower + _newVotingPower;
        members[_member].votingPower = _newVotingPower;
    }
    
    // ============ PROPOSAL FUNCTIONS ============
    
    function createProposal(string memory _title, string memory _description) external onlyActiveMember {
        require(bytes(_title).length > 0, "DAO: Title cannot be empty");
        require(bytes(_description).length > 0, "DAO: Description cannot be empty");
        
        proposalCount++;
        
        proposals[proposalCount] = Proposal({
            id: proposalCount,
            title: _title,
            description: _description,
            votesFor: 0,
            votesAgainst: 0,
            votingEndTime: block.timestamp + votingDuration,
            proposer: msg.sender,
            executed: false,
            status: ProposalStatus.Active
        });
        
        emit ProposalCreated(proposalCount, _title, msg.sender);
    }
    
    function castVote(uint256 _proposalId, bool _support) external onlyActiveMember proposalExists(_proposalId) {
        Proposal storage proposal = proposals[_proposalId];
        
        require(block.timestamp < proposal.votingEndTime, "DAO: Voting has ended");
        require(!hasVoted[_proposalId][msg.sender], "DAO: Already voted on this proposal");
        
        uint256 voterPower = members[msg.sender].votingPower;
        hasVoted[_proposalId][msg.sender] = true;
        members[msg.sender].lastVoteTimestamp = block.timestamp;
        
        if (_support) {
            proposal.votesFor += voterPower;
        } else {
            proposal.votesAgainst += voterPower;
        }
        
        emit VoteCast(_proposalId, msg.sender, _support, voterPower);
    }
    
    function executeProposal(uint256 _proposalId) external onlyActiveMember proposalExists(_proposalId) {
        Proposal storage proposal = proposals[_proposalId];
        
        require(block.timestamp >= proposal.votingEndTime, "DAO: Voting still active");
        require(!proposal.executed, "DAO: Proposal already executed");
        require(proposal.status == ProposalStatus.Active, "DAO: Invalid proposal status");
        
        // Calculate quorum
        uint256 totalVotesCast = proposal.votesFor + proposal.votesAgainst;
        uint256 quorumRequired = (totalVotingPower * minimumQuorum) / 100;
        
        bool passed = (totalVotesCast >= quorumRequired) && (proposal.votesFor > proposal.votesAgainst);
        
        if (passed) {
            proposal.status = ProposalStatus.Passed;
        } else {
            proposal.status = ProposalStatus.Rejected;
        }
        
        proposal.executed = true;
        emit ProposalExecuted(_proposalId);
    }
    
    // ============ WHITELIST FUNCTIONS (for backend integration) ============
    
    function whitelistAddress(address _address, bool _whitelisted) external onlyAdmin {
        isWhitelisted[_address] = _whitelisted;
        emit WhitelistUpdated(_address, _whitelisted);
    }
    
    function isAddressWhitelisted(address _address) external view returns (bool) {
        return isWhitelisted[_address];
    }
    
    // ============ VIEW FUNCTIONS ============
    
    function getProposal(uint256 _proposalId) external view returns (Proposal memory) {
        return proposals[_proposalId];
    }
    
    function getMember(address _member) external view returns (Member memory) {
        return members[_member];
    }
    
    function getProposalStatus(uint256 _proposalId) external view returns (ProposalStatus) {
        Proposal storage proposal = proposals[_proposalId];
        
        if (proposal.executed) {
            return proposal.status;
        }
        
        if (block.timestamp < proposal.votingEndTime) {
            return ProposalStatus.Active;
        }
        
        uint256 totalVotesCast = proposal.votesFor + proposal.votesAgainst;
        uint256 quorumRequired = (totalVotingPower * minimumQuorum) / 100;
        
        if (totalVotesCast < quorumRequired) {
            return ProposalStatus.Rejected;
        }
        
        return proposal.votesFor > proposal.votesAgainst ? ProposalStatus.Passed : ProposalStatus.Rejected;
    }
    
    function getAllProposals() external view returns (Proposal[] memory) {
        Proposal[] memory allProposals = new Proposal[](proposalCount);
        for (uint256 i = 1; i <= proposalCount; i++) {
            allProposals[i - 1] = proposals[i];
        }
        return allProposals;
    }
    
    function getActiveProposals() external view returns (Proposal[] memory) {
        uint256 activeCount = 0;
        
        // Count active proposals
        for (uint256 i = 1; i <= proposalCount; i++) {
            if (block.timestamp < proposals[i].votingEndTime && !proposals[i].executed) {
                activeCount++;
            }
        }
        
        Proposal[] memory activeProposals = new Proposal[](activeCount);
        uint256 index = 0;
        
        for (uint256 i = 1; i <= proposalCount; i++) {
            if (block.timestamp < proposals[i].votingEndTime && !proposals[i].executed) {
                activeProposals[index] = proposals[i];
                index++;
            }
        }
        
        return activeProposals;
    }
    
    function getMemberVotingPower(address _member) external view returns (uint256) {
        return members[_member].votingPower;
    }
    
    function hasUserVotedOnProposal(uint256 _proposalId, address _user) external view returns (bool) {
        return hasVoted[_proposalId][_user];
    }
    
    function getTotalVotingPower() external view returns (uint256) {
        return totalVotingPower;
    }
    
    function getActiveMembersCount() external view returns (uint256) {
        return activeMembersCount;
    }
    
    // ============ ADMIN FUNCTIONS ============
    
    function setVotingDuration(uint256 _newDuration) external onlyAdmin {
        require(_newDuration >= 1 hours, "DAO: Duration too short");
        votingDuration = _newDuration;
        emit VotingDurationUpdated(_newDuration);
    }
    
    function setMinimumQuorum(uint256 _newQuorum) external onlyAdmin {
        require(_newQuorum <= 100, "DAO: Quorum cannot exceed 100%");
        minimumQuorum = _newQuorum;
    }
    
    function transferAdmin(address _newAdmin) external onlyAdmin {
        require(_newAdmin != address(0), "DAO: Invalid admin address");
        admin = _newAdmin;
    }
}