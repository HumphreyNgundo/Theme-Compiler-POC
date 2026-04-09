// Mock data matching the TypeScript types in sample_files/kijani-finance/src/types.ts

class MockAccount {
  final String id;
  final String type;
  final double balance;
  final String accountNumber;

  const MockAccount({
    required this.id,
    required this.type,
    required this.balance,
    required this.accountNumber,
  });
}

class MockTransaction {
  final String id;
  final String type;
  final String title;
  final String subtitle;
  final double amount;
  final String date;
  final String status;

  const MockTransaction({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.date,
    required this.status,
  });

  bool get isNegative => amount < 0;
}

const mockAccounts = <MockAccount>[
  MockAccount(id: '1', type: 'Wallet', balance: 45250.50, accountNumber: '0712****89'),
  MockAccount(id: '2', type: 'Savings', balance: 125000.00, accountNumber: '8829****12'),
];

const mockTransactions = <MockTransaction>[
  MockTransaction(
    id: '1',
    type: 'send',
    title: 'Sent to John Doe',
    subtitle: 'M-Pesa Transfer',
    amount: -2500,
    date: 'Today, 10:45 AM',
    status: 'success',
  ),
  MockTransaction(
    id: '2',
    type: 'receive',
    title: 'Received from Jane Smith',
    subtitle: 'Mobile Money',
    amount: 5000,
    date: 'Yesterday, 04:20 PM',
    status: 'success',
  ),
  MockTransaction(
    id: '3',
    type: 'paybill',
    title: 'Kenya Power',
    subtitle: 'Paybill 888888',
    amount: -1200,
    date: 'Apr 08, 2026',
    status: 'success',
  ),
  MockTransaction(
    id: '4',
    type: 'airtime',
    title: 'Safaricom Airtime',
    subtitle: 'Self Purchase',
    amount: -500,
    date: 'Apr 07, 2026',
    status: 'success',
  ),
  MockTransaction(
    id: '5',
    type: 'till',
    title: 'Java House',
    subtitle: 'Till 123456',
    amount: -850,
    date: 'Apr 07, 2026',
    status: 'failed',
  ),
];
