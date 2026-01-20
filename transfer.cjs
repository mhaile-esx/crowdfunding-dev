const { ethers } = require("ethers");

async function main() {
  const provider = new ethers.JsonRpcProvider("http://localhost:8545");

  const validatorKey = "0xbbe53e9589af28f4e8495540b7abb56d7e21a5440a874bad2c189e428321c99e";
  const wallet = new ethers.Wallet(validatorKey, provider);
  
  console.log("Validator:", wallet.address);
  console.log("Validator balance:", ethers.formatEther(await provider.getBalance(wallet.address)));

  // Check pending pool - try nonce 0 with HIGHER gas price to replace stuck tx
  const tx = await wallet.sendTransaction({
    to: "0x49065C1C0cFc356313eB67860bD6b697a9317a83",
    value: ethers.parseEther("50000"),
    nonce: 0,
    gasLimit: 21000,
    gasPrice: ethers.parseUnits("10", "gwei"),  // 10x higher to replace
    type: 0
  });

  console.log("TX hash:", tx.hash);
  await tx.wait();
  
  const newBalance = await provider.getBalance("0x49065C1C0cFc356313eB67860bD6b697a9317a83");
  console.log("Deployer new balance:", ethers.formatEther(newBalance));
}

main().catch(console.error);
