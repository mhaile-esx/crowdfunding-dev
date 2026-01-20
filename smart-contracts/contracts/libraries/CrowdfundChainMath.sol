// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title CrowdfundChainMath
 * @dev Mathematical utilities and calculations for the platform
 */

library CrowdfundChainMath {
    uint256 private constant BASIS_POINTS = 10000;
    uint256 private constant ETH_DECIMALS = 18;
    uint256 private constant VOTING_POWER_THRESHOLD = 1000; // 1000 ETB per vote
    
    /**
     * @dev Calculate percentage of a value
     * @param value The base value
     * @param percentage Percentage in basis points (100 = 1%)
     * @return result The calculated percentage
     */
    function calculatePercentage(uint256 value, uint256 percentage) 
        internal 
        pure 
        returns (uint256 result) 
    {
        return (value * percentage) / BASIS_POINTS;
    }
    
    /**
     * @dev Calculate voting power based on investment amount
     * @param investmentAmount Investment amount in Wei
     * @return votingPower Number of votes (minimum 1)
     */
    function calculateVotingPower(uint256 investmentAmount) 
        internal 
        pure 
        returns (uint256 votingPower) 
    {
        // 1 vote per 1000 ETH invested
        votingPower = investmentAmount / (VOTING_POWER_THRESHOLD * 10**ETH_DECIMALS);
        return votingPower == 0 ? 1 : votingPower;
    }
    
    /**
     * @dev Calculate share count based on investment and funding goal
     * @param investmentAmount Investment amount in Wei
     * @param fundingGoal Total funding goal in Wei
     * @param totalShares Total shares available (usually 1000 for 0.1% precision)
     * @return shareCount Number of shares allocated
     */
    function calculateShareCount(
        uint256 investmentAmount,
        uint256 fundingGoal,
        uint256 totalShares
    ) internal pure returns (uint256 shareCount) {
        return (investmentAmount * totalShares) / fundingGoal;
    }
    
    /**
     * @dev Calculate platform fee
     * @param amount Total amount
     * @param feePercent Fee percentage in basis points
     * @return fee Platform fee amount
     */
    function calculatePlatformFee(uint256 amount, uint256 feePercent) 
        internal 
        pure 
        returns (uint256 fee) 
    {
        return calculatePercentage(amount, feePercent);
    }
    
    /**
     * @dev Calculate success threshold (75% of funding goal)
     * @param fundingGoal Total funding goal
     * @return threshold 75% threshold amount
     */
    function calculateSuccessThreshold(uint256 fundingGoal) 
        internal 
        pure 
        returns (uint256 threshold) 
    {
        return calculatePercentage(fundingGoal, 7500); // 75%
    }
    
    /**
     * @dev Calculate progress percentage
     * @param raised Amount raised
     * @param goal Funding goal
     * @return percentage Progress percentage (0-10000 basis points)
     */
    function calculateProgress(uint256 raised, uint256 goal) 
        internal 
        pure 
        returns (uint256 percentage) 
    {
        if (goal == 0) return 0;
        return (raised * BASIS_POINTS) / goal;
    }
    
    /**
     * @dev Check if amount meets minimum investment threshold
     * @param amount Investment amount
     * @return valid True if amount meets minimum
     */
    function isValidInvestmentAmount(uint256 amount) 
        internal 
        pure 
        returns (bool valid) 
    {
        // Minimum investment: 0.01 ETH
        return amount >= 0.01 ether;
    }
    
    /**
     * @dev Calculate time remaining until deadline
     * @param deadline Campaign deadline timestamp
     * @return remaining Time remaining in seconds (0 if expired)
     */
    function calculateTimeRemaining(uint256 deadline) 
        internal 
        view 
        returns (uint256 remaining) 
    {
        if (block.timestamp >= deadline) return 0;
        return deadline - block.timestamp;
    }
    
    /**
     * @dev Check if voting period is valid
     * @param period Voting period in seconds
     * @param minPeriod Minimum allowed period
     * @param maxPeriod Maximum allowed period
     * @return valid True if period is within valid range
     */
    function isValidVotingPeriod(
        uint256 period,
        uint256 minPeriod,
        uint256 maxPeriod
    ) internal pure returns (bool valid) {
        return period >= minPeriod && period <= maxPeriod;
    }
    
    /**
     * @dev Calculate weighted voting result
     * @param forVotes Votes in favor
     * @param againstVotes Votes against
     * @param quorum Required quorum
     * @return passed True if proposal should pass
     * @return metQuorum True if quorum was met
     */
    function calculateVotingResult(
        uint256 forVotes,
        uint256 againstVotes,
        uint256 quorum
    ) internal pure returns (bool passed, bool metQuorum) {
        uint256 totalVotes = forVotes + againstVotes;
        metQuorum = totalVotes >= quorum;
        passed = metQuorum && forVotes > againstVotes;
    }
    
    /**
     * @dev Safe conversion from Wei to human-readable format
     * @param weiAmount Amount in Wei
     * @param decimals Decimal places for display
     * @return converted Converted amount
     */
    function weiToDisplayAmount(uint256 weiAmount, uint8 decimals) 
        internal 
        pure 
        returns (uint256 converted) 
    {
        return weiAmount / (10**(ETH_DECIMALS - decimals));
    }
    
    /**
     * @dev Safe conversion from human-readable format to Wei
     * @param displayAmount Amount in display format
     * @param decimals Decimal places from display
     * @return converted Amount in Wei
     */
    function displayAmountToWei(uint256 displayAmount, uint8 decimals) 
        internal 
        pure 
        returns (uint256 converted) 
    {
        return displayAmount * (10**(ETH_DECIMALS - decimals));
    }
}