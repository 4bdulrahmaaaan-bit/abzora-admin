import React from 'react';
import { ActivityIndicator, FlatList, SafeAreaView, Text, View } from 'react-native';
import InvoiceCard from '../components/InvoiceCard';
import { useInvoices } from '../hooks/useInvoices';
import { Invoice } from '../types/invoice';

type Props = {
  onOpenInvoice: (invoice: Invoice) => void;
};

export default function InvoiceHistoryScreen({ onOpenInvoice }: Props) {
  const { loading, error, invoices, reload } = useInvoices();

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: '#F7F2E8' }}>
      <View style={{ padding: 16 }}>
        <Text style={{ fontSize: 22, fontWeight: '800', color: '#111' }}>Invoices</Text>
        <Text style={{ color: '#6F6658', marginTop: 4 }}>Your GST-ready ABZORA invoices</Text>
      </View>
      {loading ? (
        <ActivityIndicator color="#8B6A34" />
      ) : error ? (
        <View style={{ padding: 16 }}>
          <Text style={{ color: '#B00020' }}>{error}</Text>
          <Text onPress={reload} style={{ color: '#8B6A34', marginTop: 8 }}>Retry</Text>
        </View>
      ) : (
        <FlatList
          contentContainerStyle={{ padding: 16, paddingTop: 6 }}
          data={invoices}
          keyExtractor={(item) => item.id}
          renderItem={({ item }) => <InvoiceCard invoice={item} onPress={onOpenInvoice} />}
        />
      )}
    </SafeAreaView>
  );
}
