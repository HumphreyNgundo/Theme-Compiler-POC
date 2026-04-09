import React, { useState } from "react";
import { motion, AnimatePresence } from "motion/react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardContent } from "@/components/ui/card";
import { Smartphone, Lock, Fingerprint, ChevronRight } from "lucide-react";

interface LoginProps {
  onLogin: () => void;
}

export function Login({ onLogin }: LoginProps) {
  const [phone, setPhone] = useState("");
  const [pin, setPin] = useState("");
  const [step, setStep] = useState<"login" | "otp">("login");

  const handleLogin = (e: React.FormEvent) => {
    e.preventDefault();
    setStep("otp");
  };

  const handleVerify = () => {
    onLogin();
  };

  return (
    <div className="min-h-screen bg-background flex flex-col items-center justify-center p-6">
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        className="w-full max-w-md space-y-8"
      >
        <div className="text-center space-y-2">
          <div className="w-16 h-16 bg-primary rounded-2xl mx-auto flex items-center justify-center shadow-lg shadow-primary/20">
            <Smartphone className="text-primary-foreground w-8 h-8" />
          </div>
          <h1 className="text-3xl font-bold tracking-tight">Kijani Finance</h1>
          <p className="text-muted-foreground">Modern banking for Kenya</p>
        </div>

        <AnimatePresence mode="wait">
          {step === "login" ? (
            <motion.div
              key="login"
              initial={{ opacity: 0, x: -20 }}
              animate={{ opacity: 1, x: 0 }}
              exit={{ opacity: 0, x: 20 }}
              className="space-y-6"
            >
              <Card className="border-none shadow-xl bg-card/50 backdrop-blur-sm">
                <CardContent className="pt-6 space-y-4">
                  <div className="space-y-2">
                    <label className="text-sm font-medium px-1">Phone Number</label>
                    <div className="relative">
                      <span className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground font-medium">
                        +254
                      </span>
                      <Input
                        type="tel"
                        placeholder="712 345 678"
                        className="pl-14 h-12 text-lg"
                        value={phone}
                        onChange={(e) => setPhone(e.target.value)}
                      />
                    </div>
                  </div>
                  <div className="space-y-2">
                    <label className="text-sm font-medium px-1">Security PIN</label>
                    <div className="relative">
                      <Lock className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground w-5 h-5" />
                      <Input
                        type="password"
                        placeholder="••••"
                        maxLength={4}
                        className="pl-10 h-12 text-lg tracking-[0.5em]"
                        value={pin}
                        onChange={(e) => setPin(e.target.value)}
                      />
                    </div>
                  </div>
                  <Button onClick={handleLogin} className="w-full h-12 text-lg font-semibold group">
                    Sign In
                    <ChevronRight className="ml-2 w-5 h-5 group-hover:translate-x-1 transition-transform" />
                  </Button>
                </CardContent>
              </Card>

              <div className="flex flex-col items-center gap-4">
                <button className="text-primary font-medium text-sm">Forgot PIN?</button>
                <div className="flex items-center gap-2 text-muted-foreground">
                  <div className="h-px w-8 bg-border" />
                  <span className="text-xs uppercase tracking-widest">Or use biometrics</span>
                  <div className="h-px w-8 bg-border" />
                </div>
                <Button variant="outline" size="icon" className="w-16 h-16 rounded-full border-2">
                  <Fingerprint className="w-8 h-8 text-primary" />
                </Button>
              </div>
            </motion.div>
          ) : (
            <motion.div
              key="otp"
              initial={{ opacity: 0, x: 20 }}
              animate={{ opacity: 1, x: 0 }}
              exit={{ opacity: 0, x: -20 }}
              className="space-y-6"
            >
              <Card className="border-none shadow-xl bg-card/50 backdrop-blur-sm">
                <CardContent className="pt-6 space-y-6 text-center">
                  <div className="space-y-2">
                    <h2 className="text-xl font-bold">Verify Identity</h2>
                    <p className="text-sm text-muted-foreground">
                      We've sent a 6-digit code to <br />
                      <span className="text-foreground font-medium">+254 {phone}</span>
                    </p>
                  </div>

                  <div className="flex justify-center gap-2">
                    {[1, 2, 3, 4, 5, 6].map((i) => (
                      <Input
                        key={i}
                        type="text"
                        maxLength={1}
                        className="w-10 h-12 text-center text-xl font-bold p-0"
                        autoFocus={i === 1}
                      />
                    ))}
                  </div>

                  <Button onClick={handleVerify} className="w-full h-12 text-lg font-semibold">
                    Verify & Continue
                  </Button>

                  <p className="text-sm text-muted-foreground">
                    Didn't receive code?{" "}
                    <button className="text-primary font-medium">Resend (45s)</button>
                  </p>
                </CardContent>
              </Card>
            </motion.div>
          )}
        </AnimatePresence>
      </motion.div>
    </div>
  );
}
