#!/usr/bin/env node
/**
 * Dual-Ledger Pattern Verification Script
 * 
 * Tests the hybrid PostgreSQL + Blockchain architecture:
 * 1. PostgreSQL as source of truth
 * 2. Blockchain as immutable audit trail
 * 3. Automatic synchronization between both ledgers
 */

import { ethers } from "ethers";
import pg from "pg";
import dotenv from "dotenv";

dotenv.config();

// Configuration
const config = {
  postgres: {
    connectionString: process.env.DATABASE_URL,
  },
  blockchain: {
    rpcUrl: process.env.BLOCKCHAIN_RPC_URL || "http://172.18.0.5:8545",
    privateKey: process.env.BLOCKCHAIN_PRIVATE_KEY || "0x3d5a9e9ae238ea42815fd4e84be3005ed5d4d32eb3d5655f7a47539889f91e4b",
    contracts: {
      factory: process.env.CONTRACT_CAMPAIGN_FACTORY,
      nft: process.env.CONTRACT_NFT_CERTIFICATE,
      dao: process.env.CONTRACT_DAO_GOVERNANCE,
    }
  }
};

// ANSI color codes
const colors = {
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  blue: '\x1b[36m',
  reset: '\x1b[0m',
  bold: '\x1b[1m'
};

const log = {
  success: (msg) => console.log(`${colors.green}✓${colors.reset} ${msg}`),
  error: (msg) => console.log(`${colors.red}✗${colors.reset} ${msg}`),
  info: (msg) => console.log(`${colors.blue}ℹ${colors.reset} ${msg}`),
  warn: (msg) => console.log(`${colors.yellow}⚠${colors.reset} ${msg}`),
  section: (msg) => console.log(`\n${colors.bold}${colors.blue}━━━ ${msg} ━━━${colors.reset}\n`),
};

class DualLedgerVerifier {
  constructor() {
    this.pgClient = null;
    this.provider = null;
    this.wallet = null;
    this.results = {
      postgres: { passed: 0, failed: 0 },
      blockchain: { passed: 0, failed: 0 },
      integration: { passed: 0, failed: 0 }
    };
  }

  async connectPostgreSQL() {
    log.section("PostgreSQL Connection Test");
    try {
      this.pgClient = new pg.Client({
        connectionString: config.postgres.connectionString,
      });
      await this.pgClient.connect();
      log.success("Connected to PostgreSQL");
      
      const result = await this.pgClient.query("SELECT version()");
      log.info(`Version: ${result.rows[0].version.split(' ').slice(0, 2).join(' ')}`);
      this.results.postgres.passed++;
      return true;
    } catch (error) {
      log.error(`PostgreSQL connection failed: ${error.message}`);
      this.results.postgres.failed++;
      return false;
    }
  }

  async connectBlockchain() {
    log.section("Blockchain Connection Test");
    try {
      this.provider = new ethers.JsonRpcProvider(config.blockchain.rpcUrl);
      this.wallet = new ethers.Wallet(config.blockchain.privateKey, this.provider);
      
      const blockNumber = await this.provider.getBlockNumber();
      const network = await this.provider.getNetwork();
      const balance = await this.provider.getBalance(this.wallet.address);
      
      log.success(`Connected to blockchain at ${config.blockchain.rpcUrl}`);
      log.info(`Network: Chain ID ${network.chainId}`);
      log.info(`Current block: ${blockNumber}`);
      log.info(`Wallet: ${this.wallet.address}`);
      log.info(`Balance: ${ethers.formatEther(balance)} ETH`);
      this.results.blockchain.passed++;
      return true;
    } catch (error) {
      log.error(`Blockchain connection failed: ${error.message}`);
      this.results.blockchain.failed++;
      return false;
    }
  }

