import { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  TouchableOpacity,
  ActivityIndicator,
  RefreshControl,
} from 'react-native';
import { api } from '../services/api';

interface Campaign {
  id: string;
  title: string;
  description: string;
  goal_amount: number;
  raised_amount: number;
  status: string;
  company: {
    name: string;
  };
}

interface Props {
  navigation: any;
}

export default function CampaignsScreen({ navigation }: Props) {
  const [campaigns, setCampaigns] = useState<Campaign[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [isRefreshing, setIsRefreshing] = useState(false);

  useEffect(() => {
    loadCampaigns();
  }, []);

  async function loadCampaigns() {
    const result = await api.getCampaigns();
    if (result.data) {
      setCampaigns(result.data);
    }
    setIsLoading(false);
    setIsRefreshing(false);
  }

  function handleRefresh() {
    setIsRefreshing(true);
    loadCampaigns();
  }

  function getProgress(raised: number, goal: number): number {
    if (!goal) return 0;
    return Math.min((raised / goal) * 100, 100);
  }

  function formatAmount(amount: number): string {
    return new Intl.NumberFormat('en-ET', {
      style: 'currency',
      currency: 'ETB',
      maximumFractionDigits: 0,
    }).format(amount || 0);
  }

  function renderCampaign({ item }: { item: Campaign }) {
    const progress = getProgress(item.raised_amount, item.goal_amount);
    
    return (
      <TouchableOpacity
        style={styles.campaignCard}
        onPress={() => navigation.navigate('CampaignDetail', { id: item.id })}
      >
        <View style={styles.cardHeader}>
          <Text style={styles.companyName}>{item.company?.name || 'Company'}</Text>
          <View style={[styles.statusBadge, styles[`status_${item.status}`]]}>
            <Text style={styles.statusText}>{item.status}</Text>
          </View>
        </View>
        
        <Text style={styles.campaignTitle}>{item.title}</Text>
        <Text style={styles.description} numberOfLines={2}>
          {item.description}
        </Text>
        
        <View style={styles.progressContainer}>
          <View style={styles.progressBar}>
            <View style={[styles.progressFill, { width: `${progress}%` }]} />
          </View>
          <Text style={styles.progressText}>{progress.toFixed(0)}%</Text>
        </View>
        
        <View style={styles.amountContainer}>
          <View>
            <Text style={styles.amountLabel}>Raised</Text>
            <Text style={styles.amount}>{formatAmount(item.raised_amount)}</Text>
          </View>
          <View style={styles.goalContainer}>
            <Text style={styles.amountLabel}>Goal</Text>
            <Text style={styles.amount}>{formatAmount(item.goal_amount)}</Text>
          </View>
        </View>
      </TouchableOpacity>
    );
  }

  if (isLoading) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color="#6366f1" />
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Investment Opportunities</Text>
      
      <FlatList
        data={campaigns}
        renderItem={renderCampaign}
        keyExtractor={(item) => item.id}
        contentContainerStyle={styles.listContent}
        refreshControl={
          <RefreshControl
            refreshing={isRefreshing}
            onRefresh={handleRefresh}
            tintColor="#6366f1"
          />
        }
        ListEmptyComponent={
          <Text style={styles.emptyText}>No campaigns available</Text>
        }
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#1a1a2e',
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#1a1a2e',
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#fff',
    padding: 20,
  },
  listContent: {
    padding: 16,
  },
  campaignCard: {
    backgroundColor: '#16213e',
    borderRadius: 16,
    padding: 16,
    marginBottom: 16,
  },
  cardHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  companyName: {
    fontSize: 12,
    color: '#888',
  },
  statusBadge: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 8,
  },
  status_active: {
    backgroundColor: '#22c55e33',
  },
  status_pending: {
    backgroundColor: '#f59e0b33',
  },
  status_completed: {
    backgroundColor: '#6366f133',
  },
  statusText: {
    fontSize: 10,
    color: '#fff',
    textTransform: 'uppercase',
  },
  campaignTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#fff',
    marginBottom: 8,
  },
  description: {
    fontSize: 14,
    color: '#888',
    marginBottom: 16,
  },
  progressContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 12,
  },
  progressBar: {
    flex: 1,
    height: 8,
    backgroundColor: '#374151',
    borderRadius: 4,
    marginRight: 8,
  },
  progressFill: {
    height: '100%',
    backgroundColor: '#6366f1',
    borderRadius: 4,
  },
  progressText: {
    color: '#6366f1',
    fontSize: 12,
    fontWeight: '600',
    width: 40,
    textAlign: 'right',
  },
  amountContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  goalContainer: {
    alignItems: 'flex-end',
  },
  amountLabel: {
    fontSize: 12,
    color: '#888',
  },
  amount: {
    fontSize: 16,
    fontWeight: '600',
    color: '#fff',
  },
  emptyText: {
    color: '#888',
    textAlign: 'center',
    marginTop: 40,
  },
});
