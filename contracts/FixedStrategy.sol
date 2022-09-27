//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

//@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
//@@@@@@@@@@@@@@@@@@@@@@@@@@(((###@@@@@@@@@@@@@@@@@@@@@@@@@@@@
//@@@@@@@@@@@@@@@@@@@@@@@@((((######@@@@@@@@@@@@@@@@@@@@@@@@@@
//@@@@@@@@@@@@@@@@@@@@@((((((((#######&@@@@@@@@@@@@@@@@@@@@@@@
//@@@@@@@@@@@@@@@@@@@((((((((((##########@@@@@@@@@@@@@@@@@@@@@
//@@@@@@@@@@@@@@@@#((((((((((((############@@@@@@@@@@@@@@@@@@@
//@@@@@@@@@@@@@@(((((((((((@@@@@#########@@@%%%%%@@@@@@@@@@@@@
//@@@@@@@@@@@&(((((((((((@@@@@@@@#######@@@%%%%%%%%@@@@@@@@@@@
//@@@@@@@@@(((((((((((%@@@@@@@%############@@@%%%%%%%%@@@@@@@@
//@@@@@@@(((((((((((@@@@@@@@((###############@@@%%%%%%%%@@@@@@
//@@@@((((((((((((@@@@@@@@(((((#################@@@%%%%%%%%@@@
//@@(((((((((((@@@@@@@@(((((((####################@@@%%%%%%%%@
//@@(((((((((((@@@@@@@@(((((((####################@@@%%%%%%%%@
//@@@@((((((((((((@@@@@@@@(((((#################@@@%%%%%%%%@@@
//@@@@@@@(((((((((((@@@@@@@@(((##############@@@%%%%%%%%@@@@@@
//@@@@@@@@@((((((((((((@@@@@@@@############@@@%%%%%%%%@@@@@@@@
//@@@@@@@@@@@@(((((((((((@@@@@@@@#######@@@%%%%%%%%@@@@@@@@@@@
//@@@@@@@@@@@@@@((((((((((((@@@@#########@@@%%%%%@@@@@@@@@@@@@
//@@@@@@@@@@@@@@@@@(((((((((((#############@@@@@@@@@@@@@@@@@@@
//@@@@@@@@@@@@@@@@@@@((((((((((##########@@@@@@@@@@@@@@@@@@@@@
//@@@@@@@@@@@@@@@@@@@@@%(((((((#######@@@@@@@@@@@@@@@@@@@@@@@@
//@@@@@@@@@@@@@@@@@@@@@@@@((((######@@@@@@@@@@@@@@@@@@@@@@@@@@
//@@@@@@@@@@@@@@@@@@@@@@@@@@((###@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IOneInch.sol";
import "./interfaces/IStakeDao.sol";
import "./interfaces/IStableMasterFront.sol";
import "hardhat/console.sol";

/// @author Ulaş Erdoğan - @ulerdogan from Ethylene Studio - @ethylenestudio
/// @author Rafi Ersözlü - @rersozlu from Ethylene Studio - @ethylenestudio
/// @title Strategy Provides Fixed Max 8% APY on sanFRAX_EUR tokens
/// @dev Contract stakes sanFRAX_EUR tokens to StakeDAO LL and compounds generated
/// income by selling reward tokens on 1inch
/// @dev Implemented Mock OneInch Router for Testing "./MockOneInch.sol"
/// @dev NOT AUDITED nor TESTED IN FULL COVERAGE

