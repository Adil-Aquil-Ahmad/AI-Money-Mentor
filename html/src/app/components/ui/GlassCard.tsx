import { ReactNode } from "react";
import { motion, HTMLMotionProps } from "motion/react";
import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

interface GlassCardProps extends HTMLMotionProps<"div"> {
  children: ReactNode;
  className?: string;
  glowColor?: string;
}

export function GlassCard({ children, className, glowColor, ...props }: GlassCardProps) {
  return (
    <motion.div
      className={cn(
        "relative rounded-[32px] border border-white/10 bg-white/[0.02] backdrop-blur-xl overflow-hidden",
        className
      )}
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.4, ease: "easeOut" }}
      {...props}
    >
      {glowColor && (
        <div 
          className="absolute -top-40 -left-40 w-80 h-80 rounded-full blur-[100px] opacity-30 pointer-events-none"
          style={{ backgroundColor: glowColor }}
        />
      )}
      <div className="relative z-10 w-full h-full p-6">
        {children}
      </div>
    </motion.div>
  );
}
