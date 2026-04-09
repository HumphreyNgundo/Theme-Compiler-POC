/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { useState, useEffect } from "react";
import { motion, AnimatePresence } from "motion/react";
import { BottomNav } from "@/components/BottomNav";
import { Dashboard } from "@/components/Dashboard";
import { Payments } from "@/components/Payments";
import { Profile } from "@/components/Profile";
import { Login } from "@/components/Auth";
import { ScrollArea } from "@/components/ui/scroll-area";

export default function App() {
  const [isLoggedIn, setIsLoggedIn] = useState(false);
  const [activeTab, setActiveTab] = useState("home");
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    // Simulate initial load
    const timer = setTimeout(() => setIsLoading(false), 1500);
    return () => clearTimeout(timer);
  }, []);

  if (isLoading) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <motion.div
          animate={{
            scale: [1, 1.2, 1],
            rotate: [0, 180, 360],
          }}
          transition={{
            duration: 2,
            repeat: Infinity,
            ease: "easeInOut",
          }}
          className="w-12 h-12 border-4 border-primary border-t-transparent rounded-full"
        />
      </div>
    );
  }

  if (!isLoggedIn) {
    return <Login onLogin={() => setIsLoggedIn(true)} />;
  }

  const renderContent = () => {
    switch (activeTab) {
      case "home":
        return <Dashboard />;
      case "payments":
        return <Payments />;
      case "profile":
        return <Profile onLogout={() => setIsLoggedIn(false)} />;
      case "transactions":
        return (
          <div className="p-6 text-center space-y-4 pt-20">
            <h2 className="text-2xl font-bold">Transaction History</h2>
            <p className="text-muted-foreground">Full history view coming soon.</p>
          </div>
        );
      default:
        return <Dashboard />;
    }
  };

  return (
    <div className="min-h-screen bg-background text-foreground selection:bg-primary/20">
      <ScrollArea className="h-screen">
        <AnimatePresence mode="wait">
          <motion.div
            key={activeTab}
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -10 }}
            transition={{ duration: 0.2 }}
          >
            {renderContent()}
          </motion.div>
        </AnimatePresence>
      </ScrollArea>
      <BottomNav activeTab={activeTab} onTabChange={setActiveTab} />
    </div>
  );
}