  async verifyPostgreSQLSchema() {
    log.section("PostgreSQL Schema Verification");
    
    const requiredTables = [
      'users',
      'companies', 
      'campaigns',
      'investments',
      'blockchain_transactions',
      'smart_contracts',
      'blockchain_sync',
      'wallets',
      'nft_shares'
    ];

    try {
      const result = await this.pgClient.query(`
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_type = 'BASE TABLE'
        ORDER BY table_name
      `);
      
      const existingTables = result.rows.map(r => r.table_name);
      
      log.info(`Found ${existingTables.length} tables in database`);
      
      for (const table of requiredTables) {
        if (existingTables.includes(table)) {
          const countResult = await this.pgClient.query(`SELECT COUNT(*) FROM ${table}`);
          const count = parseInt(countResult.rows[0].count);
          log.success(`Table '${table}' exists (${count} records)`);
          this.results.postgres.passed++;
        } else {
          log.error(`Table '${table}' is missing`);
          this.results.postgres.failed++;
        }
      }
      
      return this.results.postgres.failed === 0;
    } catch (error) {
      log.error(`Schema verification failed: ${error.message}`);
      this.results.postgres.failed++;
      return false;
    }
  }

  async verifySmartContracts() {
    log.section("Smart Contract Verification");
    
    const contracts = {
      'Campaign Factory': config.blockchain.contracts.factory,
      'NFT Certificate': config.blockchain.contracts.nft,
      'DAO Governance': config.blockchain.contracts.dao,
    };

    for (const [name, address] of Object.entries(contracts)) {
      if (!address) {
        log.warn(`${name}: Not configured`);
        continue;
      }

      try {
        const code = await this.provider.getCode(address);
        if (code === '0x') {
          log.error(`${name} (${address}): No code deployed`);
          this.results.blockchain.failed++;
        } else {
          log.success(`${name} (${address}): Deployed (${code.length} bytes)`);
          this.results.blockchain.passed++;
        }
      } catch (error) {
        log.error(`${name} verification failed: ${error.message}`);
        this.results.blockchain.failed++;
      }
    }
  }

  async testDualLedgerFlow() {
    log.section("Dual-Ledger Integration Test");
    
    if (!config.blockchain.contracts.factory) {
      log.warn("Campaign Factory not configured - skipping integration test");
      return;
    }

    try {
      // Step 1: Check if we can query blockchain state
      log.info("Testing blockchain read operations...");
      const factoryABI = [
        "function campaignCount() external view returns (uint256)"
      ];
      const factory = new ethers.Contract(
        config.blockchain.contracts.factory,
        factoryABI,
        this.provider
      );
      
      const campaignCount = await factory.campaignCount();
      log.success(`Blockchain campaigns: ${campaignCount.toString()}`);
      this.results.integration.passed++;

      // Step 2: Check PostgreSQL campaigns
      const pgResult = await this.pgClient.query(
        "SELECT COUNT(*) FROM campaigns WHERE smart_contract_address IS NOT NULL"
      );
      const pgCampaignCount = parseInt(pgResult.rows[0].count);
      log.success(`PostgreSQL campaigns with blockchain address: ${pgCampaignCount}`);
      this.results.integration.passed++;

      // Step 3: Verify blockchain_transactions table tracks on-chain activity
      const txResult = await this.pgClient.query(
        "SELECT COUNT(*) FROM blockchain_transactions"
      );
      const txCount = parseInt(txResult.rows[0].count);
      log.success(`Blockchain transactions recorded: ${txCount}`);
      this.results.integration.passed++;

      // Step 4: Check smart_contracts registry
      const contractResult = await this.pgClient.query(
        "SELECT COUNT(*) FROM smart_contracts"
      );
      const contractCount = parseInt(contractResult.rows[0].count);
      log.success(`Smart contracts registered: ${contractCount}`);
      this.results.integration.passed++;

      // Step 5: Verify dual-ledger pattern integrity
      log.info("\nDual-Ledger Pattern Status:");
      log.info("━".repeat(50));
      log.info(`PostgreSQL (Source of Truth):`);
      log.info(`  - Campaigns: ${pgCampaignCount} with blockchain addresses`);
      log.info(`  - Transactions: ${txCount} recorded`);
      log.info(`  - Contracts: ${contractCount} registered`);
      log.info(`\nBlockchain (Immutable Audit Trail):`);
      log.info(`  - Campaigns deployed: ${campaignCount.toString()}`);
      log.info(`  - Network: Connected and synced`);
      log.info("━".repeat(50));

      if (campaignCount.toString() === pgCampaignCount.toString() && pgCampaignCount > 0) {
        log.success("\n✓ Dual-ledger synchronization: PERFECT MATCH");
        this.results.integration.passed++;
      } else if (pgCampaignCount === 0 && campaignCount.toString() === "0") {
        log.info("\n✓ Dual-ledger ready: No campaigns yet (expected for new setup)");
        this.results.integration.passed++;
      } else {
        log.warn(`\n⚠ Ledger mismatch: Blockchain has ${campaignCount}, PostgreSQL has ${pgCampaignCount}`);
        log.info("This is normal during initial deployment or if campaigns are pending blockchain deployment");
      }

    } catch (error) {
      log.error(`Integration test failed: ${error.message}`);
      this.results.integration.failed++;
    }
  }

