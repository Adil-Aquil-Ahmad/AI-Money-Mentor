import { useState, useEffect } from "react";
import { GlassCard } from "../components/ui/GlassCard";
import { motion, useAnimation } from "motion/react";
import { RefreshCw, ShieldCheck, PiggyBank, TrendingUp, HeartPulse } from "lucide-react";
import { toast } from "sonner";

export function HealthScore() {
  const [score, setScore] = useState(72);
  const controls = useAnimation();

  useEffect(() => {
    controls.start({
      strokeDasharray: `${score}, 100`,
      transition: { duration: 1.5, ease: "easeOut" }
    });
  }, [score, controls]);

  const refreshScore = () => {
    setScore(0);
    setTimeout(() => {
      setScore(Math.floor(Math.random() * 40) + 60);
      toast.success("Health score refreshed based on latest profile data.");
    }, 500);
  };

  const categories = [
    {
      name: "Emergency Fund",
      icon: ShieldCheck,
      score: 25,
      max: 25,
      color: "#3DE0FC",
      desc: "Excellent! You have 6 months of expenses saved."
    },
    {
      name: "Savings Rate",
      icon: PiggyBank,
      score: 18,
      max: 25,
      color: "#E977F5",
      desc: "Good, but try pushing savings to 35% of income."
    },
    {
      name: "Investments",
      icon: TrendingUp,
      score: 12,
      max: 25,
      color: "#733E85",
      desc: "Needs work. SIPs should be increased to reach your goal."
    },
    {
      name: "Debt & Insurance",
      icon: HeartPulse,
      score: 17,
      max: 25,
      color: "#2475AC",
      desc: "No debt, but ensure term life coverage is adequate."
    }
  ];

  const getGrade = (s: number) => {
    if (s >= 90) return "A";
    if (s >= 80) return "B";
    if (s >= 70) return "C";
    if (s >= 60) return "D";
    return "F";
  };

  const getGradeColor = (s: number) => {
    if (s >= 90) return "text-[#3DE0FC]";
    if (s >= 70) return "text-[#E977F5]";
    return "text-rose-500";
  };

  return (
    <div className="p-8 h-full overflow-y-auto no-scrollbar relative">
      <div className="max-w-5xl mx-auto flex flex-col gap-8">
        {/* Header Area */}
        <div className="flex items-center justify-between">
          <div>
            <h2 className="text-3xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-white to-[#3DE0FC] mb-2">
              Money Health Score
            </h2>
            <p className="text-slate-400">Your financial credit score, evaluated across 4 pillars.</p>
          </div>
          <button 
            onClick={refreshScore}
            className="flex items-center gap-2 px-5 py-3 rounded-2xl bg-white/5 border border-white/10 hover:bg-white/10 hover:border-[#3DE0FC]/30 transition-all text-white font-medium group"
          >
            <RefreshCw size={18} className="group-hover:animate-spin-slow text-[#3DE0FC]" />
            Refresh Score
          </button>
        </div>

        {/* Main Score Area */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          {/* Circular Score */}
          <GlassCard glowColor="#3DE0FC" className="lg:col-span-1 flex flex-col items-center justify-center p-10 relative overflow-hidden group">
            <div className="absolute inset-0 bg-gradient-to-b from-[#153C6A]/20 to-transparent pointer-events-none" />
            <div className="relative w-48 h-48">
              <svg viewBox="0 0 36 36" className="w-full h-full drop-shadow-[0_0_20px_rgba(61,224,252,0.4)]">
                <path
                  className="stroke-white/10"
                  fill="none"
                  strokeWidth="3"
                  d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831"
                />
                <motion.path
                  className="stroke-[#3DE0FC]"
                  fill="none"
                  strokeWidth="3"
                  strokeLinecap="round"
                  animate={controls}
                  d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831"
                />
              </svg>
              <div className="absolute inset-0 flex flex-col items-center justify-center">
                <motion.span 
                  className="text-6xl font-black bg-clip-text text-transparent bg-gradient-to-b from-white to-[#3DE0FC]"
                  initial={{ opacity: 0, scale: 0.5 }}
                  animate={{ opacity: 1, scale: 1 }}
                  transition={{ delay: 0.3 }}
                >
                  {score}
                </motion.span>
                <span className="text-sm text-slate-400 font-medium">Out of 100</span>
              </div>
            </div>

            <div className="mt-8 text-center">
              <div className="text-sm text-slate-400 mb-1">Overall Grade</div>
              <div className={`text-4xl font-black ${getGradeColor(score)}`}>
                Grade {getGrade(score)}
              </div>
            </div>
          </GlassCard>

          {/* Breakdown / Insights Area */}
          <div className="lg:col-span-2 grid grid-cols-1 md:grid-cols-2 gap-6">
            {categories.map((cat, i) => (
              <GlassCard 
                key={i} 
                className="p-6 flex flex-col justify-between hover:bg-white/[0.04] transition-colors border-l-4"
                style={{ borderLeftColor: cat.color }}
              >
                <div className="flex items-start justify-between mb-4">
                  <div className="flex items-center gap-3">
                    <div 
                      className="w-10 h-10 rounded-xl flex items-center justify-center bg-white/5"
                      style={{ color: cat.color }}
                    >
                      <cat.icon size={20} />
                    </div>
                    <span className="font-semibold text-white text-lg">{cat.name}</span>
                  </div>
                  <div className="text-right">
                    <span className="text-2xl font-bold text-white">{cat.score}</span>
                    <span className="text-sm text-slate-400">/{cat.max}</span>
                  </div>
                </div>

                {/* Mini Progress Bar */}
                <div className="w-full h-2 bg-white/10 rounded-full mb-4 overflow-hidden">
                  <motion.div 
                    className="h-full rounded-full"
                    style={{ backgroundColor: cat.color }}
                    initial={{ width: 0 }}
                    animate={{ width: `${(cat.score / cat.max) * 100}%` }}
                    transition={{ duration: 1, delay: i * 0.1 }}
                  />
                </div>

                <p className="text-sm text-slate-400 leading-relaxed">
                  {cat.desc}
                </p>
              </GlassCard>
            ))}
          </div>
        </div>

        {/* Actionable Advice Section */}
        <GlassCard className="p-8 mt-4 !bg-[#733E85]/10 !border-[#E977F5]/30 flex flex-col md:flex-row gap-6 items-center">
           <div className="w-16 h-16 rounded-full bg-gradient-to-br from-[#E977F5] to-[#733E85] flex flex-shrink-0 items-center justify-center shadow-[0_0_30px_rgba(233,119,245,0.4)]">
             <TrendingUp size={30} className="text-white" />
           </div>
           <div>
              <h4 className="text-xl font-bold text-white mb-2">Targeted Recommendation</h4>
              <p className="text-slate-300">
                Your weakest area is <span className="text-[#E977F5] font-semibold">Investments (12/25)</span>. 
                Based on your ₹1L income, having only ₹10,000 invested scores low. We recommend starting an additional SIP of ₹5,000 immediately to boost this score.
              </p>
           </div>
           <button className="md:ml-auto mt-4 md:mt-0 whitespace-nowrap px-6 py-3 rounded-full bg-white/10 hover:bg-white/20 text-white font-medium border border-white/20 transition-all">
             View Investment Plan
           </button>
        </GlassCard>
      </div>
    </div>
  );
}
