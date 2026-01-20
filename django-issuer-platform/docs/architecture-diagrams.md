# CrowdfundChain Platform Architecture Diagrams

## Mind Map - Platform Overview

```mermaid
mindmap
  root((django-issuer-platform))
    Apps
      Issuers["Issuers (User & KYC lifecycle)"]
        Models
          User["User (UUID pk, roles, KYC flags, wallet)"]
          Company["Company (branding, blockchain registration)"]
          IssuerProfile["IssuerProfile (business details)"]
          KYCDocument["KYCDocument (verification docs)"]
      CampaignsModule["Campaigns Module"]
        Models
          Campaign["Campaign (funding goal, deployment state)"]
          CampaignDocument["CampaignDocument (IPFS refs)"]
          CampaignUpdate["CampaignUpdate (investor comms)"]
      Investments["Investments (funding + NFT)"]
        Models
          Investment["Investment (dual-ledger tracking)"]
          NFTShareCertificate["NFTShareCertificate (token metadata)"]
          Payment["Payment (Ethiopian gateways)"]
      Escrow["Escrow (fund disbursement)"]
        Models
          EscrowAccount["Custodial accounts"]
          ReleaseRequest["Release workflows"]
      Blockchain["Blockchain Integration"]
        Components
          web3_client["PolygonEdgeClient (RPC, signer)"]
          services["Issuer & Campaign services"]
          tasks["Celery sync/monitoring"]
    API Endpoints
      Auth["/api/auth/ (JWT tokens)"]
      Issuers["/api/issuers/ (CRUD, KYC)"]
      Campaigns["/api/campaigns/ (lifecycle)"]
      Investments["/api/investments/ (NFT minting)"]
      Escrow["/api/escrow/ (fund release)"]
      Blockchain["/api/blockchain/ (health, balances)"]
      Docs["/api/docs (Swagger UI)"]
    Services
      IssuerBlockchainService["Register issuers on-chain"]
      CampaignBlockchainService["Deploy campaigns"]
      NFTMetadataGenerator["Rich certificate metadata"]
      WalletService["Encrypted key management"]
      ContractService["Smart contract interactions"]
    Blockchain Stack
      Network["Polygon Edge v1.3.1 (IBFT)"]
      Contracts["IssuerRegistry, CampaignFactory, FundEscrow, NFTCertificate"]
      DualLedger["PostgreSQL + blockchain audit trail"]
      Credentials["BLOCKCHAIN_DEPLOYER_PRIVATE_KEY"]
```

---

## Sequence Diagram 1: Investment Flow with NFT Minting

```mermaid
sequenceDiagram
    participant Investor
    participant Frontend
    participant Django API
    participant PostgreSQL
    participant Blockchain
    participant NFTContract

    Investor->>Frontend: Select campaign & amount
    Frontend->>Django API: POST /api/investments/
    Django API->>Django API: Validate (min/max, campaign active)
    Django API->>PostgreSQL: Create Investment (status=pending)
    Django API->>Frontend: Return investment ID
    
    Investor->>Frontend: Complete payment
    Frontend->>Django API: POST /api/investments/{id}/confirm/
    Django API->>PostgreSQL: Update status=confirmed
    Django API->>Blockchain: Record investment on-chain
    Blockchain-->>Django API: tx_hash
    Django API->>PostgreSQL: Store blockchain_tx_hash
    
    Django API->>Django API: Generate NFT metadata (issuer branding)
    Django API->>NFTContract: Mint certificate
    NFTContract-->>Django API: token_id
    Django API->>PostgreSQL: Create NFTShareCertificate
    Django API->>Frontend: Return NFT details
    Frontend->>Investor: Display certificate
```

---

## Sequence Diagram 2: SME Onboarding & Campaign Creation

```mermaid
sequenceDiagram
    participant SME
    participant Frontend
    participant Django API
    participant PostgreSQL
    participant Blockchain
    participant IssuerRegistry

    SME->>Frontend: Register account
    Frontend->>Django API: POST /api/auth/register/
    Django API->>PostgreSQL: Create User (role=issuer)
    Django API->>Frontend: JWT tokens

    SME->>Frontend: Submit company details
    Frontend->>Django API: POST /api/issuers/companies/
    Django API->>PostgreSQL: Create Company
    
    SME->>Frontend: Upload KYC documents
    Frontend->>Django API: POST /api/issuers/kyc/
    Django API->>PostgreSQL: Store KYCDocument
    
    Note over Django API: Admin verifies KYC
    Django API->>Blockchain: Register issuer
    IssuerRegistry-->>Django API: tx_hash
    Django API->>PostgreSQL: Update verified=true
    
    SME->>Frontend: Create campaign
    Frontend->>Django API: POST /api/campaigns/
    Django API->>PostgreSQL: Create Campaign (status=draft)
    
    Note over Django API: Admin approves campaign
    Django API->>Blockchain: Deploy campaign contract
    Blockchain-->>Django API: contract_address
    Django API->>PostgreSQL: Update smart_contract_address
    Django API->>Frontend: Campaign active
```

