import React from "react";
import { motion } from "motion/react";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { 
  Plus, 
  Send, 
  ArrowDownLeft, 
  ArrowUpRight, 
  Smartphone, 
  Zap, 
  CreditCard, 
  MoreHorizontal,
  Bell,
  Search
} from "lucide-react";
import { MOCK_ACCOUNTS, MOCK_TRANSACTIONS, type Transaction } from "@/types";

export function Dashboard() {
  return (
    <div className="pb-24 pt-6 space-y-8">
      {/* Header */}
      <header className="px-6 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <Avatar className="w-12 h-12 border-2 border-primary/20">
            <AvatarImage src="https://picsum.photos/seed/kenya/200" />
            <AvatarFallback>CN</AvatarFallback>
          </Avatar>
          <div>
            <p className="text-xs text-muted-foreground font-medium uppercase tracking-wider">Good morning,</p>
            <h2 className="text-xl font-bold">Candice Ngundo</h2>
          </div>
        </div>
        <div className="flex gap-2">
          <Button variant="ghost" size="icon" className="rounded-full bg-muted/50">
            <Search className="w-5 h-5" />
          </Button>
          <Button variant="ghost" size="icon" className="rounded-full bg-muted/50 relative">
            <Bell className="w-5 h-5" />
            <span className="absolute top-2 right-2 w-2 h-2 bg-destructive rounded-full border-2 border-background" />
          </Button>
        </div>
      </header>

      {/* Account Cards Carousel */}
      <section className="px-6 overflow-x-auto no-scrollbar flex gap-4 pb-2">
        {MOCK_ACCOUNTS.map((account, idx) => (
          <motion.div
            key={account.id}
            initial={{ opacity: 0, scale: 0.9 }}
            animate={{ opacity: 1, scale: 1 }}
            transition={{ delay: idx * 0.1 }}
            className="min-w-[300px]"
          >
            <Card className={`border-none shadow-xl overflow-hidden relative ${idx === 0 ? 'bg-primary text-primary-foreground' : 'bg-secondary text-secondary-foreground'}`}>
              <div className="absolute top-0 right-0 p-4 opacity-10">
                <CreditCard className="w-24 h-24" />
              </div>
              <CardContent className="p-6 space-y-6">
                <div className="flex justify-between items-start">
                  <div>
                    <p className="text-xs font-medium uppercase tracking-widest opacity-80">{account.type} Account</p>
                    <p className="text-sm font-mono opacity-60 mt-1">{account.accountNumber}</p>
                  </div>
                  <Badge variant="outline" className="bg-white/10 border-white/20 text-inherit">
                    Active
                  </Badge>
                </div>
                <div>
                  <p className="text-xs opacity-80 mb-1">Available Balance</p>
                  <div className="flex items-baseline gap-1">
                    <span className="text-sm font-medium">KES</span>
                    <h3 className="text-3xl font-bold tracking-tight">
                      {account.balance.toLocaleString(undefined, { minimumFractionDigits: 2 })}
                    </h3>
                  </div>
                </div>
                <div className="flex gap-2 pt-2">
                  <Button variant={idx === 0 ? "secondary" : "default"} size="sm" className="flex-1 rounded-xl h-10 font-semibold">
                    <Plus className="w-4 h-4 mr-2" /> Top Up
                  </Button>
                  <Button variant={idx === 0 ? "secondary" : "default"} size="sm" className="flex-1 rounded-xl h-10 font-semibold">
                    <Send className="w-4 h-4 mr-2" /> Send
                  </Button>
                </div>
              </CardContent>
            </Card>
          </motion.div>
        ))}
      </section>

      {/* Quick Actions */}
      <section className="px-6 space-y-4">
        <div className="flex items-center justify-between">
          <h3 className="font-bold text-lg">Quick Actions</h3>
          <Button variant="link" className="text-primary p-0 h-auto">View All</Button>
        </div>
        <div className="grid grid-cols-4 gap-4">
          {[
            { icon: Send, label: "Send", color: "bg-blue-500/10 text-blue-600" },
            { icon: Smartphone, label: "Airtime", color: "bg-green-500/10 text-green-600" },
            { icon: Zap, label: "Bills", color: "bg-amber-500/10 text-amber-600" },
            { icon: MoreHorizontal, label: "More", color: "bg-muted text-muted-foreground" },
          ].map((action, i) => (
            <button key={i} className="flex flex-col items-center gap-2 group">
              <div className={`w-14 h-14 rounded-2xl ${action.color} flex items-center justify-center transition-transform group-active:scale-90 shadow-sm`}>
                <action.icon className="w-6 h-6" />
              </div>
              <span className="text-xs font-medium">{action.label}</span>
            </button>
          ))}
        </div>
      </section>

      {/* Recent Transactions */}
      <section className="px-6 space-y-4">
        <div className="flex items-center justify-between">
          <h3 className="font-bold text-lg">Recent Activity</h3>
          <Button variant="link" className="text-primary p-0 h-auto">History</Button>
        </div>
        <div className="space-y-3">
          {MOCK_TRANSACTIONS.map((tx) => (
            <TransactionItem key={tx.id} transaction={tx} />
          ))}
        </div>
      </section>
    </div>
  );
}

interface TransactionItemProps {
  transaction: Transaction;
  key?: string | number;
}

function TransactionItem({ transaction }: TransactionItemProps) {
  const isNegative = transaction.amount < 0;
  
  return (
    <motion.div
      whileHover={{ scale: 1.01 }}
      whileTap={{ scale: 0.99 }}
      className="bg-card p-4 rounded-2xl flex items-center justify-between shadow-sm border border-border/50"
    >
      <div className="flex items-center gap-4">
        <div className={`w-12 h-12 rounded-xl flex items-center justify-center ${
          transaction.status === 'failed' ? 'bg-destructive/10 text-destructive' :
          isNegative ? 'bg-muted text-muted-foreground' : 'bg-primary/10 text-primary'
        }`}>
          {isNegative ? <ArrowUpRight className="w-6 h-6" /> : <ArrowDownLeft className="w-6 h-6" />}
        </div>
        <div>
          <h4 className="font-bold text-sm">{transaction.title}</h4>
          <p className="text-xs text-muted-foreground">{transaction.subtitle}</p>
        </div>
      </div>
      <div className="text-right">
        <p className={`font-bold text-sm ${isNegative ? 'text-foreground' : 'text-primary'}`}>
          {isNegative ? '-' : '+'} KES {Math.abs(transaction.amount).toLocaleString()}
        </p>
        <p className="text-[10px] text-muted-foreground uppercase tracking-wider font-medium">{transaction.date}</p>
      </div>
    </motion.div>
  );
}
