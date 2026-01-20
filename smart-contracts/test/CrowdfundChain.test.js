const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("CrowdfundChain Platform", function () {
  let nftContract, daoContract, factoryContract, implementationContract;
  let owner, creator, investor1, investor2, platformWallet;
  let campaignAddress;

  const PLATFORM_FEE = 250; // 2.5%
  const FUNDING_GOAL = ethers.parseEther("10"); // 10 ETH
  const SUCCESS_THRESHOLD = ethers.parseEther("7.5"); // 75% of goal
  const PROPOSAL_FEE = ethers.parseEther("0.1");
  const MIN_VOTING_PERIOD = 86400; // 1 day
  const MAX_VOTING_PERIOD = 604800; // 7 days

  beforeEach(async function () {
    [owner, creator, investor1, investor2, platformWallet] = await ethers.getSigners();

    // Deploy NFT Share Certificate contract
    const NFTContract = await ethers.getContractFactory("NFTShareCertificate");
    nftContract = await NFTContract.deploy();

    // Deploy DAO Governance contract
    const DAOContract = await ethers.getContractFactory("DAOGovernance");
    daoContract = await DAOContract.deploy(
      await nftContract.getAddress(),
      PROPOSAL_FEE,
      MIN_VOTING_PERIOD,
      MAX_VOTING_PERIOD
    );

    // Deploy Campaign Implementation (template)
    const ImplementationContract = await ethers.getContractFactory("CampaignImplementation");
    implementationContract = await ImplementationContract.deploy();

    // Deploy Campaign Factory
    const FactoryContract = await ethers.getContractFactory("CampaignFactory");
    factoryContract = await FactoryContract.deploy(
      await implementationContract.getAddress(),
      await nftContract.getAddress(),
      await daoContract.getAddress(),
      platformWallet.address,
      PLATFORM_FEE
    );

    // Grant factory permission to mint NFTs
    await nftContract.grantRole(await nftContract.MINTER_ROLE(), await factoryContract.getAddress());
  });

  describe("Campaign Lifecycle", function () {
    it("Should create a campaign successfully", async function () {
      const tx = await factoryContract.connect(creator).createCampaign(
        "CAMPAIGN001",
        "Ethiopian Coffee Co",
        "Premium coffee export business",
        FUNDING_GOAL,
        86400 * 30, // 30 days
        "QmTestHash123"
      );

      await expect(tx).to.emit(factoryContract, "CampaignCreated");
      
      campaignAddress = await factoryContract.getCampaignByID("CAMPAIGN001");
      expect(campaignAddress).to.not.equal(ethers.ZeroAddress);
    });

    it("Should handle crypto investments correctly", async function () {
      await factoryContract.connect(creator).createCampaign(
        "CAMPAIGN001",
        "Ethiopian Coffee Co",
        "Premium coffee export business",
        FUNDING_GOAL,
        86400 * 30,
        "QmTestHash123"
      );

      campaignAddress = await factoryContract.getCampaignByID("CAMPAIGN001");
      const campaign = await ethers.getContractAt("CampaignImplementation", campaignAddress);

      const investmentAmount = ethers.parseEther("3");
      await campaign.connect(investor1).investCrypto({ value: investmentAmount });

      expect(await campaign.getInvestmentAmount(investor1.address)).to.equal(investmentAmount);
      const progress = await campaign.getProgressPercentage();
      expect(progress).to.equal(3000); // 30% in basis points
    });

    it("Should handle traditional payment investments", async function () {
      await factoryContract.connect(creator).createCampaign(
        "CAMPAIGN001",
        "Ethiopian Coffee Co",
        "Premium coffee export business",
        FUNDING_GOAL,
        86400 * 30,
        "QmTestHash123"
      );

      campaignAddress = await factoryContract.getCampaignByID("CAMPAIGN001");
      const campaign = await ethers.getContractAt("CampaignImplementation", campaignAddress);

      const investmentAmount = ethers.parseEther("2");
      await campaign.connect(owner).recordInvestment(
        investor2.address,
        investmentAmount,
        "Telebirr",
        "TXN123456789"
      );

      expect(await campaign.getInvestmentAmount(investor2.address)).to.equal(investmentAmount);
    });

    it("Should complete campaign and issue NFT certificates", async function () {
      await factoryContract.connect(creator).createCampaign(
        "CAMPAIGN001",
        "Ethiopian Coffee Co",
        "Premium coffee export business",
        FUNDING_GOAL,
        86400 * 30,
        "QmTestHash123"
      );

      campaignAddress = await factoryContract.getCampaignByID("CAMPAIGN001");
      const campaign = await ethers.getContractAt("CampaignImplementation", campaignAddress);

      // Invest enough to meet success threshold
      await campaign.connect(investor1).investCrypto({ value: ethers.parseEther("4") });
      await campaign.connect(owner).recordInvestment(
        investor2.address,
        ethers.parseEther("4"),
        "CBE Bank",
        "TXN987654321"
      );

      // Complete the campaign
      await factoryContract.connect(creator).completeCampaign(campaignAddress);

      // Check that campaign is completed
      const [, , , , , , , completed] = await campaign.getCampaignDetails();
      expect(completed).to.be.true;

      // Check NFT certificates were issued
      const investor1Certificates = await nftContract.getCertificatesByOwner(investor1.address);
      const investor2Certificates = await nftContract.getCertificatesByOwner(investor2.address);
      
      expect(investor1Certificates.length).to.equal(1);
      expect(investor2Certificates.length).to.equal(1);

      // Check voting power
      const investor1VotingPower = await nftContract.getVotingPower(investor1.address);
      const investor2VotingPower = await nftContract.getVotingPower(investor2.address);
      
      expect(investor1VotingPower).to.be.greaterThan(0);
      expect(investor2VotingPower).to.be.greaterThan(0);
    });
  });

  describe("DAO Governance", function () {
    beforeEach(async function () {
      // Create campaign and issue certificates for voting power
      await factoryContract.connect(creator).createCampaign(
        "CAMPAIGN001",
        "Ethiopian Coffee Co",
        "Premium coffee export business",
        FUNDING_GOAL,
        86400 * 30,
        "QmTestHash123"
      );

      campaignAddress = await factoryContract.getCampaignByID("CAMPAIGN001");
      const campaign = await ethers.getContractAt("CampaignImplementation", campaignAddress);

      await campaign.connect(investor1).investCrypto({ value: ethers.parseEther("4") });
      await campaign.connect(owner).recordInvestment(
        investor2.address,
        ethers.parseEther("4"),
        "CBE Bank",
        "TXN987654321"
      );

      await factoryContract.connect(creator).completeCampaign(campaignAddress);
    });

    it("Should create governance proposals", async function () {
      const tx = await daoContract.connect(investor1).createProposal(
        0, // CAMPAIGN type
        "New Platform Feature",
        "Implement advanced analytics dashboard",
        "0x0000000000000000000000000000000000000000",
        0,
        "0x",
        MIN_VOTING_PERIOD,
        { value: PROPOSAL_FEE }
      );

      await expect(tx).to.emit(daoContract, "ProposalCreated");
    });

    it("Should allow voting on proposals", async function () {
      await daoContract.connect(investor1).createProposal(
        0, // CAMPAIGN type
        "New Platform Feature",
        "Implement advanced analytics dashboard",
        "0x0000000000000000000000000000000000000000",
        0,
        "0x",
        MIN_VOTING_PERIOD,
        { value: PROPOSAL_FEE }
      );

      const proposalId = 1;
      await daoContract.connect(investor1).vote(proposalId, true);
      await daoContract.connect(investor2).vote(proposalId, true);

      const [, , , , , , , , , forVotes, againstVotes] = await daoContract.getProposal(proposalId);
      expect(forVotes).to.be.greaterThan(0);
      expect(againstVotes).to.equal(0);
    });
  });

  describe("NFT Share Certificates", function () {
    beforeEach(async function () {
      await nftContract.grantRole(await nftContract.MINTER_ROLE(), owner.address);
    });

    it("Should issue certificates with correct voting power", async function () {
      const investmentAmount = ethers.parseEther("5"); // 5 ETH
      await nftContract.issueCertificate(
        investor1.address,
        "CAMPAIGN001",
        "Ethiopian Coffee Co",
        investmentAmount,
        500, // share count
        "ipfs://certificate-metadata"
      );

      const votingPower = await nftContract.getVotingPower(investor1.address);
      expect(votingPower).to.be.greaterThan(0);

      const certificates = await nftContract.getCertificatesByOwner(investor1.address);
      expect(certificates.length).to.equal(1);
    });

    it("Should track certificate details correctly", async function () {
      const investmentAmount = ethers.parseEther("3");
      await nftContract.issueCertificate(
        investor1.address,
        "CAMPAIGN001",
        "Ethiopian Coffee Co",
        investmentAmount,
        300,
        "ipfs://certificate-metadata"
      );

      const certificate = await nftContract.getCertificate(1);
      expect(certificate.campaignId).to.equal("CAMPAIGN001");
      expect(certificate.companyName).to.equal("Ethiopian Coffee Co");
      expect(certificate.investmentAmount).to.equal(investmentAmount);
      expect(certificate.isActive).to.be.true;
    });
  });

  describe("Platform Statistics", function () {
    it("Should track campaign statistics correctly", async function () {
      // Create multiple campaigns
      await factoryContract.connect(creator).createCampaign(
        "CAMPAIGN001",
        "Ethiopian Coffee Co",
        "Coffee export business",
        FUNDING_GOAL,
        86400 * 30,
        "QmTestHash1"
      );

      await factoryContract.connect(creator).createCampaign(
        "CAMPAIGN002",
        "Tech Startup ETH",
        "Fintech solution",
        ethers.parseEther("15"),
        86400 * 45,
        "QmTestHash2"
      );

      const [totalCampaigns, activeCampaigns, completedCampaigns, totalRaised] = 
        await factoryContract.getCampaignStats();

      expect(totalCampaigns).to.equal(2);
      expect(activeCampaigns).to.equal(2);
      expect(completedCampaigns).to.equal(0);
    });
  });

  describe("Security Features", function () {
    it("Should prevent unauthorized minting", async function () {
      await expect(
        nftContract.connect(investor1).issueCertificate(
          investor1.address,
          "CAMPAIGN001",
          "Test Company",
          ethers.parseEther("1"),
          100,
          "ipfs://test"
        )
      ).to.be.reverted;
    });

    it("Should prevent campaign creator from investing", async function () {
      await factoryContract.connect(creator).createCampaign(
        "CAMPAIGN001",
        "Ethiopian Coffee Co",
        "Coffee export business",
        FUNDING_GOAL,
        86400 * 30,
        "QmTestHash1"
      );

      campaignAddress = await factoryContract.getCampaignByID("CAMPAIGN001");
      const campaign = await ethers.getContractAt("CampaignImplementation", campaignAddress);

      await expect(
        campaign.connect(creator).investCrypto({ value: ethers.parseEther("1") })
      ).to.be.reverted;
    });

    it("Should handle refunds for failed campaigns", async function () {
      await factoryContract.connect(creator).createCampaign(
        "CAMPAIGN001",
        "Ethiopian Coffee Co",
        "Coffee export business",
        FUNDING_GOAL,
        1, // Very short duration
        "QmTestHash1"
      );

      campaignAddress = await factoryContract.getCampaignByID("CAMPAIGN001");
      const campaign = await ethers.getContractAt("CampaignImplementation", campaignAddress);

      const investmentAmount = ethers.parseEther("2");
      await campaign.connect(investor1).investCrypto({ value: investmentAmount });

      // Wait for campaign to end
      await ethers.provider.send("evm_increaseTime", [2]);
      await ethers.provider.send("evm_mine");

      const balanceBefore = await ethers.provider.getBalance(investor1.address);
      await campaign.connect(investor1).requestRefund();
      const balanceAfter = await ethers.provider.getBalance(investor1.address);

      expect(balanceAfter).to.be.greaterThan(balanceBefore);
    });
  });
});