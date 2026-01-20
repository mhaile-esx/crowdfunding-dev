import { createContext, useContext, useState, useEffect, ReactNode } from 'react';
import { api } from '../services/api';
import { walletService } from '../services/wallet';
import * as SecureStore from 'expo-secure-store';

interface User {
  id: string;
  username: string;
  email: string;
  role: string;
  wallet_address: string | null;
  kyc_verified: boolean;
}

interface AuthContextType {
  user: User | null;
  isLoading: boolean;
  isAuthenticated: boolean;
  walletAddress: string | null;
  login: (username: string, password: string) => Promise<{ success: boolean; error?: string }>;
  logout: () => Promise<void>;
  connectWallet: () => Promise<{ success: boolean; error?: string }>;
  refreshProfile: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [walletAddress, setWalletAddress] = useState<string | null>(null);

  useEffect(() => {
    loadStoredAuth();
  }, []);

  async function loadStoredAuth() {
    try {
      const accessToken = await SecureStore.getItemAsync('access_token');
      const refreshToken = await SecureStore.getItemAsync('refresh_token');
      
      if (accessToken && refreshToken) {
        api.setTokens(accessToken, refreshToken);
        const result = await api.getProfile();
        if (result.data) {
          setUser(result.data);
        }
      }
      
      const wallet = await walletService.loadWallet();
      if (wallet) {
        setWalletAddress(wallet.address);
      }
    } catch (error) {
      console.error('Error loading auth:', error);
    } finally {
      setIsLoading(false);
    }
  }

  async function login(username: string, password: string) {
    const result = await api.login(username, password);
    
    if (result.error) {
      return { success: false, error: result.error };
    }
    
    if (result.data) {
      await SecureStore.setItemAsync('access_token', result.data.access);
      await SecureStore.setItemAsync('refresh_token', result.data.refresh);
      
      const profileResult = await api.getProfile();
      if (profileResult.data) {
        setUser(profileResult.data);
      }
      
      return { success: true };
    }
    
    return { success: false, error: 'Unknown error' };
  }

  async function logout() {
    await SecureStore.deleteItemAsync('access_token');
    await SecureStore.deleteItemAsync('refresh_token');
    api.clearTokens();
    setUser(null);
  }

  async function connectWallet() {
    if (!walletAddress) {
      return { success: false, error: 'No wallet available. Create or import a wallet first.' };
    }
    
    try {
      const { message } = walletService.generateConnectMessage();
      const signature = await walletService.signMessage(message);
      
      const result = await api.connectWallet(walletAddress, message, signature);
      
      if (result.error) {
        return { success: false, error: result.error };
      }
      
      if (result.data) {
        await SecureStore.setItemAsync('access_token', result.data.access);
        await SecureStore.setItemAsync('refresh_token', result.data.refresh);
        api.setTokens(result.data.access, result.data.refresh);
        setUser(result.data.user);
        return { success: true };
      }
      
      return { success: false, error: 'Unknown error' };
    } catch (error) {
      return { success: false, error: 'Failed to sign message' };
    }
  }

  async function refreshProfile() {
    const result = await api.getProfile();
    if (result.data) {
      setUser(result.data);
    }
  }

  return (
    <AuthContext.Provider
      value={{
        user,
        isLoading,
        isAuthenticated: !!user,
        walletAddress,
        login,
        logout,
        connectWallet,
        refreshProfile,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}
