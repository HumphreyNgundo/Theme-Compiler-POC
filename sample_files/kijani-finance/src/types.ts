export interface Transaction {
  id: string;
  type: 'send' | 'receive' | 'paybill' | 'till' | 'airtime';
  title: string;
  subtitle: string;
  amount: number;
  date: string;
  status: 'success' | 'pending' | 'failed';
}

export interface Account {
  id: string;
  type: 'Savings' | 'Current' | 'Wallet';
  balance: number;
  accountNumber: string;
}

export const MOCK_ACCOUNTS: Account[] = [
  { id: '1', type: 'Wallet', balance: 45250.50, accountNumber: '0712****89' },
  { id: '2', type: 'Savings', balance: 125000.00, accountNumber: '8829****12' },
];

export const MOCK_TRANSACTIONS: Transaction[] = [
  { id: '1', type: 'send', title: 'Sent to John Doe', subtitle: 'M-Pesa Transfer', amount: -2500, date: 'Today, 10:45 AM', status: 'success' },
  { id: '2', type: 'receive', title: 'Received from Jane Smith', subtitle: 'Mobile Money', amount: 5000, date: 'Yesterday, 04:20 PM', status: 'success' },
  { id: '3', type: 'paybill', title: 'Kenya Power', subtitle: 'Paybill 888888', amount: -1200, date: 'Apr 08, 2026', status: 'success' },
  { id: '4', type: 'airtime', title: 'Safaricom Airtime', subtitle: 'Self Purchase', amount: -500, date: 'Apr 07, 2026', status: 'success' },
  { id: '5', type: 'till', title: 'Java House', subtitle: 'Till 123456', amount: -850, date: 'Apr 07, 2026', status: 'failed' },
];
