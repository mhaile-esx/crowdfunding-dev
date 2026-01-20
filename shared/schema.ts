import { sql } from "drizzle-orm";
import { relations } from "drizzle-orm";
import { pgTable, text, varchar, integer, boolean, timestamp, decimal, pgEnum, json } from "drizzle-orm/pg-core";
import { createInsertSchema } from "drizzle-zod";
import { z } from "zod";

export const campaignStatusEnum = pgEnum("campaign_status", ["draft", "active", "successful", "failed", "cancelled"]);
export const industrySectorEnum = pgEnum("industry_sector", ["agriculture", "technology", "manufacturing", "healthcare", "education", "retail"]);
export const investorTypeEnum = pgEnum("investor_type", ["retail", "institutional"]);
export const userRoleEnum = pgEnum("user_role", ["admin", "compliance_officer", "custodian", "regulator", "issuer", "investor"]);
export const kycLevelEnum = pgEnum("kyc_level", ["basic", "enhanced", "premium"]);
export const amlRiskEnum = pgEnum("aml_risk", ["low", "medium", "high"]);

export const users = pgTable("users", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  username: text("username").notNull().unique(),
  email: text("email").notNull().unique(),
  fullName: text("full_name").notNull(),
  walletAddress: text("wallet_address"),
  kycVerified: boolean("kyc_verified").default(false),
  investorType: investorTypeEnum("investor_type").default("retail"),
  role: userRoleEnum("role").default("investor"),
  kycLevel: kycLevelEnum("kyc_level").default("basic"),
  amlRiskLevel: amlRiskEnum("aml_risk_level").default("low"),
  complianceScore: integer("compliance_score").default(0),
  lastAmlCheck: timestamp("last_aml_check"),
  metadata: text("metadata"), // JSON string for additional data
  createdAt: timestamp("created_at").defaultNow(),
  updatedAt: timestamp("updated_at").defaultNow(),
});

export const companies = pgTable("companies", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  userId: varchar("user_id").references(() => users.id).notNull(),
  name: text("name").notNull(),
  tinNumber: text("tin_number").notNull().unique(),
  sector: industrySectorEnum("sector").notNull(),
  registrationYear: integer("registration_year"),
  verified: boolean("verified").default(false),
  createdAt: timestamp("created_at").defaultNow(),
});

export const campaigns = pgTable("campaigns", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  companyId: varchar("company_id").references(() => companies.id).notNull(),
  title: text("title").notNull(),
  description: text("description").notNull(),
  fundingGoal: decimal("funding_goal", { precision: 15, scale: 2 }).notNull(),
  currentFunding: decimal("current_funding", { precision: 15, scale: 2 }).default("0"),
  duration: integer("duration").notNull(), // in days
  status: campaignStatusEnum("status").default("draft"),
  startDate: timestamp("start_date"),
  endDate: timestamp("end_date"),
  investorCount: integer("investor_count").default(0),
  successThreshold: decimal("success_threshold", { precision: 5, scale: 2 }).default("75"), // percentage
  documentsHash: text("documents_hash"), // IPFS hash
  smartContractAddress: text("smart_contract_address"),
  createdAt: timestamp("created_at").defaultNow(),
});

export const investments = pgTable("investments", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  campaignId: varchar("campaign_id").references(() => campaigns.id).notNull(),
  userId: varchar("user_id").references(() => users.id).notNull(),
  amount: decimal("amount", { precision: 15, scale: 2 }).notNull(),
  yieldEarned: decimal("yield_earned", { precision: 15, scale: 2 }).default("0"),
  nftTokenId: text("nft_token_id"),
  transactionHash: text("transaction_hash"),
  createdAt: timestamp("created_at").defaultNow(),
});

export const nftShares = pgTable("nft_shares", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  investmentId: varchar("investment_id").references(() => investments.id).notNull(),
  tokenId: text("token_id").notNull(),
  contractAddress: text("contract_address").notNull(),
  metadata: text("metadata"), // JSON string
  votingWeight: decimal("voting_weight", { precision: 10, scale: 6 }),
  createdAt: timestamp("created_at").defaultNow(),
});

// Payment transactions for Ethiopian payment integration
export const payments = pgTable("payments", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  transactionId: text("transaction_id").unique().notNull(),
  campaignId: varchar("campaign_id").references(() => campaigns.id).notNull(),
  amount: decimal("amount", { precision: 15, scale: 2 }).notNull(),
  provider: text("provider").notNull(), // telebirr, cbe, awash, dashen
  phoneNumber: text("phone_number"),
  accountNumber: text("account_number"),
  status: text("status").notNull().default("pending"), // pending, completed, failed
  description: text("description"),
  createdAt: timestamp("created_at").defaultNow(),
  updatedAt: timestamp("updated_at").defaultNow(),
});

// DAO Governance proposals
export const proposals = pgTable("proposals", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  blockchainId: text("blockchain_id").unique(),
  title: text("title").notNull(),
  description: text("description").notNull(),
  campaignId: varchar("campaign_id").references(() => campaigns.id),
  proposer: text("proposer").notNull(), // wallet address
  category: text("category").notNull(), // campaign, platform, treasury, governance
  votesFor: text("votes_for").default("0"),
  votesAgainst: text("votes_against").default("0"),
  votingPowerRequired: text("voting_power_required").default("100"),
  endTime: timestamp("end_time").notNull(),
  executed: boolean("executed").default(false),
  executionHash: text("execution_hash"),
  transactionHash: text("transaction_hash"),
  createdAt: timestamp("created_at").defaultNow(),
});

// DAO Governance votes
export const votes = pgTable("votes", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  proposalId: varchar("proposal_id").references(() => proposals.id).notNull(),
  voter: text("voter").notNull(), // wallet address
  support: boolean("support").notNull(),
  votingPower: text("voting_power").notNull(),
  transactionHash: text("transaction_hash"),
  createdAt: timestamp("created_at").defaultNow(),
});

