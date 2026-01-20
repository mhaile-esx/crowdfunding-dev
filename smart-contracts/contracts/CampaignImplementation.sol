// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title CampaignImplementation
 * @dev Individual crowdfunding campaign contract with escrow functionality
 * Supports both crypto and traditional payment integration
 */
contract CampaignImplementation is 
    Initializable, 
    ReentrancyGuardUpgradeable, 
    PausableUpgradeable, 
    AccessControlUpgradeable 
{
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    
    struct Investment {
        address investor;
        uint256 amount;
        uint256 timestamp;
        string paymentMethod; // "crypto", "telebirr", "cbe", etc.
        string transactionHash;
        bool refunded;
    }
    
    address public creator;
    string public campaignId;
    string public companyName;
    string public description;
    uint256 public fundingGoal;
    uint256 public deadline;
    string public documentHash;
    
    address public factory;
    address public nftContract;
    uint256 public platformFee; // In basis points
    
    uint256 public totalRaised;
    uint256 public successThreshold; // 75% of funding goal
    bool public fundsReleased;
    bool public completed;
    
    mapping(address => uint256) public investments;
    mapping(address => Investment[]) public investorTransactions;
    address[] public investors;
    Investment[] public allInvestments;
    
    event InvestmentMade(
        address indexed investor,
        uint256 amount,
        string paymentMethod,
        string transactionHash
    );
    
    event FundsReleased(uint256 amount, uint256 platformFee);
    event RefundIssued(address indexed investor, uint256 amount);
    event CampaignCompleted(bool successful, uint256 totalRaised);
    
    modifier onlyCreator() {
        require(msg.sender == creator, "Only creator allowed");
        _;
    }
    
    modifier onlyFactory() {
        require(msg.sender == factory, "Only factory allowed");
        _;
    }
    
    modifier campaignActive() {
        require(block.timestamp <= deadline, "Campaign ended");
        require(!completed, "Campaign completed");
        _;
    }
    
    modifier campaignEnded() {
        require(block.timestamp > deadline || completed, "Campaign still active");
        _;
    }
    
    function initialize(
        address creator_,
        string memory campaignId_,
        string memory companyName_,
        string memory description_,
        uint256 fundingGoal_,
        uint256 deadline_,
        string memory documentHash_,
        address factory_,
        address nftContract_,
        uint256 platformFee_
    ) public initializer {
        __ReentrancyGuard_init();
        __Pausable_init();
        __AccessControl_init();
        
        require(creator_ != address(0), "Invalid creator");
        require(bytes(campaignId_).length > 0, "Campaign ID required");
        require(fundingGoal_ > 0, "Invalid funding goal");
        require(deadline_ > block.timestamp, "Invalid deadline");
        
        creator = creator_;
        campaignId = campaignId_;
        companyName = companyName_;
        description = description_;
        fundingGoal = fundingGoal_;
        deadline = deadline_;
        documentHash = documentHash_;
        factory = factory_;
        nftContract = nftContract_;
        platformFee = platformFee_;
        
        successThreshold = (fundingGoal_ * 75) / 100; // 75% threshold
        
        _grantRole(DEFAULT_ADMIN_ROLE, factory_);
        _grantRole(ADMIN_ROLE, factory_);
        _grantRole(OPERATOR_ROLE, factory_);
    }
    
    /**
     * @dev Invest in the campaign with crypto payment
     */
    function investCrypto() 
        public 
        payable 
        nonReentrant 
        whenNotPaused 
        campaignActive 
    {
        require(msg.value > 0, "Investment amount must be positive");
        require(msg.sender != creator, "Creator cannot invest");
        
        _processInvestment(msg.sender, msg.value, "crypto", "");
    }
    
    /**
     * @dev Record investment from traditional payment gateway
     */
    function recordInvestment(
        address investor,
        uint256 amount,
        string memory paymentMethod,
        string memory transactionHash
    ) 
        public 
        onlyRole(OPERATOR_ROLE) 
        nonReentrant 
        whenNotPaused 
        campaignActive 
    {
        require(investor != address(0), "Invalid investor");
        require(amount > 0, "Investment amount must be positive");
        require(bytes(paymentMethod).length > 0, "Payment method required");
        require(bytes(transactionHash).length > 0, "Transaction hash required");
        
        _processInvestment(investor, amount, paymentMethod, transactionHash);
    }
    
    /**
     * @dev Internal function to process investments
     */
    function _processInvestment(
        address investor,
        uint256 amount,
        string memory paymentMethod,
        string memory transactionHash
    ) internal {
        // Add to investor's total if first time
        if (investments[investor] == 0) {
            investors.push(investor);
        }
        
        investments[investor] += amount;
        totalRaised += amount;
        
        // Create investment record
        Investment memory investment = Investment({
            investor: investor,
            amount: amount,
            timestamp: block.timestamp,
            paymentMethod: paymentMethod,
            transactionHash: transactionHash,
            refunded: false
        });
        
        investorTransactions[investor].push(investment);
        allInvestments.push(investment);
        
        emit InvestmentMade(investor, amount, paymentMethod, transactionHash);
        
        // Check if funding goal reached
        if (totalRaised >= successThreshold && !fundsReleased) {
            _releaseFunds();
        }
    }
    
    /**
     * @dev Release funds to campaign creator
     */
    function _releaseFunds() internal {
        require(!fundsReleased, "Funds already released");
        require(totalRaised >= successThreshold, "Success threshold not met");
        
        fundsReleased = true;
        
        // Calculate platform fee
        uint256 feeAmount = (address(this).balance * platformFee) / 10000;
        uint256 creatorAmount = address(this).balance - feeAmount;
        
        // Transfer funds
        if (feeAmount > 0) {
            payable(factory).transfer(feeAmount);
        }
        
        if (creatorAmount > 0) {
            payable(creator).transfer(creatorAmount);
        }
        
        emit FundsReleased(creatorAmount, feeAmount);
    }
    
    /**
     * @dev Complete the campaign
     */
    function completeCampaign() 
        public 
        onlyRole(OPERATOR_ROLE) 
        campaignEnded 
    {
        require(!completed, "Campaign already completed");
        
        completed = true;
        
        bool successful = totalRaised >= successThreshold;
        
        // If not successful and funds not released, enable refunds
        if (!successful && !fundsReleased) {
            // Refunds will be processed individually
        }
        
        emit CampaignCompleted(successful, totalRaised);
    }
    
    /**
     * @dev Request refund for failed campaign
     */
    function requestRefund() 
        public 
        nonReentrant 
        campaignEnded 
    {
        require(completed, "Campaign not completed");
        require(!isSuccessful(), "Campaign was successful");
        require(!fundsReleased, "Funds already released");
        require(investments[msg.sender] > 0, "No investment to refund");
        
        uint256 refundAmount = investments[msg.sender];
        investments[msg.sender] = 0;
        
        // Mark all transactions as refunded
        Investment[] storage userTransactions = investorTransactions[msg.sender];
        for (uint256 i = 0; i < userTransactions.length; i++) {
            if (!userTransactions[i].refunded) {
                userTransactions[i].refunded = true;
            }
        }
        
        // Only refund crypto investments from contract balance
        uint256 cryptoRefund = _calculateCryptoRefund(msg.sender);
        
        if (cryptoRefund > 0 && address(this).balance >= cryptoRefund) {
            payable(msg.sender).transfer(cryptoRefund);
        }
        
        emit RefundIssued(msg.sender, refundAmount);
    }
    
    /**
     * @dev Calculate crypto refund amount for an investor
     */
    function _calculateCryptoRefund(address investor) internal view returns (uint256) {
        uint256 cryptoAmount = 0;
        Investment[] storage userTransactions = investorTransactions[investor];
        
        for (uint256 i = 0; i < userTransactions.length; i++) {
            if (keccak256(bytes(userTransactions[i].paymentMethod)) == keccak256(bytes("crypto")) &&
                !userTransactions[i].refunded) {
                cryptoAmount += userTransactions[i].amount;
            }
        }
        
        return cryptoAmount;
    }
    
    /**
     * @dev Check if campaign is successful
     */
    function isSuccessful() public view returns (bool) {
        return totalRaised >= successThreshold;
    }
    
    /**
     * @dev Check if campaign is completed
     */
    function isCompleted() public view returns (bool) {
        return completed;
    }
    
    /**
     * @dev Get campaign progress percentage
     */
    function getProgressPercentage() public view returns (uint256) {
        if (fundingGoal == 0) return 0;
        return (totalRaised * 100) / fundingGoal;
    }
    
    /**
     * @dev Get time remaining in seconds
     */
    function getTimeRemaining() public view returns (uint256) {
        if (block.timestamp >= deadline) return 0;
        return deadline - block.timestamp;
    }
    
    /**
     * @dev Get all investors
     */
    function getInvestors() public view returns (address[] memory) {
        return investors;
    }
    
    /**
     * @dev Get investor count
     */
    function getInvestorCount() public view returns (uint256) {
        return investors.length;
    }
    
    /**
     * @dev Get investment amount for specific investor
     */
    function getInvestmentAmount(address investor) public view returns (uint256) {
        return investments[investor];
    }
    
    /**
     * @dev Get investor transactions
     */
    function getInvestorTransactions(address investor) 
        public 
        view 
        returns (Investment[] memory) 
    {
        return investorTransactions[investor];
    }
    
    /**
     * @dev Get all investments
     */
    function getAllInvestments() public view returns (Investment[] memory) {
        return allInvestments;
    }
    
    /**
     * @dev Get campaign details
     */
    function getCampaignDetails() public view returns (
        address creator_,
        string memory campaignId_,
        string memory companyName_,
        string memory description_,
        uint256 fundingGoal_,
        uint256 deadline_,
        uint256 totalRaised_,
        bool completed_,
        bool fundsReleased_
    ) {
        return (
            creator,
            campaignId,
            companyName,
            description,
            fundingGoal,
            deadline,
            totalRaised,
            completed,
            fundsReleased
        );
    }
    
    /**
     * @dev Emergency withdrawal (admin only)
     */
    function emergencyWithdraw() public onlyRole(ADMIN_ROLE) {
        payable(factory).transfer(address(this).balance);
    }
    
    /**
     * @dev Pause campaign
     */
    function pause() public onlyRole(ADMIN_ROLE) {
        _pause();
    }
    
    /**
     * @dev Unpause campaign
     */
    function unpause() public onlyRole(ADMIN_ROLE) {
        _unpause();
    }
    
    /**
     * @dev Receive ETH payments
     */
    receive() external payable {
        if (msg.value > 0) {
            investCrypto();
        }
    }
}