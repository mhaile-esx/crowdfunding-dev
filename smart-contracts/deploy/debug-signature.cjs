const { ethers } = require("hardhat");

async function main() {
  console.log("🔍 Testing type 0 legacy transaction for Polygon Edge...\n");
  
  const network = await ethers.provider.getNetwork();
  console.log("Network chainId:", network.chainId.toString());
  
  const wallet = new ethers.Wallet(process.env.POLYGON_EDGE_PRIVATE_KEY, ethers.provider);
  console.log("Wallet address:", wallet.address);
  console.log("Balance:", ethers.formatEther(await ethers.provider.getBalance(wallet.address)));
  
  const nonce = await ethers.provider.getTransactionCount(wallet.address);
  console.log("Current nonce:", nonce);
  
  console.log("\n📤 Sending type 0 legacy transaction...");
  
  try {
    const rawTx = {
      to: wallet.address,
      value: 0,
      gasLimit: 21000,
      gasPrice: ethers.parseUnits("1", "gwei"),
      nonce: nonce,
      type: 0  // Force legacy transaction type for Polygon Edge
    };
    
    const signed = await wallet.signTransaction(rawTx);
    console.log("Signed tx prefix:", signed.substring(0, 10));
    console.log("(Should start with 0xf8 for legacy type 0)");
    
    const result = await ethers.provider.send("eth_sendRawTransaction", [signed]);
    console.log("✅ Transaction hash:", result);
  } catch (e) {
    console.log("❌ Error:", e.message);
  }
}

main().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
