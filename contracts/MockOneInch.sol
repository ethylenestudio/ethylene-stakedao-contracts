//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IOneInch.sol";

contract MockOneInch is IAggregationRouterV4 {
    using SafeERC20 for IERC20;

    address public constant ANGL = 0x31429d1856aD1377A8A0079410B297e1a9e214c2;
    address public constant SDT = 0x73968b9a57c6E53d41345FD57a6E6ae27d6CDB2F;
    address public constant FRAX = 0x853d955aCEf822Db058eb8505911ED77F175b99e;


    struct Ratios {
        bool registered;
        address dstToken;
        uint256 ratio;
    }

    mapping(address => Ratios) public mockRatios;

    constructor() {
        mockRatios[ANGL] = Ratios(true, FRAX, 2);
        mockRatios[SDT] = Ratios(true, FRAX, 4);
    }

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
    {
        returnAmount = desc.amount * mockRatios[address(desc.srcToken)].ratio;
        spentAmount = desc.amount;

        require(mockRatios[address(desc.srcToken)].registered, "[MOCK][swap] Inavailable in mock.");
        require(address(desc.dstToken) == mockRatios[address(desc.srcToken)].dstToken, "[MOCK][swap] Inappropriate output.");
        require(desc.dstToken.balanceOf(address(this)) >= returnAmount, "[MOCK][swap] Not enough output token.");

        desc.srcToken.safeTransferFrom(msg.sender, address(this), spentAmount);

        address dstReceiver = desc.dstReceiver == address(0) ? msg.sender : desc.dstReceiver;

        desc.dstToken.safeTransfer(dstReceiver, returnAmount);
        gasLeft = gasleft();

        caller = caller;
        data = data;
    }
}
