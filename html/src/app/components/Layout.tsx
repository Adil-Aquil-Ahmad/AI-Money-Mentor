import { Outlet, NavLink, useLocation } from "react-router";
import { 
  MessageSquare, User, Activity, PieChart, 
  Flame, HelpCircle, LogOut, Sun, Moon, Wallet
} from "lucide-react";
import { useState, useEffect } from "react";
import { toast } from "sonner";
import { motion, AnimatePresence } from "motion/react";

export function Layout() {
  const [theme, setTheme] = useState<"dark" | "light">("dark");
  
  // Apply theme class to root html element for global styling if needed, 
  // but we can also just use a wrapper class
  useEffect(() => {
    if (theme === "dark") {
      document.documentElement.classList.add("dark");
    } else {
      document.documentElement.classList.remove("dark");
    }
  }, [theme]);

  const toggleTheme = () => {
    setTheme(theme === "dark" ? "light" : "dark");
    toast(`Switched to ${theme === "dark" ? "light" : "dark"} mode!`);
  };

  const navLinks = [
    { to: "/", icon: MessageSquare, label: "Advisor Chat" },
    { to: "/profile", icon: User, label: "My Profile" },
    { to: "/health-score", icon: Activity, label: "Health Score" },
    { to: "/portfolio", icon: PieChart, label: "Portfolio" },
    { to: "/fire-calculator", icon: Flame, label: "FIRE Calculator" },
    { to: "/what-if", icon: HelpCircle, label: "What-If Simulator" },
  ];

  const handleLogout = () => {
    toast.success("Logged out successfully.");
  };

  return (
    <div className={`flex h-screen w-full transition-colors duration-500 overflow-hidden ${theme === 'dark' ? 'bg-[#042142] text-white' : 'bg-slate-100 text-slate-900'}`}>
      {/* Background Orbs */}
      <div className="absolute top-0 left-0 w-full h-full overflow-hidden pointer-events-none z-0">
        <div className="absolute -top-40 -left-40 w-[500px] h-[500px] bg-[#733E85] rounded-full mix-blend-screen filter blur-[150px] opacity-40 animate-pulse-slow"></div>
        <div className="absolute top-40 right-10 w-[400px] h-[400px] bg-[#153C6A] rounded-full mix-blend-screen filter blur-[150px] opacity-50"></div>
        <div className="absolute -bottom-20 left-60 w-[600px] h-[600px] bg-[#3DE0FC] rounded-full mix-blend-screen filter blur-[150px] opacity-20"></div>
        <div className="absolute bottom-10 -right-20 w-[450px] h-[450px] bg-[#E977F5] rounded-full mix-blend-screen filter blur-[150px] opacity-30"></div>
      </div>

      {/* Sidebar */}
      <motion.aside 
        initial={{ x: -100, opacity: 0 }}
        animate={{ x: 0, opacity: 1 }}
        transition={{ duration: 0.5, ease: "easeOut" }}
        className="w-[280px] h-full p-4 z-10 hidden md:flex flex-col gap-4"
      >
        <div className={`flex-1 rounded-[32px] border ${theme === 'dark' ? 'border-white/10 bg-white/[0.02]' : 'border-slate-300 bg-white/50'} backdrop-blur-2xl flex flex-col p-6`}>
          <div className="flex items-center gap-3 mb-10">
            <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-[#3DE0FC] to-[#2475AC] flex items-center justify-center text-white font-bold text-xl shadow-[0_0_20px_rgba(61,224,252,0.5)]">
              <Wallet size={24} className="text-white" />
            </div>
            <h1 className="text-xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-[#042142] to-[#153C6A] dark:from-white dark:to-slate-400">
              Money Mentor
            </h1>
          </div>

          <nav className="flex-1 flex flex-col gap-2">
            {navLinks.map((link) => (
              <NavLink
                key={link.to}
                to={link.to}
                className={({ isActive }) => 
                  `flex items-center gap-4 px-4 py-3 rounded-2xl transition-all duration-300 ${
                    isActive 
                    ? `bg-gradient-to-r from-[#153C6A]/80 to-transparent border-l-4 border-[#3DE0FC] text-[#3DE0FC]`
                    : `text-slate-400 hover:text-white hover:bg-white/5`
                  }`
                }
              >
                <link.icon size={20} />
                <span className="font-medium text-sm">{link.label}</span>
              </NavLink>
            ))}
          </nav>

          <div className="mt-auto flex flex-col gap-2 pt-6 border-t border-white/10">
            <button 
              onClick={toggleTheme}
              className="flex items-center gap-4 px-4 py-3 rounded-2xl text-slate-400 hover:text-white hover:bg-white/5 transition-all"
            >
              {theme === "dark" ? <Sun size={20} /> : <Moon size={20} />}
              <span className="font-medium text-sm">{theme === "dark" ? "Light Mode" : "Dark Mode"}</span>
            </button>
            <button 
              onClick={handleLogout}
              className="flex items-center gap-4 px-4 py-3 rounded-2xl text-rose-400 hover:bg-rose-500/10 transition-all"
            >
              <LogOut size={20} />
              <span className="font-medium text-sm">Logout</span>
            </button>
          </div>
        </div>
      </motion.aside>

      {/* Main Content Area */}
      <main className="flex-1 h-full p-4 md:pl-0 z-10 overflow-hidden relative">
        <div className={`w-full h-full rounded-[32px] border ${theme === 'dark' ? 'border-white/10 bg-white/[0.01]' : 'border-slate-300 bg-white/40'} backdrop-blur-2xl overflow-y-auto no-scrollbar shadow-2xl relative`}>
          <AnimatePresence mode="wait">
            <Outlet />
          </AnimatePresence>
        </div>
      </main>

      {/* Mobile Nav (simplified for real app, but just stubbed here) */}
      <div className="md:hidden fixed bottom-0 left-0 w-full h-20 bg-[#042142]/90 backdrop-blur-lg border-t border-white/10 z-50 flex items-center justify-around px-4">
         {navLinks.slice(0, 5).map(link => (
            <NavLink
              key={link.to}
              to={link.to}
              className={({ isActive }) => `p-3 rounded-xl ${isActive ? 'bg-[#153C6A] text-[#3DE0FC]' : 'text-slate-400'}`}
            >
              <link.icon size={24} />
            </NavLink>
         ))}
      </div>
    </div>
  );
}
