// Blockchain network configuration
export interface BlockchainNetwork {
  name: string;
  chainId: number;
  rpcUrl: string;
  blockExplorer?: string;
  nativeCurrency: {
    name: string;
    symbol: string;
    decimals: number;
  };
}

export const NETWORKS: Record<string, BlockchainNetwork> = {
  // Local development (private Polygon network)
  local: {
    name: "CrowdfundChain Local",
    chainId: 1337,
    rpcUrl: import.meta.env.VITE_BLOCKCHAIN_RPC_URL || "http://localhost:8545",
    nativeCurrency: {
      name: "Ethereum",
      symbol: "ETH",
      decimals: 18,
    },
  },
  
  // Polygon Mumbai testnet
  mumbai: {
    name: "Polygon Mumbai",
    chainId: 80001,
    rpcUrl: "https://rpc-mumbai.maticvigil.com",
    blockExplorer: "https://mumbai.polygonscan.com",
    nativeCurrency: {
      name: "MATIC",
      symbol: "MATIC",
      decimals: 18,
    },
  },
  
  // Polygon mainnet
  polygon: {
    name: "Polygon Mainnet",
    chainId: 137,
    rpcUrl: "https://polygon-rpc.com",
    blockExplorer: "https://polygonscan.com",
    nativeCurrency: {
      name: "MATIC",
      symbol: "MATIC",
      decimals: 18,
    },
  },
};

// Get active network from environment
export function getActiveNetwork(): BlockchainNetwork {
  const env = import.meta.env.VITE_BLOCKCHAIN_NETWORK || process.env.BLOCKCHAIN_NETWORK || "local";
  return NETWORKS[env] || NETWORKS.local;
}

// Contract addresses (updated after deployment)
export const CONTRACT_ADDRESSES = {
  local: {
    campaignFactory: "",
    campaignManager: "",
    issuerRegistry: "",
    fundEscrow: "",
    nftShareCertificate: "",
    daoGovernance: "",
  },
  mumbai: {
    campaignFactory: "",
    campaignManager: "",
    issuerRegistry: "",
    fundEscrow: "",
    nftShareCertificate: "",
    daoGovernance: "",
  },
  polygon: {
    campaignFactory: "",
    campaignManager: "",
    issuerRegistry: "",
    fundEscrow: "",
    nftShareCertificate: "",
    daoGovernance: "",
  },
};

export function getContractAddresses() {
  const network = getActiveNetwork();
  const networkKey = network.chainId === 1337 ? "local" : network.chainId === 80001 ? "mumbai" : "polygon";
  return CONTRACT_ADDRESSES[networkKey];
}

// Gas price settings
export const GAS_SETTINGS = {
  local: {
    gasPrice: "20000000000", // 20 gwei
    gasLimit: 5000000,
  },
  mumbai: {
    gasPrice: "30000000000", // 30 gwei
    gasLimit: 8000000,
  },
  polygon: {
    gasPrice: "50000000000", // 50 gwei
    gasLimit: 10000000,
  },
};

export function getGasSettings() {
  const network = getActiveNetwork();
  const networkKey = network.chainId === 1337 ? "local" : network.chainId === 80001 ? "mumbai" : "polygon";
  return GAS_SETTINGS[networkKey];
}

// Blockchain configuration constants
export const BLOCKCHAIN_CONFIG = {
  // Confirmation blocks required for transaction finality
  CONFIRMATION_BLOCKS: {
    local: 1,
    mumbai: 3,
    polygon: 12,
  },
  
  // Block time in seconds
  BLOCK_TIME: {
    local: 2,
    mumbai: 2,
    polygon: 2,
  },
  
  // Transaction retry settings
  MAX_RETRIES: 3,
  RETRY_DELAY_MS: 5000,
  
  // Event sync settings
  SYNC_BATCH_SIZE: 1000, // blocks per sync batch
  SYNC_INTERVAL_MS: 10000, // 10 seconds
  
  // Campaign success threshold (75%)
  SUCCESS_THRESHOLD: 75,
  
  // Investment limits (in ETH/MATIC)
  MIN_INVESTMENT: "0.01",
  MAX_INVESTMENT: "1000",
};
