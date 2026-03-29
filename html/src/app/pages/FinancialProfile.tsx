import { useState } from "react";
import { User, Wallet, Target, Activity, CheckCircle2, AlertCircle } from "lucide-react";
import { GlassCard } from "../components/ui/GlassCard";
import { motion } from "motion/react";
import { toast } from "sonner";

export function FinancialProfile() {
  const [formData, setFormData] = useState({
    name: "Alex",
    age: "28",
    income: "100000",
    expenses: "40000",
    savings: "50000",
    investments: "120000",
    debt: "0",
    emergencyMonths: "4",
    hasInsurance: true,
    goals: "Buy a house in 5 years",
    riskProfile: "Medium"
  });

  const handleSave = (e: React.FormEvent) => {
    e.preventDefault();
    toast.success("Profile saved successfully! Advice is now tailored to your new data.");
  };

  const InputField = ({ label, icon: Icon, type = "text", value, name }: any) => (
    <div className="flex flex-col gap-2">
      <label className="text-sm text-slate-400 font-medium flex items-center gap-2">
        <Icon size={16} className="text-[#3DE0FC]" />
        {label}
      </label>
      <input
        type={type}
        name={name}
        value={value}
        onChange={(e) => setFormData({ ...formData, [name]: e.target.value })}
        className="bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-white outline-none focus:border-[#3DE0FC]/50 focus:shadow-[0_0_15px_rgba(61,224,252,0.2)] transition-all placeholder:text-slate-600"
      />
    </div>
  );

  return (
    <div className="p-8 h-full overflow-y-auto no-scrollbar relative">
      <div className="max-w-4xl mx-auto">
        <div className="mb-10">
          <h2 className="text-3xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-white to-[#3DE0FC] mb-2">
            Your Financial Profile
          </h2>
          <p className="text-slate-400">The foundation that powers your personalized advice.</p>
        </div>

        <form onSubmit={handleSave} className="space-y-8">
          {/* Basics */}
          <GlassCard glowColor="#153C6A" className="p-8 space-y-6">
            <h3 className="text-xl font-semibold text-white flex items-center gap-2 border-b border-white/10 pb-4">
              <User size={24} className="text-[#3DE0FC]" /> Personal Details
            </h3>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <InputField label="Full Name" name="name" value={formData.name} icon={User} />
              <InputField label="Age" type="number" name="age" value={formData.age} icon={User} />
            </div>
          </GlassCard>

          {/* Finances */}
          <GlassCard glowColor="#733E85" className="p-8 space-y-6">
            <h3 className="text-xl font-semibold text-white flex items-center gap-2 border-b border-white/10 pb-4">
              <Wallet size={24} className="text-[#E977F5]" /> Financial Overview
            </h3>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              <InputField label="Monthly Income (₹)" type="number" name="income" value={formData.income} icon={Wallet} />
              <InputField label="Monthly Expenses (₹)" type="number" name="expenses" value={formData.expenses} icon={Wallet} />
              <InputField label="Current Savings (₹)" type="number" name="savings" value={formData.savings} icon={Wallet} />
              <InputField label="Total Investments (₹)" type="number" name="investments" value={formData.investments} icon={Wallet} />
              <InputField label="Current Debt (₹)" type="number" name="debt" value={formData.debt} icon={AlertCircle} />
              <InputField label="Emergency Fund (Months)" type="number" name="emergencyMonths" value={formData.emergencyMonths} icon={Activity} />
            </div>

            <div className="mt-6 flex items-center justify-between p-4 rounded-xl bg-white/5 border border-white/10">
              <div className="flex flex-col">
                <span className="font-medium text-white">Active Insurance Coverage</span>
                <span className="text-sm text-slate-400">Life/Health insurance active</span>
              </div>
              <label className="relative inline-flex items-center cursor-pointer">
                <input 
                  type="checkbox" 
                  checked={formData.hasInsurance} 
                  onChange={(e) => setFormData({...formData, hasInsurance: e.target.checked})}
                  className="sr-only peer" 
                />
                <div className="w-14 h-7 bg-slate-700 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-[26px] peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[3px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-6 after:w-6 after:transition-all peer-checked:bg-gradient-to-r peer-checked:from-[#3DE0FC] peer-checked:to-[#2475AC]"></div>
              </label>
            </div>
          </GlassCard>

          {/* Goals & Risk */}
          <GlassCard glowColor="#2475AC" className="p-8 space-y-6">
             <h3 className="text-xl font-semibold text-white flex items-center gap-2 border-b border-white/10 pb-4">
              <Target size={24} className="text-[#3DE0FC]" /> Strategy & Goals
            </h3>
            
            <div className="flex flex-col gap-2">
              <label className="text-sm text-slate-400 font-medium flex items-center gap-2">
                <Target size={16} className="text-[#3DE0FC]" />
                Primary Financial Goal
              </label>
              <textarea
                name="goals"
                value={formData.goals}
                onChange={(e) => setFormData({...formData, goals: e.target.value})}
                className="bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-white outline-none focus:border-[#3DE0FC]/50 h-24 resize-none"
              />
            </div>

            <div className="flex flex-col gap-3 pt-4">
              <label className="text-sm text-slate-400 font-medium">Risk Profile</label>
              <div className="grid grid-cols-3 gap-4">
                {["Low", "Medium", "High"].map((level) => (
                  <button
                    type="button"
                    key={level}
                    onClick={() => setFormData({...formData, riskProfile: level})}
                    className={`py-3 rounded-xl border transition-all ${
                      formData.riskProfile === level 
                        ? 'bg-gradient-to-r from-[#3DE0FC]/20 to-[#2475AC]/20 border-[#3DE0FC] text-white shadow-[0_0_15px_rgba(61,224,252,0.3)]'
                        : 'border-white/10 bg-white/5 text-slate-400 hover:bg-white/10'
                    }`}
                  >
                    {level}
                  </button>
                ))}
              </div>
            </div>
          </GlassCard>

          <div className="flex justify-end pb-10">
            <button
              type="submit"
              className="px-8 py-4 rounded-full bg-gradient-to-r from-[#3DE0FC] to-[#2475AC] text-white font-bold text-lg hover:shadow-[0_0_30px_rgba(61,224,252,0.5)] transition-all transform hover:scale-105 flex items-center gap-2"
            >
              <CheckCircle2 size={24} />
              Save Profile
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
