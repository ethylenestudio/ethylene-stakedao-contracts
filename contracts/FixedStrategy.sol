//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IAngle {
    function deposit(address _staker, uint256 _amount, bool _earn) external;
    function withdraw(uint256 _shares) external;
    function balanceOf(address account) external view returns(uint256);
    function approve(address spender, uint256 amount) external returns(bool);
}

interface IStrats {
    function claim(address _token) external;
}

contract FixedStrategy is ERC20, Ownable {
    using SafeERC20 for IERC20;

    IAngle angleVault; // angleVault
    IStrats angleStrat; // angleStrat
    IERC20 token; //sanFRAX_EUR

    uint256 public claimerFee;
    uint256 public collectedFee;
    uint256 public maxYield;

    address[] public rewardTokens;
    address public constant ANGL = 0x31429d1856aD1377A8A0079410B297e1a9e214c2;
    address public constant SDT = 0x73968b9a57c6E53d41345FD57a6E6ae27d6CDB2F;

    mapping(address => uint256) stakeTimestamps;
    mapping(address => uint256) initialPPS;

    constructor(
        address angleVaultAddr,
        address angleStratAddr,
        address lockToken
    ) ERC20("sanFRAX_EUR_FSTR", "SFESTR") {
        angleVault = IAngle(angleVaultAddr);
        angleStrat = IStrats(angleStratAddr);
        token = IERC20(lockToken);
        claimerFee = 10;
        maxYield = 80;
        rewardTokens.push(ANGL);
        rewardTokens.push(SDT);
    }

    //////////////////////////// VIEW FUNCTIONS ////////////////////////////

    function pricePerShare() public view returns (uint256) {
        return
            (totalSupply() == 0)
                ? 1e18
                : (angleVault.balanceOf(address(this)) * 1e18) / totalSupply();
    }

    function currentRatioForUser() public view returns(uint256) {
        uint256 ppsChange = (pricePerShare() - initialPPS[msg.sender]) * 1000 / initialPPS[msg.sender];
        uint256 timePast = block.timestamp - stakeTimestamps[msg.sender];

        return (ppsChange * 365 days / timePast);
    }

    function maxEarningToDate(uint256 amount) public view returns(uint256) {
        uint256 timePast = block.timestamp - stakeTimestamps[msg.sender];
        return amount * (1000 + (timePast * maxYield / 365 days)) / 1000;        
    }

    //////////////////////////// EXTERNAL FUNCTIONS ////////////////////////////

    /**
     * @param amount uint256 - amount to deposit into stake contract
     * @param earnFSD bool - user must decide whether or not to call earn() function of Stake contract
     * @param earnFT bool - user must decide whether or not to call harvest() function of this contract
     */
    function deposit(
        uint256 amount,
        bool earnFSD,
        bool earnFT
    ) external {
        require(initialPPS[msg.sender] == 0, "[deposit] Already locked!");
        stakeTimestamps[msg.sender] = block.timestamp;
        initialPPS[msg.sender] = pricePerShare();

        token.safeTransferFrom(msg.sender, address(this), amount);
        token.approve(address(angleVault), amount);

        if (!earnFT) {
            uint256 cut = (amount * claimerFee) / 10000;
            amount -= cut;
            collectedFee += cut;
        } else {
            amount += collectedFee;
            collectedFee = 0;
        }

        uint256 _prev = angleVault.balanceOf(address(this));

        angleVault.deposit(address(this), amount, earnFSD);
    
        uint256 _after = angleVault.balanceOf(address(this));
        uint256 _diff = _after - _prev;

        if (totalSupply() == 0) {
            _mint(msg.sender, _diff);
        } else {
            _mint(msg.sender, (_diff * 1e18) / pricePerShare());
        }

        if (earnFT) earn();
    }

    function withdraw(uint256 shares) external {
        require(
            balanceOf(msg.sender) >= shares,
            "[withdraw] Insufficient balance!"
        );
        require(
            stakeTimestamps[msg.sender] + 90 days <= block.timestamp,
            "[withdraw] Early withdraw!"
        );

        uint256 tokenBalance = (shares * pricePerShare()) / 1e18;
        _burn(msg.sender, shares);

        if (tokenBalance + collectedFee > token.balanceOf(address(this)))
            angleVault.withdraw(tokenBalance + collectedFee - token.balanceOf(address(this)));


        if (balanceOf(msg.sender) == 0) {
            delete(initialPPS[msg.sender]);
            delete(stakeTimestamps[msg.sender]);
        }

        if (currentRatioForUser() >= maxYield){
            uint256 withdrawAmount = maxEarningToDate(shares * initialPPS[msg.sender] / 1e18);
            token.safeTransfer(owner(), tokenBalance - withdrawAmount);
            tokenBalance = withdrawAmount;
        }

        token.safeTransfer(msg.sender, tokenBalance);
    }

    function setFee(uint256 newFee) external onlyOwner {
        claimerFee = newFee;
    }

    function harvest() external onlyOwner {
        angleStrat.claim(address(token));
        //implement swapping tokens and receiving LP

        // for(uint256 i = 0; i < rewardTokens.length; i++) {
        //     rewardTokens[i]
        // }
    }

    function earn() private {
        uint256 tokenBalance = token.balanceOf(address(this)) - collectedFee;
        token.approve(address(angleVault), tokenBalance);
        angleVault.deposit(address(this), tokenBalance, false);
    }
}

// TODO: REENTRANCY CHECK
// TODO: CONFIGURE IN STYLE GUIDE
// TODO: ADD EVENTS
// TODO: approve -> safe methods