// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./NFTShareCertificate.sol";

/**
 * @title DAOGovernance
 * @dev Decentralized governance system for CrowdfundChain platform
 * Uses NFT share certificates for voting power calculation
 */
contract DAOGovernance is AccessControl, ReentrancyGuard {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    
    NFTShareCertificate public immutable nftContract;
    
    uint256 private _proposalIdCounter;
    
    enum ProposalType { CAMPAIGN, PLATFORM, TREASURY, GOVERNANCE }
    enum ProposalStatus { PENDING, ACTIVE, EXECUTED, CANCELLED, FAILED }
    
    struct Proposal {
        uint256 id;
        address proposer;
        ProposalType proposalType;
        string title;
        string description;
        string targetAddress;
        uint256 amount;
        bytes data;
        uint256 startTime;
        uint256 endTime;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 quorum;
        ProposalStatus status;
        bool executed;
        mapping(address => bool) hasVoted;
        mapping(address => bool) voteChoice; // true = for, false = against
    }
    
    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256[]) public userProposals;
    
    uint256 public minVotingPeriod = 86400; // 1 day
    uint256 public maxVotingPeriod = 604800; // 7 days
    uint256 public defaultQuorum = 1000; // Minimum voting power required
    uint256 public proposalFee = 0.1 ether; // Fee to create proposal
    
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        ProposalType proposalType,
        string title,
        uint256 startTime,
        uint256 endTime
    );
    
    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        bool support,
        uint256 votingPower
    );
    
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCancelled(uint256 indexed proposalId);
    event QuorumUpdated(uint256 newQuorum);
    event VotingPeriodUpdated(uint256 newMinPeriod, uint256 newMaxPeriod);
    
    constructor(
        address nftContractAddress,
        uint256 minVotingPeriod_,
        uint256 maxVotingPeriod_
    ) {
        require(nftContractAddress != address(0), "Invalid NFT contract address");
        
        nftContract = NFTShareCertificate(nftContractAddress);
        minVotingPeriod = minVotingPeriod_;
        maxVotingPeriod = maxVotingPeriod_;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(PROPOSER_ROLE, msg.sender);
    }
    
    /**
     * @dev Create a new governance proposal
     */
    function createProposal(
        ProposalType proposalType,
        string memory title,
        string memory description,
        string memory targetAddress,
        uint256 amount,
        bytes memory data,
        uint256 votingPeriod
    ) public payable nonReentrant returns (uint256) {
        require(msg.value >= proposalFee, "Insufficient proposal fee");
        require(bytes(title).length > 0, "Title required");
        require(bytes(description).length > 0, "Description required");
        require(votingPeriod >= minVotingPeriod && votingPeriod <= maxVotingPeriod, 
                "Invalid voting period");
        
        // Check if user has minimum voting power to create proposals
        uint256 userVotingPower = nftContract.getVotingPower(msg.sender);
        require(userVotingPower >= 100, "Insufficient voting power to create proposal");
        
        _proposalIdCounter++;
        uint256 proposalId = _proposalIdCounter;
        
        Proposal storage proposal = proposals[proposalId];
        proposal.id = proposalId;
        proposal.proposer = msg.sender;
        proposal.proposalType = proposalType;
        proposal.title = title;
        proposal.description = description;
        proposal.targetAddress = targetAddress;
        proposal.amount = amount;
        proposal.data = data;
        proposal.startTime = block.timestamp;
        proposal.endTime = block.timestamp + votingPeriod;
        proposal.forVotes = 0;
        proposal.againstVotes = 0;
        proposal.quorum = defaultQuorum;
        proposal.status = ProposalStatus.ACTIVE;
        proposal.executed = false;
        
        userProposals[msg.sender].push(proposalId);
        
        emit ProposalCreated(
            proposalId,
            msg.sender,
            proposalType,
            title,
            proposal.startTime,
            proposal.endTime
        );
        
        return proposalId;
    }
    
    /**
     * @dev Cast a vote on a proposal
     */
    function vote(uint256 proposalId, bool support) public nonReentrant {
        require(proposalId <= _proposalIdCounter, "Invalid proposal ID");
        
        Proposal storage proposal = proposals[proposalId];
        require(proposal.status == ProposalStatus.ACTIVE, "Proposal not active");
        require(block.timestamp <= proposal.endTime, "Voting period ended");
        require(!proposal.hasVoted[msg.sender], "Already voted");
        
        uint256 votingPower = nftContract.getVotingPower(msg.sender);
        require(votingPower > 0, "No voting power");
        
        proposal.hasVoted[msg.sender] = true;
        proposal.voteChoice[msg.sender] = support;
        
        if (support) {
            proposal.forVotes += votingPower;
        } else {
            proposal.againstVotes += votingPower;
        }
        
        emit VoteCast(proposalId, msg.sender, support, votingPower);
    }
    
    /**
     * @dev Execute a proposal if it passes
     */
    function executeProposal(uint256 proposalId) public nonReentrant {
        require(proposalId <= _proposalIdCounter, "Invalid proposal ID");
        
        Proposal storage proposal = proposals[proposalId];
        require(proposal.status == ProposalStatus.ACTIVE, "Proposal not active");
        require(block.timestamp > proposal.endTime, "Voting period not ended");
        require(!proposal.executed, "Proposal already executed");
        
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes;
        require(totalVotes >= proposal.quorum, "Quorum not reached");
        require(proposal.forVotes > proposal.againstVotes, "Proposal failed");
        
        proposal.executed = true;
        proposal.status = ProposalStatus.EXECUTED;
        
        // Execute the proposal based on type
        if (proposal.proposalType == ProposalType.TREASURY && proposal.amount > 0) {
            // Transfer funds from treasury
            payable(proposal.proposer).transfer(proposal.amount);
        }
        
        emit ProposalExecuted(proposalId);
    }
    
    /**
     * @dev Cancel a proposal (admin only)
     */
    function cancelProposal(uint256 proposalId) public onlyRole(ADMIN_ROLE) {
        require(proposalId <= _proposalIdCounter, "Invalid proposal ID");
        
        Proposal storage proposal = proposals[proposalId];
        require(proposal.status == ProposalStatus.ACTIVE, "Proposal not active");
        
        proposal.status = ProposalStatus.CANCELLED;
        
        emit ProposalCancelled(proposalId);
    }
    
    /**
     * @dev Get proposal details
     */
    function getProposal(uint256 proposalId) public view returns (
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
    ) {
        require(proposalId <= _proposalIdCounter, "Invalid proposal ID");
        
        Proposal storage proposal = proposals[proposalId];
        
        return (
            proposal.id,
            proposal.proposer,
            proposal.proposalType,
            proposal.title,
            proposal.description,
            proposal.targetAddress,
            proposal.amount,
            proposal.startTime,
            proposal.endTime,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.quorum,
            proposal.status,
            proposal.executed
        );
    }
    
    /**
     * @dev Check if user has voted on a proposal
     */
    function hasVoted(uint256 proposalId, address voter) public view returns (bool) {
        return proposals[proposalId].hasVoted[voter];
    }
    
    /**
     * @dev Get user's vote choice on a proposal
     */
    function getVoteChoice(uint256 proposalId, address voter) public view returns (bool) {
        require(proposals[proposalId].hasVoted[voter], "User has not voted");
        return proposals[proposalId].voteChoice[voter];
    }
    
    /**
     * @dev Get proposals created by a user
     */
    function getUserProposals(address user) public view returns (uint256[] memory) {
        return userProposals[user];
    }
    
    /**
     * @dev Get current proposal ID counter
     */
    function getCurrentProposalId() public view returns (uint256) {
        return _proposalIdCounter;
    }
    
    /**
     * @dev Update quorum requirement
     */
    function updateQuorum(uint256 newQuorum) public onlyRole(ADMIN_ROLE) {
        defaultQuorum = newQuorum;
        emit QuorumUpdated(newQuorum);
    }
    
    /**
     * @dev Update voting period limits
     */
    function updateVotingPeriod(uint256 newMinPeriod, uint256 newMaxPeriod) 
        public 
        onlyRole(ADMIN_ROLE) 
    {
        require(newMinPeriod < newMaxPeriod, "Invalid period range");
        minVotingPeriod = newMinPeriod;
        maxVotingPeriod = newMaxPeriod;
        emit VotingPeriodUpdated(newMinPeriod, newMaxPeriod);
    }
    
    /**
     * @dev Update proposal fee
     */
    function updateProposalFee(uint256 newFee) public onlyRole(ADMIN_ROLE) {
        proposalFee = newFee;
    }
    
    /**
     * @dev Grant proposer role
     */
    function grantProposerRole(address account) public onlyRole(ADMIN_ROLE) {
        _grantRole(PROPOSER_ROLE, account);
    }
    
    /**
     * @dev Revoke proposer role
     */
    function revokeProposerRole(address account) public onlyRole(ADMIN_ROLE) {
        _revokeRole(PROPOSER_ROLE, account);
    }
    
    /**
     * @dev Withdraw contract balance (admin only)
     */
    function withdraw() public onlyRole(ADMIN_ROLE) {
        payable(msg.sender).transfer(address(this).balance);
    }
    
    /**
     * @dev Receive ETH deposits
     */
    receive() external payable {}
}