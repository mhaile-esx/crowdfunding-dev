// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Custom error definitions for gas-efficient error handling

// NFT Share Certificate Errors
error InvalidAddress();
error EmptyCampaignId();
error EmptyCompanyName();
error InvalidInvestmentAmount();
error InvalidShareCount();
error CertificateNotFound();
error CertificateAlreadyRevoked();
error UnauthorizedMinter();

// DAO Governance Errors
error InsufficientProposalFee();
error EmptyTitle();
error EmptyDescription();
error InvalidVotingPeriod();
error InsufficientVotingPower();
error ProposalNotActive();
error VotingPeriodEnded();
error AlreadyVoted();
error NoVotingPower();
error InvalidProposalId();
error VotingPeriodNotEnded();
error ProposalAlreadyExecuted();
error QuorumNotReached();
error ProposalFailed();

// Campaign Factory Errors
error InvalidDuration();
error CampaignIdExists();
error ImplementationNotSet();
error CampaignNotActive();
error InvalidFeePercentage();
error InvalidRecipient();

// Campaign Implementation Errors
error InvalidCreator();
error InvalidFundingGoal();
error InvalidDeadline();
error CampaignEnded();
error CampaignCompleted();
error CreatorCannotInvest();
error InvalidInvestor();
error EmptyPaymentMethod();
error EmptyTransactionHash();
error FundsAlreadyReleased();
error SuccessThresholdNotMet();
error CampaignNotCompleted();
error CampaignWasSuccessful();
error NoInvestmentToRefund();
error InsufficientContractBalance();

// DeFi Pool Errors
error InvalidCampaignId();
error PoolNotActive();

// General Errors
error ZeroAddress();
error Unauthorized();
error Paused();
error NotPaused();
error ReentrancyDetected();
error TransferFailed();
error InvalidAmount();
error InvalidParameters();