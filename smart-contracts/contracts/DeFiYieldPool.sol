// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./utils/CrowdfundChainErrors.sol";
import "./libraries/CrowdfundChainMath.sol";

/**
 * @dev External DeFi protocol interface (simplified)
 */
interface IYieldProtocol {
    function deposit(uint256 amount) external returns (uint256);
    function withdraw(uint256 shares) external returns (uint256);
    function getYield(address account) external view returns (uint256);
}

/**
 * @title DeFiYieldPool
 * @dev Manages DeFi yield generation for escrowed funds (Aave or Compound-like)
 */
contract DeFiYieldPool is AccessControl, ReentrancyGuard, Pausable {
    using CrowdfundChainMath for uint256;
    
    bytes32 public constant POOL_MANAGER_ROLE = keccak256("POOL_MANAGER_ROLE");
    bytes32 public constant ESCROW_ROLE = keccak256("ESCROW_ROLE");
    
    // Yield pool configuration
    struct PoolConfig {
        uint256 baseYieldRate;      // Base yield rate per year (basis points)
        uint256 compoundingPeriod;  // Compounding period in seconds
        bool isActive;              // Pool active status
        uint256 totalStaked;        // Total amount staked
        uint256 totalYieldPaid;     // Total yield distributed
    }
    
    // Campaign stake tracking
    struct CampaignStake {
        uint256 principal;          // Principal amount staked
        uint256 yieldAccrued;       // Yield accrued so far
        uint256 stakeTime;          // When stake was created
        uint256 lastCompoundTime;   // Last compounding calculation
        bool harvested;             // Whether yield has been harvested
    }
    
    // Pool configuration
    PoolConfig public poolConfig;
    
    // External yield protocol integration
    IYieldProtocol public yieldProtocol;
    mapping(string => uint256) public protocolShares; // Campaign -> Protocol shares
    
    // Campaign stakes
    mapping(string => CampaignStake) public campaignStakes;
    mapping(string => bool) public authorizedCampaigns;
    
    // Platform statistics
    uint256 public totalValueLocked;
    uint256 public totalYieldGenerated;
    
    // Events
    event FundsStaked(
        string indexed campaignId,
        uint256 amount,
        uint256 expectedYield
    );
    
    event YieldHarvested(
        string indexed campaignId,
        uint256 principal,
        uint256 yieldAmount,
        uint256 totalReturn
    );
    
    event YieldCompounded(
        string indexed campaignId,
        uint256 newYieldAccrued,
        uint256 totalYield
    );
    
    event PoolConfigUpdated(
        uint256 newYieldRate,
        uint256 newCompoundingPeriod,
        bool isActive
    );
    
    event ProtocolIntegrationUpdated(address newProtocol);
    
    constructor(
        uint256 _baseYieldRate,
        uint256 _compoundingPeriod
    ) {
        poolConfig = PoolConfig({
            baseYieldRate: _baseYieldRate,
            compoundingPeriod: _compoundingPeriod,
            isActive: true,
            totalStaked: 0,
            totalYieldPaid: 0
        });
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(POOL_MANAGER_ROLE, msg.sender);
    }
    
    /**
     * @dev Stake funds for yield generation
     * @param campaignId Campaign identifier
     */
    function stake(string memory campaignId) external payable onlyRole(ESCROW_ROLE) nonReentrant {
        if (!poolConfig.isActive) revert PoolNotActive();
        if (msg.value == 0) revert InvalidAmount();
        if (bytes(campaignId).length == 0) revert EmptyCampaignId();
        if (campaignStakes[campaignId].stakeTime != 0) revert CampaignIdExists();
        
        uint256 stakeAmount = msg.value;
        
        // Create campaign stake record
        campaignStakes[campaignId] = CampaignStake({
            principal: stakeAmount,
            yieldAccrued: 0,
            stakeTime: block.timestamp,
            lastCompoundTime: block.timestamp,
            harvested: false
        });
        
        authorizedCampaigns[campaignId] = true;
        
        // Update pool statistics
        poolConfig.totalStaked += stakeAmount;
        totalValueLocked += stakeAmount;
        
        // Deposit to external yield protocol if available
        if (address(yieldProtocol) != address(0)) {
            uint256 shares = yieldProtocol.deposit(stakeAmount);
            protocolShares[campaignId] = shares;
        }
        
        uint256 expectedYield = _calculateExpectedYield(stakeAmount, 365 days);
        
        emit FundsStaked(campaignId, stakeAmount, expectedYield);
    }
    
    /**
     * @dev Harvest yield for campaign
     * @param campaignId Campaign identifier
     * @return totalYield Total yield harvested
     */
    function harvestYield(string memory campaignId) external onlyRole(ESCROW_ROLE) nonReentrant returns (uint256 totalYield) {
        CampaignStake storage stake = campaignStakes[campaignId];
        if (stake.stakeTime == 0) revert InvalidCampaignId();
        if (stake.harvested) revert FundsAlreadyReleased();
        if (!authorizedCampaigns[campaignId]) revert Unauthorized();
        
        // Compound any pending yield
        _compoundYield(campaignId);
        
        uint256 principal = stake.principal;
        uint256 yieldAmount = stake.yieldAccrued;
        
        // Withdraw from external protocol if integrated
        if (address(yieldProtocol) != address(0) && protocolShares[campaignId] > 0) {
            uint256 protocolYield = yieldProtocol.getYield(address(this));
            if (protocolYield > yieldAmount) {
                yieldAmount = protocolYield;
            }
            
            // Withdraw principal + yield from protocol
            yieldProtocol.withdraw(protocolShares[campaignId]);
        }
        
        stake.harvested = true;
        totalYield = yieldAmount;
        
        // Update pool statistics
        poolConfig.totalStaked -= principal;
        poolConfig.totalYieldPaid += yieldAmount;
        totalYieldGenerated += yieldAmount;
        
        // Transfer total amount back to escrow
        uint256 totalReturn = principal + yieldAmount;
        if (totalReturn > address(this).balance) {
            totalReturn = address(this).balance;
        }
        
        (bool success, ) = msg.sender.call{value: totalReturn}("");
        if (!success) revert TransferFailed();
        
        emit YieldHarvested(campaignId, principal, yieldAmount, totalReturn);
        
        return totalYield;
    }
    
    /**
     * @dev Compound yield for campaign
     * @param campaignId Campaign identifier
     */
    function compoundYield(string memory campaignId) external {
        _compoundYield(campaignId);
    }
    
    /**
     * @dev Internal function to compound yield
     * @param campaignId Campaign identifier
     */
    function _compoundYield(string memory campaignId) internal {
        CampaignStake storage stake = campaignStakes[campaignId];
        if (stake.stakeTime == 0 || stake.harvested) return;
        
        uint256 timeElapsed = block.timestamp - stake.lastCompoundTime;
        if (timeElapsed < poolConfig.compoundingPeriod) return;
        
        uint256 periods = timeElapsed / poolConfig.compoundingPeriod;
        uint256 newYield = _calculateYieldForPeriods(stake.principal + stake.yieldAccrued, periods);
        
        stake.yieldAccrued += newYield;
        stake.lastCompoundTime = block.timestamp;
        
        emit YieldCompounded(campaignId, newYield, stake.yieldAccrued);
    }
    
    /**
     * @dev Calculate expected yield for amount and duration
     * @param amount Principal amount
     * @param duration Duration in seconds
     * @return expectedYield Expected yield amount
     */
    function _calculateExpectedYield(uint256 amount, uint256 duration) internal view returns (uint256 expectedYield) {
        uint256 annualYield = amount.calculatePercentage(poolConfig.baseYieldRate);
        return (annualYield * duration) / 365 days;
    }
    
    /**
     * @dev Calculate yield for specific number of compounding periods
     * @param amount Current amount (principal + accrued yield)
     * @param periods Number of compounding periods
     * @return yield Yield for the periods
     */
    function _calculateYieldForPeriods(uint256 amount, uint256 periods) internal view returns (uint256 yield) {
        if (periods == 0) return 0;
        
        uint256 periodYieldRate = (poolConfig.baseYieldRate * poolConfig.compoundingPeriod) / 365 days;
        
        // Simplified compound interest calculation
        for (uint256 i = 0; i < periods && i < 100; i++) { // Limit iterations for gas
            uint256 periodYield = amount.calculatePercentage(periodYieldRate);
            yield += periodYield;
            amount += periodYield;
        }
        
        return yield;
    }
    
    /**
     * @dev Get campaign stake details
     * @param campaignId Campaign identifier
     * @return stake Campaign stake details
     */
    function getCampaignStake(string memory campaignId) external view returns (CampaignStake memory stake) {
        return campaignStakes[campaignId];
    }
    
    /**
     * @dev Get real-time yield for campaign
     * @param campaignId Campaign identifier
     * @return currentYield Current accrued yield
     */
    function getCurrentYield(string memory campaignId) external view returns (uint256 currentYield) {
        CampaignStake memory stake = campaignStakes[campaignId];
        if (stake.stakeTime == 0 || stake.harvested) return 0;
        
        uint256 timeElapsed = block.timestamp - stake.lastCompoundTime;
        uint256 periods = timeElapsed / poolConfig.compoundingPeriod;
        
        uint256 pendingYield = _calculateYieldForPeriods(stake.principal + stake.yieldAccrued, periods);
        return stake.yieldAccrued + pendingYield;
    }
    
    /**
     * @dev Update pool configuration
     * @param newYieldRate New base yield rate
     * @param newCompoundingPeriod New compounding period
     * @param isActive Pool active status
     */
    function updatePoolConfig(
        uint256 newYieldRate,
        uint256 newCompoundingPeriod,
        bool isActive
    ) external onlyRole(POOL_MANAGER_ROLE) {
        poolConfig.baseYieldRate = newYieldRate;
        poolConfig.compoundingPeriod = newCompoundingPeriod;
        poolConfig.isActive = isActive;
        
        emit PoolConfigUpdated(newYieldRate, newCompoundingPeriod, isActive);
    }
    
    /**
     * @dev Set external yield protocol integration
     * @param protocolAddress Address of external yield protocol
     */
    function setYieldProtocol(address protocolAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        yieldProtocol = IYieldProtocol(protocolAddress);
        emit ProtocolIntegrationUpdated(protocolAddress);
    }
    
    /**
     * @dev Get pool statistics
     * @return totalStaked Total amount staked
     * @return totalYieldPaid Total yield distributed
     * @return currentTVL Current total value locked
     * @return yieldGenerated Total yield generated
     */
    function getPoolStats() external view returns (
        uint256 totalStaked,
        uint256 totalYieldPaid,
        uint256 currentTVL,
        uint256 yieldGenerated
    ) {
        return (
            poolConfig.totalStaked,
            poolConfig.totalYieldPaid,
            totalValueLocked,
            totalYieldGenerated
        );
    }
    
    /**
     * @dev Emergency pause
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
        poolConfig.isActive = false;
    }
    
    /**
     * @dev Emergency unpause
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
        poolConfig.isActive = true;
    }
    
    /**
     * @dev Emergency withdrawal
     * @param amount Amount to withdraw
     * @param recipient Recipient address
     */
    function emergencyWithdraw(
        uint256 amount,
        address recipient
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (recipient == address(0)) revert InvalidAddress();
        if (amount > address(this).balance) revert InsufficientContractBalance();
        
        (bool success, ) = recipient.call{value: amount}("");
        if (!success) revert TransferFailed();
    }
    
    receive() external payable {
        // Allow contract to receive ETH from external protocols
    }
}