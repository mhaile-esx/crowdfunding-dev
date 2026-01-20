require('@nomicfoundation/hardhat-toolbox');

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: '0.8.20',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      },
      viaIR: true
    }
  },
  networks: {
    hardhat: {
      chainId: 100,
      accounts: {
        mnemonic: process.env.MNEMONIC || 'test test test test test test test test test test test junk',
        count: 10
      }
    },
    localhost: {
      url: 'http://127.0.0.1:8546',
      chainId: 100
    },
    'polygon-edge': {
      url: process.env.POLYGON_EDGE_RPC_URL || 'http://localhost:8546',
      chainId: 100,
      accounts: process.env.POLYGON_EDGE_PRIVATE_KEY ? [process.env.POLYGON_EDGE_PRIVATE_KEY] : [],
      gas: 10000000,
      gasPrice: 0
    }
  },
  paths: {
    sources: './smart-contracts/contracts',
    tests: './test',
    cache: './cache',
    artifacts: './artifacts'
  },
  mocha: {
    timeout: 60000
  }
};
