// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title DAOTreasury
 * @dev Treasury managed by DAO governance
 */
contract DAOTreasury is AccessControl {
    bytes32 public constant TREASURER_ROLE = keccak256("TREASURER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    
    event FundsDeposited(address indexed from, uint256 amount);
    event FundsWithdrawn(address indexed to, uint256 amount);
    event TokensWithdrawn(address indexed token, address indexed to, uint256 amount);
    
    constructor(address governor, address initialTreasurer) {
        _grantRole(DEFAULT_ADMIN_ROLE, governor);
        _grantRole(TREASURER_ROLE, initialTreasurer);
        _grantRole(EXECUTOR_ROLE, governor);
    }
    
    /**
     * @dev Receive ETH
     */
    receive() external payable {
        emit FundsDeposited(msg.sender, msg.value);
    }
    
    /**
     * @dev Withdraw ETH (only executor - DAO)
     */
    function withdrawETH(address payable to, uint256 amount) external onlyRole(EXECUTOR_ROLE) {
        require(address(this).balance >= amount, "Insufficient balance");
        to.transfer(amount);
        emit FundsWithdrawn(to, amount);
    }
    
    /**
     * @dev Withdraw ERC20 tokens (only executor - DAO)
     */
    function withdrawToken(address token, address to, uint256 amount) external onlyRole(EXECUTOR_ROLE) {
        require(IERC20(token).balanceOf(address(this)) >= amount, "Insufficient balance");
        IERC20(token).transfer(to, amount);
        emit TokensWithdrawn(token, to, amount);
    }
    
    /**
     * @dev Get contract balance
     */
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    /**
     * @dev Get token balance
     */
    function getTokenBalance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
}