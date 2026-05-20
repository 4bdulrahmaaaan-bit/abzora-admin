import { useEffect, useState, useCallback } from 'react';
import { fetchMyInvoices } from '../api/invoiceApi';
import { Invoice } from '../types/invoice';

export function useInvoices() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [invoices, setInvoices] = useState<Invoice[]>([]);

  const reload = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const rows = await fetchMyInvoices();
      setInvoices(rows);
    } catch (err: any) {
      setError(err?.response?.data?.message ?? 'Failed to load invoices');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void reload();
  }, [reload]);

  return { loading, error, invoices, reload };
}