// RBAC and Compliance Tables
export const userPermissions = pgTable("user_permissions", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  userId: varchar("user_id").references(() => users.id).notNull(),
  permission: text("permission").notNull(),
  grantedBy: varchar("granted_by").references(() => users.id),
  grantedAt: timestamp("granted_at").defaultNow(),
  expiresAt: timestamp("expires_at"),
});

export const auditLogs = pgTable("audit_logs", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  userId: varchar("user_id").references(() => users.id),
  action: text("action").notNull(),
  resource: text("resource").notNull(),
  resourceId: text("resource_id"),
  metadata: text("metadata"), // JSON string
  ipAddress: text("ip_address"),
  userAgent: text("user_agent"),
  timestamp: timestamp("timestamp").defaultNow(),
});





// Insert schemas
export const insertUserSchema = createInsertSchema(users).pick({
  username: true,
  email: true,
  fullName: true,
  walletAddress: true,
  investorType: true,
  role: true,
  kycLevel: true,
  metadata: true,
});

export const insertCompanySchema = createInsertSchema(companies).pick({
  name: true,
  tinNumber: true,
  sector: true,
  registrationYear: true,
});

export const insertCampaignSchema = createInsertSchema(campaigns).pick({
  title: true,
  description: true,
  fundingGoal: true,
  duration: true,
});

export const insertInvestmentSchema = createInsertSchema(investments).pick({
  campaignId: true,
  amount: true,
});

// Types
export type User = typeof users.$inferSelect;
export type InsertUser = z.infer<typeof insertUserSchema>;
export type Company = typeof companies.$inferSelect;
export type InsertCompany = z.infer<typeof insertCompanySchema>;
export type Campaign = typeof campaigns.$inferSelect;
export type InsertCampaign = z.infer<typeof insertCampaignSchema>;
export type Investment = typeof investments.$inferSelect;
export type InsertInvestment = z.infer<typeof insertInvestmentSchema>;
export type NFTShare = typeof nftShares.$inferSelect;
export type Payment = typeof payments.$inferSelect;
export type Proposal = typeof proposals.$inferSelect;
export type Vote = typeof votes.$inferSelect;
export type UserPermission = typeof userPermissions.$inferSelect;
export type AuditLog = typeof auditLogs.$inferSelect;
export type KYCDocument = typeof kycDocuments.$inferSelect;
export type AMLTransaction = typeof amlTransactionMonitoring.$inferSelect;

// Extended types for API responses
export type CampaignWithCompany = Campaign & {
  company: Company;
  progressPercentage: number;
  daysLeft: number;
};

export type InvestmentWithCampaign = Investment & {
  campaign: Campaign & { company: Company };
};

export type UserPortfolio = {
  totalInvested: string;
  activeInvestments: number;
  yieldEarned: string;
  nftShares: number;
  investments: InvestmentWithCampaign[];
};

// Agricultural Extensions
export const agriculturalCampaigns = pgTable("agricultural_campaigns", {
  id: text("id").primaryKey().$defaultFn(() => crypto.randomUUID()),
  campaignId: text("campaign_id").references(() => campaigns.id).notNull(),
  cropType: text("crop_type").notNull(), // coffee, teff, wheat, maize, etc.
  landSizeHectares: decimal("land_size_hectares", { precision: 10, scale: 2 }),
  gpsCoordinates: text("gps_coordinates"), // JSON string with lat/lng
  expectedYieldTons: decimal("expected_yield_tons", { precision: 10, scale: 2 }),
  plantingDate: timestamp("planting_date"),
  expectedHarvestDate: timestamp("expected_harvest_date"),
  farmingMethod: text("farming_method"), // organic, conventional, mixed
  irrigationType: text("irrigation_type"), // rain-fed, irrigated, both
  weatherRiskScore: decimal("weather_risk_score", { precision: 5, scale: 2 }),
  soilQualityRating: text("soil_quality_rating"), // excellent, good, fair, poor
  createdAt: timestamp("created_at").defaultNow().notNull(),
});

export const insuranceCompanies = pgTable("insurance_companies", {
  id: text("id").primaryKey().$defaultFn(() => crypto.randomUUID()),
  name: text("name").notNull(),
  licenseNumber: text("license_number").notNull(),
  contactEmail: text("contact_email").notNull(),
  contactPhone: text("contact_phone"),
  address: text("address"),
  apiEndpoint: text("api_endpoint"),
  isActive: boolean("is_active").default(true),
  createdAt: timestamp("created_at").defaultNow().notNull(),
});

export const insurancePolicies = pgTable("insurance_policies", {
  id: text("id").primaryKey().$defaultFn(() => crypto.randomUUID()),
  campaignId: text("campaign_id").references(() => campaigns.id).notNull(),
  insuranceCompanyId: text("insurance_company_id").references(() => insuranceCompanies.id).notNull(),
  policyType: text("policy_type").notNull(), // weather, yield, price, comprehensive
  coverageAmount: decimal("coverage_amount", { precision: 15, scale: 2 }).notNull(),
  premiumAmount: decimal("premium_amount", { precision: 15, scale: 2 }).notNull(),
  policyStartDate: timestamp("policy_start_date").notNull(),
  policyEndDate: timestamp("policy_end_date").notNull(),
  termsConditions: text("terms_conditions"), // JSON string
  status: text("status").default("active"), // active, expired, claimed, cancelled
  policyNumber: text("policy_number"),
  createdAt: timestamp("created_at").defaultNow().notNull(),
});