---

## Sequence Diagram 3: Authentication Flow (JWT)

```mermaid
sequenceDiagram
    participant User
    participant Frontend
    participant Django API
    participant PostgreSQL

    User->>Frontend: Enter credentials
    Frontend->>Django API: POST /api/auth/token/
    Django API->>PostgreSQL: Validate user
    Django API->>Frontend: {access_token, refresh_token}
    Frontend->>Frontend: Store tokens in localStorage

    Note over Frontend: Token expires
    Frontend->>Django API: POST /api/auth/token/refresh/
    Django API->>Frontend: New access_token

    User->>Frontend: Connect wallet
    Frontend->>Django API: POST /api/auth/wallet-connect/
    Django API->>PostgreSQL: Link wallet to user
    Django API->>Frontend: JWT tokens
```

---

## Sequence Diagram 4: Escrow & Fund Release

```mermaid
sequenceDiagram
    participant SME
    participant Admin
    participant Django API
    participant PostgreSQL
    participant EscrowContract

    Note over EscrowContract: Campaign reaches goal
    Django API->>PostgreSQL: Update campaign status=funded
    
    SME->>Django API: POST /api/escrow/release-request/
    Django API->>PostgreSQL: Create ReleaseRequest
    
    Admin->>Django API: POST /api/escrow/approve/{id}/
    Django API->>EscrowContract: Release funds
    EscrowContract-->>Django API: tx_hash
    Django API->>PostgreSQL: Update release status
    Django API->>SME: Funds released notification
```

---

## Sequence Diagram 5: Issuer Registration & Verification Flow

```mermaid
sequenceDiagram
    participant SME as SME/Issuer
    participant Frontend
    participant DjangoAPI as Django API
    participant DB as PostgreSQL
    participant Admin
    participant Blockchain
    participant IssuerRegistry as IssuerRegistry Contract

    rect rgb(240, 248, 255)
        Note over SME,DjangoAPI: Step 1: Account Registration
        SME->>Frontend: Click "Register as Issuer"
        Frontend->>DjangoAPI: POST /api/auth/register/<br/>{username, email, password, role: "issuer"}
        DjangoAPI->>DB: Create User (role=issuer, kyc_verified=false)
        DjangoAPI->>Frontend: {access_token, refresh_token}
        Frontend->>SME: Redirect to onboarding
    end

    rect rgb(255, 248, 240)
        Note over SME,DB: Step 2: Company Profile Setup
        SME->>Frontend: Fill company details
        Frontend->>DjangoAPI: POST /api/issuers/companies/<br/>{name, tin_number, sector, logo_url, description}
        DjangoAPI->>DB: Create Company (verified=false)
        DjangoAPI->>Frontend: Company created
        
        SME->>Frontend: Fill issuer profile
        Frontend->>DjangoAPI: POST /api/issuers/profiles/<br/>{phone, address, business_description}
        DjangoAPI->>DB: Create IssuerProfile
    end

    rect rgb(240, 255, 240)
        Note over SME,DB: Step 3: KYC Document Upload
        SME->>Frontend: Upload business license
        Frontend->>DjangoAPI: POST /api/issuers/kyc/<br/>{document_type: "business_license", file}
        DjangoAPI->>DB: Create KYCDocument (status=pending)
        
        SME->>Frontend: Upload TIN certificate
        Frontend->>DjangoAPI: POST /api/issuers/kyc/<br/>{document_type: "tin_certificate", file}
        DjangoAPI->>DB: Create KYCDocument (status=pending)
    end

    rect rgb(255, 240, 245)
        Note over Admin,Blockchain: Step 4: Admin Verification
        Admin->>DjangoAPI: GET /api/issuers/kyc/pending/
        DjangoAPI->>Admin: List pending documents
        Admin->>DjangoAPI: POST /api/issuers/kyc/{id}/verify/
        DjangoAPI->>DB: Update KYCDocument (status=approved)
        DjangoAPI->>DB: Update User (kyc_verified=true)
        
        Admin->>DjangoAPI: POST /api/issuers/companies/{id}/verify/
        DjangoAPI->>Blockchain: Register issuer on-chain
        Blockchain->>IssuerRegistry: registerIssuer(address, tinHash, sector)
        IssuerRegistry-->>Blockchain: IssuerRegistered event
        Blockchain-->>DjangoAPI: tx_hash
        DjangoAPI->>DB: Update Company<br/>(verified=true, blockchain_tx_hash)
        DjangoAPI->>SME: Notification: "Verified - Ready to create campaigns"
    end
```

