const { ethers } = require("hardhat");

async function main() {
  console.log("🚀 Starting CrowdfundChain deployment...");
  
  // Create wallet directly for type 0 transaction support (Polygon Edge compatibility)
  const wallet = new ethers.Wallet(process.env.POLYGON_EDGE_PRIVATE_KEY, ethers.provider);
  console.log("Deploying with account:", wallet.address);
  console.log("Account balance:", ethers.formatEther(await ethers.provider.getBalance(wallet.address)));

  // Configuration
  const PLATFORM_FEE = 250; // 2.5%
  const MIN_VOTING_PERIOD = 86400; // 1 day
  const MAX_VOTING_PERIOD = 604800; // 7 days
  const NFT_NAME = "CrowdfundChain Share Certificate";
  const NFT_SYMBOL = "CFCSC";
  const BASE_TOKEN_URI = "https://api.crowdfundchain.africa/nft/metadata/";

  // Helper function to deploy with type 0 legacy transactions (required for Polygon Edge)
  async function deployContract(name, args = []) {
    const factory = await ethers.getContractFactory(name, wallet);
    const deployTx = await factory.getDeployTransaction(...args);
    
    const nonce = await ethers.provider.getTransactionCount(wallet.address);
    const tx = {
      ...deployTx,
      nonce,
      gasLimit: 5000000,
      gasPrice: ethers.parseUnits("1", "gwei"),
      type: 0 // Force legacy transaction for Polygon Edge
    };
    
    const signedTx = await wallet.signTransaction(tx);
    const response = await ethers.provider.broadcastTransaction(signedTx);
    const receipt = await response.wait();
    
    return new ethers.Contract(receipt.contractAddress, factory.interface, wallet);
  }

  // Helper to send type 0 transaction
  async function sendTx(contract, method, args = []) {
    const data = contract.interface.encodeFunctionData(method, args);
    const nonce = await ethers.provider.getTransactionCount(wallet.address);
    
    const tx = {
      to: await contract.getAddress(),
      data,
      nonce,
      gasLimit: 500000,
      gasPrice: ethers.parseUnits("1", "gwei"),
      type: 0
    };
    
    const signedTx = await wallet.signTransaction(tx);
    const response = await ethers.provider.broadcastTransaction(signedTx);
    return response.wait();
  }

  console.log("\n📜 Deploying contracts...");

  // 1. Deploy NFT Share Certificate contract
  console.log("1. Deploying NFTShareCertificate...");
  const nftContract = await deployContract("NFTShareCertificate", [NFT_NAME, NFT_SYMBOL, BASE_TOKEN_URI]);
  console.log("✅ NFTShareCertificate deployed to:", await nftContract.getAddress());

  // 2. Deploy DAO Governance contract
  console.log("2. Deploying DAOGovernance...");
  const daoContract = await deployContract("DAOGovernance", [
    await nftContract.getAddress(),
    MIN_VOTING_PERIOD,
    MAX_VOTING_PERIOD
  ]);
  console.log("✅ DAOGovernance deployed to:", await daoContract.getAddress());

  // 3. Deploy Campaign Implementation (template)
  console.log("3. Deploying CampaignImplementation...");
  const implementationContract = await deployContract("CampaignImplementation", []);
  console.log("✅ CampaignImplementation deployed to:", await implementationContract.getAddress());

  // 4. Deploy Campaign Factory
  console.log("4. Deploying CampaignFactory...");
  const factoryContract = await deployContract("CampaignFactory", [
    await nftContract.getAddress(),
    await daoContract.getAddress(),
    PLATFORM_FEE
  ]);
  console.log("✅ CampaignFactory deployed to:", await factoryContract.getAddress());

  // 4.5. Set implementation contract on factory
  console.log("4.5. Setting implementation contract...");
  await sendTx(factoryContract, "setImplementation", [await implementationContract.getAddress()]);
  console.log("✅ Implementation set on CampaignFactory");

  // 5. Set up permissions
  console.log("\n🔐 Setting up permissions...");
  const MINTER_ROLE = await nftContract.MINTER_ROLE();
  await sendTx(nftContract, "grantRole", [MINTER_ROLE, await factoryContract.getAddress()]);
  console.log("✅ Granted MINTER_ROLE to CampaignFactory");

  // 6. Create sample campaign for testing
  console.log("\n🎯 Creating sample campaign...");
  const createCampaignData = factoryContract.interface.encodeFunctionData("createCampaign", [
    "ETH-COFFEE-001",
    "Ethiopian Premium Coffee Export",
    "Exporting premium Ethiopian coffee beans to international markets with blockchain-verified supply chain tracking",
    ethers.parseEther("50"),
    86400 * 60,
    "QmSampleDocumentHash123"
  ]);
  
  const campaignNonce = await ethers.provider.getTransactionCount(wallet.address);
  const campaignTx = {
    to: await factoryContract.getAddress(),
    data: createCampaignData,
    nonce: campaignNonce,
    gasLimit: 2000000,
    gasPrice: ethers.parseUnits("1", "gwei"),
    type: 0
  };
  
  const signedCampaignTx = await wallet.signTransaction(campaignTx);
  const campaignResponse = await ethers.provider.broadcastTransaction(signedCampaignTx);
  await campaignResponse.wait();
  
  const sampleCampaignAddress = await factoryContract.getCampaignByID("ETH-COFFEE-001");
  console.log("✅ Sample campaign created at:", sampleCampaignAddress);

  // 7. Display deployment summary
  console.log("\n🎉 Deployment Complete!");
  console.log("======================================");
  console.log("Network:", (await ethers.provider.getNetwork()).name);
  console.log("Chain ID:", (await ethers.provider.getNetwork()).chainId.toString());
  console.log("Deployer:", wallet.address);
  console.log("Platform Fee:", PLATFORM_FEE / 100, "%");
  console.log("\n📋 Contract Addresses:");
  console.log("NFTShareCertificate:", await nftContract.getAddress());
  console.log("DAOGovernance:", await daoContract.getAddress());
  console.log("CampaignImplementation:", await implementationContract.getAddress());
  console.log("CampaignFactory:", await factoryContract.getAddress());
  console.log("Sample Campaign:", sampleCampaignAddress);

  // 8. Export addresses for frontend integration
  const deploymentData = {
    network: (await ethers.provider.getNetwork()).name,
    chainId: (await ethers.provider.getNetwork()).chainId.toString(),
    deployer: wallet.address,
    platformFee: PLATFORM_FEE,
    contracts: {
      NFTShareCertificate: await nftContract.getAddress(),
      DAOGovernance: await daoContract.getAddress(),
      CampaignImplementation: await implementationContract.getAddress(),
      CampaignFactory: await factoryContract.getAddress()
    },
    sampleCampaign: {
      id: "ETH-COFFEE-001",
      address: sampleCampaignAddress
    },
    timestamp: new Date().toISOString()
  };

  const fs = require('fs');
  fs.writeFileSync(
    './deployment-info.json',
    JSON.stringify(deploymentData, null, 2)
  );
  console.log("\n💾 Deployment info saved to deployment-info.json");
  console.log("\n🎯 Ready for production use!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Deployment failed:", error);
    process.exit(1);
  });