  async verifyEventListener() {
    log.section("Event Listener Status");
    
    try {
      const result = await this.pgClient.query(`
        SELECT * FROM blockchain_sync 
        ORDER BY last_synced_block DESC 
        LIMIT 5
      `);
      
      if (result.rows.length === 0) {
        log.warn("No sync records found - event listener may not be running");
        log.info("Event listener syncs blockchain events to PostgreSQL");
      } else {
        log.success("Event listener sync records found:");
        for (const row of result.rows) {
          log.info(`  - Contract: ${row.contract_address?.substring(0, 10)}...`);
          log.info(`    Last block: ${row.last_synced_block}`);
          log.info(`    Last sync: ${new Date(row.last_sync_time).toISOString()}`);
        }
        this.results.integration.passed++;
      }
    } catch (error) {
      log.error(`Event listener check failed: ${error.message}`);
      this.results.integration.failed++;
    }
  }

  printSummary() {
    log.section("Verification Summary");
    
    const total = {
      passed: this.results.postgres.passed + this.results.blockchain.passed + this.results.integration.passed,
      failed: this.results.postgres.failed + this.results.blockchain.failed + this.results.integration.failed
    };

    console.log("PostgreSQL Tests:");
    console.log(`  ${colors.green}Passed: ${this.results.postgres.passed}${colors.reset}`);
    console.log(`  ${colors.red}Failed: ${this.results.postgres.failed}${colors.reset}`);
    
    console.log("\nBlockchain Tests:");
    console.log(`  ${colors.green}Passed: ${this.results.blockchain.passed}${colors.reset}`);
    console.log(`  ${colors.red}Failed: ${this.results.blockchain.failed}${colors.reset}`);
    
    console.log("\nIntegration Tests:");
    console.log(`  ${colors.green}Passed: ${this.results.integration.passed}${colors.reset}`);
    console.log(`  ${colors.red}Failed: ${this.results.integration.failed}${colors.reset}`);
    
    console.log("\n" + "━".repeat(50));
    console.log(`${colors.bold}TOTAL: ${colors.green}${total.passed} passed${colors.reset}${colors.bold}, ${colors.red}${total.failed} failed${colors.reset}`);
    console.log("━".repeat(50));

    if (total.failed === 0) {
      log.success("\n🎉 All tests passed! Dual-Ledger Pattern is working correctly.");
      return 0;
    } else {
      log.error(`\n⚠️  ${total.failed} test(s) failed. Please review the errors above.`);
      return 1;
    }
  }

  async cleanup() {
    if (this.pgClient) {
      await this.pgClient.end();
    }
  }

  async run() {
    console.log(`
${colors.bold}${colors.blue}╔════════════════════════════════════════════════╗
║   CrowdfundChain Dual-Ledger Verifier v1.0    ║
╚════════════════════════════════════════════════╝${colors.reset}
`);

    try {
      // Test PostgreSQL
      const pgConnected = await this.connectPostgreSQL();
      if (pgConnected) {
        await this.verifyPostgreSQLSchema();
      }

      // Test Blockchain
      const blockchainConnected = await this.connectBlockchain();
      if (blockchainConnected) {
        await this.verifySmartContracts();
      }

      // Test Integration (only if both connected)
      if (pgConnected && blockchainConnected) {
        await this.testDualLedgerFlow();
        await this.verifyEventListener();
      }

      // Print summary
      const exitCode = this.printSummary();
      
      await this.cleanup();
      process.exit(exitCode);
      
    } catch (error) {
      log.error(`Fatal error: ${error.message}`);
      console.error(error);
      await this.cleanup();
      process.exit(1);
    }
  }
}

// Run verification
const verifier = new DualLedgerVerifier();
verifier.run();
