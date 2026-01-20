// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./utils/CrowdfundChainErrors.sol";

/**
 * @title IssuerRegistry
 * @dev Registers issuers with Keycloak-issued VC hash and prevents double fundraising
 */
contract IssuerRegistry is AccessControl, ReentrancyGuard {
    bytes32 public constant REGISTRAR_ROLE = keccak256("REGISTRAR_ROLE");
    
    struct Issuer {
        string vcHash;           // Keycloak-issued Verifiable Credential hash
        string ipfsHash;         // Information Memorandum IPFS hash
        uint256 registeredAt;    // Registration timestamp
        bool isActive;           // Active status
        uint256 lastCampaignYear; // Last campaign year to prevent double fundraising
        bool exclusivityLock;    // Prevents concurrent campaigns
    }
    
    // Mapping from issuer address to issuer data
    mapping(address => Issuer) public issuers;
    
    // Mapping to track active campaigns per issuer
    mapping(address => address) public activeCampaigns;
    
    // Array of all registered issuers
    address[] public registeredIssuers;
    
    // Events
    event IssuerRegistered(
        address indexed issuer,
        string vcHash,
        string ipfsHash,
        uint256 timestamp
    );
    
    event IssuerDeactivated(address indexed issuer, uint256 timestamp);
    event ExclusivityLockSet(address indexed issuer, bool locked);
    event InformationMemorandumUpdated(address indexed issuer, string newIpfsHash);
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(REGISTRAR_ROLE, msg.sender);
    }
    
    /**
     * @dev Register a new issuer with VC hash and Information Memorandum
     * @param issuer Address of the issuer
     * @param vcHash Keycloak-issued Verifiable Credential hash
     * @param ipfsHash Information Memorandum IPFS hash
     */
    function registerIssuer(
        address issuer,
        string memory vcHash,
        string memory ipfsHash
    ) external onlyRole(REGISTRAR_ROLE) {
        if (issuer == address(0)) revert InvalidAddress();
        if (bytes(vcHash).length == 0) revert EmptyDescription();
        if (bytes(ipfsHash).length == 0) revert EmptyDescription();
        if (issuers[issuer].registeredAt != 0) revert CampaignIdExists();
        
        issuers[issuer] = Issuer({
            vcHash: vcHash,
            ipfsHash: ipfsHash,
            registeredAt: block.timestamp,
            isActive: true,
            lastCampaignYear: 0,
            exclusivityLock: false
        });
        
        registeredIssuers.push(issuer);
        
        emit IssuerRegistered(issuer, vcHash, ipfsHash, block.timestamp);
    }
    
    /**
     * @dev Check if issuer can start a new campaign (prevents double fundraising)
     * @param issuer Address of the issuer
     * @return canStartCampaign True if issuer can start a campaign
     */
    function canStartCampaign(address issuer) external view returns (bool canStartCampaign) {
        Issuer memory issuerData = issuers[issuer];
        
        // Must be registered and active
        if (!issuerData.isActive || issuerData.registeredAt == 0) {
            return false;
        }
        
        // Must not have exclusivity lock (no active campaign)
        if (issuerData.exclusivityLock) {
            return false;
        }
        
        // Must not have run a campaign this calendar year
        uint256 currentYear = getCurrentYear();
        if (issuerData.lastCampaignYear == currentYear) {
            return false;
        }
        
        return true;
    }
    
    /**
     * @dev Set exclusivity lock when campaign starts
     * @param issuer Address of the issuer
     * @param campaignAddress Address of the campaign contract
     */
    function setExclusivityLock(
        address issuer,
        address campaignAddress
    ) external onlyRole(REGISTRAR_ROLE) {
        if (!issuers[issuer].isActive) revert Unauthorized();
        if (issuers[issuer].exclusivityLock) revert CampaignIdExists();
        
        issuers[issuer].exclusivityLock = true;
        issuers[issuer].lastCampaignYear = getCurrentYear();
        activeCampaigns[issuer] = campaignAddress;
        
        emit ExclusivityLockSet(issuer, true);
    }
    
    /**
     * @dev Release exclusivity lock when campaign ends
     * @param issuer Address of the issuer
     */
    function releaseExclusivityLock(address issuer) external onlyRole(REGISTRAR_ROLE) {
        if (!issuers[issuer].exclusivityLock) revert Unauthorized();
        
        issuers[issuer].exclusivityLock = false;
        delete activeCampaigns[issuer];
        
        emit ExclusivityLockSet(issuer, false);
    }
    
    /**
     * @dev Update Information Memorandum IPFS hash
     * @param newIpfsHash New IPFS hash for Information Memorandum
     */
    function updateInformationMemorandum(
        string memory newIpfsHash
    ) external {
        if (!issuers[msg.sender].isActive) revert Unauthorized();
        if (bytes(newIpfsHash).length == 0) revert EmptyDescription();
        
        issuers[msg.sender].ipfsHash = newIpfsHash;
        
        emit InformationMemorandumUpdated(msg.sender, newIpfsHash);
    }
    
    /**
     * @dev Deactivate an issuer
     * @param issuer Address of the issuer to deactivate
     */
    function deactivateIssuer(address issuer) external onlyRole(REGISTRAR_ROLE) {
        if (!issuers[issuer].isActive) revert Unauthorized();
        
        issuers[issuer].isActive = false;
        
        // Release any exclusivity lock
        if (issuers[issuer].exclusivityLock) {
            issuers[issuer].exclusivityLock = false;
            delete activeCampaigns[issuer];
        }
        
        emit IssuerDeactivated(issuer, block.timestamp);
    }
    
    /**
     * @dev Get issuer information
     * @param issuer Address of the issuer
     * @return vcHash Verifiable Credential hash
     * @return ipfsHash Information Memorandum IPFS hash
     * @return registeredAt Registration timestamp
     * @return isActive Active status
     * @return exclusivityLock Exclusivity lock status
     * @return activeCampaign Active campaign address
     */
    function getIssuer(address issuer) external view returns (
        string memory vcHash,
        string memory ipfsHash,
        uint256 registeredAt,
        bool isActive,
        bool exclusivityLock,
        address activeCampaign
    ) {
        Issuer memory issuerData = issuers[issuer];
        return (
            issuerData.vcHash,
            issuerData.ipfsHash,
            issuerData.registeredAt,
            issuerData.isActive,
            issuerData.exclusivityLock,
            activeCampaigns[issuer]
        );
    }
    
    /**
     * @dev Get all registered issuers
     * @return issuers Array of issuer addresses
     */
    function getAllIssuers() external view returns (address[] memory) {
        return registeredIssuers;
    }
    
    /**
     * @dev Get current calendar year
     * @return year Current year
     */
    function getCurrentYear() public view returns (uint256 year) {
        // Approximate year calculation (365.25 days per year)
        return 1970 + (block.timestamp / 31557600);
    }
    
    /**
     * @dev Check if issuer is registered and active
     * @param issuer Address to check
     * @return registered True if issuer is registered and active
     */
    function isRegisteredIssuer(address issuer) external view returns (bool registered) {
        return issuers[issuer].isActive && issuers[issuer].registeredAt != 0;
    }
}