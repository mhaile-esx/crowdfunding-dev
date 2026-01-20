// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../utils/CrowdfundChainErrors.sol";
import "../libraries/CrowdfundChainMath.sol";

/**
 * @title ESXNFTShareCertificate
 * @dev Issues ESX-bound (non-transferable) NFTs with comprehensive metadata
 * Includes issuer name, equity %, campaign ID, and voting weight for DAO governance
 */
contract ESXNFTShareCertificate is ERC721, ERC721URIStorage, AccessControl, ReentrancyGuard {
    using CrowdfundChainMath for uint256;
    
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant ESX_ADMIN_ROLE = keccak256("ESX_ADMIN_ROLE");
    
    uint256 private _tokenIdCounter;
    
    struct ShareCertificateMetadata {
        string issuerName;          // Company/Issuer name
        string campaignId;          // Campaign identifier
        uint256 equityPercentage;   // Equity percentage (basis points)
        uint256 investmentAmount;   // Investment amount in ETB
        uint256 shareCount;         // Number of shares
        uint256 votingWeight;       // Voting weight for DAO
        uint256 issuedAt;          // Issuance timestamp
        bool isActive;             // Certificate active status
        bool isESXBound;           // ESX-bound (non-transferable)
    }
    
    // Certificate storage
    mapping(uint256 => ShareCertificateMetadata) public certificates;
    mapping(address => uint256[]) public ownerCertificates;
    mapping(string => uint256[]) public campaignCertificates;
    mapping(string => uint256[]) public issuerCertificates;
    
    // ESX compliance settings
    bool public transfersEnabled;
    mapping(uint256 => bool) public esxApprovedTransfers;
    address public esxRegulator;
    
    // Voting power calculation
    uint256 public constant VOTING_POWER_DIVISOR = 1000; // 1 vote per 1000 ETB
    
    // Events
    event ESXCertificateIssued(
        uint256 indexed tokenId,
        address indexed owner,
        string indexed campaignId,
        string issuerName,
        uint256 equityPercentage,
        uint256 investmentAmount,
        uint256 votingWeight
    );
    
    event CertificateRevoked(
        uint256 indexed tokenId,
        string reason,
        uint256 timestamp
    );
    
    event ESXTransferApproved(
        uint256 indexed tokenId,
        address indexed from,
        address indexed to,
        uint256 timestamp
    );
    
    event TransferStatusChanged(bool transfersEnabled);
    
    constructor(
        string memory name,
        string memory symbol,
        address _esxRegulator
    ) ERC721(name, symbol) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(ESX_ADMIN_ROLE, msg.sender);
        
        esxRegulator = _esxRegulator;
        transfersEnabled = false; // Start with transfers disabled (ESX-bound)
    }
    
    /**
     * @dev Issue ESX-bound share certificate
     * @param to Certificate recipient
     * @param issuerName Company/Issuer name
     * @param campaignId Campaign identifier
     * @param equityPercentage Equity percentage in basis points
     * @param investmentAmount Investment amount in ETB
     * @param shareCount Number of shares
     * @param tokenURI Metadata URI
     */
    function issueESXCertificate(
        address to,
        string memory issuerName,
        string memory campaignId,
        uint256 equityPercentage,
        uint256 investmentAmount,
        uint256 shareCount,
        string memory tokenURI
    ) external onlyRole(MINTER_ROLE) nonReentrant returns (uint256) {
        if (to == address(0)) revert InvalidAddress();
        if (bytes(issuerName).length == 0) revert EmptyCompanyName();
        if (bytes(campaignId).length == 0) revert EmptyCampaignId();
        if (investmentAmount == 0) revert InvalidInvestmentAmount();
        if (shareCount == 0) revert InvalidShareCount();
        
        _tokenIdCounter++;
        uint256 tokenId = _tokenIdCounter;
        
        // Calculate voting weight based on investment amount
        uint256 votingWeight = investmentAmount.calculateVotingPower();
        
        // Create certificate metadata
        certificates[tokenId] = ShareCertificateMetadata({
            issuerName: issuerName,
            campaignId: campaignId,
            equityPercentage: equityPercentage,
            investmentAmount: investmentAmount,
            shareCount: shareCount,
            votingWeight: votingWeight,
            issuedAt: block.timestamp,
            isActive: true,
            isESXBound: true
        });
        
        // Update tracking mappings
        ownerCertificates[to].push(tokenId);
        campaignCertificates[campaignId].push(tokenId);
        issuerCertificates[issuerName].push(tokenId);
        
        // Mint NFT
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, tokenURI);
        
        emit ESXCertificateIssued(
            tokenId,
            to,
            campaignId,
            issuerName,
            equityPercentage,
            investmentAmount,
            votingWeight
        );
        
        return tokenId;
    }
    
    /**
     * @dev Calculate total voting power for address
     * @param owner Address to calculate voting power for
     * @return totalVotingPower Total voting power
     */
    function getVotingPower(address owner) external view returns (uint256 totalVotingPower) {
        uint256[] memory tokenIds = ownerCertificates[owner];
        
        for (uint256 i = 0; i < tokenIds.length; i++) {
            ShareCertificateMetadata memory cert = certificates[tokenIds[i]];
            if (cert.isActive && ownerOf(tokenIds[i]) == owner) {
                totalVotingPower += cert.votingWeight;
            }
        }
        
        return totalVotingPower;
    }
    
    /**
     * @dev Get certificates owned by address
     * @param owner Certificate owner
     * @return tokenIds Array of token IDs
     */
    function getCertificatesByOwner(address owner) external view returns (uint256[] memory tokenIds) {
        return ownerCertificates[owner];
    }
    
    /**
     * @dev Get certificates for campaign
     * @param campaignId Campaign identifier
     * @return tokenIds Array of token IDs
     */
    function getCertificatesByCampaign(string memory campaignId) external view returns (uint256[] memory tokenIds) {
        return campaignCertificates[campaignId];
    }
    
    /**
     * @dev Get certificates for issuer
     * @param issuerName Issuer name
     * @return tokenIds Array of token IDs
     */
    function getCertificatesByIssuer(string memory issuerName) external view returns (uint256[] memory tokenIds) {
        return issuerCertificates[issuerName];
    }
    
    /**
     * @dev Get certificate metadata
     * @param tokenId Token ID
     * @return metadata Certificate metadata
     */
    function getCertificateMetadata(uint256 tokenId) external view returns (ShareCertificateMetadata memory metadata) {
        if (_ownerOf(tokenId) == address(0)) revert CertificateNotFound();
        return certificates[tokenId];
    }
    
    /**
     * @dev Revoke certificate (ESX compliance)
     * @param tokenId Token ID to revoke
     * @param reason Revocation reason
     */
    function revokeCertificate(
        uint256 tokenId,
        string memory reason
    ) external onlyRole(ESX_ADMIN_ROLE) {
        if (_ownerOf(tokenId) == address(0)) revert CertificateNotFound();
        if (!certificates[tokenId].isActive) revert CertificateAlreadyRevoked();
        
        certificates[tokenId].isActive = false;
        
        emit CertificateRevoked(tokenId, reason, block.timestamp);
    }
    
    /**
     * @dev Approve ESX transfer (regulator approval)
     * @param tokenId Token ID to approve for transfer
     * @param from Current owner
     * @param to New owner
     */
    function approveESXTransfer(
        uint256 tokenId,
        address from,
        address to
    ) external onlyRole(ESX_ADMIN_ROLE) {
        if (_ownerOf(tokenId) == address(0)) revert CertificateNotFound();
        if (ownerOf(tokenId) != from) revert Unauthorized();
        if (to == address(0)) revert InvalidAddress();
        
        esxApprovedTransfers[tokenId] = true;
        
        emit ESXTransferApproved(tokenId, from, to, block.timestamp);
    }
    
    /**
     * @dev Enable/disable transfers globally
     * @param enabled Transfer status
     */
    function setTransfersEnabled(bool enabled) external onlyRole(ESX_ADMIN_ROLE) {
        transfersEnabled = enabled;
        emit TransferStatusChanged(enabled);
    }
    
    /**
     * @dev Update ESX regulator address
     * @param newRegulator New regulator address
     */
    function setESXRegulator(address newRegulator) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newRegulator == address(0)) revert InvalidAddress();
        esxRegulator = newRegulator;
        _grantRole(ESX_ADMIN_ROLE, newRegulator);
    }
    
    /**
     * @dev Override _update to implement ESX-bound logic (OZ v5)
     */
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override returns (address) {
        address from = _ownerOf(tokenId);
        
        // Allow minting (from = address(0))
        if (from != address(0)) {
            // Check if transfers are globally enabled or specifically approved
            if (!transfersEnabled && !esxApprovedTransfers[tokenId]) {
                revert Unauthorized();
            }
            
            // Reset transfer approval after use
            if (esxApprovedTransfers[tokenId]) {
                esxApprovedTransfers[tokenId] = false;
            }
        }
        
        // Update owner tracking on transfer (not minting or burning)
        if (from != address(0) && to != address(0)) {
            // Remove from old owner's list
            uint256[] storage fromTokens = ownerCertificates[from];
            for (uint256 i = 0; i < fromTokens.length; i++) {
                if (fromTokens[i] == tokenId) {
                    fromTokens[i] = fromTokens[fromTokens.length - 1];
                    fromTokens.pop();
                    break;
                }
            }
            
            // Add to new owner's list
            ownerCertificates[to].push(tokenId);
        }
        
        return super._update(to, tokenId, auth);
    }
    
    /**
     * @dev Check if certificate is ESX-bound
     * @param tokenId Token ID
     * @return isESXBound True if certificate is ESX-bound
     */
    function isESXBound(uint256 tokenId) external view returns (bool) {
        if (_ownerOf(tokenId) == address(0)) revert CertificateNotFound();
        return certificates[tokenId].isESXBound;
    }
    
    /**
     * @dev Get total number of certificates issued
     * @return totalCertificates Total certificates count
     */
    function getTotalCertificates() external view returns (uint256 totalCertificates) {
        return _tokenIdCounter;
    }
    
    /**
     * @dev Required override for ERC721URIStorage
     */
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }
    
    /**
     * @dev Required override for AccessControl
     */
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}