export const yieldMonitoring = pgTable("yield_monitoring", {
  id: text("id").primaryKey().$defaultFn(() => crypto.randomUUID()),
  campaignId: text("campaign_id").references(() => campaigns.id).notNull(),
  dataSource: text("data_source").notNull(), // iot, satellite, manual, weather_api
  measurementType: text("measurement_type").notNull(), // soil_moisture, temperature, ndvi, rainfall
  value: decimal("value", { precision: 10, scale: 4 }).notNull(),
  unit: text("unit").notNull(),
  recordedAt: timestamp("recorded_at").notNull(),
  gpsLocation: text("gps_location"), // JSON string with lat/lng
  sensorId: text("sensor_id"),
  notes: text("notes"),
  createdAt: timestamp("created_at").defaultNow().notNull(),
});

export const insuranceClaims = pgTable("insurance_claims", {
  id: text("id").primaryKey().$defaultFn(() => crypto.randomUUID()),
  policyId: text("policy_id").references(() => insurancePolicies.id).notNull(),
  claimType: text("claim_type").notNull(), // weather_damage, pest_damage, yield_shortfall
  claimAmount: decimal("claim_amount", { precision: 15, scale: 2 }).notNull(),
  evidenceDocuments: text("evidence_documents"), // JSON array of document URLs
  claimDate: timestamp("claim_date").notNull(),
  verificationStatus: text("verification_status").default("pending"), // pending, verified, rejected
  payoutAmount: decimal("payout_amount", { precision: 15, scale: 2 }),
  payoutDate: timestamp("payout_date"),
  adjustorNotes: text("adjustor_notes"),
  createdAt: timestamp("created_at").defaultNow().notNull(),
});

// Agricultural insert schemas
export const insertAgriculturalCampaignSchema = createInsertSchema(agriculturalCampaigns).omit({
  id: true,
  createdAt: true,
});

export const insertInsuranceCompanySchema = createInsertSchema(insuranceCompanies).omit({
  id: true,
  createdAt: true,
});

export const insertInsurancePolicySchema = createInsertSchema(insurancePolicies).omit({
  id: true,
  createdAt: true,
});

export const insertYieldMonitoringSchema = createInsertSchema(yieldMonitoring).omit({
  id: true,
  createdAt: true,
});

export const insertInsuranceClaimSchema = createInsertSchema(insuranceClaims).omit({
  id: true,
  createdAt: true,
});

// Agricultural types
export type AgriculturalCampaign = typeof agriculturalCampaigns.$inferSelect;
export type InsuranceCompany = typeof insuranceCompanies.$inferSelect;
export type InsurancePolicy = typeof insurancePolicies.$inferSelect;
export type YieldMonitoring = typeof yieldMonitoring.$inferSelect;
export type InsuranceClaim = typeof insuranceClaims.$inferSelect;

export type InsertAgriculturalCampaign = z.infer<typeof insertAgriculturalCampaignSchema>;
export type InsertInsuranceCompany = z.infer<typeof insertInsuranceCompanySchema>;
export type InsertInsurancePolicy = z.infer<typeof insertInsurancePolicySchema>;
export type InsertYieldMonitoring = z.infer<typeof insertYieldMonitoringSchema>;
export type InsertInsuranceClaim = z.infer<typeof insertInsuranceClaimSchema>;

// Agricultural relations
export const agriculturalCampaignsRelations = relations(agriculturalCampaigns, ({ one, many }) => ({
  campaign: one(campaigns, {
    fields: [agriculturalCampaigns.campaignId],
    references: [campaigns.id],
  }),
  yieldData: many(yieldMonitoring),
}));

export const insuranceCompaniesRelations = relations(insuranceCompanies, ({ many }) => ({
  policies: many(insurancePolicies),
}));

export const insurancePoliciesRelations = relations(insurancePolicies, ({ one, many }) => ({
  campaign: one(campaigns, {
    fields: [insurancePolicies.campaignId],
    references: [campaigns.id],
  }),
  insuranceCompany: one(insuranceCompanies, {
    fields: [insurancePolicies.insuranceCompanyId],
    references: [insuranceCompanies.id],
  }),
  claims: many(insuranceClaims),
}));

export const yieldMonitoringRelations = relations(yieldMonitoring, ({ one }) => ({
  campaign: one(campaigns, {
    fields: [yieldMonitoring.campaignId],
    references: [campaigns.id],
  }),
  agriculturalCampaign: one(agriculturalCampaigns, {
    fields: [yieldMonitoring.campaignId],
    references: [agriculturalCampaigns.campaignId],
  }),
}));

export const insuranceClaimsRelations = relations(insuranceClaims, ({ one }) => ({
  policy: one(insurancePolicies, {
    fields: [insuranceClaims.policyId],
    references: [insurancePolicies.id],
  }),
}));

// Blockchain Integration Tables

// Blockchain transactions tracking for dual-ledger system
export const blockchainTransactions = pgTable("blockchain_transactions", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  txHash: text("tx_hash").notNull().unique(),
  blockNumber: text("block_number"),
  fromAddress: text("from_address").notNull(),
  toAddress: text("to_address").notNull(),
  amount: decimal("amount", { precision: 30, scale: 18 }), // Support ETH precision
  gasUsed: text("gas_used"),
  gasPrice: text("gas_price"),
  status: text("status").notNull().default("pending"), // pending, confirmed, failed
  contractAddress: text("contract_address"),
  methodName: text("method_name"), // createCampaign, invest, releaseFunds, etc.
  metadata: text("metadata"), // JSON string with additional data
  relatedEntityType: text("related_entity_type"), // campaign, investment, payment
  relatedEntityId: varchar("related_entity_id"),
  createdAt: timestamp("created_at").defaultNow(),
  confirmedAt: timestamp("confirmed_at"),
});