---

## Sequence Diagram 6: Campaign Lifecycle Flow

```mermaid
sequenceDiagram
    participant Issuer
    participant Frontend
    participant DjangoAPI as Django API
    participant DB as PostgreSQL
    participant Admin
    participant Blockchain
    participant CampaignFactory as CampaignFactory Contract
    participant CampaignContract as Campaign Contract

    rect rgb(240, 248, 255)
        Note over Issuer,DB: Step 1: Campaign Draft Creation
        Issuer->>Frontend: Click "Create Campaign"
        Frontend->>DjangoAPI: POST /api/campaigns/<br/>{title, description, funding_goal, min_investment}
        DjangoAPI->>DjangoAPI: Validate issuer is verified
        DjangoAPI->>DB: Create Campaign (status=draft)
        DjangoAPI->>Frontend: Campaign ID
        
        Issuer->>Frontend: Upload pitch deck
        Frontend->>DjangoAPI: POST /api/campaigns/{id}/documents/<br/>{type: "pitch_deck", file}
        DjangoAPI->>DB: Create CampaignDocument
        
        Issuer->>Frontend: Upload financials
        Frontend->>DjangoAPI: POST /api/campaigns/{id}/documents/<br/>{type: "financial_statement", file}
        DjangoAPI->>DB: Create CampaignDocument
    end

    rect rgb(255, 248, 240)
        Note over Issuer,DB: Step 2: Submit for Review
        Issuer->>Frontend: Click "Submit for Review"
        Frontend->>DjangoAPI: POST /api/campaigns/{id}/submit/
        DjangoAPI->>DjangoAPI: Validate all required docs uploaded
        DjangoAPI->>DB: Update Campaign (status=pending_review)
        DjangoAPI->>Admin: Notification: New campaign for review
    end

    rect rgb(240, 255, 240)
        Note over Admin,Blockchain: Step 3: Admin Approval & Deployment
        Admin->>DjangoAPI: GET /api/campaigns/pending/
        DjangoAPI->>Admin: List pending campaigns
        Admin->>DjangoAPI: Review campaign details
        
        Admin->>DjangoAPI: POST /api/campaigns/{id}/approve/
        DjangoAPI->>DB: Update Campaign (status=approved)
        
        DjangoAPI->>Blockchain: Deploy campaign contract
        Blockchain->>CampaignFactory: createCampaign(issuer, goal, duration)
        CampaignFactory->>CampaignContract: Deploy new contract
        CampaignContract-->>CampaignFactory: contract_address
        CampaignFactory-->>Blockchain: CampaignCreated event
        Blockchain-->>DjangoAPI: {tx_hash, contract_address}
        
        DjangoAPI->>DB: Update Campaign<br/>(smart_contract_address, blockchain_tx_hash)
    end

    rect rgb(255, 240, 245)
        Note over Admin,Issuer: Step 4: Campaign Activation
        Admin->>DjangoAPI: POST /api/campaigns/{id}/activate/
        DjangoAPI->>Blockchain: Activate campaign on-chain
        Blockchain->>CampaignContract: activate()
        CampaignContract-->>Blockchain: CampaignActivated event
        Blockchain-->>DjangoAPI: tx_hash
        
        DjangoAPI->>DB: Update Campaign (status=active, start_date)
        DjangoAPI->>Issuer: Notification: "Campaign is now live!"
        DjangoAPI->>Frontend: Campaign visible to investors
    end

    rect rgb(248, 248, 255)
        Note over Issuer,CampaignContract: Step 5: Campaign Updates
        Issuer->>Frontend: Post investor update
        Frontend->>DjangoAPI: POST /api/campaigns/{id}/updates/<br/>{title, content}
        DjangoAPI->>DB: Create CampaignUpdate
        DjangoAPI->>DjangoAPI: Notify all investors
    end
```

---

## Sequence Diagram 7: Campaign Completion & Escrow Release

