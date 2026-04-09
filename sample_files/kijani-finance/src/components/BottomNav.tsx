import React from "react";
import { Home, Send, History, User } from "lucide-react";
import { cn } from "@/lib/utils";

interface BottomNavProps {
  activeTab: string;
  onTabChange: (tab: string) => void;
}

export function BottomNav({ activeTab, onTabChange }: BottomNavProps) {
  const tabs = [
    { id: "home", label: "Home", icon: Home },
    { id: "payments", label: "Pay", icon: Send },
    { id: "transactions", label: "Activity", icon: History },
    { id: "profile", label: "Profile", icon: User },
  ];

  return (
    <nav className="fixed bottom-0 left-0 right-0 bg-background border-t border-border px-6 py-3 flex justify-between items-center z-50 pb-safe">
      {tabs.map((tab) => {
        const Icon = tab.icon;
        const isActive = activeTab === tab.id;
        return (
          <button
            key={tab.id}
            onClick={() => onTabChange(tab.id)}
            className={cn(
              "flex flex-col items-center gap-1 transition-colors duration-200",
              isActive ? "text-primary" : "text-muted-foreground"
            )}
          >
            <Icon className={cn("w-6 h-6", isActive && "fill-primary/20")} />
            <span className="text-[10px] font-medium uppercase tracking-wider">
              {tab.label}
            </span>
            {isActive && (
              <div className="w-1 h-1 rounded-full bg-primary absolute -bottom-1" />
            )}
          </button>
        );
      })}
    </nav>
  );
}
