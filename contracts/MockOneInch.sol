//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./interfaces/IOneInch.sol";

contract MockOneInch is IAggregationRouterV4 {
    function swap(
        IAggregationExecutor caller,
        SwapDescription calldata desc,
        bytes calldata data
    )
        external
        payable
        virtual
        override
        returns (
            uint256 returnAmount,
            uint256 spentAmount,
            uint256 gasLeft
        )
    {}
}
