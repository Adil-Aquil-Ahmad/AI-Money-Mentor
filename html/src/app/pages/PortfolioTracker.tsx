import { useState } from "react";
import { GlassCard } from "../components/ui/GlassCard";
import { PieChart, Pie, Cell, ResponsiveContainer, AreaChart, Area, XAxis, YAxis, Tooltip, CartesianGrid } from "recharts";
import { Briefcase, ArrowRight, Zap, AlertTriangle, TrendingUp } from "lucide-react";
import { motion } from "motion/react";

const portfolioData = [
  { name: "Equity Mutual Funds", value: 650000, color: "#3DE0FC" },
  { name: "Direct Stocks", value: 250000, color: "#E977F5" },
  { name: "Fixed Deposits", value: 400000, color: "#733E85" },
  { name: "Gold/SGBs", value: 150000, color: "#2475AC" },
  { name: "EPF/PPF", value: 350000, color: "#153C6A" },
];

const projectionData = [
  { year: "Year 0", value: 1800000 },
  { year: "Year 1", value: 2016000 },
  { year: "Year 3", value: 2520000 },
  { year: "Year 5", value: 3150000 },
  { year: "Year 10", value: 5544000 },
];

export function PortfolioTracker() {
  const [activeTab, setActiveTab] = useState("overview");

  return (
    <div className="p-8 h-full overflow-y-auto no-scrollbar relative">
      <div className="max-w-6xl mx-auto flex flex-col gap-8">
        
        {/* Header */}
        <div className="flex flex-col md:flex-row items-start md:items-center justify-between gap-4">
          <div>
            <h2 className="text-3xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-white to-[#E977F5] mb-2">
              Portfolio Tracker
            </h2>
            <p className="text-slate-400">Analyze, project, and align your investments with your goals.</p>
          </div>
          
          <div className="flex bg-white/5 rounded-full p-1 border border-white/10">
            {["overview", "projections"].map((tab) => (
              <button
                key={tab}
                onClick={() => setActiveTab(tab)}
                className={`px-6 py-2 rounded-full font-medium text-sm transition-all capitalize ${
                  activeTab === tab 
                  ? "bg-gradient-to-r from-[#733E85] to-[#E977F5] text-white shadow-[0_0_15px_rgba(233,119,245,0.4)]" 
                  : "text-slate-400 hover:text-white"
                }`}
              >
                {tab}
              </button>
            ))}
          </div>
        </div>

        {/* Total Value Banner */}
        <GlassCard className="p-8 !bg-gradient-to-r from-[#153C6A]/40 to-[#042142]/40 !border-[#3DE0FC]/20 flex flex-col md:flex-row items-center justify-between">
          <div className="flex items-center gap-6">
            <div className="w-16 h-16 rounded-2xl bg-gradient-to-br from-[#3DE0FC] to-[#2475AC] flex items-center justify-center shadow-[0_0_30px_rgba(61,224,252,0.3)]">
              <Briefcase size={32} className="text-white" />
            </div>
            <div>
              <p className="text-slate-400 font-medium mb-1">Total Portfolio Value</p>
              <h1 className="text-4xl md:text-5xl font-black text-white">₹18,00,000</h1>
              <p className="text-[#3DE0FC] font-semibold text-sm mt-2 flex items-center gap-1">
                <TrendingUp size={16} /> +12.4% Annualized Returns
              </p>
            </div>
          </div>
          
          <div className="mt-6 md:mt-0 flex gap-4">
            <button className="px-6 py-3 rounded-full bg-white/10 text-white font-medium hover:bg-white/20 transition-all border border-white/10 flex items-center gap-2">
               Add Investment
            </button>
            <button className="px-6 py-3 rounded-full bg-gradient-to-r from-[#3DE0FC] to-[#2475AC] text-white font-bold hover:shadow-[0_0_20px_rgba(61,224,252,0.4)] transition-all">
               Rebalance
            </button>
          </div>
        </GlassCard>

        {activeTab === "overview" && (
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
            {/* Allocation Chart */}
            <GlassCard className="p-8 flex flex-col items-center">
              <h3 className="text-xl font-semibold text-white mb-6 self-start w-full border-b border-white/10 pb-4">
                Asset Allocation
              </h3>
              <div className="w-full h-64">
                <ResponsiveContainer key="rc-pie" width="100%" height="100%">
                  <PieChart key="piechart">
                    <Pie
                      key="pie"
                      data={portfolioData}
                      innerRadius={80}
                      outerRadius={100}
                      paddingAngle={5}
                      dataKey="value"
                      stroke="none"
                      isAnimationActive={false}
                    >
                      {portfolioData.map((entry, index) => (
                        <Cell key={`cell-${index}`} fill={entry.color} />
                      ))}
                    </Pie>
                    <Tooltip 
                      key="tooltip"
                      formatter={(value: number) => `₹${value.toLocaleString()}`}
                      contentStyle={{ backgroundColor: "#042142", border: "1px solid rgba(255,255,255,0.1)", borderRadius: "12px", color: "#fff" }}
                    />
                  </PieChart>
                </ResponsiveContainer>
              </div>
              
              <div className="w-full grid grid-cols-2 gap-4 mt-6">
                {portfolioData.map((item, i) => (
                  <div key={i} className="flex items-center gap-3">
                    <div className="w-3 h-3 rounded-full" style={{ backgroundColor: item.color }} />
                    <div className="flex flex-col">
                      <span className="text-xs text-slate-400">{item.name}</span>
                      <span className="font-medium text-white text-sm">₹{item.value.toLocaleString()}</span>
                    </div>
                  </div>
                ))}
              </div>
            </GlassCard>

            {/* Insights & Alerts */}
            <div className="flex flex-col gap-6">
              <GlassCard className="p-6 !bg-[#733E85]/10 !border-[#E977F5]/30">
                <div className="flex items-start gap-4">
                  <div className="p-3 bg-white/5 rounded-xl border border-white/10">
                    <Zap className="text-[#E977F5]" size={24} />
                  </div>
                  <div>
                    <h4 className="font-semibold text-white mb-1">Goal Alignment: On Track</h4>
                    <p className="text-sm text-slate-300 mb-4">
                      Your goal to buy a house in 7 years for ₹80L requires ₹45,000/mo SIP. You are currently investing ₹48,000. Keep it up!
                    </p>
                    <button className="text-xs font-bold text-[#E977F5] uppercase tracking-wider flex items-center gap-1 hover:gap-2 transition-all">
                      View Goal Details <ArrowRight size={14} />
                    </button>
                  </div>
                </div>
              </GlassCard>

              <GlassCard className="p-6 !bg-rose-500/10 !border-rose-500/30">
                <div className="flex items-start gap-4">
                  <div className="p-3 bg-rose-500/20 rounded-xl border border-rose-500/20">
                    <AlertTriangle className="text-rose-400" size={24} />
                  </div>
                  <div>
                    <h4 className="font-semibold text-white mb-1">High FD Concentration Alert</h4>
                    <p className="text-sm text-slate-300 mb-4">
                      ₹4L (22%) is in FDs earning 6.5%. With 5.5% inflation, your real return is only 1%. Consider shifting ₹2L to conservative hybrid funds.
                    </p>
                    <button className="text-xs font-bold text-rose-400 uppercase tracking-wider flex items-center gap-1 hover:gap-2 transition-all">
                      Review Shift Strategy <ArrowRight size={14} />
                    </button>
                  </div>
                </div>
              </GlassCard>
            </div>
          </div>
        )}

        {activeTab === "projections" && (
          <GlassCard className="p-8 flex flex-col" glowColor="#153C6A">
            <h3 className="text-xl font-semibold text-white mb-2">Future Growth Projection</h3>
            <p className="text-sm text-slate-400 mb-8">Assuming blended 10.5% return based on current asset allocation</p>
            
            <div className="w-full h-80">
              <ResponsiveContainer key="rc-area" width="100%" height="100%">
                <AreaChart key="areachart" data={projectionData} margin={{ top: 10, right: 30, left: 0, bottom: 0 }}>
                  <defs key="defs">
                    <linearGradient id="colorValue" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#3DE0FC" stopOpacity={0.8}/>
                      <stop offset="95%" stopColor="#3DE0FC" stopOpacity={0}/>
                    </linearGradient>
                  </defs>
                  <CartesianGrid key="grid" strokeDasharray="3 3" stroke="rgba(255,255,255,0.05)" vertical={false} />
                  <XAxis key="xaxis" dataKey="year" stroke="#94a3b8" fontSize={12} tickLine={false} axisLine={false} />
                  <YAxis 
                    key="yaxis"
                    stroke="#94a3b8" 
                    fontSize={12} 
                    tickFormatter={(value) => `₹${(value/100000).toFixed(0)}L`}
                    tickLine={false} 
                    axisLine={false}
                  />
                  <Tooltip 
                    key="tooltip"
                    formatter={(value: number) => `₹${value.toLocaleString()}`}
                    contentStyle={{ backgroundColor: "#042142", border: "1px solid rgba(61,224,252,0.3)", borderRadius: "12px", color: "#fff" }}
                    itemStyle={{ color: "#3DE0FC", fontWeight: "bold" }}
                  />
                  <Area 
                    key="area"
                    type="monotone" 
                    dataKey="value" 
                    stroke="#3DE0FC" 
                    strokeWidth={4}
                    fillOpacity={1} 
                    fill="url(#colorValue)" 
                    isAnimationActive={false}
                  />
                </AreaChart>
              </ResponsiveContainer>
            </div>
            
            <div className="mt-8 grid grid-cols-2 md:grid-cols-4 gap-4">
               {projectionData.slice(1).map((data, i) => (
                 <div key={i} className="p-4 rounded-2xl bg-white/5 border border-white/10 text-center">
                   <div className="text-sm text-slate-400 mb-1">{data.year}</div>
                   <div className="font-bold text-lg text-white">₹{(data.value/100000).toFixed(2)}L</div>
                 </div>
               ))}
            </div>
          </GlassCard>
        )}
      </div>
    </div>
  );
}
