import { createBrowserRouter } from "react-router";
import { Layout } from "./components/Layout";
import { ChatAdvisor } from "./pages/ChatAdvisor";
import { FinancialProfile } from "./pages/FinancialProfile";
import { HealthScore } from "./pages/HealthScore";
import { PortfolioTracker } from "./pages/PortfolioTracker";
import { FireCalculator } from "./pages/FireCalculator";
import { WhatIfSimulator } from "./pages/WhatIfSimulator";

export const router = createBrowserRouter([
  {
    path: "/",
    Component: Layout,
    children: [
      { index: true, Component: ChatAdvisor },
      { path: "profile", Component: FinancialProfile },
      { path: "health-score", Component: HealthScore },
      { path: "portfolio", Component: PortfolioTracker },
      { path: "fire-calculator", Component: FireCalculator },
      { path: "what-if", Component: WhatIfSimulator },
    ],
  },
]);
