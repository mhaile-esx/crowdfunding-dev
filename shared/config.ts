/**
 * Platform Configuration
 * Controls regional settings and module availability
 */

export interface PlatformConfig {
  region: {
    name: string;
    currency: string;
    currencyCode: string;
    countries: string[];
    stockExchanges: string[];
    regulatoryFramework: string;
  };
  modules: {
    campaigns: boolean;
    agriculture: boolean;
    governance: boolean;
    nftShares: boolean;
    insurance: boolean;
    defiYield: boolean;
    adminPanel: boolean;
  };
  features: {
    multiPaymentGateways: boolean;
    blockchainIntegration: boolean;
    kycVerification: boolean;
    smartContracts: boolean;
    mobilePayments: boolean;
  };
}

// Default configuration for African deployment
export const defaultPlatformConfig: PlatformConfig = {
  region: {
    name: "Africa",
    currency: "African Franc", // Configurable per country
    currencyCode: "XAF", // Configurable per country
    countries: [
      "Nigeria", "Kenya", "Ethiopia", "Ghana", "South Africa", 
      "Tanzania", "Uganda", "Rwanda", "Morocco", "Egypt",
      "Botswana", "Namibia", "Zambia", "Zimbabwe", "Senegal",
      "Mali", "Burkina Faso", "Ivory Coast", "Cameroon", "Chad"
    ],
    stockExchanges: [
      "Nigerian Exchange (NGX)",
      "Nairobi Securities Exchange (NSE)", 
      "Ethiopian Securities Exchange (ESX)",
      "Ghana Stock Exchange (GSE)",
      "Johannesburg Stock Exchange (JSE)",
      "Dar es Salaam Stock Exchange (DSE)",
      "Uganda Securities Exchange (USE)",
      "Rwanda Stock Exchange (RSE)",
      "Casablanca Stock Exchange (CSE)",
      "Egyptian Exchange (EGX)"
    ],
    regulatoryFramework: "African Capital Markets"
  },
  modules: {
    campaigns: true,
    agriculture: true,
    governance: true,
    nftShares: true,
    insurance: true,
    defiYield: true,
    adminPanel: true
  },
  features: {
    multiPaymentGateways: true,
    blockchainIntegration: true,
    kycVerification: true,
    smartContracts: true,
    mobilePayments: true
  }
};

// Country-specific configurations
export const countryConfigs: Record<string, Partial<PlatformConfig>> = {
  nigeria: {
    region: {
      name: "Nigeria",
      currency: "Naira",
      currencyCode: "NGN",
      countries: ["Nigeria"],
      stockExchanges: ["Nigerian Exchange (NGX)"],
      regulatoryFramework: "Securities and Exchange Commission (SEC)"
    }
  },
  kenya: {
    region: {
      name: "Kenya", 
      currency: "Kenyan Shilling",
      currencyCode: "KES",
      countries: ["Kenya"],
      stockExchanges: ["Nairobi Securities Exchange (NSE)"],
      regulatoryFramework: "Capital Markets Authority (CMA)"
    }
  },
  ethiopia: {
    region: {
      name: "Ethiopia",
      currency: "Ethiopian Birr", 
      currencyCode: "ETB",
      countries: ["Ethiopia"],
      stockExchanges: ["Ethiopian Securities Exchange (ESX)"],
      regulatoryFramework: "National Bank of Ethiopia (NBE)"
    }
  },
  ghana: {
    region: {
      name: "Ghana",
      currency: "Ghana Cedi",
      currencyCode: "GHS", 
      countries: ["Ghana"],
      stockExchanges: ["Ghana Stock Exchange (GSE)"],
      regulatoryFramework: "Securities and Exchange Commission"
    }
  },
  southafrica: {
    region: {
      name: "South Africa",
      currency: "South African Rand",
      currencyCode: "ZAR",
      countries: ["South Africa"],
      stockExchanges: ["Johannesburg Stock Exchange (JSE)"],
      regulatoryFramework: "Financial Sector Conduct Authority (FSCA)"
    }
  }
};

// Module configuration schema
export interface ModuleConfig {
  id: string;
  name: string;
  description: string;
  enabled: boolean;
  dependencies?: string[];
  routes: string[];
  permissions: string[];
}

export const moduleDefinitions: ModuleConfig[] = [
  {
    id: "campaigns",
    name: "Traditional Campaigns",
    description: "Standard crowdfunding campaigns for businesses and startups",
    enabled: true,
    routes: ["/campaigns", "/create", "/campaigns/:id"],
    permissions: ["campaigns.view", "campaigns.create", "campaigns.invest"]
  },
  {
    id: "agriculture", 
    name: "Agricultural Finance",
    description: "Farm yield tracking, agricultural campaigns, and insurance integration",
    enabled: true,
    dependencies: ["campaigns"],
    routes: ["/agriculture", "/agriculture/create", "/agriculture/:id"],
    permissions: ["agriculture.view", "agriculture.create", "agriculture.invest", "agriculture.insure"]
  },
  {
    id: "governance",
    name: "DAO Governance", 
    description: "Decentralized governance with proposal creation and voting",
    enabled: true,
    dependencies: ["campaigns", "nftShares"],
    routes: ["/governance", "/governance/:id"],
    permissions: ["governance.view", "governance.propose", "governance.vote"]
  },
  {
    id: "nftShares",
    name: "NFT Share Certificates",
    description: "Blockchain-based investment certificates and portfolio management",
    enabled: true,
    dependencies: ["campaigns"],
    routes: ["/nft-shares", "/portfolio"],
    permissions: ["nft.view", "nft.mint", "nft.transfer"]
  },
  {
    id: "insurance",
    name: "Insurance Integration",
    description: "Investment protection and agricultural insurance coverage",
    enabled: true,
    dependencies: ["campaigns"],
    routes: ["/insurance", "/insurance/quotes"],
    permissions: ["insurance.view", "insurance.purchase", "insurance.claim"]
  },
  {
    id: "defiYield",
    name: "DeFi Yield Farming",
    description: "Automated yield generation and fund optimization",
    enabled: true,
    dependencies: ["campaigns"],
    routes: ["/defi", "/yield"],
    permissions: ["defi.view", "defi.stake", "defi.harvest"]
  },
  {
    id: "adminPanel",
    name: "Admin Control Panel",
    description: "Platform administration and user management",
    enabled: true,
    routes: ["/admin", "/admin/users", "/admin/campaigns"],
    permissions: ["admin.view", "admin.manage", "admin.configure"]
  }
];

// Environment-based configuration loading
export function getPlatformConfig(): PlatformConfig {
  const country = process.env.PLATFORM_COUNTRY?.toLowerCase() || "africa";
  const baseConfig = defaultPlatformConfig;
  
  if (country !== "africa" && countryConfigs[country]) {
    return {
      ...baseConfig,
      ...countryConfigs[country],
      region: {
        ...baseConfig.region,
        ...countryConfigs[country].region
      }
    };
  }
  
  return baseConfig;
}

// Module configuration management
export function getEnabledModules(): ModuleConfig[] {
  const config = getPlatformConfig();
  return moduleDefinitions.filter(module => config.modules[module.id as keyof typeof config.modules]);
}

export function isModuleEnabled(moduleId: string): boolean {
  const config = getPlatformConfig();
  return config.modules[moduleId as keyof typeof config.modules] || false;
}

export function getModuleRoutes(): string[] {
  return getEnabledModules().flatMap(module => module.routes);
}

export function getModulePermissions(): string[] {
  return getEnabledModules().flatMap(module => module.permissions);
}