// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title GovernanceToken
 * @dev ERC20 token with voting capabilities using OpenZeppelin's ERC20Votes
 * Members hold these tokens to gain voting power in the DAO
 */
contract GovernanceToken is ERC20, ERC20Votes, Ownable {
    uint256 public constant INITIAL_SUPPLY = 1_000_000 * 10**18; // 1 Million tokens
    uint256 public constant MAX_SUPPLY = 10_000_000 * 10**18; // 10 Million max
    
    event TokensMinted(address indexed to, uint256 amount);
    event TokensBurned(address indexed from, uint256 amount);
    
constructor()
    ERC20("DAO Governance Token", "GOV")
    ERC20Votes()
    Ownable(msg.sender)
{
    _mint(msg.sender, INITIAL_SUPPLY);
}
    
    /**
     * @dev Mint new governance tokens (only owner - DAO Treasury)
     * @param to Recipient address
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) external onlyOwner {
        require(totalSupply() + amount <= MAX_SUPPLY, "Exceeds max supply");
        _mint(to, amount);
        emit TokensMinted(to, amount);
    }
    
    /**
     * @dev Burn governance tokens
     * @param amount Amount to burn
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
        emit TokensBurned(msg.sender, amount);
    }
    
    /**
     * @dev Delegate voting power to self (required for voting)
     */
    function delegateSelf() external {
        _delegate(msg.sender, msg.sender);
    }
    
    // Required overrides for ERC20Votes
    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Votes)
    {
        super._update(from, to, value);
    }
    
function nonces(address owner)
    public
    view
    override(ERC20, ERC20Votes)
    returns (uint256)
{
    return super.nonces(owner);
    }