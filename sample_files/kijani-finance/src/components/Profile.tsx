import React from "react";
import { motion } from "motion/react";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { 
  User, 
  Settings, 
  Shield, 
  Bell, 
  HelpCircle, 
  LogOut, 
  ChevronRight,
  Moon,
  Smartphone,
  CreditCard
} from "lucide-react";

interface ProfileProps {
  onLogout: () => void;
}

export function Profile({ onLogout }: ProfileProps) {
  const menuItems = [
    { icon: User, label: "Personal Information", subtitle: "Name, email, phone number" },
    { icon: CreditCard, label: "My Accounts", subtitle: "Manage your linked accounts" },
    { icon: Shield, label: "Security & PIN", subtitle: "Change PIN, biometric settings" },
    { icon: Bell, label: "Notifications", subtitle: "Alerts, transaction updates" },
    { icon: Moon, label: "Appearance", subtitle: "Dark mode, theme settings" },
    { icon: HelpCircle, label: "Support & FAQ", subtitle: "Get help with your account" },
  ];

  return (
    <div className="pb-24 pt-6 px-6 space-y-8">
      <header className="flex flex-col items-center text-center space-y-4">
        <div className="relative">
          <Avatar className="w-24 h-24 border-4 border-primary/10">
            <AvatarImage src="https://picsum.photos/seed/kenya/200" />
            <AvatarFallback>CN</AvatarFallback>
          </Avatar>
          <Button size="icon" className="absolute bottom-0 right-0 rounded-full w-8 h-8 border-2 border-background">
            <Settings className="w-4 h-4" />
          </Button>
        </div>
        <div>
          <h2 className="text-2xl font-bold">Candice Ngundo</h2>
          <p className="text-muted-foreground font-medium">+254 712 345 678</p>
          <div className="mt-2">
            <span className="bg-primary/10 text-primary text-[10px] font-bold uppercase tracking-widest px-3 py-1 rounded-full border border-primary/20">
              Gold Member
            </span>
          </div>
        </div>
      </header>

      <div className="space-y-4">
        <h3 className="font-bold text-lg px-2">Settings</h3>
        <div className="space-y-2">
          {menuItems.map((item, i) => (
            <motion.button
              key={i}
              whileHover={{ x: 4 }}
              className="w-full flex items-center gap-4 p-4 bg-card rounded-3xl shadow-sm border border-border/50 group"
            >
              <div className="w-10 h-10 rounded-xl bg-muted flex items-center justify-center text-muted-foreground group-hover:bg-primary/10 group-hover:text-primary transition-colors">
                <item.icon className="w-5 h-5" />
              </div>
              <div className="flex-1 text-left">
                <h4 className="font-bold text-sm">{item.label}</h4>
                <p className="text-[10px] text-muted-foreground">{item.subtitle}</p>
              </div>
              <ChevronRight className="text-muted-foreground w-4 h-4 group-hover:translate-x-1 transition-transform" />
            </motion.button>
          ))}
        </div>
      </div>

      <Button 
        variant="destructive" 
        onClick={onLogout}
        className="w-full h-14 rounded-3xl font-bold flex gap-2 shadow-lg shadow-destructive/20"
      >
        <LogOut className="w-5 h-5" />
        Log Out
      </Button>

      <p className="text-center text-[10px] text-muted-foreground uppercase tracking-[0.2em] font-medium">
        Kijani Finance v1.0.4
      </p>
    </div>
  );
}
