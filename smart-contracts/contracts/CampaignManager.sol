// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./IssuerRegistry.sol";
import "./FundEscrow.sol";
import "./utils/CrowdfundChainErrors.sol";
import "./libraries/CrowdfundChainMath.sol";

/**
 * @title CampaignManager
 * @dev Automates campaign states and enforces Ethiopian Securities Exchange regulations
 */
contract CampaignManager is AccessControl, ReentrancyGuard, Pausable {
    using CrowdfundChainMath for uint256;
    
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    
    enum CampaignState { DRAFT, LIVE, SUCCESSFUL, FAILED, REFUNDING }
    
    // Ethiopian regulations
    uint256 public constant MAX_GOAL_ETB = 5_000_000 ether; // 5M ETB per year
    uint256 public constant SUCCESS_THRESHOLD = 7500; // 75% in basis points
    uint256 public constant MAX_DURATION = 180 days; // Maximum campaign duration
    uint256 public constant REFUND_PERIOD = 20; // 20 business days for refunds
    
    struct Campaign {
        address issuer;
        string campaignId;
        string companyName;
        string description;
        uint256 fundingGoal;
        uint256 totalRaised;
        uint256 startTime;
        uint256 endTime;
        uint256 deadline;
        CampaignState state;
        address escrowContract;
        uint256 investorCount;
        bool fundsReleased;
        string ipfsHash;
    }
    
    // Contract references
    IssuerRegistry public immutable issuerRegistry;
    
    // Campaign storage
    mapping(string => Campaign) public campaigns;
    mapping(string => address[]) public campaignInvestors;
    mapping(string => mapping(address => uint256)) public investments;
    string[] public allCampaignIds;
    
    // Real-time progress tracking
    mapping(string => uint256) public lastProgressUpdate;
    
    // Events
    event CampaignCreated(
        string indexed campaignId,
        address indexed issuer,
        string companyName,
        uint256 fundingGoal,
        uint256 deadline
    );
    
    event CampaignStateChanged(
        string indexed campaignId,
        CampaignState oldState,
        CampaignState newState,
        uint256 timestamp
    );
    
    event InvestmentRecorded(
        string indexed campaignId,
        address indexed investor,
        uint256 amount,
        uint256 newTotal,
        uint256 progressPercent
    );
    
    event ProgressUpdated(
        string indexed campaignId,
        uint256 fundedPercent,
        uint256 investorCount,
        uint256 timestamp
    );
    
    event RefundInitiated(
        string indexed campaignId,
        uint256 totalAmount,
        uint256 investorCount
    );
    
    constructor(address _issuerRegistry) {
        if (_issuerRegistry == address(0)) revert InvalidAddress();
        
        issuerRegistry = IssuerRegistry(_issuerRegistry);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);
    }
    
    /**
     * @dev Create a new campaign (Draft state)
     * @param campaignId Unique campaign identifier
     * @param companyName Company name
     * @param description Campaign description
     * @param fundingGoal Funding goal in ETB
     * @param duration Campaign duration in seconds
     * @param ipfsHash IPFS hash for campaign documents
     */
    function createCampaign(
        string memory campaignId,
        string memory companyName,
        string memory description,
        uint256 fundingGoal,
        uint256 duration,
        string memory ipfsHash
    ) external whenNotPaused {
        if (bytes(campaignId).length == 0) revert EmptyCampaignId();
        if (bytes(companyName).length == 0) revert EmptyCompanyName();
        if (bytes(description).length == 0) revert EmptyDescription();
        if (campaigns[campaignId].issuer != address(0)) revert CampaignIdExists();
        if (fundingGoal == 0 || fundingGoal > MAX_GOAL_ETB) revert InvalidFundingGoal();
        if (duration == 0 || duration > MAX_DURATION) revert InvalidDuration();
        
        // Check issuer eligibility
        if (!issuerRegistry.canStartCampaign(msg.sender)) revert Unauthorized();
        
        uint256 deadline = block.timestamp + duration;
        
        campaigns[campaignId] = Campaign({
            issuer: msg.sender,
            campaignId: campaignId,
            companyName: companyName,
            description: description,
            fundingGoal: fundingGoal,
            totalRaised: 0,
            startTime: 0,
            endTime: 0,
            deadline: deadline,
            state: CampaignState.DRAFT,
            escrowContract: address(0),
            investorCount: 0,
            fundsReleased: false,
            ipfsHash: ipfsHash
        });
        
        allCampaignIds.push(campaignId);
        
        emit CampaignCreated(campaignId, msg.sender, companyName, fundingGoal, deadline);
    }
    
    /**
     * @dev Launch campaign (Draft → Live)
     * @param campaignId Campaign to launch
     * @param escrowContract Address of the escrow contract
     */
    function launchCampaign(
        string memory campaignId,
        address escrowContract
    ) external onlyRole(OPERATOR_ROLE) {
        Campaign storage campaign = campaigns[campaignId];
        if (campaign.issuer == address(0)) revert InvalidCampaignId();
        if (campaign.state != CampaignState.DRAFT) revert CampaignNotActive();
        if (escrowContract == address(0)) revert InvalidAddress();
        
        campaign.state = CampaignState.LIVE;
        campaign.startTime = block.timestamp;
        campaign.escrowContract = escrowContract;
        
        // Set exclusivity lock in issuer registry
        issuerRegistry.setExclusivityLock(campaign.issuer, escrowContract);
        
        emit CampaignStateChanged(campaignId, CampaignState.DRAFT, CampaignState.LIVE, block.timestamp);
    }
    
    /**
     * @dev Record investment and update campaign progress
     * @param campaignId Campaign ID
     * @param investor Investor address
     * @param amount Investment amount
     */
    function recordInvestment(
        string memory campaignId,
        address investor,
        uint256 amount
    ) external onlyRole(OPERATOR_ROLE) {
        Campaign storage campaign = campaigns[campaignId];
        if (campaign.state != CampaignState.LIVE) revert CampaignNotActive();
        if (investor == address(0)) revert InvalidAddress();
        if (amount == 0) revert InvalidAmount();
        if (block.timestamp > campaign.deadline) revert CampaignEnded();
        
        // Record new investment
        if (investments[campaignId][investor] == 0) {
            campaignInvestors[campaignId].push(investor);
            campaign.investorCount++;
        }
        
        investments[campaignId][investor] += amount;
        campaign.totalRaised += amount;
        
        // Calculate progress
        uint256 progressPercent = campaign.totalRaised.calculateProgress(campaign.fundingGoal);
        
        emit InvestmentRecorded(campaignId, investor, amount, campaign.totalRaised, progressPercent);
        
        // Update real-time progress
        _updateProgress(campaignId);
        
        // Auto-check success threshold
        _checkCampaignCompletion(campaignId);
    }
    
    /**
     * @dev Check and update campaign completion status
     * @param campaignId Campaign to check
     */
    function checkCampaignCompletion(string memory campaignId) external {
        _checkCampaignCompletion(campaignId);
    }
    
    /**
     * @dev Internal function to check campaign completion
     * @param campaignId Campaign to check
     */
    function _checkCampaignCompletion(string memory campaignId) internal {
        Campaign storage campaign = campaigns[campaignId];
        if (campaign.state != CampaignState.LIVE) return;
        
        uint256 successThreshold = campaign.fundingGoal.calculateSuccessThreshold();
        bool deadlinePassed = block.timestamp > campaign.deadline;
        bool successfullyFunded = campaign.totalRaised >= successThreshold;
        
        if (successfullyFunded || deadlinePassed) {
            CampaignState newState = successfullyFunded ? 
                CampaignState.SUCCESSFUL : CampaignState.FAILED;
            
            campaign.state = newState;
            campaign.endTime = block.timestamp;
            
            // Release exclusivity lock
            issuerRegistry.releaseExclusivityLock(campaign.issuer);
            
            emit CampaignStateChanged(campaignId, CampaignState.LIVE, newState, block.timestamp);
            
            // Initiate refunds for failed campaigns
            if (newState == CampaignState.FAILED) {
                _initiateRefunds(campaignId);
            }
        }
    }
    
    /**
     * @dev Initiate refund process for failed campaign
     * @param campaignId Failed campaign ID
     */
    function _initiateRefunds(string memory campaignId) internal {
        Campaign storage campaign = campaigns[campaignId];
        campaign.state = CampaignState.REFUNDING;
        
        emit RefundInitiated(campaignId, campaign.totalRaised, campaign.investorCount);
    }
    
    /**
     * @dev Update real-time progress
     * @param campaignId Campaign ID
     */
    function _updateProgress(string memory campaignId) internal {
        Campaign storage campaign = campaigns[campaignId];
        uint256 fundedPercent = campaign.totalRaised.calculateProgress(campaign.fundingGoal);
        
        lastProgressUpdate[campaignId] = block.timestamp;
        
        emit ProgressUpdated(campaignId, fundedPercent, campaign.investorCount, block.timestamp);
    }
    
    /**
     * @dev Get campaign details
     * @param campaignId Campaign ID
     * @return campaign Campaign struct
     */
    function getCampaign(string memory campaignId) external view returns (Campaign memory campaign) {
        return campaigns[campaignId];
    }
    
    /**
     * @dev Get real-time campaign progress
     * @param campaignId Campaign ID
     * @return fundedPercent Percentage funded (basis points)
     * @return investorCount Number of investors
     * @return timeRemaining Time remaining in seconds
     * @return isSuccessful True if success threshold met
     */
    function getCampaignProgress(string memory campaignId) external view returns (
        uint256 fundedPercent,
        uint256 investorCount,
        uint256 timeRemaining,
        bool isSuccessful
    ) {
        Campaign memory campaign = campaigns[campaignId];
        
        fundedPercent = campaign.totalRaised.calculateProgress(campaign.fundingGoal);
        investorCount = campaign.investorCount;
        timeRemaining = campaign.deadline.calculateTimeRemaining();
        
        uint256 successThreshold = campaign.fundingGoal.calculateSuccessThreshold();
        isSuccessful = campaign.totalRaised >= successThreshold;
    }
    
    /**
     * @dev Get campaign investors
     * @param campaignId Campaign ID
     * @return investors Array of investor addresses
     */
    function getCampaignInvestors(string memory campaignId) external view returns (address[] memory investors) {
        return campaignInvestors[campaignId];
    }
    
    /**
     * @dev Get investment amount for specific investor
     * @param campaignId Campaign ID
     * @param investor Investor address
     * @return amount Investment amount
     */
    function getInvestmentAmount(
        string memory campaignId,
        address investor
    ) external view returns (uint256 amount) {
        return investments[campaignId][investor];
    }
    
    /**
     * @dev Get all campaign IDs
     * @return campaignIds Array of all campaign IDs
     */
    function getAllCampaignIds() external view returns (string[] memory campaignIds) {
        return allCampaignIds;
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
}