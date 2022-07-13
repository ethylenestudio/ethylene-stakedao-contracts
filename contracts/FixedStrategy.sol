//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

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
    function claim(address _token) external;
}

interface IGauge {
    function balanceOf(address account) external view returns (uint256);
}

contract FixedStrategy is Ownable {
    using SafeERC20 for IERC20;

    IAngle angleVault; // angleVault
    IStrats angleStrat; // angleStrat
    IGauge angleGauge; //angleGauge
    IERC20 token; //sanFRAX_EUR

    uint256 public maxYield;
    uint256 public totalSupply;

    address[] public rewardTokens;
    address public constant ANGL = 0x31429d1856aD1377A8A0079410B297e1a9e214c2;
    address public constant SDT = 0x73968b9a57c6E53d41345FD57a6E6ae27d6CDB2F;

    mapping(address => uint256) stakeTimestamps;
    mapping(address => uint256) initialPPS;
    mapping(address => uint256) userToShare;

    event Deposit(address locker, uint256 amount);
    event Withdraw(address locker, uint256 amount);
    event Compounded(address compounder, uint256 amount);
    event MaxYieldChanged(uint256 newYield);

    constructor(
        address angleVaultAddr,
        address angleStratAddr,
        address gaugeAdd,
        address lockToken
    ) {
        angleVault = IAngle(angleVaultAddr);
        angleStrat = IStrats(angleStratAddr);
        angleGauge = IGauge(gaugeAdd);
        token = IERC20(lockToken);
        maxYield = 80;
        rewardTokens.push(ANGL);
        rewardTokens.push(SDT);
    }

    //////////////////////////// VIEW FUNCTIONS ////////////////////////////

    function pricePerShare() public view returns (uint256) {
        return
            (totalSupply == 0)
                ? 1e18
                : ((angleGauge.balanceOf(address(this)) +
                    token.balanceOf(address(this))) * 1e18) / totalSupply;
    }

    function currentRatioForUser() public view returns (uint256) {
        uint256 ppsChange = ((pricePerShare() - initialPPS[msg.sender]) *
            1000) / initialPPS[msg.sender];
        uint256 timePast = block.timestamp - stakeTimestamps[msg.sender];

        return ((ppsChange * 365 days) / timePast);
    }

    function maxEarningToDate(uint256 amount) public view returns (uint256) {
        uint256 timePast = block.timestamp - stakeTimestamps[msg.sender];
        return (amount * (1000 + ((timePast * maxYield) / 365 days))) / 1000;
    }

    //////////////////////////// EXTERNAL FUNCTIONS ////////////////////////////

    /**
     * @param amount uint256 - amount to deposit into stake contract
     */
    function deposit(uint256 amount) external {
        require(initialPPS[msg.sender] == 0, "[deposit] Already locked!");
        stakeTimestamps[msg.sender] = block.timestamp;
        initialPPS[msg.sender] = pricePerShare();

        token.safeTransferFrom(msg.sender, address(this), amount);

        userToShare[msg.sender] += (amount * 1e18) / pricePerShare();
        totalSupply += (amount * 1e18) / pricePerShare();

        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 shares) external {
        require(
            userToShare[msg.sender] >= shares,
            "[withdraw] Insufficient balance!"
        );
        require(
            stakeTimestamps[msg.sender] + 90 days <= block.timestamp,
            "[withdraw] Early withdraw!"
        );

        uint256 tokenBalance = (shares * pricePerShare()) / 1e18;
        userToShare[msg.sender] -= shares;
        totalSupply -= shares;

        if (tokenBalance > token.balanceOf(address(this)))
            angleVault.withdraw(tokenBalance - token.balanceOf(address(this)));

        if (userToShare[msg.sender] == 0) {
            delete (initialPPS[msg.sender]);
            delete (stakeTimestamps[msg.sender]);
        }

        if (currentRatioForUser() >= maxYield) {
            uint256 withdrawAmount = maxEarningToDate(
                (shares * initialPPS[msg.sender]) / 1e18
            );
            token.safeTransfer(owner(), tokenBalance - withdrawAmount);
            tokenBalance = withdrawAmount;
        }

        token.safeTransfer(msg.sender, tokenBalance);

        emit Withdraw(msg.sender, tokenBalance);
    }

    function setMaxYield(uint256 newYield) external onlyOwner {
        maxYield = newYield;
        emit MaxYieldChanged(newYield);
    }

    function harvest() external onlyOwner {
        angleStrat.claim(address(token));
        //eğer claim edemiyorsak ve kontratımızda sdt angl var ise onları değiştiremeden yukardaki satır revert eder. tokenlar sıkışır.
        //implement swapping tokens and receiving LP

        // for(uint256 i = 0; i < rewardTokens.length; i++) {
        //     rewardTokens[i]
        // }
    }

    function comp(bool isEarn) public {
        uint256 tokenBalance = token.balanceOf(address(this));
        token.safeIncreaseAllowance(address(angleVault), tokenBalance);
        angleVault.deposit(address(this), tokenBalance, isEarn);

        emit Compounded(msg.sender, tokenBalance);
    }
}

// TODO: REENTRANCY CHECK
// TODO: CONFIGURE IN STYLE GUIDE