```mermaid
sequenceDiagram
    participant System
    participant DjangoAPI as Django API
    participant DB as PostgreSQL
    participant CampaignContract as Campaign Contract
    participant EscrowContract as Escrow Contract
    participant Issuer
    participant Investors

    rect rgb(240, 255, 240)
        Note over System,CampaignContract: Campaign Reaches Goal
        System->>CampaignContract: Check funding status
        CampaignContract-->>System: goal_reached = true
        System->>DjangoAPI: Trigger campaign completion
        DjangoAPI->>DB: Update Campaign (status=funded)
        DjangoAPI->>Investors: Notification: "Campaign fully funded!"
        DjangoAPI->>Issuer: Notification: "Congratulations! Goal reached"
    end

    rect rgb(255, 248, 240)
        Note over Issuer,EscrowContract: Fund Release Process
        Issuer->>DjangoAPI: POST /api/escrow/release-request/<br/>{campaign_id, amount, milestone}
        DjangoAPI->>DB: Create ReleaseRequest (status=pending)
        DjangoAPI->>DjangoAPI: Notify admin for approval
        
        Note over DjangoAPI: Admin reviews request
        DjangoAPI->>EscrowContract: releaseFunds(campaign, amount, recipient)
        EscrowContract->>EscrowContract: Validate milestone
        EscrowContract->>Issuer: Transfer ETB/crypto
        EscrowContract-->>DjangoAPI: FundsReleased event
        
        DjangoAPI->>DB: Update ReleaseRequest (status=completed)
        DjangoAPI->>DB: Record blockchain transaction
        DjangoAPI->>Issuer: Notification: "Funds released"
    end

    rect rgb(248, 240, 255)
        Note over System,Investors: Campaign Fails (Goal Not Met)
        System->>CampaignContract: Check deadline
        CampaignContract-->>System: expired, goal_not_reached
        System->>DjangoAPI: Trigger refund process
        
        loop For each investor
            DjangoAPI->>EscrowContract: refund(investor_address)
            EscrowContract->>Investors: Return funds
            EscrowContract-->>DjangoAPI: RefundProcessed event
            DjangoAPI->>DB: Update Investment (status=refunded)
        end
        
        DjangoAPI->>DB: Update Campaign (status=failed)
        DjangoAPI->>Issuer: Notification: "Campaign did not reach goal"
    end
```

---

## Sequence Diagram 8: NFT Share Certificate Minting

```mermaid
sequenceDiagram
    participant Investor
    participant DjangoAPI as Django API
    participant DB as PostgreSQL
    participant NFTMetadataGenerator
    participant IPFS
    participant NFTContract as NFTCertificate Contract
    participant Blockchain

    rect rgb(240, 248, 255)
        Note over Investor,DB: Investment Confirmed
        Investor->>DjangoAPI: Investment confirmed
        DjangoAPI->>DB: Investment (status=confirmed, nft_minted=false)
    end

    rect rgb(255, 248, 240)
        Note over DjangoAPI,IPFS: Generate Rich Metadata
        DjangoAPI->>NFTMetadataGenerator: generate_certificate_metadata(investment)
        NFTMetadataGenerator->>DB: Fetch Company branding (logo, description)
        NFTMetadataGenerator->>DB: Fetch Campaign details
        NFTMetadataGenerator->>NFTMetadataGenerator: Build ERC721 metadata
        Note over NFTMetadataGenerator: Includes issuer logo, sector,<br/>TIN, share details, voting power
        NFTMetadataGenerator-->>DjangoAPI: metadata JSON
        
        DjangoAPI->>IPFS: Upload metadata
        IPFS-->>DjangoAPI: ipfs_hash
    end

    rect rgb(240, 255, 240)
        Note over DjangoAPI,Blockchain: Mint NFT On-Chain
        DjangoAPI->>Blockchain: Prepare mint transaction
        Blockchain->>NFTContract: mint(investor_address, token_id, metadata_uri)
        NFTContract->>NFTContract: _safeMint()
        NFTContract->>NFTContract: _setTokenURI()
        NFTContract-->>Blockchain: Transfer event
        Blockchain-->>DjangoAPI: tx_hash, token_id
    end

    rect rgb(255, 240, 245)
        Note over DjangoAPI,Investor: Record & Notify
        DjangoAPI->>DB: Create NFTShareCertificate
        DjangoAPI->>DB: Update Investment (nft_minted=true, nft_token_id)
        DjangoAPI->>Investor: Notification: "Your NFT certificate is ready!"
        Investor->>DjangoAPI: GET /api/investments/{id}/nft/
        DjangoAPI->>Investor: {token_id, metadata, contract_address}
    end
```

---

## Viewing These Diagrams

1. **GitHub**: Push this file to GitHub - diagrams render automatically
2. **VS Code**: Install "Markdown Preview Mermaid Support" extension
3. **Online**: Copy diagrams to [mermaid.live](https://mermaid.live)
4. **Notion**: Paste Mermaid code blocks directly
