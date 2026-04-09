import React, { useState } from "react";
import { motion, AnimatePresence } from "motion/react";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/components/ui/tabs";
import { 
  Send, 
  Smartphone, 
  Zap, 
  CreditCard, 
  Building2, 
  Store, 
  ChevronRight,
  Search,
  CheckCircle2,
  AlertCircle
} from "lucide-react";

export function Payments() {
  const [step, setStep] = useState<"services" | "form" | "confirm" | "success">("services");
  const [activeService, setActiveService] = useState<string | null>(null);

  const services = [
    { id: "send", icon: Send, label: "Send Money", description: "To any phone number", color: "bg-blue-500" },
    { id: "paybill", icon: Building2, label: "Paybill", description: "Utilities, business, etc", color: "bg-amber-500" },
    { id: "till", icon: Store, label: "Buy Goods", description: "Pay at a shop/till", color: "bg-green-500" },
    { id: "airtime", icon: Smartphone, label: "Airtime", description: "Safaricom, Airtel, Telkom", color: "bg-purple-500" },
  ];

  const handleServiceSelect = (id: string) => {
    setActiveService(id);
    setStep("form");
  };

  return (
    <div className="pb-24 pt-6 px-6 space-y-6">
      <header className="space-y-1">
        <h2 className="text-2xl font-bold">Payments</h2>
        <p className="text-muted-foreground text-sm">Send money and pay bills easily</p>
      </header>

      <AnimatePresence mode="wait">
        {step === "services" && (
          <motion.div
            key="services"
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -20 }}
            className="space-y-6"
          >
            <div className="relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground w-5 h-5" />
              <Input placeholder="Search services, paybills..." className="pl-10 h-12 rounded-2xl bg-muted/50 border-none" />
            </div>

            <div className="grid grid-cols-1 gap-4">
              {services.map((service) => (
                <button
                  key={service.id}
                  onClick={() => handleServiceSelect(service.id)}
                  className="flex items-center gap-4 p-4 bg-card rounded-3xl shadow-sm border border-border/50 group active:scale-[0.98] transition-all"
                >
                  <div className={`w-14 h-14 rounded-2xl ${service.color} flex items-center justify-center text-white shadow-lg shadow-${service.color.split('-')[1]}-500/20`}>
                    <service.icon className="w-7 h-7" />
                  </div>
                  <div className="flex-1 text-left">
                    <h4 className="font-bold">{service.label}</h4>
                    <p className="text-xs text-muted-foreground">{service.description}</p>
                  </div>
                  <ChevronRight className="text-muted-foreground w-5 h-5 group-hover:translate-x-1 transition-transform" />
                </button>
              ))}
            </div>

            <div className="space-y-4 pt-4">
              <h3 className="font-bold text-lg">Saved Payees</h3>
              <div className="flex gap-4 overflow-x-auto no-scrollbar pb-2">
                {[
                  { name: "John Doe", initial: "JD" },
                  { name: "Kenya Power", initial: "KP" },
                  { name: "Nairobi Water", initial: "NW" },
                  { name: "Mama Mboga", initial: "MM" },
                ].map((payee, i) => (
                  <button key={i} className="flex flex-col items-center gap-2 min-w-[70px]">
                    <div className="w-14 h-14 rounded-full bg-primary/10 text-primary flex items-center justify-center font-bold text-lg border-2 border-primary/20">
                      {payee.initial}
                    </div>
                    <span className="text-[10px] font-medium text-center">{payee.name}</span>
                  </button>
                ))}
              </div>
            </div>
          </motion.div>
        )}

        {step === "form" && (
          <motion.div
            key="form"
            initial={{ opacity: 0, x: 20 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: -20 }}
            className="space-y-6"
          >
            <div className="flex items-center gap-4">
              <Button variant="ghost" size="icon" onClick={() => setStep("services")}>
                <ChevronRight className="w-6 h-6 rotate-180" />
              </Button>
              <h3 className="font-bold text-xl capitalize">{activeService?.replace('-', ' ')}</h3>
            </div>

            <Card className="border-none shadow-xl bg-card/50 backdrop-blur-sm">
              <CardContent className="pt-6 space-y-6">
                {activeService === "send" && (
                  <div className="space-y-4">
                    <div className="space-y-2">
                      <label className="text-sm font-medium">Recipient Phone Number</label>
                      <div className="relative">
                        <Smartphone className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground w-5 h-5" />
                        <Input placeholder="0712 345 678" className="pl-10 h-12" />
                      </div>
                    </div>
                    <div className="space-y-2">
                      <label className="text-sm font-medium">Amount (KES)</label>
                      <Input type="number" placeholder="0.00" className="h-14 text-2xl font-bold" />
                    </div>
                  </div>
                )}

                {activeService === "paybill" && (
                  <div className="space-y-4">
                    <div className="space-y-2">
                      <label className="text-sm font-medium">Paybill Number</label>
                      <Input placeholder="e.g. 888888" className="h-12" />
                    </div>
                    <div className="space-y-2">
                      <label className="text-sm font-medium">Account Number</label>
                      <Input placeholder="e.g. 12345678" className="h-12" />
                    </div>
                    <div className="space-y-2">
                      <label className="text-sm font-medium">Amount (KES)</label>
                      <Input type="number" placeholder="0.00" className="h-14 text-2xl font-bold" />
                    </div>
                  </div>
                )}

                <Button onClick={() => setStep("confirm")} className="w-full h-12 text-lg font-semibold">
                  Continue
                </Button>
              </CardContent>
            </Card>
          </motion.div>
        )}

        {step === "confirm" && (
          <motion.div
            key="confirm"
            initial={{ opacity: 0, scale: 0.95 }}
            animate={{ opacity: 1, scale: 1 }}
            className="space-y-6"
          >
            <div className="text-center space-y-2">
              <h3 className="text-2xl font-bold">Confirm Payment</h3>
              <p className="text-muted-foreground">Please review the details below</p>
            </div>

            <Card className="border-none shadow-xl bg-card">
              <CardContent className="pt-6 space-y-4">
                <div className="flex justify-between py-2 border-b border-border/50">
                  <span className="text-muted-foreground">Recipient</span>
                  <span className="font-bold">John Doe (+254 712 345 678)</span>
                </div>
                <div className="flex justify-between py-2 border-b border-border/50">
                  <span className="text-muted-foreground">Amount</span>
                  <span className="font-bold">KES 2,500.00</span>
                </div>
                <div className="flex justify-between py-2 border-b border-border/50">
                  <span className="text-muted-foreground">Transaction Fee</span>
                  <span className="font-bold">KES 35.00</span>
                </div>
                <div className="flex justify-between py-4">
                  <span className="text-lg font-bold">Total</span>
                  <span className="text-lg font-bold text-primary">KES 2,535.00</span>
                </div>
                
                <div className="bg-muted/50 p-4 rounded-2xl flex gap-3 items-start">
                  <AlertCircle className="w-5 h-5 text-amber-500 shrink-0 mt-0.5" />
                  <p className="text-xs text-muted-foreground">
                    Ensure the recipient details are correct. Transactions are processed immediately and cannot be reversed easily.
                  </p>
                </div>

                <div className="flex gap-3 pt-4">
                  <Button variant="outline" onClick={() => setStep("form")} className="flex-1 h-12">
                    Back
                  </Button>
                  <Button onClick={() => setStep("success")} className="flex-[2] h-12 font-bold">
                    Confirm & Pay
                  </Button>
                </div>
              </CardContent>
            </Card>
          </motion.div>
        )}

        {step === "success" && (
          <motion.div
            key="success"
            initial={{ opacity: 0, scale: 0.5 }}
            animate={{ opacity: 1, scale: 1 }}
            className="flex flex-col items-center justify-center py-12 space-y-8"
          >
            <div className="w-24 h-24 bg-primary rounded-full flex items-center justify-center shadow-2xl shadow-primary/40">
              <CheckCircle2 className="text-white w-12 h-12" />
            </div>
            
            <div className="text-center space-y-2">
              <h3 className="text-3xl font-bold">Payment Successful!</h3>
              <p className="text-muted-foreground">Ref: KJN-88293-XPL</p>
            </div>

            <Card className="w-full border-none shadow-lg bg-card p-6 text-center space-y-4">
              <div>
                <p className="text-sm text-muted-foreground uppercase tracking-widest font-medium">Amount Paid</p>
                <h4 className="text-4xl font-bold text-primary mt-1">KES 2,535.00</h4>
              </div>
              <div className="pt-4 flex flex-col gap-2">
                <Button className="w-full h-12 font-bold">Share Receipt</Button>
                <Button variant="ghost" onClick={() => setStep("services")} className="w-full h-12">
                  Done
                </Button>
              </div>
            </Card>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