// Smart contract deployments registry
export const smartContracts = pgTable("smart_contracts", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  contractType: text("contract_type").notNull(), // escrow, nft, governance, registry
  contractAddress: text("contract_address").notNull().unique(),
  deploymentTxHash: text("deployment_tx_hash").notNull(),
  abi: text("abi").notNull(), // JSON string of contract ABI
  version: text("version").notNull(),
  networkId: integer("network_id").notNull(), // 137 for Polygon, 1337 for local
  deployedBy: varchar("deployed_by").references(() => users.id),
  isActive: boolean("is_active").default(true),
  metadata: text("metadata"), // JSON string
  createdAt: timestamp("created_at").defaultNow(),
});

// Blockchain synchronization state
export const blockchainSync = pgTable("blockchain_sync", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  contractAddress: text("contract_address").notNull(),
  eventType: text("event_type").notNull(), // CampaignCreated, InvestmentMade, FundsReleased
  lastSyncedBlock: text("last_synced_block").notNull(),
  lastSyncedAt: timestamp("last_synced_at").notNull(),
  syncStatus: text("sync_status").default("active"), // active, paused, error
  errorMessage: text("error_message"),
  updatedAt: timestamp("updated_at").defaultNow(),
});

// IPFS document storage tracking
export const ipfsDocuments = pgTable("ipfs_documents", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  ipfsHash: text("ipfs_hash").notNull().unique(),
  documentType: text("document_type").notNull(), // campaign_doc, kyc, compliance, prospectus
  fileName: text("file_name").notNull(),
  fileSize: integer("file_size"), // in bytes
  mimeType: text("mime_type"),
  relatedEntityType: text("related_entity_type"), // campaign, user, company
  relatedEntityId: varchar("related_entity_id"),
  uploadedBy: varchar("uploaded_by").references(() => users.id),
  encryptionKey: text("encryption_key"), // For encrypted documents
  metadata: text("metadata"), // JSON string
  createdAt: timestamp("created_at").defaultNow(),
});

// Wallet management for users
export const wallets = pgTable("wallets", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  userId: varchar("user_id").references(() => users.id).notNull(),
  address: text("address").notNull().unique(),
  walletType: text("wallet_type").notNull(), // metamask, walletconnect, custodial
  isDefault: boolean("is_default").default(false),
  balance: decimal("balance", { precision: 30, scale: 18 }).default("0"),
  lastBalanceCheck: timestamp("last_balance_check"),
  metadata: text("metadata"), // JSON string
  createdAt: timestamp("created_at").defaultNow(),
  updatedAt: timestamp("updated_at").defaultNow(),
});

// Blockchain insert schemas
export const insertBlockchainTransactionSchema = createInsertSchema(blockchainTransactions).omit({
  id: true,
  createdAt: true,
  confirmedAt: true,
});

export const insertSmartContractSchema = createInsertSchema(smartContracts).omit({
  id: true,
  createdAt: true,
});

export const insertIpfsDocumentSchema = createInsertSchema(ipfsDocuments).omit({
  id: true,
  createdAt: true,
});

export const insertWalletSchema = createInsertSchema(wallets).omit({
  id: true,
  createdAt: true,
  updatedAt: true,
});

// Blockchain types
export type BlockchainTransaction = typeof blockchainTransactions.$inferSelect;
export type SmartContract = typeof smartContracts.$inferSelect;
export type BlockchainSync = typeof blockchainSync.$inferSelect;
export type IpfsDocument = typeof ipfsDocuments.$inferSelect;
export type Wallet = typeof wallets.$inferSelect;

export type InsertBlockchainTransaction = z.infer<typeof insertBlockchainTransactionSchema>;
export type InsertSmartContract = z.infer<typeof insertSmartContractSchema>;
export type InsertIpfsDocument = z.infer<typeof insertIpfsDocumentSchema>;
export type InsertWallet = z.infer<typeof insertWalletSchema>;

// Advanced Financial Instruments Tables

// Financial Instrument Types
export const financialInstruments = pgTable("financial_instruments", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  campaignId: varchar("campaign_id").references(() => campaigns.id),
  instrumentType: varchar("instrument_type").notNull(), // 'equity', 'sukuk', 'revenue_share', 'convertible', 'islamic_equity'
  shariahCompliant: boolean("shariah_compliant").default(false),
  minimumInvestment: varchar("minimum_investment").notNull(),
  maximumInvestment: varchar("maximum_investment"),
  expectedReturn: varchar("expected_return"), // Annual percentage
  maturityPeriod: integer("maturity_period_months"), // In months
  conversionRatio: varchar("conversion_ratio"), // For convertible instruments
  revenueSharePercentage: varchar("revenue_share_percentage"), // For revenue sharing
  profitSharingRatio: varchar("profit_sharing_ratio"), // Islamic finance
  mudarabahTerms: json("mudarabah_terms"), // Islamic partnership terms
  sukukStructure: json("sukuk_structure"), // Sukuk-specific parameters
  regulatoryApproval: varchar("regulatory_approval"), // SEC/ESX approval status
  prospectusHash: varchar("prospectus_hash"), // IPFS hash of offering document
  riskRating: varchar("risk_rating"), // A, B, C, D rating
  createdAt: timestamp("created_at").defaultNow(),
  updatedAt: timestamp("updated_at").defaultNow(),
});

// Investment Positions with Financial Instrument Details
export const investmentPositions = pgTable("investment_positions", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  investorId: varchar("investor_id").references(() => users.id),
  instrumentId: varchar("instrument_id").references(() => financialInstruments.id),
  campaignId: varchar("campaign_id").references(() => campaigns.id),
  positionType: varchar("position_type").notNull(), // 'primary', 'secondary', 'converted'
  investmentAmount: varchar("investment_amount").notNull(),
  sharesOwned: varchar("shares_owned").notNull(),
  currentValue: varchar("current_value"),
  unrealizedGains: varchar("unrealized_gains"),
  dividendsReceived: varchar("dividends_received").default("0"),
  conversionEligible: boolean("conversion_eligible").default(false),
  conversionDeadline: timestamp("conversion_deadline"),
  purchaseDate: timestamp("purchase_date").defaultNow(),
  lastValuation: timestamp("last_valuation"),
  status: varchar("status").notNull().default("active"), // active, converted, sold, matured
  blockchainTxHash: varchar("blockchain_tx_hash"),
  nftTokenId: varchar("nft_token_id"),
  createdAt: timestamp("created_at").defaultNow(),
});

