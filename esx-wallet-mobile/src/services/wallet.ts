import { ethers } from 'ethers';
import * as SecureStore from 'expo-secure-store';

const WALLET_KEY = 'esx_wallet_private_key';
const WALLET_ADDRESS_KEY = 'esx_wallet_address';

export interface WalletData {
  address: string;
  privateKey: string;
}

class WalletService {
  private wallet: ethers.Wallet | null = null;

  async createWallet(): Promise<WalletData> {
    const wallet = ethers.Wallet.createRandom();
    
    await SecureStore.setItemAsync(WALLET_KEY, wallet.privateKey);
    await SecureStore.setItemAsync(WALLET_ADDRESS_KEY, wallet.address);
    
    this.wallet = wallet;
    
    return {
      address: wallet.address,
      privateKey: wallet.privateKey,
    };
  }

  async importWallet(privateKey: string): Promise<WalletData> {
    const wallet = new ethers.Wallet(privateKey);
    
    await SecureStore.setItemAsync(WALLET_KEY, wallet.privateKey);
    await SecureStore.setItemAsync(WALLET_ADDRESS_KEY, wallet.address);
    
    this.wallet = wallet;
    
    return {
      address: wallet.address,
      privateKey: wallet.privateKey,
    };
  }

  async loadWallet(): Promise<WalletData | null> {
    const privateKey = await SecureStore.getItemAsync(WALLET_KEY);
    const address = await SecureStore.getItemAsync(WALLET_ADDRESS_KEY);
    
    if (privateKey && address) {
      this.wallet = new ethers.Wallet(privateKey);
      return { address, privateKey };
    }
    
    return null;
  }

  async deleteWallet(): Promise<void> {
    await SecureStore.deleteItemAsync(WALLET_KEY);
    await SecureStore.deleteItemAsync(WALLET_ADDRESS_KEY);
    this.wallet = null;
  }

  async signMessage(message: string): Promise<string> {
    if (!this.wallet) {
      const loaded = await this.loadWallet();
      if (!loaded) {
        throw new Error('No wallet available');
      }
    }
    
    return await this.wallet!.signMessage(message);
  }

  generateConnectMessage(): { message: string; timestamp: number } {
    const timestamp = Date.now();
    const message = `Login to CrowdfundChain at ${timestamp}`;
    return { message, timestamp };
  }

  getAddress(): string | null {
    return this.wallet?.address || null;
  }

  isLoaded(): boolean {
    return this.wallet !== null;
  }
}

export const walletService = new WalletService();
