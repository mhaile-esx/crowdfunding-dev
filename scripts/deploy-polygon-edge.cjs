const hre = require("hardhat");
const fs = require('fs');

async function main() {
  console.log("Deploying CrowdfundChain Contracts to Polygon Edge...\n");
  
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying with account:", deployer.address);
  
  const balance = await hre.ethers.provider.getBalance(deployer.address);
  console.log("Account balance:", hre.ethers.formatEther(balance), "ETH\n");
  
  if (balance === 0n) {
    console.error("Error: Deployer account has 0 ETH!");
    process.exit(1);
  }
  
  const deployments = {
    network: "polygon-edge",
    chainId: 100,
    timestamp: new Date().toISOString(),
    deployer: deployer.address,
    contracts: {}
  };
  
  console.log("Deploying NFTShareCertificate...");
  const NFTShareCertificate = await hre.ethers.getContractFactory("NFTShareCertificate");
  const nftCertificate = await NFTShareCertificate.deploy(
    "CrowdfundChain Share Certificate", "CFCSC", "https://api.crowdfundchain.com/metadata/"
  );
  await nftCertificate.waitForDeployment();
  const nftAddress = await nftCertificate.getAddress();
  console.log("NFTShareCertificate deployed to:", nftAddress);
  deployments.contracts.NFTShareCertificate = nftAddress;

  console.log("\nDeploying DAOGovernance...");
  const DAOGovernance = await hre.ethers.getContractFactory("DAOGovernance");
  // Args: (nftAddress, minVotingPeriod, maxVotingPeriod)
  const daoGovernance = await DAOGovernance.deploy(nftAddress, 86400, 604800);
  await daoGovernance.waitForDeployment();
  const daoAddress = await daoGovernance.getAddress();
  console.log("DAOGovernance deployed to:", daoAddress);
  deployments.contracts.DAOGovernance = daoAddress;

  console.log("\nDeploying DeFiYieldPool...");
  const DeFiYieldPool = await hre.ethers.getContractFactory("DeFiYieldPool");
  // Args: (baseYieldRate, compoundingPeriod) - 5% APY = 500 basis points, compound daily = 86400 seconds
  const yieldPool = await DeFiYieldPool.deploy(500, 86400);
  await yieldPool.waitForDeployment();
  const yieldPoolAddress = await yieldPool.getAddress();
  console.log("DeFiYieldPool deployed to:", yieldPoolAddress);
  deployments.contracts.DeFiYieldPool = yieldPoolAddress;

  console.log("\nDeploying FundEscrow...");
  const FundEscrow = await hre.ethers.getContractFactory("FundEscrow");
  // Args: (platformWallet, yieldPoolAddress)
  const fundEscrow = await FundEscrow.deploy(deployer.address, yieldPoolAddress);
  await fundEscrow.waitForDeployment();
  const escrowAddress = await fundEscrow.getAddress();
  console.log("FundEscrow deployed to:", escrowAddress);
  deployments.contracts.FundEscrow = escrowAddress;

  console.log("\nDeploying CampaignFactory...");
  const CampaignFactory = await hre.ethers.getContractFactory("CampaignFactory");
  // Args: (nftAddress, daoAddress, platformFee in basis points)
  const campaignFactory = await CampaignFactory.deploy(nftAddress, daoAddress, 250);
  await campaignFactory.waitForDeployment();
  const factoryAddress = await campaignFactory.getAddress();
  console.log("CampaignFactory deployed to:", factoryAddress);
  deployments.contracts.CampaignFactory = factoryAddress;
  
  fs.writeFileSync('deployments-polygon-edge.json', JSON.stringify(deployments, null, 2));
  
  console.log("\n=== Deployment Complete! ===");
  console.log("\nContract Addresses:");
  for (const [name, address] of Object.entries(deployments.contracts)) {
    console.log(`  ${name}: ${address}`);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