// Revenue Sharing Distributions
export const revenueDistributions = pgTable("revenue_distributions", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  campaignId: varchar("campaign_id").references(() => campaigns.id),
  instrumentId: varchar("instrument_id").references(() => financialInstruments.id),
  distributionPeriod: varchar("distribution_period").notNull(), // 'Q1-2024', 'monthly-2024-12'
  totalRevenue: varchar("total_revenue").notNull(),
  distributableAmount: varchar("distributable_amount").notNull(),
  sharesOutstanding: varchar("shares_outstanding").notNull(),
  distributionPerShare: varchar("distribution_per_share").notNull(),
  paymentStatus: varchar("payment_status").default("pending"), // pending, processing, completed
  paymentDate: timestamp("payment_date"),
  blockchainTxHash: varchar("blockchain_tx_hash"),
  auditReportHash: varchar("audit_report_hash"), // IPFS hash
  createdAt: timestamp("created_at").defaultNow(),
});

// Individual Investor Revenue Payments
export const investorPayments = pgTable("investor_payments", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  distributionId: varchar("distribution_id").references(() => revenueDistributions.id),
  positionId: varchar("position_id").references(() => investmentPositions.id),
  investorId: varchar("investor_id").references(() => users.id),
  paymentAmount: varchar("payment_amount").notNull(),
  sharesEligible: varchar("shares_eligible").notNull(),
  taxWithheld: varchar("tax_withheld").default("0"),
  netPayment: varchar("net_payment").notNull(),
  paymentMethod: varchar("payment_method").notNull(), // bank_transfer, crypto, mobile_money
  paymentReference: varchar("payment_reference"),
  status: varchar("status").default("pending"), // pending, sent, received, failed
  paidAt: timestamp("paid_at"),
  blockchainTxHash: varchar("blockchain_tx_hash"),
  createdAt: timestamp("created_at").defaultNow(),
});

// Secondary Market Trading
export const tradingOrders = pgTable("trading_orders", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  positionId: varchar("position_id").references(() => investmentPositions.id),
  sellerId: varchar("seller_id").references(() => users.id),
  instrumentId: varchar("instrument_id").references(() => financialInstruments.id),
  orderType: varchar("order_type").notNull(), // 'market', 'limit', 'stop_loss'
  sharesOffered: varchar("shares_offered").notNull(),
  pricePerShare: varchar("price_per_share"),
  totalOrderValue: varchar("total_order_value"),
  minimumSalePrice: varchar("minimum_sale_price"),
  orderStatus: varchar("order_status").default("active"), // active, filled, cancelled, expired
  validUntil: timestamp("valid_until"),
  shariahCompliant: boolean("shariah_compliant").default(true),
  kycRequired: boolean("kyc_required").default(true),
  accreditedInvestorOnly: boolean("accredited_investor_only").default(false),
  createdAt: timestamp("created_at").defaultNow(),
  updatedAt: timestamp("updated_at").defaultNow(),
});

// Trade Execution Records
export const tradeExecutions = pgTable("trade_executions", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  orderId: varchar("order_id").references(() => tradingOrders.id),
  buyerId: varchar("buyer_id").references(() => users.id),
  sellerId: varchar("seller_id").references(() => users.id),
  instrumentId: varchar("instrument_id").references(() => financialInstruments.id),
  sharesTraded: varchar("shares_traded").notNull(),
  pricePerShare: varchar("price_per_share").notNull(),
  totalTradeValue: varchar("total_trade_value").notNull(),
  platformFee: varchar("platform_fee").notNull(),
  sellerProceeds: varchar("seller_proceeds").notNull(),
  tradeDate: timestamp("trade_date").defaultNow(),
  settlementStatus: varchar("settlement_status").default("pending"), // pending, settled, failed
  settlementDate: timestamp("settlement_date"),
  blockchainTxHash: varchar("blockchain_tx_hash"),
  escrowAddress: varchar("escrow_address"),
  createdAt: timestamp("created_at").defaultNow(),
});

// Islamic Finance Compliance Tracking
export const shariahCompliance = pgTable("shariah_compliance", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  instrumentId: varchar("instrument_id").references(() => financialInstruments.id),
  campaignId: varchar("campaign_id").references(() => campaigns.id),
  complianceStatus: varchar("compliance_status").notNull(), // 'compliant', 'under_review', 'non_compliant'
  shariahBoardApproval: boolean("shariah_board_approval").default(false),
  approvedBy: varchar("approved_by"), // Shariah scholar name/ID
  complianceDate: timestamp("compliance_date"),
  nextReviewDate: timestamp("next_review_date"),
  complianceReportHash: varchar("compliance_report_hash"), // IPFS hash
  businessModel: varchar("business_model"), // mudarabah, musharakah, murabaha, etc.
  prohibitedActivities: json("prohibited_activities"), // List of haram activities to avoid
  profitSharingStructure: json("profit_sharing_structure"),
  riskSharingMechanism: json("risk_sharing_mechanism"),
  ghararAssessment: varchar("gharar_assessment"), // Excessive uncertainty evaluation
  ribaCompliance: varchar("riba_compliance"), // Interest-free verification
  createdAt: timestamp("created_at").defaultNow(),
  updatedAt: timestamp("updated_at").defaultNow(),
});

