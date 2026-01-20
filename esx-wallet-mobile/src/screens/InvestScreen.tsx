import { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TextInput,
  TouchableOpacity,
  Alert,
  ActivityIndicator,
  ScrollView,
} from 'react-native';
import { api } from '../services/api';
import { useAuth } from '../context/AuthContext';

interface Props {
  route: {
    params: {
      campaignId: string;
      campaignTitle: string;
    };
  };
  navigation: any;
}

const PAYMENT_METHODS = [
  { id: 'crypto', label: 'Crypto (ETH)', icon: 'ETH' },
  { id: 'telebirr', label: 'Telebirr', icon: 'TB' },
  { id: 'cbe', label: 'CBE Birr', icon: 'CBE' },
  { id: 'awash', label: 'Awash Bank', icon: 'AW' },
];

export default function InvestScreen({ route, navigation }: Props) {
  const { campaignId, campaignTitle } = route.params;
  const { user } = useAuth();
  const [amount, setAmount] = useState('');
  const [paymentMethod, setPaymentMethod] = useState('crypto');
  const [isLoading, setIsLoading] = useState(false);

  async function handleInvest() {
    if (!amount || isNaN(Number(amount))) {
      Alert.alert('Error', 'Please enter a valid amount');
      return;
    }

    if (paymentMethod === 'crypto' && !user?.wallet_address) {
      Alert.alert('Error', 'Please connect your wallet first');
      return;
    }

    setIsLoading(true);
    
    const result = await api.createInvestment(
      campaignId,
      Number(amount),
      paymentMethod
    );
    
    setIsLoading(false);

    if (result.error) {
      Alert.alert('Error', result.error);
      return;
    }

    Alert.alert(
      'Investment Successful!',
      `You have invested ${amount} ETB in ${campaignTitle}.\n\nYou will receive an NFT certificate once the investment is confirmed.`,
      [
        {
          text: 'View Investments',
          onPress: () => navigation.navigate('Portfolio'),
        },
      ]
    );
  }

  return (
    <ScrollView style={styles.container}>
      <Text style={styles.title}>Invest in</Text>
      <Text style={styles.campaignTitle}>{campaignTitle}</Text>

      <View style={styles.section}>
        <Text style={styles.label}>Investment Amount (ETB)</Text>
        <TextInput
          style={styles.input}
          placeholder="Enter amount"
          placeholderTextColor="#666"
          keyboardType="numeric"
          value={amount}
          onChangeText={setAmount}
        />
        
        <View style={styles.quickAmounts}>
          {['1000', '5000', '10000', '50000'].map((preset) => (
            <TouchableOpacity
              key={preset}
              style={styles.quickButton}
              onPress={() => setAmount(preset)}
            >
              <Text style={styles.quickButtonText}>{preset}</Text>
            </TouchableOpacity>
          ))}
        </View>
      </View>

      <View style={styles.section}>
        <Text style={styles.label}>Payment Method</Text>
        {PAYMENT_METHODS.map((method) => (
          <TouchableOpacity
            key={method.id}
            style={[
              styles.paymentOption,
              paymentMethod === method.id && styles.paymentOptionSelected,
            ]}
            onPress={() => setPaymentMethod(method.id)}
          >
            <View style={styles.paymentIcon}>
              <Text style={styles.paymentIconText}>{method.icon}</Text>
            </View>
            <Text style={styles.paymentLabel}>{method.label}</Text>
            {paymentMethod === method.id && (
              <View style={styles.checkmark}>
                <Text style={styles.checkmarkText}>✓</Text>
              </View>
            )}
          </TouchableOpacity>
        ))}
      </View>

      {paymentMethod === 'crypto' && !user?.wallet_address && (
        <View style={styles.warning}>
          <Text style={styles.warningText}>
            Connect your wallet to invest with crypto
          </Text>
        </View>
      )}

      <TouchableOpacity
        style={[styles.investButton, isLoading && styles.investButtonDisabled]}
        onPress={handleInvest}
        disabled={isLoading}
      >
        {isLoading ? (
          <ActivityIndicator color="#fff" />
        ) : (
          <Text style={styles.investButtonText}>Confirm Investment</Text>
        )}
      </TouchableOpacity>

      <Text style={styles.disclaimer}>
        By investing, you agree to the terms and conditions. All investments
        carry risk. You may lose your entire investment.
      </Text>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#1a1a2e',
    padding: 20,
  },
  title: {
    fontSize: 16,
    color: '#888',
  },
  campaignTitle: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#fff',
    marginBottom: 30,
  },
  section: {
    marginBottom: 24,
  },
  label: {
    fontSize: 14,
    color: '#888',
    marginBottom: 12,
  },
  input: {
    backgroundColor: '#16213e',
    borderRadius: 12,
    padding: 16,
    fontSize: 18,
    color: '#fff',
    marginBottom: 12,
  },
  quickAmounts: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  quickButton: {
    backgroundColor: '#374151',
    paddingVertical: 8,
    paddingHorizontal: 16,
    borderRadius: 8,
  },
  quickButtonText: {
    color: '#fff',
    fontSize: 12,
  },
  paymentOption: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#16213e',
    borderRadius: 12,
    padding: 16,
    marginBottom: 8,
  },
  paymentOptionSelected: {
    borderWidth: 2,
    borderColor: '#6366f1',
  },
  paymentIcon: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: '#374151',
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 12,
  },
  paymentIconText: {
    color: '#fff',
    fontSize: 12,
    fontWeight: 'bold',
  },
  paymentLabel: {
    color: '#fff',
    fontSize: 16,
    flex: 1,
  },
  checkmark: {
    width: 24,
    height: 24,
    borderRadius: 12,
    backgroundColor: '#6366f1',
    justifyContent: 'center',
    alignItems: 'center',
  },
  checkmarkText: {
    color: '#fff',
    fontSize: 14,
  },
  warning: {
    backgroundColor: '#f59e0b33',
    borderRadius: 8,
    padding: 12,
    marginBottom: 20,
  },
  warningText: {
    color: '#f59e0b',
    textAlign: 'center',
  },
  investButton: {
    backgroundColor: '#6366f1',
    borderRadius: 12,
    padding: 18,
    alignItems: 'center',
    marginTop: 20,
  },
  investButtonDisabled: {
    opacity: 0.6,
  },
  investButtonText: {
    color: '#fff',
    fontSize: 18,
    fontWeight: 'bold',
  },
  disclaimer: {
    fontSize: 12,
    color: '#666',
    textAlign: 'center',
    marginTop: 20,
    lineHeight: 18,
  },
});
