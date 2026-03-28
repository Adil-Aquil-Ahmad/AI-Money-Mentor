"""
AI Money Mentor — Deterministic fallback responses.
"""
import logging

logger = logging.getLogger("templates")


def strict_template_response(intent: dict, profile: dict, rule_output: dict, stock_data: list | None = None) -> str | None:
    """Return deterministic responses for high-confidence template-driven queries."""
    stock_data = stock_data or []
    intents = intent.get("intents", [intent.get("intent", "general_advice")])
    strategy = rule_output.get("strategy", {})
    ps = rule_output.get("profile_summary", {})
    snapshot = rule_output.get("financial_snapshot", {})
    amount = int(rule_output.get("allocation_target_amount") or (intent.get("amounts") or [0])[0] or 0)
    goals = ps.get("goal_names", ps.get("goals", []))

    if "multi_goal_planning" in intents and len(goals) >= 2 and ps.get("total_savings", 0) > 0:
        amount = amount or int(ps.get("total_savings", 0))
        capital_lines = strategy.get("capital_allocation", [])[:5]
        monthly_lines = strategy.get("monthly_plan", [])[:3]
        stock_lines = [
            "Use Nifty 50 or Nifty Next 50 index funds as the core investment exposure.",
            "Keep direct stocks small: Reliance Industries (energy), TCS / Infosys (IT), HDFC Bank (banking).",
            "Treat direct stocks as only 20-30% of the equity bucket, not the whole portfolio.",
        ]
        return (
            "Priority:\n"
            "- You now have two goals: house first and car second. These need separate buckets and separate timelines.\n\n"
            "Capital Allocation:\n"
            f"- Full allocation of Rs{amount:,} is covered below.\n"
            f"{_bullet_block(capital_lines)}\n\n"
            "Investment Strategy:\n"
            "- Keep the house fund as the priority because it is the larger goal.\n"
            "- If the car is needed within 1-2 years, keep the car fund in safe assets.\n"
            "- If the car timing is flexible, keep house contributions ahead of the car bucket.\n\n"
            "Monthly Plan:\n"
            f"{_bullet_block(monthly_lines)}\n\n"
            "Stock Suggestions:\n"
            f"{_bullet_block(stock_lines)}\n\n"
            "What Not To Do:\n"
            "- Do not mix house money, car money, and long-term investing into one generic pool.\n"
            "- Do not let a car purchase consume the house fund without a separate allocation.\n"
            "- Do not overreact with aggressive equity while both goal timelines are still unclear."
        )

    if "invest_savings" in intents and amount:
        capital_lines = strategy.get("capital_allocation", [])[:4]
        monthly_lines = strategy.get("monthly_plan", [])[:3]
        stock_lines = [
            "Use Nifty 50 or Nifty Next 50 index funds as the core equity exposure.",
            "Keep direct stocks small: Reliance Industries (energy), TCS / Infosys (IT), HDFC Bank (banking).",
            "Limit direct stocks to about 20-30% of the equity bucket, not the full corpus.",
        ]
        risk_line = ""
        if ps.get("goal_horizon") == "short_term":
            risk_line = "- Because the goal is short-term, keep the majority in FD or liquid funds."
        elif ps.get("goal_horizon") == "unknown":
            risk_line = "- Until the house timeline is clear, keep the majority in FD or liquid funds."

        monthly_block = _bullet_block(monthly_lines)
        if risk_line:
            monthly_block = f"{monthly_block}\n{risk_line}" if monthly_block else risk_line

        return (
            "Capital Allocation:\n"
            f"- Full allocation of Rs{amount:,} is covered below.\n"
            f"{_bullet_block(capital_lines)}\n\n"
            "Monthly Plan:\n"
            f"{monthly_block}\n\n"
            "Stock Suggestions:\n"
            f"{_bullet_block(stock_lines)}\n\n"
            "What Not To Do:\n"
            "- Do not invest the entire savings corpus into stocks.\n"
            "- Do not rely only on SIPs while leaving existing capital unallocated.\n"
            "- Do not increase equity exposure until the goal timeline and budget are clearer."
        )

    if "best_stocks" in intents and "invest_now" not in intents:
        stock_lines = []
        if ps.get("total_savings", 0) > 0 and snapshot.get("emergency_fund_gap", 0) > 0:
            stock_lines.append("Stocks are secondary until emergency reserves and core allocation are in place.")
        stock_lines.extend([
            "Use index funds as the base and keep direct stocks limited to about 20-30% of the equity allocation.",
            "Focus on stable sectors such as IT, banking, and energy.",
            "Examples: Reliance Industries, TCS, Infosys, and HDFC Bank. These are examples, not guarantees.",
        ])
        return (
            "Priority:\n"
            "Get the broader allocation right first, then use direct stocks only as a small satellite bucket.\n\n"
            "Stock Suggestions:\n"
            f"{_bullet_block(stock_lines)}\n\n"
            "What Not To Do:\n"
            "- Do not build the portfolio around one stock.\n"
            "- Do not skip index funds and jump straight into concentrated picks."
        )

    if "invest_now" in intents and stock_data:
        mover_lines = []
        for item in stock_data[:5]:
            change = item.get("change_percent", 0)
            sign = "+" if change > 0 else ""
            volume = item.get("volume")
            volume_text = f", volume {volume:,}" if isinstance(volume, (int, float)) else ""
            mover_lines.append(
                f"{item['name']}: Rs{item['price']:,.2f} ({sign}{change}%)" + volume_text
            )
        return (
            "Market Movers Today:\n"
            f"{_bullet_block(mover_lines)}\n\n"
            "Disclaimer:\n"
            "- Short-term movement does not equal long-term quality.\n\n"
            "What Not To Do:\n"
            "- Do not invest based only on today's move.\n"
            "- Use diversified funds plus only a small direct-stock allocation."
        )

    return None


