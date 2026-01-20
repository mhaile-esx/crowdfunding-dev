// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title NFTShareCertificate
 * @dev Issues ESX-bound (non-transferable) NFTs with metadata for equity and voting
 * Includes issuer name, equity %, campaign ID, and voting weight for DAO
 */
contract NFTShareCertificate is ERC721, ERC721URIStorage, AccessControl, ReentrancyGuard {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    uint256 private _tokenIdCounter;
    
    struct ShareCertificate {
        string campaignId;
        string companyName;
        uint256 investmentAmount;
        uint256 shareCount;
        uint256 votingPower;
        uint256 issuedAt;
        bool isActive;
    }
    
    mapping(uint256 => ShareCertificate) public certificates;
    mapping(address => uint256[]) public ownerCertificates;
    mapping(string => uint256[]) public campaignCertificates;
    
    string private _baseTokenURI;
    
    event CertificateIssued(
        uint256 indexed tokenId,
        address indexed owner,
        string campaignId,
        uint256 investmentAmount,
        uint256 shareCount
    );
    
    event CertificateRevoked(uint256 indexed tokenId, string reason);
    event BaseURIUpdated(string newBaseURI);
    
    constructor(
        string memory name,
        string memory symbol,
        string memory baseTokenURI
    ) ERC721(name, symbol) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _baseTokenURI = baseTokenURI;
    }
    
    /**
     * @dev Issue a new share certificate NFT
     * @param to Address to mint the certificate to
     * @param campaignId ID of the campaign
     * @param companyName Name of the company
     * @param investmentAmount Amount invested in Wei
     * @param shareCount Number of shares represented
     * @param tokenURI Metadata URI for the NFT
     */
    function issueCertificate(
        address to,
        string memory campaignId,
        string memory companyName,
        uint256 investmentAmount,
        uint256 shareCount,
        string memory tokenURI
    ) public onlyRole(MINTER_ROLE) nonReentrant returns (uint256) {
        require(to != address(0), "Cannot mint to zero address");
        require(bytes(campaignId).length > 0, "Campaign ID required");
        require(bytes(companyName).length > 0, "Company name required");
        require(investmentAmount > 0, "Investment amount must be positive");
        require(shareCount > 0, "Share count must be positive");
        
        _tokenIdCounter++;
        uint256 tokenId = _tokenIdCounter;
        
        // Calculate voting power (1 vote per 1000 ETB invested)
        uint256 votingPower = investmentAmount / (1000 * 10**18);
        if (votingPower == 0) votingPower = 1; // Minimum 1 vote
        
        certificates[tokenId] = ShareCertificate({
            campaignId: campaignId,
            companyName: companyName,
            investmentAmount: investmentAmount,
            shareCount: shareCount,
            votingPower: votingPower,
            issuedAt: block.timestamp,
            isActive: true
        });
        
        ownerCertificates[to].push(tokenId);
        campaignCertificates[campaignId].push(tokenId);
        
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, tokenURI);
        
        emit CertificateIssued(tokenId, to, campaignId, investmentAmount, shareCount);
        
        return tokenId;
    }
    
    /**
     * @dev Revoke a certificate (mark as inactive)
     * @param tokenId ID of the token to revoke
     * @param reason Reason for revocation
     */
    function revokeCertificate(uint256 tokenId, string memory reason) 
        public 
        onlyRole(ADMIN_ROLE) 
    {
        require(_ownerOf(tokenId) != address(0), "Certificate does not exist");
        
        certificates[tokenId].isActive = false;
        
        emit CertificateRevoked(tokenId, reason);
    }
    
    /**
     * @dev Get total voting power for an address
     * @param owner Address to check voting power for
     */
    function getVotingPower(address owner) public view returns (uint256) {
        uint256 totalVotingPower = 0;
        uint256[] memory tokenIds = ownerCertificates[owner];
        
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (certificates[tokenIds[i]].isActive) {
                totalVotingPower += certificates[tokenIds[i]].votingPower;
            }
        }
        
        return totalVotingPower;
    }
    
    /**
     * @dev Get all certificates owned by an address
     * @param owner Address to get certificates for
     */
    function getCertificatesByOwner(address owner) 
        public 
        view 
        returns (uint256[] memory) 
    {
        return ownerCertificates[owner];
    }
    
    /**
     * @dev Get all certificates for a campaign
     * @param campaignId Campaign ID to get certificates for
     */
    function getCertificatesByCampaign(string memory campaignId) 
        public 
        view 
        returns (uint256[] memory) 
    {
        return campaignCertificates[campaignId];
    }
    
    /**
     * @dev Get certificate details
     * @param tokenId ID of the certificate
     */
    function getCertificate(uint256 tokenId) 
        public 
        view 
        returns (ShareCertificate memory) 
    {
        require(_ownerOf(tokenId) != address(0), "Certificate does not exist");
        return certificates[tokenId];
    }
    
    /**
     * @dev Set authorized minter
     * @param minter Address to grant minter role
     */
    function setAuthorizedMinter(address minter) public onlyRole(ADMIN_ROLE) {
        _grantRole(MINTER_ROLE, minter);
    }
    
    /**
     * @dev Remove minter authorization
     * @param minter Address to revoke minter role from
     */
    function removeAuthorizedMinter(address minter) public onlyRole(ADMIN_ROLE) {
        _revokeRole(MINTER_ROLE, minter);
    }
    
    /**
     * @dev Update base URI for token metadata
     * @param newBaseURI New base URI
     */
    function setBaseURI(string memory newBaseURI) public onlyRole(ADMIN_ROLE) {
        _baseTokenURI = newBaseURI;
        emit BaseURIUpdated(newBaseURI);
    }
    
    /**
     * @dev Get current token ID counter
     */
    function getCurrentTokenId() public view returns (uint256) {
        return _tokenIdCounter;
    }
    
    /**
     * @dev Override _update to track owner mappings (OZ v5 replacement for _beforeTokenTransfer)
     */
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override returns (address) {
        address from = _ownerOf(tokenId);
        
        if (from != address(0) && to != address(0)) {
            // Remove from previous owner's list
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
    
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }
    
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }
    
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}