contract FixedStrategy is Ownable {
    ///////////////////// INTERFACEs & LIBRARIES /////////////////////

    // Using OpenZeppelin's SafeERC20 Util
    using SafeERC20 for IERC20;

    // OneInch Swap Router address
    IAggregationRouterV4 oneInchRouter;
    // stdAngle Vault address
    IAngle angleVault;
    // stdAngle Strategy address
    IStrats angleStrat;
    // Angle's Stable Master Front address
    IStableMasterFront angleFront;
    // stdAngle Gauge address
    IGauge angleGauge;
    // Locking token address - sanFRAX_EUR
    IERC20 token;

    ///////////////////// STATE VARIABLES /////////////////////
    bool public emergency;

    // Max reflected income for stakers
    /// @dev based on 1000 - 10 means 1%
    uint256 public maxYield;

    // Total share amount
    uint256 public totalSupply;

    ///////////////////// CONSTANT VARIABLES /////////////////////
    address public constant ANGL = 0x31429d1856aD1377A8A0079410B297e1a9e214c2;
    address public constant SDT = 0x73968b9a57c6E53d41345FD57a6E6ae27d6CDB2F;
    address public constant FRAX = 0x853d955aCEf822Db058eb8505911ED77F175b99e;
    address public constant ANGLE_POOL_MANAGER =
        0x6b4eE7352406707003bC6f6b96595FD35925af48;

    ///////////////////// TYPES /////////////////////

    // Stores users initial staking timestamps
    mapping(address => uint256) public stakeTimestamps;

    // Each shares value in initial staking timestamp
    mapping(address => uint256) public initialPPS;

    // Users shares, specified due to share values and stake amounts in deposit
    mapping(address => uint256) public userToShare;

    // Address of the tokens that the contracts get rewards
    /// @dev initially [ANGL, SDT]
    address[] public rewardTokens;

    ///////////////////// EVENTS /////////////////////

    // User "locker" deposits "amount" tokens
    event Deposit(address locker, uint256 amount);
    // User "locker" withdraws "amount" tokens
    event Withdraw(address locker, uint256 amount);
    // User "locker" withdraws "amount" tokens in emergency
    event EmergencyWithdraw(address locker, uint256 amount);
    // Contract tokens compounded
    event Compounded(address compounder, uint256 amount);
    // User tokens harvested
    event Harvested();
    // Contract max yield chang'ed
    event MaxYieldChanged(uint256 newYield);
    // Emergency status chang'ed
    event EmergencyChanged(bool newState);

    ///////////////////// FUNCTIONS /////////////////////

    /**
     * @notice Constructor function - takes the parameters of used addresses
     * @param oneInchAddr adddress - OneInch Swap Router address
     * @param angleVaultAddr adddress - stakeDAO Angle Vault address
     * @param angleStratAddr adddress - stakeDAO Angle Strategy address
     * @param angleFrontAddr adddress - Angle's Stable Master Front address
     * @param gaugeAddr adddress - stakeDAO Angle Gauge address
     * @param lockTokenAddr adddress - Locking token address - sanFRAX_EUR
     * @dev Mock OneInch Contract can be deployed and specified for tests
     */
    constructor(
        address angleVaultAddr,
        address angleStratAddr,
        address oneInchAddr,
        address angleFrontAddr,
        address gaugeAddr,
        address lockTokenAddr
    ) {
        // Initializes the interfaces
        oneInchRouter = IAggregationRouterV4(oneInchAddr);
        angleVault = IAngle(angleVaultAddr);
        angleStrat = IStrats(angleStratAddr);
        angleFront = IStableMasterFront(angleFrontAddr);
        angleGauge = IGauge(gaugeAddr);
        token = IERC20(lockTokenAddr);
        // Sets initial max yield to 8%
        maxYield = 80;
        // Specifies initial reward tokens: ANGL, SDT
        rewardTokens.push(ANGL);
        rewardTokens.push(SDT);
    }

    /**
     * @notice Direct native coin transfers are closed
     */
    receive() external payable {
        revert();
    }

    /**
     * @notice Direct native coin transfers are closed
     */
    fallback() external payable {
        revert();
    }

    ///////////////////// OWNER VIEWERS /////////////////////
    /**
     * @notice Amount of the tokens that the contracts get rewards
     */
    function rewardTokensLength() external view returns (uint256) {
        return rewardTokens.length;
    }

    ///////////////////// USER INTERACTIONS /////////////////////

    /**
     * @notice User can deposit sanFRAX_EUR tokens to earn a fixed max yield
     * @notice The tokens will not be available for 3 months (90 days)
     * @param amount uint256 - amount to deposit into stake contract
     * @dev sanFRAX_EUR must be approved by user for this contract
     */
    function deposit(uint256 amount) external {
        // Check if not in emergency status
        require(!emergency, "[withdraw] Emergency!");
        // Block the repetitive stakes
        require(initialPPS[msg.sender] == 0, "[deposit] Already locked!");

        // Set the staking moment vars for users
        stakeTimestamps[msg.sender] = block.timestamp;
        initialPPS[msg.sender] = pricePerShare();

        // Move users tokens to contract
        token.safeTransferFrom(msg.sender, address(this), amount);

        // Calculate users share amounts and share TVL
        userToShare[msg.sender] += (amount * 1e18) / initialPPS[msg.sender];
        totalSupply += userToShare[msg.sender];

        emit Deposit(msg.sender, amount);
    }

    /**
     * @notice Users can deposit their staked balances after lock period
     * @notice After the locking period user can withdraw any amount of stakings
     * @param shares uint256 - amount to withdraw from stake contract
     */
    function withdraw(uint256 shares) external {
        // Check if not in emergency status
        require(!emergency, "[withdraw] Emergency!");
        // Check if user has enough balance
        require(
            userToShare[msg.sender] >= shares,
            "[withdraw] Insufficient balance!"
        );
        // Block early withdraws
        require(
            stakeTimestamps[msg.sender] + 90 days <= block.timestamp,
            "[withdraw] Early withdraw!"
        );

        // Calculate users claimable token amount
        uint256 tokenBalance = (shares * pricePerShare()) / 1e18;

        // If the contract doesn't have enough token to return, withdraw from Stake
        if (tokenBalance > token.balanceOf(address(this)))
            angleVault.withdraw(tokenBalance - token.balanceOf(address(this)));

        // If the balance of user generated more yield from Max, cut fee
        if (currentRatioForUser() > maxYield) {
            uint256 withdrawAmount = maxEarningToDate(shares);
            token.safeTransfer(owner(), tokenBalance - withdrawAmount);
            tokenBalance = withdrawAmount;
        }

        // Re-calculate users share amounts and share TVL
        userToShare[msg.sender] -= shares;
        totalSupply -= shares;

        if (userToShare[msg.sender] == 0) {
            delete (initialPPS[msg.sender]);
            delete (stakeTimestamps[msg.sender]);
        }

        // Return users tokens
        token.safeTransfer(msg.sender, tokenBalance);

        emit Withdraw(msg.sender, tokenBalance);
    }

    /**
     * @notice Allows users to withdraw "all" of their tokens wo waiting locking period
     * @notice Only active if emergency status is open
     */
    function emergencyWithdraw() external {
        // Check if user have a balance
        require(
            userToShare[msg.sender] > 0,
            "[withdraw] Insufficient balance!"
        );
        // Check the emergency status
        require(emergency, "[withdraw] Not emergency!");

        // Then, similar logic with "withdraw()" fn
        uint256 tokenBalance = (userToShare[msg.sender] * pricePerShare()) /
            1e18;

        if (tokenBalance > token.balanceOf(address(this)))
            angleVault.withdraw(tokenBalance - token.balanceOf(address(this)));

        if (currentRatioForUser() >= maxYield) {
            uint256 withdrawAmount = maxEarningToDate(userToShare[msg.sender]);
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

    /**
     * @notice Allows owner to claim rewards from stdAngle Gauge
     * @notice Only owner can make this operation
     */
    function claim() external onlyOwner {
        angleGauge.claim_rewards();
    }

    /**
     * @notice Harvests contract tokens (ANGL - SDT expected) by selling them on 
       OneInch to FRAX and stakes FRAX to Angle
     * @notice Only owner can make this operation
     * @param executor address - OneInch Swap Executor
     * @param minReturnAmounts uint256[] - Minimum incomes for each swap in OneInch
     * @param permits bytes[] - permits array for each swap in OneInch
     * @param datas bytes[] - datas array for each swap in OneInch
     * @dev Param arrays must be in length of rewards count - can be obtained by "rewardTokensLength()"
     */
    function harvest(
        address executor,
        uint256[] calldata minReturnAmounts,
        bytes[] calldata permits,
        bytes[] calldata datas
    ) external onlyOwner {
        // Checking the array lengths
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

        // Do each token swap in OneInch and get FRAX tokens
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

        // Deposit obtained FRAX's to Angle -> receive SanFrax/EUR
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

    /**
     * @notice Deposit sanFRAX_EUR tokens to StakeDAO to compound rewards
     * @notice Only owner can make this operation
     * @param isEarn bool - earn option in StakeDAO contracts (it deposits into ANGLE protocol)
     */
    function comp(bool isEarn) external onlyOwner {
        uint256 tokenBalance = token.balanceOf(address(this));
        token.safeIncreaseAllowance(address(angleVault), tokenBalance);
        angleVault.deposit(address(this), tokenBalance, isEarn);

        emit Compounded(msg.sender, tokenBalance);
    }

    /**
     * @dev TEST PURPOSES: CAN REMOVE -> this claims ANGL rewards from ANGLE to STAKEDAO  (stake.harvest)
     */
    function harvestStake() external onlyOwner {
        angleStrat.claim(address(token));
    }

    ///////////////////// OWNER SETTERS /////////////////////

    /**
     * @notice Allow owner to set max yield
     * @notice Only owner can make this operation
     * @dev The number is between [0, 1000] -> 0 = 0, 1000 = %100
     */
    function setMaxYield(uint256 newYield) external onlyOwner {
        maxYield = newYield;
        emit MaxYieldChanged(newYield);
    }

    /**
     * @notice Allow owner to change emergency status
     * @notice Only owner can make this operation
     */
    function toggleEmergency() external onlyOwner {
        emergency = !emergency;
        emit EmergencyChanged(emergency);
    }

    ///////////////////// CONTRACT HELPER FUNCTIONS /////////////////////

    /**
     * @notice Value of each share token
     */
    function pricePerShare() public view returns (uint256) {
        return
            (totalSupply == 0)
                ? 1e18
                : ((angleGauge.balanceOf(address(this)) +
                    token.balanceOf(address(this))) * 1e18) / totalSupply;
    }

    /**
     * @notice Calculates users generated income percent
     */
    function currentRatioForUser() public view returns (uint256) {
        uint256 ppsChange = ((pricePerShare() - initialPPS[msg.sender]) *
            1000) / initialPPS[msg.sender];
        uint256 timePast = block.timestamp - stakeTimestamps[msg.sender];

        return ((ppsChange * 365 days) / timePast);
    }

    /**
     * @notice Calculates users max earnings due to limit
     * @param shares uint256 - Share amount
     */
    function maxEarningToDate(uint256 shares) public view returns (uint256) {
        uint256 amount = (shares * initialPPS[msg.sender]) / 1e18;
        uint256 timePast = block.timestamp - stakeTimestamps[msg.sender];
        return amount + (((amount * timePast * maxYield) / 365 days) / 1000);
    }

    /**
     * @dev FIXME: TEST PURPOSES: REMOVE -> amount of locked tokens in stake Gauge
     */
    function getBalanceInGauge() public view returns (uint256) {
        return angleGauge.balanceOf(address(this));
    }
}
