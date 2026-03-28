import { useState, useRef, useEffect } from "react";
import { Send, Sparkles, User, RefreshCw, BarChart2, TrendingUp, TrendingDown } from "lucide-react";
import { motion, AnimatePresence } from "motion/react";
import { GlassCard } from "../components/ui/GlassCard";
import { toast } from "sonner";

interface Message {
  id: string;
  role: "user" | "advisor";
  text: string;
  data?: any;
}

export function ChatAdvisor() {
  const [messages, setMessages] = useState<Message[]>([
    {
      id: "init",
      role: "advisor",
      text: "Hello! I'm your AI Money Mentor. Based on your profile, you have a moderate risk tolerance and your primary goal is buying a house in 5 years. How can I help you today?",
    }
  ]);
  const [input, setInput] = useState("");
  const [isTyping, setIsTyping] = useState(false);
  const bottomRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages, isTyping]);

  const handleSend = () => {
    if (!input.trim()) return;

    const userMsg: Message = { id: Date.now().toString(), role: "user", text: input };
    setMessages(prev => [...prev, userMsg]);
    setInput("");
    setIsTyping(true);

    // Simulate AI response
    setTimeout(() => {
      let aiResponse: Message = { id: (Date.now() + 1).toString(), role: "advisor", text: "" };

      if (userMsg.text.toLowerCase().includes("reliance")) {
        aiResponse.text = "Here is the latest data on Reliance Industries (RIL). Given your goal to buy a house in 5 years, this is a solid large-cap hold, though I wouldn't aggressively accumulate right now.";
        aiResponse.data = {
          type: "stock",
          name: "Reliance Industries",
          price: "₹2,950.40",
          change: "+1.2%",
          pe: "28.5",
          trend: "up",
          range: "₹2,220 - ₹3,024"
        };
      } else if (userMsg.text.toLowerCase().includes("compare tcs")) {
        aiResponse.text = "Comparing TCS and Infosys for your portfolio: TCS currently trades at a higher premium but offers more stability. Infosys has better growth projections for the next 4 quarters. Since you already hold 15% in mid-cap IT, I'd suggest TCS to balance the risk.";
      } else {
        aiResponse.text = "Based on your current savings rate of 30%, you're on track. I recommend increasing your SIP by ₹2,000 next month if possible to accelerate your timeline by 8 months.";
      }

      setMessages(prev => [...prev, aiResponse]);
      setIsTyping(false);
    }, 1500);
  };

  const clearChat = () => {
    setMessages([{ id: "init", role: "advisor", text: "Chat history cleared. How can I assist you now?" }]);
    toast.success("Chat history cleared.");
  };

  return (
    <div className="flex flex-col h-full relative p-6">
      {/* Header */}
      <div className="flex items-center justify-between mb-8 z-20">
        <div>
          <h2 className="text-3xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-white to-[#3DE0FC]">
            AI Chat Advisor
          </h2>
          <p className="text-slate-400 text-sm mt-1">Personalized, data-driven financial advice</p>
        </div>
        <button 
          onClick={clearChat}
          className="flex items-center gap-2 px-4 py-2 rounded-full border border-white/10 hover:bg-white/5 transition-all text-sm text-slate-300"
        >
          <RefreshCw size={16} />
          Clear Chat
        </button>
      </div>

      {/* Chat Area */}
      <div className="flex-1 overflow-y-auto no-scrollbar pb-32 flex flex-col gap-6 z-20 px-2">
        <AnimatePresence>
          {messages.map((msg) => (
            <motion.div
              key={msg.id}
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              className={`flex gap-4 max-w-[85%] ${msg.role === "user" ? "ml-auto flex-row-reverse" : "mr-auto"}`}
            >
              <div className={`w-10 h-10 rounded-full flex items-center justify-center shrink-0 shadow-lg ${
                msg.role === "user" 
                  ? "bg-gradient-to-br from-[#E977F5] to-[#733E85] text-white" 
                  : "bg-gradient-to-br from-[#3DE0FC] to-[#2475AC] text-black"
              }`}>
                {msg.role === "user" ? <User size={20} /> : <Sparkles size={20} className="text-white" />}
              </div>
              <div className="flex flex-col gap-2">
                <GlassCard 
                  className={`!rounded-[24px] !p-4 !bg-opacity-20 backdrop-blur-md ${
                    msg.role === "user" 
                      ? "!bg-[#733E85]/20 !border-[#E977F5]/30 text-white" 
                      : "!bg-[#153C6A]/30 !border-[#3DE0FC]/30 text-slate-200 leading-relaxed"
                  }`}
                >
                  {msg.text}
                </GlassCard>

                {/* Rich Data Presentation */}
                {msg.data && msg.data.type === "stock" && (
                  <GlassCard className="!p-5 !rounded-[24px] !bg-[#042142]/60 !border-white/10 mt-2 flex flex-col gap-4">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-3">
                        <div className="w-10 h-10 rounded-full bg-white/5 flex items-center justify-center border border-white/10">
                          <BarChart2 size={20} className="text-[#3DE0FC]" />
                        </div>
                        <div>
                          <h4 className="font-semibold text-white">{msg.data.name}</h4>
                          <span className="text-xs text-slate-400">Live Data</span>
                        </div>
                      </div>
                      <div className="text-right">
                        <div className="font-bold text-xl">{msg.data.price}</div>
                        <div className="text-[#3DE0FC] flex items-center gap-1 text-sm justify-end">
                          <TrendingUp size={14} /> {msg.data.change}
                        </div>
                      </div>
                    </div>
                    <div className="grid grid-cols-2 gap-4 mt-2">
                      <div className="bg-white/5 rounded-xl p-3 border border-white/5">
                        <div className="text-xs text-slate-400 mb-1">P/E Ratio</div>
                        <div className="font-medium">{msg.data.pe}</div>
                      </div>
                      <div className="bg-white/5 rounded-xl p-3 border border-white/5">
                        <div className="text-xs text-slate-400 mb-1">52W Range</div>
                        <div className="font-medium">{msg.data.range}</div>
                      </div>
                    </div>
                  </GlassCard>
                )}
              </div>
            </motion.div>
          ))}
          {isTyping && (
            <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="flex gap-4 mr-auto">
              <div className="w-10 h-10 rounded-full bg-gradient-to-br from-[#3DE0FC] to-[#2475AC] flex items-center justify-center shrink-0">
                <Sparkles size={20} className="text-white animate-pulse" />
              </div>
              <div className="bg-[#153C6A]/30 border border-[#3DE0FC]/30 rounded-[24px] p-4 flex items-center gap-2">
                <div className="w-2 h-2 rounded-full bg-[#3DE0FC] animate-bounce" style={{ animationDelay: '0ms' }} />
                <div className="w-2 h-2 rounded-full bg-[#3DE0FC] animate-bounce" style={{ animationDelay: '150ms' }} />
                <div className="w-2 h-2 rounded-full bg-[#3DE0FC] animate-bounce" style={{ animationDelay: '300ms' }} />
              </div>
            </motion.div>
          )}
        </AnimatePresence>
        <div ref={bottomRef} />
      </div>

      {/* Input Area - Absolute positioned at bottom */}
      <div className="absolute bottom-6 left-6 right-6 z-30">
        <GlassCard className="!p-2 !rounded-full !bg-[#042142]/80 !border-white/20 shadow-[0_10_40px_rgba(0,0,0,0.5)] backdrop-blur-xl transition-all focus-within:!border-[#3DE0FC]/50 focus-within:shadow-[0_0_30px_rgba(61,224,252,0.2)]">
          <div className="flex items-center gap-3 w-full pl-6 pr-2 py-2">
            <input
              type="text"
              value={input}
              onChange={(e) => setInput(e.target.value)}
              onKeyDown={(e) => e.key === "Enter" && handleSend()}
              placeholder="Ask about your portfolio, a specific stock, or next steps..."
              className="flex-1 bg-transparent border-none outline-none text-white placeholder-slate-400 text-lg"
            />
            <button
              onClick={handleSend}
              disabled={!input.trim()}
              className="w-12 h-12 rounded-full bg-gradient-to-br from-[#3DE0FC] to-[#2475AC] flex items-center justify-center shrink-0 text-white disabled:opacity-50 disabled:cursor-not-allowed hover:shadow-[0_0_20px_rgba(61,224,252,0.6)] transition-all transform hover:scale-105"
            >
              <Send size={20} className="ml-1" />
            </button>
          </div>
        </GlassCard>
      </div>
    </div>
  );
}
