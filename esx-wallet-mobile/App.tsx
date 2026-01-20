import { StatusBar } from 'expo-status-bar';
import { NavigationContainer } from '@react-navigation/native';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { AuthProvider, useAuth } from './src/context/AuthContext';
import { View, Text, ActivityIndicator, StyleSheet } from 'react-native';

import WalletScreen from './src/screens/WalletScreen';
import CampaignsScreen from './src/screens/CampaignsScreen';
import InvestScreen from './src/screens/InvestScreen';

const Tab = createBottomTabNavigator();
const Stack = createNativeStackNavigator();
const queryClient = new QueryClient();

function TabIcon({ name, focused }: { name: string; focused: boolean }) {
  const icons: Record<string, string> = {
    Wallet: '💰',
    Campaigns: '📊',
    Portfolio: '📈',
    Profile: '👤',
  };
  
  return (
    <Text style={{ fontSize: focused ? 28 : 24, opacity: focused ? 1 : 0.6 }}>
      {icons[name] || '•'}
    </Text>
  );
}

function PortfolioScreen() {
  return (
    <View style={styles.placeholder}>
      <Text style={styles.placeholderIcon}>📈</Text>
      <Text style={styles.placeholderTitle}>My Portfolio</Text>
      <Text style={styles.placeholderText}>Your investments and NFT certificates will appear here</Text>
    </View>
  );
}

function ProfileScreen() {
  const { user, logout } = useAuth();
  
  return (
    <View style={styles.placeholder}>
      <Text style={styles.placeholderIcon}>👤</Text>
      <Text style={styles.placeholderTitle}>{user?.username || 'Guest'}</Text>
      <Text style={styles.placeholderText}>{user?.email}</Text>
      <Text style={styles.placeholderText}>Role: {user?.role}</Text>
    </View>
  );
}

function CampaignStack() {
  return (
    <Stack.Navigator
      screenOptions={{
        headerStyle: { backgroundColor: '#1a1a2e' },
        headerTintColor: '#fff',
      }}
    >
      <Stack.Screen
        name="CampaignsList"
        component={CampaignsScreen}
        options={{ headerShown: false }}
      />
      <Stack.Screen
        name="Invest"
        component={InvestScreen}
        options={{ title: 'Invest' }}
      />
    </Stack.Navigator>
  );
}

function MainTabs() {
  return (
    <Tab.Navigator
      screenOptions={({ route }) => ({
        tabBarIcon: ({ focused }) => <TabIcon name={route.name} focused={focused} />,
        tabBarStyle: {
          backgroundColor: '#16213e',
          borderTopColor: '#374151',
          paddingBottom: 8,
          paddingTop: 8,
          height: 70,
        },
        tabBarActiveTintColor: '#6366f1',
        tabBarInactiveTintColor: '#888',
        headerStyle: { backgroundColor: '#1a1a2e' },
        headerTintColor: '#fff',
      })}
    >
      <Tab.Screen name="Wallet" component={WalletScreen} />
      <Tab.Screen
        name="Campaigns"
        component={CampaignStack}
        options={{ headerShown: false }}
      />
      <Tab.Screen name="Portfolio" component={PortfolioScreen} />
      <Tab.Screen name="Profile" component={ProfileScreen} />
    </Tab.Navigator>
  );
}

function AppContent() {
  const { isLoading } = useAuth();

  if (isLoading) {
    return (
      <View style={styles.loading}>
        <ActivityIndicator size="large" color="#6366f1" />
        <Text style={styles.loadingText}>Loading ESX Wallet...</Text>
      </View>
    );
  }

  return (
    <NavigationContainer>
      <MainTabs />
      <StatusBar style="light" />
    </NavigationContainer>
  );
}

export default function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <AuthProvider>
        <AppContent />
      </AuthProvider>
    </QueryClientProvider>
  );
}

const styles = StyleSheet.create({
  loading: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#1a1a2e',
  },
  loadingText: {
    color: '#888',
    marginTop: 16,
  },
  placeholder: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#1a1a2e',
    padding: 40,
  },
  placeholderIcon: {
    fontSize: 64,
    marginBottom: 16,
  },
  placeholderTitle: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#fff',
    marginBottom: 8,
  },
  placeholderText: {
    fontSize: 14,
    color: '#888',
    textAlign: 'center',
  },
});
