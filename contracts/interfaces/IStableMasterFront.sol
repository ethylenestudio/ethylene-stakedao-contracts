// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.7;

import "./AngleFlat.sol";

/// @title IStableMasterFront
/// @author Angle Core Team
/// @dev Front interface, meaning only user-facing functions
interface IStableMasterFront {
    function deposit(
        uint256 amount,
        address user,
        IPoolManager poolManager
    ) external;
}
