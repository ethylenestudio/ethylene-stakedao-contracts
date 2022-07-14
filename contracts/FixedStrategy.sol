//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IOneInch.sol";
import "./interfaces/IStakeDao.sol";
import "./interfaces/IStableMasterFront.sol";
import "hardhat/console.sol";

contract FixedStrategy is Ownable {
    ///////////////////// INTERFACEs & LIBRARIES /////////////////////

    using SafeERC20 for IERC20;

    IAggregationRouterV4 oneInchRouter; // 1inch swap router
    IStableMasterFront angleFront; // Angle Stable Master
    IAngle angleVault; // angleVault
    IStrats angleStrat; // angleStrat
    IGauge angleGauge; //angleGauge
    IERC20 token; //sanFRAX_EUR

    ///////////////////// STATE VARIABLES /////////////////////
    bool public emergency;

    uint256 public maxYield;
    uint256 public totalSupply;

    address[] public rewardTokens;
    address public constant ANGL = 0x31429d1856aD1377A8A0079410B297e1a9e214c2;
    address public constant SDT = 0x73968b9a57c6E53d41345FD57a6E6ae27d6CDB2F;
    address public constant FRAX = 0x853d955aCEf822Db058eb8505911ED77F175b99e;
    address public constant ANGLE_POOL_MANAGER =
        0x6b4eE7352406707003bC6f6b96595FD35925af48;

    ///////////////////// TYPES /////////////////////

    mapping(address => uint256) public stakeTimestamps;
    mapping(address => uint256) public initialPPS;
    mapping(address => uint256) public userToShare;

    ///////////////////// EVENTS /////////////////////

    event Deposit(address locker, uint256 amount);
    event Withdraw(address locker, uint256 amount);
    event EmergencyWithdraw(address locker, uint256 amount);
    event Compounded(address compounder, uint256 amount);
    event MaxYieldChanged(uint256 newYield);
    event Harvested();
    event EmergencyChanged(bool newState);

    ///////////////////// FUNCTIONS /////////////////////

    constructor(
        address angleVaultAddr,
        address angleStratAddr,
        address oneInchAddr,
        address angleFrontAddr,
        address gaugeAdd,
        address lockToken
    ) {
        angleVault = IAngle(angleVaultAddr);
        angleStrat = IStrats(angleStratAddr);
        angleGauge = IGauge(gaugeAdd);
        oneInchRouter = IAggregationRouterV4(oneInchAddr);
        angleFront = IStableMasterFront(angleFrontAddr);
        token = IERC20(lockToken);
        maxYield = 80;
        rewardTokens.push(ANGL);
        rewardTokens.push(SDT);
    }

    ///////////////////// USER INTERACTIONS /////////////////////

    /**
     * @param amount uint256 - amount to deposit into stake contract
     */
    function deposit(uint256 amount) external {
        require(initialPPS[msg.sender] == 0, "[deposit] Already locked!");
        stakeTimestamps[msg.sender] = block.timestamp;
        initialPPS[msg.sender] = pricePerShare();

        token.safeTransferFrom(msg.sender, address(this), amount);
        userToShare[msg.sender] += (amount * 1e18) / initialPPS[msg.sender];
        totalSupply += (amount * 1e18) / initialPPS[msg.sender];

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
        if (tokenBalance > token.balanceOf(address(this)))
            angleVault.withdraw(tokenBalance - token.balanceOf(address(this)));

        if (currentRatioForUser() > maxYield) {
            uint256 withdrawAmount = maxEarningToDate(shares);
            token.safeTransfer(owner(), tokenBalance - withdrawAmount);
            tokenBalance = withdrawAmount;
        }
        userToShare[msg.sender] -= shares;
        totalSupply -= shares;

        if (userToShare[msg.sender] == 0) {
            delete (initialPPS[msg.sender]);
            delete (stakeTimestamps[msg.sender]);
        }
        token.safeTransfer(msg.sender, tokenBalance);

        emit Withdraw(msg.sender, tokenBalance);
    }

    function emergencyWithdraw() external {
        require(
            userToShare[msg.sender] > 0,
            "[withdraw] Insufficient balance!"
        );
        require(emergency, "[withdraw] Not Emergency");
        uint256 tokenBalance = (userToShare[msg.sender] * pricePerShare()) /
            1e18;

        if (tokenBalance > token.balanceOf(address(this)))
            angleVault.withdraw(tokenBalance - token.balanceOf(address(this)));

        if (currentRatioForUser() >= maxYield) {
            uint256 withdrawAmount = maxEarningToDate(
                (tokenBalance * initialPPS[msg.sender]) / 1e18
            );
            token.safeTransfer(owner(), tokenBalance - withdrawAmount);

            tokenBalance = withdrawAmount;
        }
        delete userToShare[msg.sender];
        totalSupply -= tokenBalance;

        delete (initialPPS[msg.sender]);
        delete (stakeTimestamps[msg.sender]);
        token.safeTransfer(msg.sender, tokenBalance);

        emit EmergencyWithdraw(msg.sender, tokenBalance);
    }

    ///////////////////// OWNER MANAGEMENTS /////////////////////

    function claim() external onlyOwner {
        angleGauge.claim_rewards();
    }

    function harvest(
        address executor,
        uint256[] calldata minReturnAmounts,
        bytes[] calldata permits,
        bytes[] calldata datas
    ) external onlyOwner {
        require(
            datas.length == rewardTokens.length,
            "[harvest] Inappropriate data amount."
        );
        require(
            minReturnAmounts.length == rewardTokens.length,
            "[harvest] Inappropriate data amount."
        );
        require(
            permits.length == rewardTokens.length,
            "[harvest] Inappropriate data amount."
        );

        for (uint256 i = 0; i < rewardTokens.length; i++) {
            if (IERC20(rewardTokens[i]).balanceOf(address(this)) == 0) continue;

            IERC20(rewardTokens[i]).safeIncreaseAllowance(
                address(oneInchRouter),
                IERC20(rewardTokens[i]).balanceOf(address(this))
            );

            SwapDescription memory desc = SwapDescription({
                srcToken: IERC20(rewardTokens[i]),
                dstToken: IERC20(FRAX),
                srcReceiver: payable(address(executor)), //FIXME: I'M NOT SURE
                dstReceiver: payable(address(this)),
                amount: IERC20(rewardTokens[i]).balanceOf(address(this)),
                minReturnAmount: minReturnAmounts[i],
                flags: 4,
                permit: permits[i] //0x
            });
            oneInchRouter.swap(IAggregationExecutor(executor), desc, datas[i]); //FIXME: I'M NOT SURE

            IERC20(rewardTokens[i]).safeApprove(address(oneInchRouter), 0);
        }

        IERC20(FRAX).safeIncreaseAllowance(
            address(angleFront),
            IERC20(FRAX).balanceOf(address(this))
        );
        angleFront.deposit(
            IERC20(FRAX).balanceOf(address(this)),
            address(this),
            IPoolManager(ANGLE_POOL_MANAGER)
        );

        emit Harvested();
    }

    function comp(bool isEarn) external onlyOwner {
        uint256 tokenBalance = token.balanceOf(address(this));
        token.safeIncreaseAllowance(address(angleVault), tokenBalance);
        angleVault.deposit(address(this), tokenBalance, isEarn);

        emit Compounded(msg.sender, tokenBalance);
    }

    function harvestStake() external onlyOwner {
        angleStrat.claim(address(token));
    }

    ///////////////////// OWNER SETTERS /////////////////////

    function setMaxYield(uint256 newYield) external onlyOwner {
        maxYield = newYield;
        emit MaxYieldChanged(newYield);
    }

    function toggleEmergency() external onlyOwner {
        emergency = !emergency;
        emit EmergencyChanged(emergency);
    }

    ///////////////////// CONTRACT HELPER FUNCTIONS /////////////////////

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

    function maxEarningToDate(uint256 shares) public view returns (uint256) {
        uint256 amount = (shares * initialPPS[msg.sender]) / 1e18;
        uint256 timePast = block.timestamp - stakeTimestamps[msg.sender];
        return amount + (((amount * timePast * maxYield) / 365 days) / 1000);
    }

    function getBalanceInGauge() public view returns (uint256) {
        return angleGauge.balanceOf(address(this));
    }
}

// TODO: REENTRANCY CHECK
// TODO: CONFIGURE IN STYLE GUIDE
