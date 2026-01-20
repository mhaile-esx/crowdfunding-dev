// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./CampaignImplementation.sol";
import "./NFTShareCertificate.sol";
import "./DAOGovernance.sol";

/**
 * @title CampaignFactory
 * @dev Factory contract for creating and managing crowdfunding campaigns
 * Integrates with NFT certificates and DAO governance
 */
contract CampaignFactory is AccessControl, ReentrancyGuard {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    
    NFTShareCertificate public immutable nftContract;
    DAOGovernance public immutable daoContract;
    
    address public implementationContract;
    uint256 public platformFee; // Fee in basis points (250 = 2.5%)
    address public feeRecipient;
    
    struct Campaign {
        address payable campaignAddress;
        address creator;
        string campaignId;
        string companyName;
        uint256 fundingGoal;
        uint256 deadline;
        uint256 createdAt;
        bool isActive;
    }
    
    mapping(address => Campaign) public campaigns;
    mapping(string => address) public campaignIdToAddress;
    mapping(address => address[]) public creatorCampaigns;
    address[] public allCampaigns;
    
    event CampaignCreated(
        address indexed campaignAddress,
        address indexed creator,
        string campaignId,
        string companyName,
        uint256 fundingGoal,
        uint256 deadline
    );
    
    event CampaignCompleted(
        address indexed campaignAddress,
        string campaignId,
        uint256 totalRaised,
        bool successful
    );
    
    event ImplementationUpdated(address newImplementation);
    event PlatformFeeUpdated(uint256 newFee);
    event FeeRecipientUpdated(address newRecipient);
    
    constructor(
        address nftContractAddress,
        address payable daoContractAddress,
        uint256 platformFee_
    ) {
        require(nftContractAddress != address(0), "Invalid NFT contract");
        require(daoContractAddress != address(0), "Invalid DAO contract");
        require(platformFee_ <= 1000, "Platform fee too high"); // Max 10%
        
        nftContract = NFTShareCertificate(nftContractAddress);
        daoContract = DAOGovernance(daoContractAddress);
        platformFee = platformFee_;
        feeRecipient = msg.sender;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);
    }
    
    /**
     * @dev Create a new crowdfunding campaign
     */
    function createCampaign(
        string memory campaignId,
        string memory companyName,
        string memory description,
        uint256 fundingGoal,
        uint256 duration,
        string memory documentHash
    ) public nonReentrant returns (address) {
        require(bytes(campaignId).length > 0, "Campaign ID required");
        require(bytes(companyName).length > 0, "Company name required");
        require(fundingGoal > 0, "Funding goal must be positive");
        require(duration > 0 && duration <= 365 days, "Invalid duration");
        require(campaignIdToAddress[campaignId] == address(0), "Campaign ID already exists");
        require(implementationContract != address(0), "Implementation not set");
        
        // Clone the implementation contract
        address payable campaignAddress = payable(Clones.clone(implementationContract));
        
        // Calculate deadline
        uint256 deadline = block.timestamp + duration;
        
        // Initialize the campaign
        CampaignImplementation(campaignAddress).initialize(
            msg.sender,
            campaignId,
            companyName,
            description,
            fundingGoal,
            deadline,
            documentHash,
            address(this),
            address(nftContract),
            platformFee
        );
        
        // Store campaign information
        campaigns[campaignAddress] = Campaign({
            campaignAddress: campaignAddress,
            creator: msg.sender,
            campaignId: campaignId,
            companyName: companyName,
            fundingGoal: fundingGoal,
            deadline: deadline,
            createdAt: block.timestamp,
            isActive: true
        });
        
        campaignIdToAddress[campaignId] = campaignAddress;
        creatorCampaigns[msg.sender].push(campaignAddress);
        allCampaigns.push(campaignAddress);
        
        emit CampaignCreated(
            campaignAddress,
            msg.sender,
            campaignId,
            companyName,
            fundingGoal,
            deadline
        );
        
        return campaignAddress;
    }
    
    /**
     * @dev Complete a campaign and issue NFT certificates
     */
    function completeCampaign(address payable campaignAddress) 
        public 
        onlyRole(OPERATOR_ROLE) 
        nonReentrant 
    {
        require(campaigns[campaignAddress].isActive, "Campaign not active");
        
        CampaignImplementation campaign = CampaignImplementation(campaignAddress);
        require(campaign.isCompleted(), "Campaign not completed");
        
        campaigns[campaignAddress].isActive = false;
        
        uint256 totalRaised = campaign.totalRaised();
        bool successful = campaign.isSuccessful();
        
        if (successful) {
            // Issue NFT certificates to investors
            _issueNFTCertificates(campaignAddress);
        }
        
        emit CampaignCompleted(
            campaignAddress,
            campaigns[campaignAddress].campaignId,
            totalRaised,
            successful
        );
    }
    
    /**
     * @dev Issue NFT certificates to campaign investors
     */
    function _issueNFTCertificates(address payable campaignAddress) internal {
        CampaignImplementation campaign = CampaignImplementation(campaignAddress);
        Campaign memory campaignInfo = campaigns[campaignAddress];
        
        address[] memory investors = campaign.getInvestors();
        
        for (uint256 i = 0; i < investors.length; i++) {
            address investor = investors[i];
            uint256 investmentAmount = campaign.getInvestmentAmount(investor);
            
            if (investmentAmount > 0) {
                // Calculate share count based on investment percentage
                uint256 shareCount = (investmentAmount * 1000) / campaignInfo.fundingGoal;
                
                // Generate metadata URI
                string memory tokenURI = _generateTokenURI(
                    campaignInfo.campaignId,
                    campaignInfo.companyName,
                    investmentAmount,
                    shareCount
                );
                
                // Issue NFT certificate
                nftContract.issueCertificate(
                    investor,
                    campaignInfo.campaignId,
                    campaignInfo.companyName,
                    investmentAmount,
                    shareCount,
                    tokenURI
                );
            }
        }
    }
    
    /**
     * @dev Generate metadata URI for NFT certificate
     */
    function _generateTokenURI(
        string memory campaignId,
        string memory companyName,
        uint256 investmentAmount,
        uint256 shareCount
    ) internal pure returns (string memory) {
        // In production, this would generate a proper JSON metadata URI
        return string(abi.encodePacked(
            "https://api.crowdfundchain.com/nft/metadata/",
            campaignId,
            "/",
            Strings.toString(investmentAmount)
        ));
    }
    
    /**
     * @dev Get campaign by ID
     */
    function getCampaignByID(string memory campaignId) 
        public 
        view 
        returns (address) 
    {
        return campaignIdToAddress[campaignId];
    }
    
    /**
     * @dev Get campaigns created by an address
     */
    function getCampaignsByCreator(address creator) 
        public 
        view 
        returns (address[] memory) 
    {
        return creatorCampaigns[creator];
    }
    
    /**
     * @dev Get all campaigns
     */
    function getAllCampaigns() public view returns (address[] memory) {
        return allCampaigns;
    }
    
    /**
     * @dev Get campaign count
     */
    function getCampaignCount() public view returns (uint256) {
        return allCampaigns.length;
    }
    
    /**
     * @dev Get campaign statistics
     */
    function getCampaignStats() public view returns (
        uint256 totalCampaigns,
        uint256 activeCampaigns,
        uint256 completedCampaigns,
        uint256 totalRaised
    ) {
        totalCampaigns = allCampaigns.length;
        activeCampaigns = 0;
        completedCampaigns = 0;
        totalRaised = 0;
        
        for (uint256 i = 0; i < allCampaigns.length; i++) {
            Campaign memory campaign = campaigns[allCampaigns[i]];
            CampaignImplementation impl = CampaignImplementation(campaign.campaignAddress);
            
            if (campaign.isActive) {
                activeCampaigns++;
            } else {
                completedCampaigns++;
            }
            
            totalRaised += impl.totalRaised();
        }
    }
    
    /**
     * @dev Set implementation contract
     */
    function setImplementation(address newImplementation) 
        public 
        onlyRole(ADMIN_ROLE) 
    {
        require(newImplementation != address(0), "Invalid implementation");
        implementationContract = newImplementation;
        emit ImplementationUpdated(newImplementation);
    }
    
    /**
     * @dev Update platform fee
     */
    function updatePlatformFee(uint256 newFee) public onlyRole(ADMIN_ROLE) {
        require(newFee <= 1000, "Fee too high"); // Max 10%
        platformFee = newFee;
        emit PlatformFeeUpdated(newFee);
    }
    
    /**
     * @dev Update fee recipient
     */
    function updateFeeRecipient(address newRecipient) public onlyRole(ADMIN_ROLE) {
        require(newRecipient != address(0), "Invalid recipient");
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(newRecipient);
    }
    
    /**
     * @dev Withdraw platform fees
     */
    function withdrawFees() public onlyRole(ADMIN_ROLE) {
        require(feeRecipient != address(0), "Fee recipient not set");
        payable(feeRecipient).transfer(address(this).balance);
    }
    
    /**
     * @dev Emergency pause a campaign
     */
    function pauseCampaign(address payable campaignAddress) 
        public 
        onlyRole(ADMIN_ROLE) 
    {
        require(campaigns[campaignAddress].isActive, "Campaign not active");
        CampaignImplementation(campaignAddress).pause();
    }
    
    /**
     * @dev Resume a paused campaign
     */
    function resumeCampaign(address payable campaignAddress) 
        public 
        onlyRole(ADMIN_ROLE) 
    {
        CampaignImplementation(campaignAddress).unpause();
    }
    
    /**
     * @dev Receive ETH payments
     */
    receive() external payable {}
}