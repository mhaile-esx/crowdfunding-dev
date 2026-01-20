import { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Alert,
  ActivityIndicator,
} from 'react-native';
import { walletService } from '../services/wallet';
import { api } from '../services/api';
import { useAuth } from '../context/AuthContext';

export default function WalletScreen() {
  const { user, walletAddress, connectWallet, refreshProfile } = useAuth();
  const [balance, setBalance] = useState<string>('0');
  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => {
    if (user?.wallet_address) {
      loadBalance();
    }
  }, [user?.wallet_address]);

  async function loadBalance() {
    const result = await api.getWalletBalance();
    if (result.data) {
      setBalance(result.data.balance_eth);
    }
  }

  async function handleCreateWallet() {
    setIsLoading(true);
    try {
      const wallet = await walletService.createWallet();
      Alert.alert(
        'Wallet Created',
        `Your new wallet address:\n${wallet.address}\n\nPlease backup your wallet securely.`
      );
    } catch (error) {
      Alert.alert('Error', 'Failed to create wallet');
    } finally {
      setIsLoading(false);
    }
  }

  async function handleConnectWallet() {
    setIsLoading(true);
    const result = await connectWallet();
    setIsLoading(false);
    
    if (result.success) {
      Alert.alert('Success', 'Wallet connected to your account!');
      await refreshProfile();
    } else {
      Alert.alert('Error', result.error || 'Failed to connect wallet');
    }
  }

  const displayAddress = user?.wallet_address || walletAddress;

  return (
    <View style={styles.container}>
      <Text style={styles.title}>ESX Wallet</Text>
      
      {displayAddress ? (
        <View style={styles.walletCard}>
          <Text style={styles.label}>Wallet Address</Text>
          <Text style={styles.address} numberOfLines={1} ellipsizeMode="middle">
            {displayAddress}
          </Text>
          
          <View style={styles.balanceContainer}>
            <Text style={styles.balanceLabel}>Balance</Text>
            <Text style={styles.balance}>{balance} ETH</Text>
          </View>
          
          {!user?.wallet_address && walletAddress && (
            <TouchableOpacity
              style={styles.button}
              onPress={handleConnectWallet}
              disabled={isLoading}
            >
              {isLoading ? (
                <ActivityIndicator color="#fff" />
              ) : (
                <Text style={styles.buttonText}>Connect to Account</Text>
              )}
            </TouchableOpacity>
          )}
        </View>
      ) : (
        <View style={styles.noWallet}>
          <Text style={styles.noWalletText}>No wallet found</Text>
          
          <TouchableOpacity
            style={styles.button}
            onPress={handleCreateWallet}
            disabled={isLoading}
          >
            {isLoading ? (
              <ActivityIndicator color="#fff" />
            ) : (
              <Text style={styles.buttonText}>Create New Wallet</Text>
            )}
          </TouchableOpacity>
          
          <TouchableOpacity
            style={[styles.button, styles.secondaryButton]}
            onPress={() => Alert.alert('Import', 'Import wallet coming soon')}
          >
            <Text style={styles.buttonText}>Import Existing Wallet</Text>
          </TouchableOpacity>
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#1a1a2e',
    padding: 20,
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#fff',
    marginBottom: 30,
    textAlign: 'center',
  },
  walletCard: {
    backgroundColor: '#16213e',
    borderRadius: 16,
    padding: 20,
  },
  label: {
    fontSize: 14,
    color: '#888',
    marginBottom: 8,
  },
  address: {
    fontSize: 16,
    color: '#fff',
    fontFamily: 'monospace',
    marginBottom: 20,
  },
  balanceContainer: {
    alignItems: 'center',
    marginVertical: 20,
  },
  balanceLabel: {
    fontSize: 14,
    color: '#888',
  },
  balance: {
    fontSize: 36,
    fontWeight: 'bold',
    color: '#4ade80',
  },
  noWallet: {
    alignItems: 'center',
    justifyContent: 'center',
    flex: 1,
  },
  noWalletText: {
    fontSize: 18,
    color: '#888',
    marginBottom: 30,
  },
  button: {
    backgroundColor: '#6366f1',
    paddingVertical: 16,
    paddingHorizontal: 32,
    borderRadius: 12,
    marginTop: 16,
    minWidth: 200,
    alignItems: 'center',
  },
  secondaryButton: {
    backgroundColor: '#374151',
  },
  buttonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
});
