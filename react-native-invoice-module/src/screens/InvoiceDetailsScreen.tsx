import React, { useEffect, useState } from 'react';
import { ActivityIndicator, Alert, Linking, Pressable, SafeAreaView, ScrollView, Share, Text, View } from 'react-native';
import { emailInvoice, fetchInvoice, getSignedDownloadUrl } from '../api/invoiceApi';
import { Invoice } from '../types/invoice';

type Props = {
  invoiceId: string;
};

export default function InvoiceDetailsScreen({ invoiceId }: Props) {
  const [loading, setLoading] = useState(true);
  const [invoice, setInvoice] = useState<Invoice | null>(null);

  useEffect(() => {
    (async () => {
      try {
        setInvoice(await fetchInvoice(invoiceId));
      } catch {
        Alert.alert('Unable to load invoice');
      } finally {
        setLoading(false);
      }
    })();
  }, [invoiceId]);

  const onDownload = async () => {
    if (!invoice) return;
    const signedUrl = await getSignedDownloadUrl(invoice.id);
    await Linking.openURL(signedUrl);
  };

  const onShare = async () => {
    if (!invoice) return;
    const signedUrl = await getSignedDownloadUrl(invoice.id);
    await Share.share({ message: `Invoice ${invoice.invoiceNumber}\n${signedUrl}` });
  };

  const onEmail = async () => {
    if (!invoice) return;
    await emailInvoice(invoice.id);
    Alert.alert('Invoice email queued');
  };

  if (loading || !invoice) {
    return <ActivityIndicator color="#8B6A34" style={{ marginTop: 40 }} />;
  }

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: '#F7F2E8' }}>
      <ScrollView contentContainerStyle={{ padding: 16 }}>
        <Text style={{ fontSize: 20, fontWeight: '800', color: '#111' }}>{invoice.invoiceNumber}</Text>
        <Text style={{ color: '#6F6658', marginTop: 4 }}>Order #{invoice.orderId.slice(-8)}</Text>
        <View style={{ marginTop: 14, backgroundColor: '#FFF', borderRadius: 14, padding: 14, borderWidth: 1, borderColor: '#E6DDCF' }}>
          <Text>Subtotal: INR {invoice.subtotal.toFixed(2)}</Text>
          <Text>Discount: INR {invoice.discount.toFixed(2)}</Text>
          <Text>CGST: INR {invoice.cgst.toFixed(2)}</Text>
          <Text>SGST: INR {invoice.sgst.toFixed(2)}</Text>
          <Text>IGST: INR {invoice.igst.toFixed(2)}</Text>
          <Text style={{ marginTop: 8, fontWeight: '800' }}>Grand Total: INR {invoice.grandTotal.toFixed(2)}</Text>
        </View>
        <View style={{ flexDirection: 'row', gap: 10, marginTop: 14 }}>
          <Action title="Download" onPress={onDownload} />
          <Action title="Share" onPress={onShare} />
          <Action title="Email" onPress={onEmail} />
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

function Action({ title, onPress }: { title: string; onPress: () => void }) {
  return (
    <Pressable onPress={onPress} style={{ flex: 1, borderRadius: 12, paddingVertical: 12, backgroundColor: '#1B1B1B' }} accessibilityRole="button">
      <Text style={{ textAlign: 'center', color: '#F5E1B8', fontWeight: '700' }}>{title}</Text>
    </Pressable>
  );
}
