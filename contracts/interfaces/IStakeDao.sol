//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IAngle {
    function deposit(
        address _staker,
        uint256 _amount,
        bool _earn
    ) external;

    function withdraw(uint256 _shares) external;

    function balanceOf(address account) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);
}

interface IStrats {
    function claim(address _token) external; //harvest
}

interface IGauge {
    function balanceOf(address account) external view returns (uint256);

    function claim_rewards() external; //claim rewards
}