def template_fallback(user_input: str, profile: dict, rule_output: dict) -> str:
    """Return a minimal deterministic response when LLM generation fails."""
    msg_lower = user_input.lower()
    ps = rule_output.get("profile_summary", {})
    strategy = rule_output.get("strategy", {})

    monthly_savings = ps.get("monthly_savings", 0)
    risk = ps.get("risk_profile", "medium")
    primary_goal = ps.get("goal_name") or ", ".join(ps.get("goals", []))
    emergency_gap = rule_output.get("financial_snapshot", {}).get("emergency_fund_gap", 0)
    primary_priority = strategy.get("primary_priority", "protect liquidity first")
    action_lines = strategy.get("monthly_plan", [])[:2]
    capital_lines = strategy.get("capital_allocation", [])[:3]
    stock_lines = strategy.get("stock_guidance", [])[:3]
    intents = rule_output.get("intents", [])

    logger.info("TERTIARY SYSTEM TRIGGERED: Using static template fallback.")

    if any(q in msg_lower for q in ["best stocks", "which stock", "stock"]):
        if any(item in intents for item in ["invest_savings", "invest_lumpsum", "allocate_money", "how_much_to_invest"]) or rule_output.get("goal_amount_hint"):
            capital_block = "\n".join(f"- {line}" for line in (capital_lines or ["Allocate the stated amount across safety, goal funding, and only then long-term investing."]))
            stock_block = "\n".join(f"- {line}" for line in (stock_lines or ["Use diversified index funds as the base and keep direct stocks secondary."]))
            return (
                "Capital Allocation:\n"
                f"{capital_block}\n\n"
                "Monthly Plan:\n"
                f"- {action_lines[0] if action_lines else 'Invest gradually after liquidity and goal funding are covered.'}\n\n"
                "Stock Suggestions:\n"
                f"{stock_block}\n\n"
                "What Not To Do:\n"
                "Do not turn a full savings-allocation decision into a single-stock picking exercise."
            )
        return (
            "Priority:\n"
            "Stay diversified instead of chasing a single stock.\n\n"
            "Why:\n"
            "A concentrated stock call would ignore your broader financial plan and risk control.\n\n"
            "Action Plan:\n"
            "Use diversified index funds first, then review individual stocks only as a small satellite allocation.\n\n"
            "What Not To Do:\n"
            "Do not treat one stock pick as your main investment strategy."
        )

    plan_lines = []
    if emergency_gap > 0:
        plan_lines.append(f"Close the emergency fund gap of Rs{emergency_gap:,.0f} first.")
    plan_lines.extend(action_lines)
    plan_lines.extend(capital_lines)
    if not plan_lines:
        plan_lines.append(f"Invest from your real monthly surplus of Rs{monthly_savings:,.0f}, not from guesswork.")

    stock_block = "\n".join(f"- {line}" for line in stock_lines) if stock_lines else "- Use index funds as the base and keep direct stocks secondary."

    return (
        "Capital Allocation:\n"
        + "\n".join(f"- {line}" for line in plan_lines[:3]) +
        "\n\nMonthly Plan:\n"
        f"- Continue SIPs from monthly savings of Rs{monthly_savings:,.0f} into index or hybrid funds.\n\n"
        "Stock Suggestions:\n"
        f"{stock_block}\n\n"
        "What Not To Do:\n"
        "Do not jump into generic allocation advice or aggressive investing before your core priorities are covered."
    )


def _bullet_block(lines: list[str]) -> str:
    return "\n".join(f"- {line}" for line in lines if line)
