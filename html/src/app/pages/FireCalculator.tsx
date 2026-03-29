import { useState, useMemo } from "react";
import { GlassCard } from "../components/ui/GlassCard";
import { Flame, Info, IndianRupee, PieChart, Activity, TrendingUp } from "lucide-react";
import { AreaChart, Area, XAxis, YAxis, Tooltip, CartesianGrid, ResponsiveContainer, Legend } from "recharts";

export function FireCalculator() {
  const [inputs, setInputs] = useState({
    sip: 25000,
    returnRate: 12,
    corpus: 50000000, // 5 Cr
    currentInv: 1500000, // 15 L
    expenses: 60000
  });

  const fireData = useMemo(() => {
    let currentWealth = inputs.currentInv;
    let months = 0;
    let totalInvested = inputs.currentInv;
    const monthlyRate = inputs.returnRate / 100 / 12;
    const data = [];

    data.push({
      year: 0,
      invested: totalInvested,
      returns: 0,
      total: currentWealth
    });

    for (let year = 1; year <= 30; year++) {
      for (let m = 0; m < 12; m++) {
        currentWealth += currentWealth * monthlyRate + inputs.sip;
        totalInvested += inputs.sip;
        months++;
      }
      data.push({
        year,
        invested: Math.round(totalInvested),
        returns: Math.round(currentWealth - totalInvested),
        total: Math.round(currentWealth)
      });
      if (currentWealth >= inputs.corpus && data.length < 3) {
         // keep going a bit to show the crossing line
      }
    }

    const hitYearData = data.find(d => d.total >= inputs.corpus);
    const hitYear = hitYearData ? hitYearData.year : "> 30";
    const fireNumber = inputs.expenses * 12 * 25; // standard 4% rule
    
    // trim data for display
    const displayData = data.filter((_, i) => i % 2 === 0 || i === data.length -1).slice(0, 15);

    return {
      hitYear,
      fireNumber,
      totalInvested: hitYearData ? hitYearData.invested : totalInvested,
      returnsGained: hitYearData ? hitYearData.returns : (currentWealth - totalInvested),
      chartData: displayData
    };
  }, [inputs]);

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target;
    setInputs(prev => ({ ...prev, [name]: Number(value) }));
  };

  const ResultCard = ({ title, value, subtext, color, icon: Icon }: any) => (
    <GlassCard className="p-6 flex flex-col items-start gap-4" style={{ borderColor: `${color}40`, background: `${color}10` }}>
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 rounded-full flex items-center justify-center" style={{ backgroundColor: `${color}20` }}>
          <Icon size={20} color={color} />
        </div>
        <span className="text-slate-300 font-medium">{title}</span>
      </div>
      <div className="w-full">
        <div className="text-2xl xl:text-3xl font-black text-white truncate">{value}</div>
        {subtext && <div className="text-sm text-slate-400 mt-1 truncate">{subtext}</div>}
      </div>
    </GlassCard>
  );

  return (
    <div className="p-8 h-full overflow-y-auto no-scrollbar relative">
      <div className="max-w-6xl mx-auto flex flex-col gap-8">
        
        <div className="flex items-center gap-4 mb-2">
          <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-[#E977F5] to-[#733E85] flex items-center justify-center shadow-[0_0_20px_rgba(233,119,245,0.5)]">
            <Flame size={24} className="text-white" />
          </div>
          <div>
            <h2 className="text-3xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-white to-[#E977F5]">
              FIRE Calculator
            </h2>
            <p className="text-slate-400">Financial Independence, Retire Early.</p>
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-12 gap-8">
          
          {/* Input Panel */}
          <GlassCard className="lg:col-span-5 xl:col-span-4 p-8 space-y-6">
            <h3 className="text-xl font-semibold text-white border-b border-white/10 pb-4 flex items-center gap-2">
               Your Variables
            </h3>

            {[
              { label: "Monthly SIP", name: "sip", symbol: "₹" },
              { label: "Expected Return", name: "returnRate", symbol: "%", max: 30 },
              { label: "Target Corpus", name: "corpus", symbol: "₹" },
              { label: "Current Investments", name: "currentInv", symbol: "₹" },
              { label: "Monthly Expenses", name: "expenses", symbol: "₹" }
            ].map((field) => (
              <div key={field.name} className="flex flex-col gap-2">
                <label className="text-sm text-slate-400 font-medium flex flex-wrap justify-between gap-1">
                  <span>{field.label}</span>
                  <span className="text-[#3DE0FC]">{field.symbol}{inputs[field.name as keyof typeof inputs].toLocaleString()}</span>
                </label>
                <div className="relative">
                  <input
                    type="range"
                    name={field.name}
                    min={0}
                    max={field.max || (field.name === "corpus" ? 100000000 : field.name === "sip" ? 200000 : field.name === "currentInv" ? 10000000 : 200000)}
                    step={field.name === "returnRate" ? 0.5 : 1000}
                    value={inputs[field.name as keyof typeof inputs]}
                    onChange={handleInputChange}
                    className="w-full h-2 bg-white/10 rounded-lg appearance-none cursor-pointer accent-[#E977F5]"
                  />
                </div>
              </div>
            ))}

            <div className="bg-white/5 rounded-xl p-4 border border-white/10 mt-6 flex gap-3">
              <Info className="text-[#3DE0FC] shrink-0" size={20} />
              <p className="text-xs text-slate-300 leading-relaxed">
                Your <span className="text-[#E977F5] font-bold">FIRE Number</span> is calculated as 25x your annual expenses, assuming a 4% safe withdrawal rate.
              </p>
            </div>
          </GlassCard>

          {/* Results & Chart Panel */}
          <div className="lg:col-span-7 xl:col-span-8 flex flex-col gap-8">
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-2 xl:grid-cols-4 gap-4">
              <ResultCard 
                title="Years to Target" 
                value={fireData.hitYear === "> 30" ? "30+" : `${fireData.hitYear} yrs`} 
                color="#3DE0FC" 
                icon={Activity} 
              />
              <ResultCard 
                title="FIRE Number" 
                value={`₹${(fireData.fireNumber/100000).toFixed(1)}L`} 
                subtext="To never work again"
                color="#E977F5" 
                icon={Flame} 
              />
              <ResultCard 
                title="Total Invested" 
                value={`₹${(fireData.totalInvested/100000).toFixed(1)}L`} 
                color="#2475AC" 
                icon={PieChart} 
              />
              <ResultCard 
                title="Wealth Gained" 
                value={`₹${(fireData.returnsGained/100000).toFixed(1)}L`} 
                subtext="From compounding"
                color="#733E85" 
                icon={TrendingUp} 
              />
            </div>

            <GlassCard className="flex-1 p-8 flex flex-col relative" glowColor="#E977F5">
               <h3 className="text-xl font-semibold text-white mb-6">Wealth Growth Curve</h3>
               
               <div className="flex-1 min-h-[300px] w-full">
                 <ResponsiveContainer key="rc-area" width="100%" height="100%">
                   <AreaChart key="areachart" data={fireData.chartData} margin={{ top: 10, right: 10, left: 0, bottom: 0 }}>
                     <defs key="defs">
                       <linearGradient id="colorInvested" x1="0" y1="0" x2="0" y2="1">
                         <stop offset="5%" stopColor="#2475AC" stopOpacity={0.8}/>
                         <stop offset="95%" stopColor="#2475AC" stopOpacity={0.1}/>
                       </linearGradient>
                       <linearGradient id="colorReturns" x1="0" y1="0" x2="0" y2="1">
                         <stop offset="5%" stopColor="#E977F5" stopOpacity={0.8}/>
                         <stop offset="95%" stopColor="#E977F5" stopOpacity={0.1}/>
                       </linearGradient>
                     </defs>
                     <CartesianGrid key="grid" strokeDasharray="3 3" stroke="rgba(255,255,255,0.05)" vertical={false} />
                     <XAxis 
                       key="xaxis"
                       dataKey="year" 
                       stroke="#94a3b8" 
                       tickFormatter={(v) => `Year ${v}`} 
                       tickLine={false} 
                       axisLine={false} 
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
                       contentStyle={{ backgroundColor: "#042142", border: "1px solid rgba(233,119,245,0.3)", borderRadius: "12px", color: "#fff" }}
                     />
                     <Legend key="legend" verticalAlign="top" height={36} iconType="circle" />
                     <Area 
                       key="area1"
                       isAnimationActive={false}
                       type="monotone" 
                       dataKey="invested" 
                       name="Your Investment" 
                       stackId="1" 
                       stroke="#2475AC" 
                       fill="url(#colorInvested)" 
                       strokeWidth={2}
                     />
                     <Area 
                       key="area2"
                       isAnimationActive={false}
                       type="monotone" 
                       dataKey="returns" 
                       name="Compounding Returns" 
                       stackId="1" 
                       stroke="#E977F5" 
                       fill="url(#colorReturns)" 
                       strokeWidth={2}
                     />
                   </AreaChart>
                 </ResponsiveContainer>
               </div>
            </GlassCard>

          </div>
        </div>
      </div>
    </div>
  );
}
