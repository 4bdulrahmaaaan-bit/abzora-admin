import axios from 'axios';
import { Invoice } from '../types/invoice';

const api = axios.create({
  baseURL: process.env.EXPO_PUBLIC_API_BASE_URL ?? 'https://abzora-backend.onrender.com',
  timeout: 20000,
});

export function setAuthToken(token: string) {
  api.defaults.headers.common.Authorization = `Bearer ${token}`;
}

export async function fetchMyInvoices(): Promise<Invoice[]> {
  const { data } = await api.get('/api/invoices/my');
  return data.data;
}

export async function fetchInvoice(invoiceId: string): Promise<Invoice> {
  const { data } = await api.get(`/api/invoices/${invoiceId}`);
  return data.data;
}

export async function getSignedDownloadUrl(invoiceId: string): Promise<string> {
  const { data } = await api.get(`/api/invoices/download-link/${invoiceId}`);
  return `${api.defaults.baseURL}${data.data.signedUrl}`;
}

export async function emailInvoice(invoiceId: string): Promise<void> {
  await api.post(`/api/invoices/${invoiceId}/email`);
}

export default api;
