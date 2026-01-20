// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ICrowdfundChain Interface Collection
 * @dev Interface definitions for all CrowdfundChain smart contracts
 */

interface INFTShareCertificate {
    struct ShareCertificate {
        string campaignId;
        string companyName;
        uint256 investmentAmount;
        uint256 shareCount;
        uint256 votingPower;
        uint256 issuedAt;
        bool isActive;
    }
    
    function issueCertificate(
        address to,
        string memory campaignId,
        string memory companyName,
        uint256 investmentAmount,
        uint256 shareCount,
        string memory tokenURI
    ) external returns (uint256);
    
    function getVotingPower(address owner) external view returns (uint256);
    function getCertificatesByOwner(address owner) external view returns (uint256[] memory);
    function getCertificate(uint256 tokenId) external view returns (ShareCertificate memory);
    function revokeCertificate(uint256 tokenId, string memory reason) external;
}

interface IDAOGovernance {
    enum ProposalType { CAMPAIGN, PLATFORM, TREASURY, GOVERNANCE }
    enum ProposalStatus { PENDING, ACTIVE, EXECUTED, CANCELLED, FAILED }
    
    function createProposal(
        ProposalType proposalType,
        string memory title,
        string memory description,
        string memory targetAddress,
        uint256 amount,
        bytes memory data,
        uint256 votingPeriod
    ) external payable returns (uint256);
    
    function vote(uint256 proposalId, bool support) external;
    function executeProposal(uint256 proposalId) external;
    
    function getProposal(uint256 proposalId) external view returns (
        uint256 id,
        address proposer,
        ProposalType proposalType,
        string memory title,
        string memory description,
        string memory targetAddress,
        uint256 amount,
        uint256 startTime,
        uint256 endTime,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 quorum,
        ProposalStatus status,
        bool executed
    );
}

interface ICampaignFactory {
    function createCampaign(
        string memory campaignId,
        string memory companyName,
        string memory description,
        uint256 fundingGoal,
        uint256 duration,
        string memory documentHash
    ) external returns (address);
    
    function completeCampaign(address campaignAddress) external;
    function getCampaignByID(string memory campaignId) external view returns (address);
    function getAllCampaigns() external view returns (address[] memory);
    
    function getCampaignStats() external view returns (
        uint256 totalCampaigns,
        uint256 activeCampaigns,
        uint256 completedCampaigns,
        uint256 totalRaised
    );
}

interface ICampaignImplementation {
    struct Investment {
        address investor;
        uint256 amount;
        uint256 timestamp;
        string paymentMethod;
        string transactionHash;
        bool refunded;
    }
    
    function investCrypto() external payable;
    
    function recordInvestment(
        address investor,
        uint256 amount,
        string memory paymentMethod,
        string memory transactionHash
    ) external;
    
    function completeCampaign() external;
    function requestRefund() external;
    
    function getCampaignDetails() external view returns (
        address creator,
        string memory campaignId,
        string memory companyName,
        string memory description,
        uint256 fundingGoal,
        uint256 deadline,
        uint256 totalRaised,
        bool completed,
        bool fundsReleased
    );
    
    function getInvestors() external view returns (address[] memory);
    function getInvestmentAmount(address investor) external view returns (uint256);
    function isSuccessful() external view returns (bool);
    function isCompleted() external view returns (bool);
    function getProgressPercentage() external view returns (uint256);
}