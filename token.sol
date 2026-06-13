// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract GovernanceToken is ERC20, ERC20Snapshot, AccessControl, Pausable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant SNAPSHOT_ROLE = keccak256("SNAPSHOT_ROLE");

    uint256 public constant MAX_SUPPLY = 10000000 * 10**18;
    uint256 public constant INITIAL_SUPPLY = 5000000 * 10**18;
    
    // Staking
    mapping(address => uint256) public stakedBalance;
    mapping(address => uint256) public stakingTimestamp;
    uint256 public stakingRewardRate = 10; // 10% APY
    
    constructor() ERC20("Governance Token", "GOV") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(SNAPSHOT_ROLE, msg.sender);
        
        _mint(msg.sender, INITIAL_SUPPLY);
    }
    
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        require(totalSupply() + amount <= MAX_SUPPLY, "Exceeds max supply");
        _mint(to, amount);
    }
    
    function burn(uint256 amount) public {
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        _burn(msg.sender, amount);
    }
    
    function stake(uint256 amount) external whenNotPaused {
        require(amount > 0, "Amount must be greater than 0");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        
        // Calculate pending rewards
        if (stakedBalance[msg.sender] > 0) {
            uint256 reward = calculateReward(msg.sender);
            _mint(msg.sender, reward);
        }
        
        _transfer(msg.sender, address(this), amount);
        stakedBalance[msg.sender] += amount;
        stakingTimestamp[msg.sender] = block.timestamp;
    }
    
    function unstake(uint256 amount) external whenNotPaused {
        require(amount > 0, "Amount must be greater than 0");
        require(stakedBalance[msg.sender] >= amount, "Insufficient staked balance");
        
        // Calculate and distribute rewards
        uint256 reward = calculateReward(msg.sender);
        if (reward > 0) {
            _mint(msg.sender, reward);
        }
        
        stakedBalance[msg.sender] -= amount;
        _transfer(address(this), msg.sender, amount);
        stakingTimestamp[msg.sender] = block.timestamp;
    }
    
    function calculateReward(address staker) public view returns (uint256) {
        if (stakedBalance[staker] == 0) return 0;
        
        uint256 stakingDuration = block.timestamp - stakingTimestamp[staker];
        uint256 reward = (stakedBalance[staker] * stakingRewardRate * stakingDuration) / (365 days * 100);
        return reward;
    }
    
    function delegate(address delegatee) external {
        _delegate(msg.sender, delegatee);
    }
    
    function snapshot() external onlyRole(SNAPSHOT_ROLE) {
        _snapshot();
    }
    
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
    
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override(ERC20, ERC20Snapshot) {
        super._beforeTokenTransfer(from, to, amount);
    }
    
    function getVotingPower(address account) public view returns (uint256) {
        return balanceOf(account) + stakedBalance[account];
    }
}