// Convertible Instrument Tracking
export const conversionEvents = pgTable("conversion_events", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  positionId: varchar("position_id").references(() => investmentPositions.id),
  instrumentId: varchar("instrument_id").references(() => financialInstruments.id),
  investorId: varchar("investor_id").references(() => users.id),
  conversionTrigger: varchar("conversion_trigger").notNull(), // 'voluntary', 'automatic', 'maturity'
  sharesConverted: varchar("shares_converted").notNull(),
  conversionRatio: varchar("conversion_ratio").notNull(),
  newSharesIssued: varchar("new_shares_issued").notNull(),
  conversionValue: varchar("conversion_value").notNull(),
  conversionDate: timestamp("conversion_date").defaultNow(),
  newInstrumentType: varchar("new_instrument_type").notNull(),
  blockchainTxHash: varchar("blockchain_tx_hash"),
  status: varchar("status").default("completed"), // pending, completed, failed
  createdAt: timestamp("created_at").defaultNow(),
});

// Financial Instrument insert schemas
export const insertFinancialInstrumentSchema = createInsertSchema(financialInstruments).pick({
  campaignId: true,
  instrumentType: true,
  shariahCompliant: true,
  minimumInvestment: true,
  expectedReturn: true,
  maturityPeriod: true,
});

export const insertInvestmentPositionSchema = createInsertSchema(investmentPositions).omit({
  id: true,
  createdAt: true,
});

export const insertTradingOrderSchema = createInsertSchema(tradingOrders).pick({
  positionId: true,
  sellerId: true,
  instrumentId: true,
  orderType: true,
  sharesOffered: true,
  pricePerShare: true,
});

export const insertShariahComplianceSchema = createInsertSchema(shariahCompliance).pick({
  instrumentId: true,
  campaignId: true,
  complianceStatus: true,
  shariahBoardApproval: true,
  businessModel: true,
});

// Financial Instrument types
export type FinancialInstrument = typeof financialInstruments.$inferSelect;
export type InsertFinancialInstrument = z.infer<typeof insertFinancialInstrumentSchema>;
export type InvestmentPosition = typeof investmentPositions.$inferSelect;
export type InsertInvestmentPosition = z.infer<typeof insertInvestmentPositionSchema>;
export type RevenueDistribution = typeof revenueDistributions.$inferSelect;
export type InvestorPayment = typeof investorPayments.$inferSelect;
export type TradingOrder = typeof tradingOrders.$inferSelect;
export type InsertTradingOrder = z.infer<typeof insertTradingOrderSchema>;
export type TradeExecution = typeof tradeExecutions.$inferSelect;
export type ShariahCompliance = typeof shariahCompliance.$inferSelect;
export type InsertShariahCompliance = z.infer<typeof insertShariahComplianceSchema>;
export type ConversionEvent = typeof conversionEvents.$inferSelect;

// Financial Instrument relations
export const financialInstrumentsRelations = relations(financialInstruments, ({ one, many }) => ({
  campaign: one(campaigns, {
    fields: [financialInstruments.campaignId],
    references: [campaigns.id],
  }),
  positions: many(investmentPositions),
  tradingOrders: many(tradingOrders),
  shariahCompliance: one(shariahCompliance, {
    fields: [financialInstruments.id],
    references: [shariahCompliance.instrumentId],
  }),
}));

export const investmentPositionsRelations = relations(investmentPositions, ({ one, many }) => ({
  investor: one(users, {
    fields: [investmentPositions.investorId],
    references: [users.id],
  }),
  instrument: one(financialInstruments, {
    fields: [investmentPositions.instrumentId],
    references: [financialInstruments.id],
  }),
  campaign: one(campaigns, {
    fields: [investmentPositions.campaignId],
    references: [campaigns.id],
  }),
  tradingOrders: many(tradingOrders),
  payments: many(investorPayments),
}));

export const tradingOrdersRelations = relations(tradingOrders, ({ one, many }) => ({
  position: one(investmentPositions, {
    fields: [tradingOrders.positionId],
    references: [investmentPositions.id],
  }),
  seller: one(users, {
    fields: [tradingOrders.sellerId],
    references: [users.id],
  }),
  instrument: one(financialInstruments, {
    fields: [tradingOrders.instrumentId],
    references: [financialInstruments.id],
  }),
  executions: many(tradeExecutions),
}));

export const tradeExecutionsRelations = relations(tradeExecutions, ({ one }) => ({
  order: one(tradingOrders, {
    fields: [tradeExecutions.orderId],
    references: [tradingOrders.id],
  }),
  buyer: one(users, {
    fields: [tradeExecutions.buyerId],
    references: [users.id],
  }),
  seller: one(users, {
    fields: [tradeExecutions.sellerId],
    references: [users.id],
  }),
  instrument: one(financialInstruments, {
    fields: [tradeExecutions.instrumentId],
    references: [financialInstruments.id],
  }),
}));

// KYC/AML Comprehensive System

// KYC Verification Levels
export const kycLevels = pgTable("kyc_levels", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  levelName: varchar("level_name").notNull(), // basic, enhanced, premium
  investmentLimit: varchar("investment_limit").notNull(),
  requiredDocuments: json("required_documents").notNull(),
  verificationSteps: json("verification_steps").notNull(),
  complianceScore: integer("compliance_score").notNull(), // 0-100
  description: text("description"),
  createdAt: timestamp("created_at").defaultNow(),
});

