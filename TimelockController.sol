// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/governance/TimelockController.sol";

/**
 * @title DAOTimelockController
 * @dev Timelock controller for DAO proposals with 2-day delay
 */
contract DAOTimelockController is TimelockController {
    uint256 public constant MIN_DELAY = 2 days; // 2 days minimum delay
    uint256 public constant MAX_DELAY = 30 days; // 30 days maximum delay
    uint256 public constant GRACE_PERIOD = 14 days; // 14 days to execute after ready
    
    constructor(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors,
        address admin
    ) TimelockController(minDelay, proposers, executors, admin) {}
}