const API_BASE_URL = 'http://196.188.63.167:8000';

interface ApiResponse<T> {
  data?: T;
  error?: string;
}

class ApiService {
  private accessToken: string | null = null;
  private refreshToken: string | null = null;

  setTokens(access: string, refresh: string) {
    this.accessToken = access;
    this.refreshToken = refresh;
  }

  clearTokens() {
    this.accessToken = null;
    this.refreshToken = null;
  }

  private async request<T>(
    endpoint: string,
    options: RequestInit = {}
  ): Promise<ApiResponse<T>> {
    const headers: HeadersInit = {
      'Content-Type': 'application/json',
      ...(this.accessToken && { Authorization: `Bearer ${this.accessToken}` }),
      ...options.headers,
    };

    try {
      const response = await fetch(`${API_BASE_URL}${endpoint}`, {
        ...options,
        headers,
      });

      const data = await response.json();

      if (!response.ok) {
        return { error: data.error || data.detail || 'Request failed' };
      }

      return { data };
    } catch (error) {
      return { error: 'Network error' };
    }
  }

  async login(username: string, password: string) {
    const result = await this.request<{ access: string; refresh: string }>(
      '/api/auth/token/',
      {
        method: 'POST',
        body: JSON.stringify({ username, password }),
      }
    );

    if (result.data) {
      this.setTokens(result.data.access, result.data.refresh);
    }

    return result;
  }

  async register(username: string, email: string, password: string) {
    return this.request('/api/auth/register/', {
      method: 'POST',
      body: JSON.stringify({ username, email, password, role: 'investor' }),
    });
  }

  async getProfile() {
    return this.request<{
      id: string;
      username: string;
      email: string;
      role: string;
      wallet_address: string | null;
      kyc_verified: boolean;
    }>('/api/auth/me/');
  }

  async connectWallet(walletAddress: string, message: string, signature: string) {
    return this.request<{
      message: string;
      user: any;
      access: string;
      refresh: string;
    }>('/api/auth/wallet-connect/', {
      method: 'POST',
      body: JSON.stringify({
        wallet_address: walletAddress,
        message,
        signature,
      }),
    });
  }

  async getWalletBalance() {
    return this.request<{
      address: string;
      balance_wei: string;
      balance_eth: string;
    }>('/api/auth/wallet/balance/');
  }

  async getCampaigns() {
    return this.request<Array<{
      id: string;
      title: string;
      description: string;
      goal_amount: number;
      raised_amount: number;
      status: string;
      company: any;
    }>>('/api/campaigns/');
  }

  async getCampaign(id: string) {
    return this.request<any>(`/api/campaigns/${id}/`);
  }

  async createInvestment(campaignId: string, amount: number, paymentMethod: string) {
    return this.request<{
      id: string;
      amount: number;
      status: string;
      tx_hash?: string;
    }>('/api/investments/', {
      method: 'POST',
      body: JSON.stringify({
        campaign: campaignId,
        amount,
        payment_method: paymentMethod,
      }),
    });
  }

  async getInvestments() {
    return this.request<Array<{
      id: string;
      campaign: any;
      amount: number;
      status: string;
      nft_token_id?: number;
    }>>('/api/investments/');
  }
}

export const api = new ApiService();