// User KYC Records
export const userKyc = pgTable("user_kyc", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  userId: varchar("user_id").references(() => users.id).notNull(),
  kycLevel: varchar("kyc_level").references(() => kycLevels.id).notNull(),
  status: varchar("status").notNull().default("pending"), // pending, under_review, approved, rejected, expired
  submissionDate: timestamp("submission_date").defaultNow(),
  reviewDate: timestamp("review_date"),
  expiryDate: timestamp("expiry_date"),
  reviewedBy: varchar("reviewed_by"), // Admin/Reviewer ID
  rejectionReason: text("rejection_reason"),
  complianceScore: integer("compliance_score").default(0),
  riskScore: integer("risk_score").default(0), // 0-100, higher = more risk
  
  // Identity Information
  nationalId: varchar("national_id"),
  passportNumber: varchar("passport_number"),
  drivingLicense: varchar("driving_license"),
  dateOfBirth: timestamp("date_of_birth"),
  placeOfBirth: varchar("place_of_birth"),
  nationality: varchar("nationality"),
  
  // Address Verification
  residentialAddress: text("residential_address"),
  mailingAddress: text("mailing_address"),
  addressVerified: boolean("address_verified").default(false),
  addressVerificationDate: timestamp("address_verification_date"),
  
  // Contact Verification
  phoneNumber: varchar("phone_number"),
  phoneVerified: boolean("phone_verified").default(false),
  phoneVerificationDate: timestamp("phone_verification_date"),
  emailVerified: boolean("email_verified").default(false),
  emailVerificationDate: timestamp("email_verification_date"),
  
  // Employment Information
  occupation: varchar("occupation"),
  employerName: varchar("employer_name"),
  workAddress: text("work_address"),
  monthlyIncome: varchar("monthly_income"),
  sourceOfFunds: varchar("source_of_funds"), // salary, business, inheritance, etc.
  
  // Enhanced Due Diligence
  politicallyExposed: boolean("politically_exposed").default(false),
  sanctionsCheck: boolean("sanctions_check").default(false),
  sanctionsCheckDate: timestamp("sanctions_check_date"),
  adverseMediaCheck: boolean("adverse_media_check").default(false),
  adverseMediaCheckDate: timestamp("adverse_media_check_date"),
  
  // Biometric Data
  facialRecognitionScore: integer("facial_recognition_score"), // 0-100
  livenessCheckPassed: boolean("liveness_check_passed").default(false),
  documentAuthenticityScore: integer("document_authenticity_score"), // 0-100
  
  metadata: json("metadata"), // Additional data, flags, notes
  createdAt: timestamp("created_at").defaultNow(),
  updatedAt: timestamp("updated_at").defaultNow(),
});

// KYC Document Storage
export const kycDocuments = pgTable("kyc_documents", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  kycId: varchar("kyc_id").references(() => userKyc.id).notNull(),
  documentType: varchar("document_type").notNull(), // national_id, passport, utility_bill, bank_statement, etc.
  fileName: varchar("file_name").notNull(),
  fileHash: varchar("file_hash").notNull(), // IPFS hash or secure storage hash
  fileSize: integer("file_size"),
  mimeType: varchar("mime_type"),
  uploadDate: timestamp("upload_date").defaultNow(),
  verified: boolean("verified").default(false),
  verificationDate: timestamp("verification_date"),
  verificationMethod: varchar("verification_method"), // manual, automated, third_party
  extractedData: json("extracted_data"), // OCR/AI extracted information
  confidenceScore: integer("confidence_score"), // 0-100 for automated verification
  expiryDate: timestamp("expiry_date"), // For documents with expiry dates
  issueDate: timestamp("issue_date"),
  issuingAuthority: varchar("issuing_authority"),
  createdAt: timestamp("created_at").defaultNow(),
});

// AML Transaction Monitoring
export const amlTransactionMonitoring = pgTable("aml_transaction_monitoring", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  userId: varchar("user_id").references(() => users.id).notNull(),
  transactionId: varchar("transaction_id"), // Reference to investment/payment
  transactionType: varchar("transaction_type").notNull(), // investment, withdrawal, transfer
  amount: varchar("amount").notNull(),
  currency: varchar("currency").default("ETB"),
  transactionDate: timestamp("transaction_date").defaultNow(),
  
  // Risk Assessment
  riskScore: integer("risk_score").notNull(), // 0-100
  riskFactors: json("risk_factors"), // Array of identified risk factors
  flaggedReason: text("flagged_reason"),
  alertLevel: varchar("alert_level"), // low, medium, high, critical
  
  // Pattern Detection
  unusualPattern: boolean("unusual_pattern").default(false),
  velocityCheck: boolean("velocity_check").default(false), // High frequency transactions
  amountThresholdExceeded: boolean("amount_threshold_exceeded").default(false),
  geographicalRisk: boolean("geographical_risk").default(false),
  
  // Investigation Status
  investigationStatus: varchar("investigation_status").default("none"), // none, pending, ongoing, closed
  investigatedBy: varchar("investigated_by"),
  investigationNotes: text("investigation_notes"),
  sarFiled: boolean("sar_filed").default(false), // Suspicious Activity Report
  sarFilingDate: timestamp("sar_filing_date"),
  
  // Regulatory Reporting
  reportedToFic: boolean("reported_to_fic").default(false), // Financial Intelligence Centre
  reportingDate: timestamp("reporting_date"),
  reportReference: varchar("report_reference"),
  
  createdAt: timestamp("created_at").defaultNow(),
  updatedAt: timestamp("updated_at").defaultNow(),
});

