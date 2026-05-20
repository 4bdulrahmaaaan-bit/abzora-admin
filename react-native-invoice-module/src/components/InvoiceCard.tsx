import React from 'react';
import { View, Text, Pressable, StyleSheet } from 'react-native';
import { Invoice } from '../types/invoice';

type Props = {
  invoice: Invoice;
  onPress: (invoice: Invoice) => void;
};

export default function InvoiceCard({ invoice, onPress }: Props) {
  return (
    <Pressable
      onPress={() => onPress(invoice)}
      style={({ pressed }) => [styles.card, pressed && styles.cardPressed]}
      accessibilityRole="button"
      accessibilityLabel={`Invoice ${invoice.invoiceNumber}`}
    >
      <View style={styles.row}>
        <Text style={styles.number}>{invoice.invoiceNumber}</Text>
        <Text style={styles.status}>{invoice.status.toUpperCase()}</Text>
      </View>
      <Text style={styles.sub}>Order #{invoice.orderId.slice(-8)}</Text>
      <Text style={styles.total}>INR {invoice.grandTotal.toFixed(2)}</Text>
      <Text style={styles.sub}>{new Date(invoice.generatedAt).toLocaleDateString()}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  card: {
    borderRadius: 16,
    borderWidth: 1,
    borderColor: '#E5DDCF',
    padding: 14,
    backgroundColor: '#FFFCF7',
    marginBottom: 12,
  },
  cardPressed: { opacity: 0.8, transform: [{ scale: 0.99 }] },
  row: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  number: { fontSize: 14, fontWeight: '700', color: '#1A1A1A' },
  status: { fontSize: 11, fontWeight: '700', color: '#7C6740' },
  total: { fontSize: 16, fontWeight: '800', color: '#111', marginTop: 6 },
  sub: { marginTop: 4, color: '#7B7468', fontSize: 12 },
});
