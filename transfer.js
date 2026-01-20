const { ethers } = require("ethers");

async function main() {
  const provider = new ethers.JsonRpcProvider("http://localhost:8545");
  
  // Validator key from node1
  const validatorKey = "0xbbe53e9589af28f4e8495540b7abb56d7e21a5440a874bad2c189e428321c99e";
  const wallet = new ethers.Wallet(validatorKey, provider);
  
  console.log("Validator address:", wallet.address);
  console.log("Validator balance:", ethers.formatEther(await provider.getBalance(wallet.address)));
  
  // Transfer to deployer
  const tx = await wallet.sendTransaction({
    to: "0x49065C1C0cFc356313eB67860bD6b697a9317a83",
    value: ethers.parseEther("10000")
  });
  
  console.log("TX hash:", tx.hash);
  await tx.wait();
  console.log("Transfer complete!");
}

main().catch(console.error);