// Sanctions and Watchlist Screening
export const sanctionsScreening = pgTable("sanctions_screening", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  userId: varchar("user_id").references(() => users.id).notNull(),
  screeningDate: timestamp("screening_date").defaultNow(),
  screeningProvider: varchar("screening_provider"), // internal, world_check, etc.
  
  // Screening Results
  matchFound: boolean("match_found").default(false),
  matchDetails: json("match_details"), // Details of any matches found
  matchScore: integer("match_score"), // 0-100 confidence of match
  falsePositive: boolean("false_positive").default(false),
  
  // Lists Checked
  ofacSdnList: boolean("ofac_sdn_list").default(false), // US Treasury OFAC
  unSanctionsList: boolean("un_sanctions_list").default(false),
  euSanctionsList: boolean("eu_sanctions_list").default(false),
  pepList: boolean("pep_list").default(false), // Politically Exposed Persons
  adverseMediaList: boolean("adverse_media_list").default(false),
  
  // Review Status
  reviewStatus: varchar("review_status").default("automated"), // automated, manual_review, cleared, blocked
  reviewedBy: varchar("reviewed_by"),
  reviewNotes: text("review_notes"),
  clearanceDate: timestamp("clearance_date"),
  
  // Next screening due
  nextScreeningDate: timestamp("next_screening_date"),
  
  createdAt: timestamp("created_at").defaultNow(),
});

// Compliance Audit Trail
export const complianceAuditTrail = pgTable("compliance_audit_trail", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  userId: varchar("user_id").references(() => users.id),
  actionType: varchar("action_type").notNull(), // kyc_submission, document_upload, screening, etc.
  actionDescription: text("action_description").notNull(),
  performedBy: varchar("performed_by"), // User ID or system
  userRole: varchar("user_role"), // admin, compliance_officer, system
  
  // Before/After State
  beforeState: json("before_state"),
  afterState: json("after_state"),
  
  // System Information
  ipAddress: varchar("ip_address"),
  userAgent: varchar("user_agent"),
  sessionId: varchar("session_id"),
  
  // Regulatory Compliance
  regulatoryRequirement: varchar("regulatory_requirement"), // Which regulation this relates to
  retentionPeriod: integer("retention_period_years").default(7),
  
  timestamp: timestamp("timestamp").defaultNow(),
});

// Compliance Reporting
export const complianceReports = pgTable("compliance_reports", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  reportType: varchar("report_type").notNull(), // sar, ctr, kyc_summary, aml_summary
  reportPeriod: varchar("report_period").notNull(), // monthly, quarterly, annual
  generatedBy: varchar("generated_by").notNull(),
  generationDate: timestamp("generation_date").defaultNow(),
  
  // Report Content
  reportData: json("report_data").notNull(),
  reportHash: varchar("report_hash").notNull(), // For integrity verification
  
  // Regulatory Submission
  submittedToRegulator: boolean("submitted_to_regulator").default(false),
  submissionDate: timestamp("submission_date"),
  regulatorReference: varchar("regulator_reference"),
  
  // File Storage
  reportFileHash: varchar("report_file_hash"), // IPFS or secure storage
  encryptionKey: varchar("encryption_key"), // Encrypted storage key
  
  status: varchar("status").default("draft"), // draft, final, submitted
  createdAt: timestamp("created_at").defaultNow(),
});

// KYC insert schemas
export const insertKycLevelSchema = createInsertSchema(kycLevels).pick({
  levelName: true,
  investmentLimit: true,
  requiredDocuments: true,
  verificationSteps: true,
  complianceScore: true,
  description: true,
});

export const insertUserKycSchema = createInsertSchema(userKyc).pick({
  userId: true,
  kycLevel: true,
  nationalId: true,
  dateOfBirth: true,
  nationality: true,
  residentialAddress: true,
  phoneNumber: true,
  occupation: true,
  monthlyIncome: true,
  sourceOfFunds: true,
});

export const insertKycDocumentSchema = createInsertSchema(kycDocuments).pick({
  kycId: true,
  documentType: true,
  fileName: true,
  fileHash: true,
  fileSize: true,
  mimeType: true,
});

export const insertAmlMonitoringSchema = createInsertSchema(amlTransactionMonitoring).pick({
  userId: true,
  transactionType: true,
  amount: true,
  riskScore: true,
  alertLevel: true,
});

// KYC/AML types
export type KycLevel = typeof kycLevels.$inferSelect;
export type InsertKycLevel = z.infer<typeof insertKycLevelSchema>;
export type UserKyc = typeof userKyc.$inferSelect;
export type InsertUserKyc = z.infer<typeof insertUserKycSchema>;
export type KycDocument = typeof kycDocuments.$inferSelect;
export type InsertKycDocument = z.infer<typeof insertKycDocumentSchema>;
export type AmlTransactionMonitoring = typeof amlTransactionMonitoring.$inferSelect;
export type InsertAmlMonitoring = z.infer<typeof insertAmlMonitoringSchema>;
export type SanctionsScreening = typeof sanctionsScreening.$inferSelect;
export type ComplianceAuditTrail = typeof complianceAuditTrail.$inferSelect;
export type ComplianceReport = typeof complianceReports.$inferSelect;

// KYC/AML relations
export const kycLevelsRelations = relations(kycLevels, ({ many }) => ({
  userKyc: many(userKyc),
}));

export const userKycRelations = relations(userKyc, ({ one, many }) => ({
  user: one(users, {
    fields: [userKyc.userId],
    references: [users.id],
  }),
  kycLevel: one(kycLevels, {
    fields: [userKyc.kycLevel],
    references: [kycLevels.id],
  }),
  documents: many(kycDocuments),
  sanctionsScreening: many(sanctionsScreening),
  amlMonitoring: many(amlTransactionMonitoring),
}));

export const kycDocumentsRelations = relations(kycDocuments, ({ one }) => ({
  kyc: one(userKyc, {
    fields: [kycDocuments.kycId],
    references: [userKyc.id],
  }),
}));

export const amlTransactionMonitoringRelations = relations(amlTransactionMonitoring, ({ one }) => ({
  user: one(users, {
    fields: [amlTransactionMonitoring.userId],
    references: [users.id],
  }),
}));

export const sanctionsScreeningRelations = relations(sanctionsScreening, ({ one }) => ({
  user: one(users, {
    fields: [sanctionsScreening.userId],
    references: [users.id],
  }),
}));
