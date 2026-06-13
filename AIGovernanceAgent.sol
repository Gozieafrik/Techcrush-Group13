// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract AIGovernanceAgent is AccessControl {
    using EnumerableSet for EnumerableSet.UintSet;
    
    bytes32 public constant AGENT_ROLE = keccak256("AGENT_ROLE");
    bytes32 public constant ANALYZER_ROLE = keccak256("ANALYZER_ROLE");
    
    struct ProposalAnalysis {
        uint256 proposalId;
        string summary;
        uint256 riskScore; // 0-100, lower is better
        string recommendation; // FOR, AGAINST, ABSTAIN, MONITOR
        string reasoning;
        uint256 confidence; // 0-100
        uint256 timestamp;
        string[] riskFactors;
        uint256 dcfValue; // Discounted Cash Flow value
    }
    
    struct RiskAssessment {
        uint256 financialRisk;
        uint256 technicalRisk;
        uint256 regulatoryRisk;
        uint256 reputationRisk;
        uint256 overallScore;
        string[] flags;
    }
    
    struct VotePreference {
        address voter;
        uint256 minConfidence; // Minimum confidence to auto-vote
        bool autoDelegate;
        address delegateTo;
        string[] preferredCategories;
        uint256 maxRiskTolerance;
    }
    
    mapping(uint256 => ProposalAnalysis) public proposalAnalyses;
    mapping(address => VotePreference) public userPreferences;
    mapping(uint256 => RiskAssessment) public riskAssessments;
    EnumerableSet.UintSet private analyzedProposals;
    
    event ProposalAnalyzed(uint256 indexed proposalId, string recommendation, uint256 riskScore);
    event AutoVoteExecuted(address indexed voter, uint256 indexed proposalId, string vote);
    event PreferenceUpdated(address indexed user, uint256 minConfidence, uint256 maxRisk);
    event RiskFlagged(uint256 indexed proposalId, string riskType, string description);
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(AGENT_ROLE, msg.sender);
        _grantRole(ANALYZER_ROLE, msg.sender);
    }
    
    /**
     * @dev Analyze proposal with AI reasoning
     * @param proposalId Proposal identifier
     * @param summary Human-readable summary
     * @param riskScore Calculated risk (0-100)
     * @param recommendation Vote recommendation
     * @param reasoning AI reasoning text
     * @param confidence Confidence level (0-100)
     * @param riskFactors Array of risk factors
     * @param dcfValue Discounted cash flow valuation
     */
    function analyzeProposal(
        uint256 proposalId,
        string memory summary,
        uint256 riskScore,
        string memory recommendation,
        string memory reasoning,
        uint256 confidence,
        string[] memory riskFactors,
        uint256 dcfValue
    ) external onlyRole(ANALYZER_ROLE) {
        require(riskScore <= 100, "Invalid risk score");
        require(confidence <= 100, "Invalid confidence");
        
        proposalAnalyses[proposalId] = ProposalAnalysis({
            proposalId: proposalId,
            summary: summary,
            riskScore: riskScore,
            recommendation: recommendation,
            reasoning: reasoning,
            confidence: confidence,
            timestamp: block.timestamp,
            riskFactors: riskFactors,
            dcfValue: dcfValue
        });
        
        analyzedProposals.add(proposalId);
        
        emit ProposalAnalyzed(proposalId, recommendation, riskScore);
    }
    
    /**
     * @dev Assess risks for a proposal
     */
    function assessRisks(
        uint256 proposalId,
        uint256 financialRisk,
        uint256 technicalRisk,
        uint256 regulatoryRisk,
        uint256 reputationRisk,
        string[] memory flags
    ) external onlyRole(ANALYZER_ROLE) {
        uint256 overallScore = (financialRisk + technicalRisk + regulatoryRisk + reputationRisk) / 4;
        
        riskAssessments[proposalId] = RiskAssessment({
            financialRisk: financialRisk,
            technicalRisk: technicalRisk,
            regulatoryRisk: regulatoryRisk,
            reputationRisk: reputationRisk,
            overallScore: overallScore,
            flags: flags
        });
    }
    
    /**
     * @dev Set user voting preferences for auto-voting
     */
    function setVotingPreferences(
        uint256 minConfidence,
        bool autoDelegate,
        address delegateTo,
        string[] memory preferredCategories,
        uint256 maxRiskTolerance
    ) external {
        require(minConfidence <= 100, "Invalid confidence");
        require(maxRiskTolerance <= 100, "Invalid risk tolerance");
        
        userPreferences[msg.sender] = VotePreference({
            voter: msg.sender,
            minConfidence: minConfidence,
            autoDelegate: autoDelegate,
            delegateTo: delegateTo,
            preferredCategories: preferredCategories,
            maxRiskTolerance: maxRiskTolerance
        });
        
        emit PreferenceUpdated(msg.sender, minConfidence, maxRiskTolerance);
    }
    
    /**
     * @dev Get AI recommendation for voting
     */
    function getRecommendation(uint256 proposalId) external view returns (
        string memory recommendation,
        string memory reasoning,
        uint256 confidence,
        uint256 riskScore,
        string[] memory riskFactors
    ) {
        ProposalAnalysis memory analysis = proposalAnalyses[proposalId];
        require(analysis.timestamp > 0, "Proposal not analyzed");
        
        return (
            analysis.recommendation,
            analysis.reasoning,
            analysis.confidence,
            analysis.riskScore,
            analysis.riskFactors
        );
    }
    
    /**
     * @dev Auto-vote based on user preferences
     */
    function autoVote(uint256 proposalId) external {
        require(analyzedProposals.contains(proposalId), "Proposal not analyzed");
        
        VotePreference memory prefs = userPreferences[msg.sender];
        require(prefs.voter != address(0), "No preferences set");
        
        ProposalAnalysis memory analysis = proposalAnalyses[proposalId];
        
        // Check if confidence meets threshold
        if (analysis.confidence >= prefs.minConfidence && 
            analysis.riskScore <= prefs.maxRiskTolerance) {
            
            string memory vote = analysis.recommendation;
            emit AutoVoteExecuted(msg.sender, proposalId, vote);
        }
    }
    
    /**
     * @dev Generate DCF analysis summary
     */
    function generateDCFAnalysis(
        uint256 proposalId,
        uint256 projectedCashFlow,
        uint256 discountRate,
        uint256 yearsProjected
    ) external pure returns (uint256 npv, string memory assessment) {
        // Simple DCF calculation
        uint256 npvValue = 0;
        uint256 denominator = 100 + discountRate;
        
        for (uint256 i = 1; i <= yearsProjected; i++) {
            uint256 discountedValue = projectedCashFlow / denominator;
            npvValue += discountedValue;
        }
        
        string memory assessmentText;
        if (npvValue > projectedCashFlow * yearsProjected / 2) {
            assessmentText = "Strong investment opportunity";
        } else if (npvValue > 0) {
            assessmentText = "Moderate investment potential";
        } else {
            assessmentText = "Investment not recommended";
        }
        
        return (npvValue, assessmentText);
    }
    
    /**
     * @dev Get analysis count
     */
    function getAnalyzedProposalsCount() external view returns (uint256) {
        return analyzedProposals.length();
    }
    
    /**
     * @dev Get analyzed proposal by index
     */
    function getAnalyzedProposalAt(uint256 index) external view returns (uint256) {
        return analyzedProposals.at(index);
    }
}