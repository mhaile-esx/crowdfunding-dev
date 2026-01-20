// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./DeFiYieldPool.sol";
import "./utils/CrowdfundChainErrors.sol";
import "./libraries/CrowdfundChainMath.sol";

/**
 * @title FundEscrow
 * @dev Holds investor funds until campaign closes with optional DeFi yield generation
 */
contract FundEscrow is AccessControl, ReentrancyGuard, Pausable {
    using CrowdfundChainMath for uint256;
    
    bytes32 public constant CAMPAIGN_ROLE = keccak256("CAMPAIGN_ROLE");
    bytes32 public constant YIELD_MANAGER_ROLE = keccak256("YIELD_MANAGER_ROLE");
    
    struct EscrowAccount {
        string campaignId;
        address issuer;
        uint256 totalFunds;
        uint256 yieldGenerated;
        bool fundsReleased;
        bool refundInitiated;
        uint256 createdAt;
        uint256 releasedAt;
    }
    
    struct Investment {
        address investor;
        uint256 amount;
        uint256 timestamp;
        bool refunded;
    }
    
    // DeFi yield pool integration
    DeFiYieldPool public yieldPool;
    
    // Yield distribution percentages (basis points)
    uint256 public constant INVESTOR_YIELD_SHARE = 5000; // 50%
    uint256 public constant ISSUER_YIELD_SHARE = 3000;   // 30%
    uint256 public constant PLATFORM_YIELD_SHARE = 2000; // 20%
    
    // Escrow storage
    mapping(string => EscrowAccount) public escrowAccounts;
    mapping(string => Investment[]) public campaignInvestments;
    mapping(string => mapping(address => uint256)) public investorBalances;
    mapping(string => uint256) public campaignYieldBalance;
    
    // Platform settings
    address public platformWallet;
    bool public yieldFarmingEnabled;
    
    // Events
    event FundsDeposited(
        string indexed campaignId,
        address indexed investor,
        uint256 amount,
        uint256 totalEscrow
    );
    
    event FundsReleased(
        string indexed campaignId,
        address indexed issuer,
        uint256 principalAmount,
        uint256 yieldAmount
    );
    
    event RefundProcessed(
        string indexed campaignId,
        address indexed investor,
        uint256 principalAmount,
        uint256 yieldAmount
    );
    
    event YieldGenerated(
        string indexed campaignId,
        uint256 totalYield,
        uint256 investorShare,
        uint256 issuerShare,
        uint256 platformShare
    );
    
    event YieldFarmingToggled(bool enabled);
    
    constructor(
        address _platformWallet,
        address payable _yieldPool
    ) {
        if (_platformWallet == address(0)) revert InvalidAddress();
        
        platformWallet = _platformWallet;
        yieldPool = DeFiYieldPool(_yieldPool);
        yieldFarmingEnabled = false;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(YIELD_MANAGER_ROLE, msg.sender);
    }
    
    /**
     * @dev Create escrow account for campaign
     * @param campaignId Campaign identifier
     * @param issuer Campaign issuer address
     */
    function createEscrowAccount(
        string memory campaignId,
        address issuer
    ) external onlyRole(CAMPAIGN_ROLE) {
        if (bytes(campaignId).length == 0) revert EmptyCampaignId();
        if (issuer == address(0)) revert InvalidAddress();
        if (escrowAccounts[campaignId].createdAt != 0) revert CampaignIdExists();
        
        escrowAccounts[campaignId] = EscrowAccount({
            campaignId: campaignId,
            issuer: issuer,
            totalFunds: 0,
            yieldGenerated: 0,
            fundsReleased: false,
            refundInitiated: false,
            createdAt: block.timestamp,
            releasedAt: 0
        });
    }
    
    /**
     * @dev Deposit funds to escrow
     * @param campaignId Campaign identifier
     * @param investor Investor address
     */
    function depositFunds(
        string memory campaignId,
        address investor
    ) external payable onlyRole(CAMPAIGN_ROLE) nonReentrant {
        if (msg.value == 0) revert InvalidAmount();
        if (investor == address(0)) revert InvalidAddress();
        
        EscrowAccount storage account = escrowAccounts[campaignId];
        if (account.createdAt == 0) revert InvalidCampaignId();
        if (account.fundsReleased || account.refundInitiated) revert CampaignCompleted();
        
        // Record investment
        campaignInvestments[campaignId].push(Investment({
            investor: investor,
            amount: msg.value,
            timestamp: block.timestamp,
            refunded: false
        }));
        
        investorBalances[campaignId][investor] += msg.value;
        account.totalFunds += msg.value;
        
        // Optionally stake in DeFi yield pool
        if (yieldFarmingEnabled && address(yieldPool) != address(0)) {
            yieldPool.stake{value: msg.value}(campaignId);
        }
        
        emit FundsDeposited(campaignId, investor, msg.value, account.totalFunds);
    }
    
    /**
     * @dev Release funds to successful campaign issuer
     * @param campaignId Campaign identifier
     */
    function releaseFunds(string memory campaignId) external onlyRole(CAMPAIGN_ROLE) nonReentrant {
        EscrowAccount storage account = escrowAccounts[campaignId];
        if (account.createdAt == 0) revert InvalidCampaignId();
        if (account.fundsReleased) revert FundsAlreadyReleased();
        if (account.refundInitiated) revert CampaignWasSuccessful();
        if (account.totalFunds == 0) revert InsufficientContractBalance();
        
        account.fundsReleased = true;
        account.releasedAt = block.timestamp;
        
        uint256 principalAmount = account.totalFunds;
        uint256 yieldAmount = 0;
        
        // Harvest yield if yield farming is enabled
        if (yieldFarmingEnabled && address(yieldPool) != address(0)) {
            yieldAmount = yieldPool.harvestYield(campaignId);
            if (yieldAmount > 0) {
                _distributeYield(campaignId, yieldAmount);
                // Issuer gets their share of yield
                uint256 issuerYieldShare = yieldAmount.calculatePercentage(ISSUER_YIELD_SHARE);
                principalAmount += issuerYieldShare;
            }
        }
        
        // Transfer principal + issuer yield share to issuer
        (bool success, ) = account.issuer.call{value: principalAmount}("");
        if (!success) revert TransferFailed();
        
        emit FundsReleased(campaignId, account.issuer, account.totalFunds, yieldAmount);
    }
    
    /**
     * @dev Process refunds for failed campaign
     * @param campaignId Campaign identifier
     */
    function processRefunds(string memory campaignId) external onlyRole(CAMPAIGN_ROLE) nonReentrant {
        EscrowAccount storage account = escrowAccounts[campaignId];
        if (account.createdAt == 0) revert InvalidCampaignId();
        if (account.fundsReleased) revert FundsAlreadyReleased();
        if (account.refundInitiated) revert CampaignCompleted();
        
        account.refundInitiated = true;
        
        uint256 totalYield = 0;
        
        // Harvest yield if yield farming is enabled
        if (yieldFarmingEnabled && address(yieldPool) != address(0)) {
            totalYield = yieldPool.harvestYield(campaignId);
            if (totalYield > 0) {
                _distributeYield(campaignId, totalYield);
            }
        }
        
        // Process individual refunds
        Investment[] storage investments = campaignInvestments[campaignId];
        uint256 investorYieldShare = totalYield.calculatePercentage(INVESTOR_YIELD_SHARE);
        
        for (uint256 i = 0; i < investments.length; i++) {
            Investment storage investment = investments[i];
            if (!investment.refunded) {
                investment.refunded = true;
                
                uint256 principalRefund = investment.amount;
                uint256 yieldRefund = 0;
                
                // Calculate proportional yield share
                if (investorYieldShare > 0) {
                    yieldRefund = (investment.amount * investorYieldShare) / account.totalFunds;
                }
                
                uint256 totalRefund = principalRefund + yieldRefund;
                
                (bool success, ) = investment.investor.call{value: totalRefund}("");
                if (!success) revert TransferFailed();
                
                emit RefundProcessed(campaignId, investment.investor, principalRefund, yieldRefund);
            }
        }
    }
    
    /**
     * @dev Distribute yield among stakeholders
     * @param campaignId Campaign identifier
     * @param totalYield Total yield generated
     */
    function _distributeYield(string memory campaignId, uint256 totalYield) internal {
        uint256 investorShare = totalYield.calculatePercentage(INVESTOR_YIELD_SHARE);
        uint256 issuerShare = totalYield.calculatePercentage(ISSUER_YIELD_SHARE);
        uint256 platformShare = totalYield.calculatePercentage(PLATFORM_YIELD_SHARE);
        
        // Store campaign yield balance for later distribution
        campaignYieldBalance[campaignId] = investorShare;
        
        // Transfer platform share immediately
        if (platformShare > 0) {
            (bool success, ) = platformWallet.call{value: platformShare}("");
            if (!success) revert TransferFailed();
        }
        
        emit YieldGenerated(campaignId, totalYield, investorShare, issuerShare, platformShare);
    }
    
    /**
     * @dev Enable/disable yield farming
     * @param enabled True to enable yield farming
     */
    function setYieldFarming(bool enabled) external onlyRole(YIELD_MANAGER_ROLE) {
        yieldFarmingEnabled = enabled;
        emit YieldFarmingToggled(enabled);
    }
    
    /**
     * @dev Update yield pool contract
     * @param newYieldPool New yield pool address
     */
    function setYieldPool(address payable newYieldPool) external onlyRole(DEFAULT_ADMIN_ROLE) {
        yieldPool = DeFiYieldPool(newYieldPool);
    }
    
    /**
     * @dev Update platform wallet
     * @param newPlatformWallet New platform wallet address
     */
    function setPlatformWallet(address newPlatformWallet) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newPlatformWallet == address(0)) revert InvalidAddress();
        platformWallet = newPlatformWallet;
    }
    
    /**
     * @dev Get escrow account details
     * @param campaignId Campaign identifier
     * @return account Escrow account details
     */
    function getEscrowAccount(string memory campaignId) external view returns (EscrowAccount memory account) {
        return escrowAccounts[campaignId];
    }
    
    /**
     * @dev Get campaign investments
     * @param campaignId Campaign identifier
     * @return investments Array of investments
     */
    function getCampaignInvestments(string memory campaignId) external view returns (Investment[] memory investments) {
        return campaignInvestments[campaignId];
    }
    
    /**
     * @dev Get investor balance for campaign
     * @param campaignId Campaign identifier
     * @param investor Investor address
     * @return balance Investor's balance
     */
    function getInvestorBalance(
        string memory campaignId,
        address investor
    ) external view returns (uint256 balance) {
        return investorBalances[campaignId][investor];
    }
    
    /**
     * @dev Emergency pause
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    /**
     * @dev Emergency unpause
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
    
    /**
     * @dev Emergency withdrawal (only admin)
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
        // Allow contract to receive ETH
    }
}