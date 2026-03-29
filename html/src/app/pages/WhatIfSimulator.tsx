import { useState, useMemo } from "react";
import { GlassCard } from "../components/ui/GlassCard";
import { HelpCircle, Play, SlidersHorizontal, ArrowRight, BarChart2 } from "lucide-react";
import { BarChart, Bar, XAxis, YAxis, Tooltip, CartesianGrid, ResponsiveContainer, Legend } from "recharts";
import { motion, AnimatePresence } from "motion/react";
import { toast } from "sonner";

export function WhatIfSimulator() {
  const [scenario, setScenario] = useState("sip");
  const [params, setParams] = useState({
    sip: 10000,
    duration: 10,
    returnRate: 12,
  });
  const [simulatedData, setSimulatedData] = useState<any>(null);

  const runSimulation = () => {
    let currentWealth = 0;
    let totalInvested = 0;
    const monthlyRate = params.returnRate / 100 / 12;
    const data = [];

    for (let year = 1; year <= params.duration; year++) {
      for (let m = 0; m < 12; m++) {
        currentWealth += currentWealth * monthlyRate + params.sip;
        totalInvested += params.sip;
      }
      data.push({
        year: `Year ${year}`,
        invested: Math.round(totalInvested),
        totalValue: Math.round(currentWealth),
        returns: Math.round(currentWealth - totalInvested)
      });
    }

    setSimulatedData({
      chartData: data,
      finalInvested: totalInvested,
      finalValue: currentWealth,
      netWealth: currentWealth - totalInvested
    });

    toast.success("Simulation complete! Check the growth chart.");
  };

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target;
    setParams(prev => ({ ...prev, [name]: Number(value) }));
  };

  return (
    <div className="p-8 h-full overflow-y-auto no-scrollbar relative">
      <div className="max-w-6xl mx-auto flex flex-col gap-8">
        
        {/* Header */}
        <div className="flex items-center gap-4 mb-2">
          <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-[#3DE0FC] to-[#2475AC] flex items-center justify-center shadow-[0_0_20px_rgba(61,224,252,0.5)]">
            <HelpCircle size={24} className="text-white" />
          </div>
          <div>
            <h2 className="text-3xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-white to-[#3DE0FC]">
              What-If Simulator
            </h2>
            <p className="text-slate-400">Test financial decisions before committing to them.</p>
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-12 gap-8">
          
          {/* Controls Panel */}
          <GlassCard className="lg:col-span-5 xl:col-span-4 p-8 flex flex-col gap-6 h-fit" glowColor="#153C6A">
             <div className="flex items-center justify-between border-b border-white/10 pb-4">
               <h3 className="text-xl font-semibold text-white flex items-center gap-2">
                 <SlidersHorizontal size={20} className="text-[#3DE0FC]" /> Scenario
               </h3>
               <select 
                 className="bg-white/5 border border-white/10 text-white text-sm rounded-lg px-3 py-1 outline-none"
                 value={scenario}
                 onChange={(e) => setScenario(e.target.value)}
               >
                 <option value="sip">SIP Growth</option>
                 <option value="lumpsum">Lumpsum Growth</option>
                 <option value="withdrawal">Withdrawal</option>
               </select>
             </div>

             <div className="flex flex-col gap-6 pt-2">
                <div className="flex flex-col gap-2">
                  <label className="text-sm text-slate-400 font-medium flex flex-wrap justify-between gap-1">
                    <span>Monthly SIP Amount</span>
                    <span className="text-white font-bold">₹{params.sip.toLocaleString()}</span>
                  </label>
                  <input
                    type="range"
                    name="sip"
                    min="1000"
                    max="100000"
                    step="1000"
                    value={params.sip}
                    onChange={handleChange}
                    className="w-full h-2 bg-white/10 rounded-lg appearance-none cursor-pointer accent-[#3DE0FC]"
                  />
                </div>

                <div className="flex flex-col gap-2">
                  <label className="text-sm text-slate-400 font-medium flex flex-wrap justify-between gap-1">
                    <span>Investment Duration</span>
                    <span className="text-white font-bold">{params.duration} Years</span>
                  </label>
                  <input
                    type="range"
                    name="duration"
                    min="1"
                    max="40"
                    step="1"
                    value={params.duration}
                    onChange={handleChange}
                    className="w-full h-2 bg-white/10 rounded-lg appearance-none cursor-pointer accent-[#3DE0FC]"
                  />
                </div>

                <div className="flex flex-col gap-2">
                  <label className="text-sm text-slate-400 font-medium flex flex-wrap justify-between gap-1">
                    <span>Expected Annual Return</span>
                    <span className="text-white font-bold">{params.returnRate}%</span>
                  </label>
                  <input
                    type="range"
                    name="returnRate"
                    min="4"
                    max="30"
                    step="0.5"
                    value={params.returnRate}
                    onChange={handleChange}
                    className="w-full h-2 bg-white/10 rounded-lg appearance-none cursor-pointer accent-[#3DE0FC]"
                  />
                </div>
             </div>

             <button 
               onClick={runSimulation}
               className="mt-6 w-full py-4 rounded-xl bg-gradient-to-r from-[#3DE0FC] to-[#2475AC] text-white font-bold text-lg flex items-center justify-center gap-2 hover:shadow-[0_0_20px_rgba(61,224,252,0.4)] transition-all group"
             >
               <Play size={20} className="fill-white group-hover:scale-110 transition-transform" /> 
               Simulate Outcome
             </button>
          </GlassCard>

          {/* Visualization Panel */}
          <div className="lg:col-span-7 xl:col-span-8 flex flex-col gap-8">
            <AnimatePresence mode="wait">
              {simulatedData ? (
                <motion.div
                  key="results"
                  initial={{ opacity: 0, y: 20 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0, y: -20 }}
                  className="flex flex-col gap-8 h-full"
                >
                  <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                    <GlassCard className="p-6 text-center border-t-4 !border-t-slate-500">
                      <div className="text-sm text-slate-400 mb-2">Total Invested</div>
                      <div className="text-3xl font-black text-white">₹{(simulatedData.finalInvested/100000).toFixed(2)}L</div>
                    </GlassCard>
                    <GlassCard className="p-6 text-center border-t-4 !border-t-[#E977F5]">
                      <div className="text-sm text-slate-400 mb-2">Net Wealth Gained</div>
                      <div className="text-3xl font-black text-[#E977F5]">₹{(simulatedData.netWealth/100000).toFixed(2)}L</div>
                    </GlassCard>
                    <GlassCard className="p-6 text-center border-t-4 !border-t-[#3DE0FC]">
                      <div className="text-sm text-slate-400 mb-2">Final Portfolio Value</div>
                      <div className="text-3xl font-black text-[#3DE0FC]">₹{(simulatedData.finalValue/100000).toFixed(2)}L</div>
                    </GlassCard>
                  </div>

                  <GlassCard className="flex-1 p-8 flex flex-col min-h-[400px]" glowColor="#3DE0FC">
                    <h3 className="text-xl font-semibold text-white mb-6 flex items-center gap-2">
                       <BarChart2 size={24} className="text-[#3DE0FC]"/> Growth Over Time
                    </h3>
                    <div className="flex-1 w-full h-full min-h-[300px]">
                      <ResponsiveContainer key="rc" width="100%" height="100%">
                        <BarChart key="barchart" data={simulatedData.chartData} margin={{ top: 20, right: 30, left: 20, bottom: 5 }}>
                          <CartesianGrid key="grid" strokeDasharray="3 3" stroke="rgba(255,255,255,0.05)" vertical={false} />
                          <XAxis 
                            key="xaxis"
                            dataKey="year" 
                            stroke="#94a3b8" 
                            tickLine={false} 
                            axisLine={false} 
                            tick={{ fontSize: 12 }} 
                            interval="preserveStartEnd" 
                          />
                          <YAxis 
                            key="yaxis"
                            stroke="#94a3b8" 
                            tickFormatter={(value) => `₹${(value/100000).toFixed(0)}L`}
                            tickLine={false} 
                            axisLine={false}
                          />
                          <Tooltip 
                            key="tooltip"
                            formatter={(value: number) => `₹${value.toLocaleString()}`}
                            contentStyle={{ backgroundColor: "#042142", border: "1px solid rgba(61,224,252,0.3)", borderRadius: "12px", color: "#fff" }}
                            cursor={{ fill: 'rgba(255,255,255,0.05)' }}
                          />
                          <Legend key="legend" verticalAlign="top" height={36} iconType="circle" />
                          <Bar key="bar1" isAnimationActive={false} dataKey="invested" name="Actual Input" fill="#64748b" radius={[4, 4, 0, 0]} barSize={20} />
                          <Bar key="bar2" isAnimationActive={false} dataKey="totalValue" name="Total Value (with Returns)" fill="#3DE0FC" radius={[4, 4, 0, 0]} barSize={20} />
                        </BarChart>
                      </ResponsiveContainer>
                    </div>
                  </GlassCard>
                </motion.div>
              ) : (
                <motion.div
                  key="empty"
                  initial={{ opacity: 0 }}
                  animate={{ opacity: 1 }}
                  className="flex-1 flex flex-col items-center justify-center border-2 border-dashed border-white/10 rounded-[32px] p-12 text-center h-[500px]"
                >
                  <div className="w-24 h-24 rounded-full bg-white/5 flex items-center justify-center mb-6">
                    <SlidersHorizontal size={40} className="text-slate-500" />
                  </div>
                  <h3 className="text-2xl font-bold text-white mb-2">Ready to Simulate</h3>
                  <p className="text-slate-400 max-w-md">
                    Adjust the variables on the left and hit 'Simulate Outcome' to instantly calculate how your money will grow over time.
                  </p>
                  <button 
                    onClick={runSimulation}
                    className="mt-8 flex items-center gap-2 text-[#3DE0FC] font-semibold hover:gap-4 transition-all"
                  >
                    Run Default Simulation <ArrowRight size={18} />
                  </button>
                </motion.div>
              )}
            </AnimatePresence>
          </div>
        </div>
      </div>
    </div>
  );
}
