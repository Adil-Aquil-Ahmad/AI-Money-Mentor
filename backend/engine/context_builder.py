"""
Chrysos — Strategy-first prompt assembly.
Builds a single-pass prompt using normalized profile data, deterministic strategy,
recent memory, recent chat context, and a few relevant knowledge facts.
"""
import json
import os
import logging

logger = logging.getLogger("context_builder")


_knowledge = {}
_knowledge_path = os.path.join(os.path.dirname(__file__), "..", "data", "financial_knowledge.json")
try:
    with open(_knowledge_path, "r", encoding="utf-8") as f:
        _knowledge = json.load(f)
except Exception as e:
    logger.warning("Could not load financial_knowledge.json: %s", e)


BASE_SYSTEM = (
    "MASTER SYSTEM PROMPT - AI MONEY MENTOR\n\n"
    "You are a professional Indian financial advisor.\n"
    "Your job is to explain a financial strategy that is already computed by the backend.\n"
    "Do not invent new numbers. You may reason using provided values.\n"
    "Use the strategy object as the source of truth.\n"
    "Do not fall back to generic allocations or beginner templates.\n\n"
    "You must first determine:\n"
    "1. The user's biggest financial priority\n"
    "2. How existing savings should be used\n"
    "3. The safest optimal strategy for their goal\n\n"
    "If the user has high savings, start from capital allocation, not SIP advice.\n"
    "If the user has large existing savings, always explain how the current corpus should be split before discussing monthly flows.\n"
    "If timeline or goal cost is unclear, say that directly and keep the strategy conservative.\n"
    "If the user has an emergency fund gap or costly debt, do not ignore it.\n"
    "If the user asks multiple questions, you must answer all parts and must not ignore any portion.\n"
    "Whenever a user provides a specific amount of money, you must explain how to allocate it.\n"
    "If the user provides total savings, you must allocate 100% of that amount. No partial allocation is allowed.\n"
    "If the user asks for stocks, you must provide 3-5 example stocks or sectors, or index funds plus 1-2 stock examples.\n"
    "For savings-allocation questions, do not stop at monthly flow. Start with the existing corpus split.\n"
    "For stock-related queries, use live yfinance-backed data when available and show price plus percentage change.\n"
    "When a current portfolio snapshot is provided, analyze winners, losers, allocation, and recent news without overreacting.\n"
    "Do not give direct buy or sell commands based only on short-term performance or headlines.\n"
    "If the user has monthly savings, you must provide a SIP amount and SIP type.\n"
    "Keep the answer practical, financially correct, and personalized.\n"
    "Target length: 100-180 words.\n"
)


KNOWLEDGE_INTENT_MAP = {
    "multi_goal_planning": ["risk_categories", "index_funds"],
    "invest_savings": ["sip_strategies", "risk_categories", "index_funds"],
    "best_stocks": ["index_funds", "risk_categories"],
    "best_mutual_funds": ["sip_strategies", "index_funds", "risk_categories"],
    "tax_saving": ["tax_saving_instruments"],
    "start_investing": ["sip_strategies", "risk_categories", "index_funds"],
    "beginner_investing": ["sip_strategies", "risk_categories", "index_funds"],
    "reduce_risk": ["risk_categories", "index_funds"],
    "buy_house": ["risk_categories"],
    "good_portfolio": ["risk_categories", "index_funds"],
    "rebalance_portfolio": ["risk_categories", "index_funds"],
    "diversify_portfolio": ["risk_categories", "index_funds"],
}

INTENT_PLAYBOOKS = {
    "multi_goal_planning": [
        "Detect and mention both goals explicitly.",
        "Prioritize the larger goal first, usually house before car.",
        "Allocate savings across emergency fund, goal one, goal two, and only then investments.",
        "Split monthly savings across both goals and SIPs.",
        "Do not ignore the smaller goal or collapse everything into the house plan.",
    ],
    "invest_savings": [
        "Use the savings template exactly: Capital Allocation, Monthly Plan, Stock Suggestions, What Not To Do.",
        "Start with full allocation of the stated savings corpus.",
        "Break the corpus into emergency fund, goal-based safe allocation, and investment portion.",
        "Use FD or liquid funds for safety and index funds for growth.",
        "After corpus allocation, give a monthly continuation plan.",
        "Do not answer with monthly flow only.",
    ],
    "best_stocks": [
        "First check whether the user's allocation is already in order. If not, say stocks are secondary.",
        "Suggest sectors such as IT, banking, and energy.",
        "Give 3-5 concrete examples like Reliance, TCS, Infosys, and HDFC Bank.",
        "State that these are examples, not guarantees.",
        "Keep direct stocks to a small portion and combine them with index funds.",
    ],
    "invest_now": [
        "Use live yfinance-backed market data when available.",
        "For 'going up today' or 'best stock today', show 3-5 names with price and percentage move.",
        "Add a disclaimer that short-term movement does not equal long-term quality.",
        "Do not recommend investing based only on today's move.",
    ],
    "how_much_to_invest": [
        "Use the monthly investing template: split monthly savings into goal fund, SIP, and buffer.",
        "Give a real SIP amount range and mention index funds or hybrid funds.",
    ],
    "invest_lumpsum": [
        "Use the lump-sum template: allocate 100% of the lump sum.",
        "Split into emergency reserve, safe allocation, and staggered equity.",
        "Say clearly not to put the full lump sum into equity at once.",
    ],
    "goal_planning": [
        "Prioritize goals and separate money by goal and timeline.",
    ],
    "buy_house": [
        "Identify the timeline and say clearly if it is missing.",
        "For short-term house goals, keep most money in FD or liquid funds and limit equity.",
        "Allocate existing savings before monthly flows.",
    ],
    "next_steps": [
        "Give only the most important 3-5 steps using actual profile numbers.",
    ],
    "am_i_saving_enough": [
        "Calculate savings rate and compare it against a 20-30% benchmark and the user's goals.",
    ],
    "emergency_fund": [
        "Use 3-6 months of expenses, compare against current reserves, and state the gap.",
    ],
    "diversify_portfolio": [
        "Show how equity, debt, funds, and direct stocks should be balanced to reduce concentration.",
    ],
    "bonus_money": [
        "Split bonus into goal funding, investment, and buffer.",
    ],
    "reduce_risk": [
        "Use emergency fund, diversification, and asset allocation to reduce risk.",
    ],
    "manage_income": [
        "Split salary into expenses, savings, and investing.",
    ],
    "best_mutual_funds": [
        "Favor index, large-cap, and hybrid funds. Avoid random fund naming without context.",
    ],
    "start_investing": [
        "Keep the setup simple with SIPs, index funds, and buffer building.",
    ],
    "good_portfolio": [
        "Use the live portfolio summary, not a generic template.",
        "Mention the overall gain or loss, the strongest holding, and the weakest holding.",
        "Suggest review or rebalancing where concentration is high, but do not give extreme buy or sell commands.",
        "Use recent news only as context, not as a trigger for impulsive action.",
    ],
    "rebalance_portfolio": [
        "Check concentration, direct-stock exposure, and diversification gaps.",
        "Recommend gradual rebalancing and better balance across asset types.",
        "Do not tell the user to dump a position immediately because of short-term moves.",
    ],
    "diversify_portfolio": [
        "Use the tracked holdings to identify concentration by type or position.",
        "Suggest diversification across funds, debt, gold, and direct stocks where appropriate.",
    ],
}


def build_response_context(
    profile: dict,
    rule_output: dict,
    chat_history: list,
    intent: dict,
    memories: list | None = None,
    stock_data: list | None = None,
    portfolio_context: dict | None = None,
) -> tuple[str, str]:
    """Single-pass response prompt with compact strategy and supporting context."""
    memories = memories or []
    stock_data = stock_data or []
    ps = rule_output.get("profile_summary", {})
    strategy = rule_output.get("strategy", {})
    msg = intent.get("original_message", "")
    multi_intent = len(intent.get("intents", [])) > 1

    sections = [
        _profile_section(ps),
        _strategy_section(strategy),
        _facts_section(rule_output),
    ]

    knowledge_facts = _select_knowledge_facts(intent.get("intents", [intent.get("intent", "general_advice")]), ps, strategy)
    if knowledge_facts:
        sections.append("Relevant knowledge facts:\n" + "\n".join(f"- {fact}" for fact in knowledge_facts))

    if stock_data:
        lines = []
        for stock in stock_data[:5]:
            line = f"{stock['name']}: Rs{stock['price']:,.2f}"
            if stock.get("change_percent") is not None:
                sign = "+" if stock["change_percent"] > 0 else ""
                line += f" ({sign}{stock['change_percent']}%)"
            lines.append(f"- {line}")
        sections.append("Live market data:\n" + "\n".join(lines))

    if portfolio_context and portfolio_context.get("assets"):
        sections.append(_portfolio_section(portfolio_context))

    if memories:
        mem_bits = [m["content"] for m in memories[:3]]
        sections.append("Long-term memory:\n" + "\n".join(f"- {bit}" for bit in mem_bits))

    history_section = _history_section(chat_history, msg, intent)
    if history_section:
        sections.append(history_section)

    if multi_intent:
        sections.append("Requested answer coverage:\n" + "\n".join(f"- {item}" for item in intent.get("intents", [])))
        sections.append("Intent playbook:\n" + "\n".join(_playbook_lines(intent.get("intents", []))))
    else:
        sections.append("Intent playbook:\n" + "\n".join(_playbook_lines(intent.get("intents", [intent.get("intent", "general_advice")]))))

    user_prompt = (
        f"User question:\n{msg}\n\n"
        f"{chr(10).join(section for section in sections if section)}\n\n"
        "Write the final response directly. Use actual numbers from context. "
        "When the user has large savings, explain the corpus split first and then the monthly split. "
        "Do not invent a precise rupee split unless the strategy provides a range or exact backend fact. "
        "If the timeline is unknown, say that it affects the house strategy. "
        "If the amount is the user's total savings, explicitly say that the full corpus is allocated across the listed buckets. "
        "For stock-related queries, use live stock data when available and include price plus percentage change where relevant. "
        f"{_template_contract(intent, strategy)} "
        f"{_response_structure_instruction(intent, multi_intent)} "
        "Do not mention backend, strategy object, prompt rules, or templates."
    )
    return BASE_SYSTEM, user_prompt


def build_correction_context(
    intent: dict,
    rule_output: dict,
    critical_issues: list[str],
    soft_issues: list[str],
    current_response: str,
) -> tuple[str, str]:
    """Compact prompt to improve an existing response without rewriting everything."""
    strategy = rule_output.get("strategy", {})
    issue_lines = []
    if critical_issues:
        issue_lines.append("Critical issues:")
        issue_lines.extend(f"- {check}" for check in critical_issues)
    if soft_issues:
        issue_lines.append("Soft issues:")
        issue_lines.extend(f"- {check}" for check in soft_issues[:6])
    user_prompt = (
        f"User question:\n{intent.get('original_message', '')}\n\n"
        "Current response:\n"
        f"{current_response}\n\n"
        + "\n".join(issue_lines) + "\n\n"
        f"{_strategy_section(strategy)}\n\n"
        "Improve this response by fixing the listed issues. "
        "Do not rewrite everything from scratch unless necessary. "
        "Keep the parts that are already correct. "
        f"{_template_contract(intent, strategy)} "
        f"{_response_structure_instruction(intent, len(intent.get('intents', [])) > 1)} "
        "Use only the provided numbers and stay within 100-180 words."
    )
    return BASE_SYSTEM, user_prompt


def _history_section(chat_history: list, current_message: str, intent: dict) -> str:
    if not chat_history:
        return ""

    intents = intent.get("intents", [intent.get("intent", "general_advice")])
    template_driven = any(item in intents for item in {
        "invest_savings", "invest_lumpsum", "best_stocks", "invest_now", "how_much_to_invest", "buy_house"
    })
    current_norm = (current_message or "").strip().lower()

    filtered = []
    recent_user_duplicates = 0
    for item in chat_history[-6:]:
        role = item["role"]
        content = item["content"]
        content_norm = (content or "").strip().lower()

        if role == "assistant" and template_driven:
            continue
        if role == "user" and content_norm == current_norm:
            recent_user_duplicates += 1
            if recent_user_duplicates > 1:
                continue

        filtered.append(item)

    if not filtered:
        return ""

    history_lines = []
    for item in filtered[-3:]:
        role = "User" if item["role"] == "user" else "Advisor"
        content = item["content"]
        if len(content) > 140:
            content = content[:140] + "..."
        history_lines.append(f"- {role}: {content}")
    return "Recent conversation:\n" + "\n".join(history_lines)


def _profile_section(ps: dict) -> str:
    goals = ", ".join(ps.get("goals", [])) if ps.get("goals") else "none stated"
    return (
        "Normalized profile:\n"
        f"- Age: {ps.get('age', 'N/A')}\n"
        f"- Monthly income: Rs{ps.get('income', 0):,}\n"
        f"- Monthly expenses: Rs{ps.get('expenses', 0):,}\n"
        f"- Monthly savings: Rs{ps.get('monthly_savings', 0):,}\n"
        f"- Savings rate: {ps.get('savings_rate', 0)}%\n"
        f"- Total savings: Rs{ps.get('total_savings', 0):,}\n"
        f"- Current investments: Rs{ps.get('investments', 0):,}\n"
        f"- Current debt: Rs{ps.get('debt', 0):,}\n"
        f"- Risk profile: {ps.get('risk_profile', 'medium')}\n"
        f"- Emergency fund months: {ps.get('emergency_fund_months', 0)}\n"
        f"- Goal horizon: {ps.get('goal_horizon', 'unknown')}\n"
        f"- Goals: {goals}"
    )


def _strategy_section(strategy: dict) -> str:
    parts = [
        "Deterministic strategy:",
        f"- Primary priority: {strategy.get('primary_priority', '')}",
        f"- Secondary priority: {strategy.get('secondary_priority', '')}",
    ]

    for item in strategy.get("capital_allocation", []):
        parts.append(f"- Capital allocation: {item}")
    for item in strategy.get("monthly_plan", []):
        parts.append(f"- Monthly plan: {item}")
    for item in strategy.get("constraints", []):
        parts.append(f"- Constraint: {item}")
    for item in strategy.get("warnings", []):
        parts.append(f"- Warning: {item}")
    for item in strategy.get("stock_guidance", []):
        parts.append(f"- Stock guidance: {item}")
    for item in strategy.get("sip_guidance", []):
        parts.append(f"- SIP guidance: {item}")
    for item in strategy.get("reasoning_facts", [])[:5]:
        parts.append(f"- Fact: {item}")

    return "\n".join(parts)


def _facts_section(rule_output: dict) -> str:
    snapshot = rule_output.get("financial_snapshot", {})
    lines = [
        "Computed financial facts:",
        f"- Emergency fund target: Rs{snapshot.get('emergency_fund_target', 0):,}",
        f"- Emergency fund gap: Rs{snapshot.get('emergency_fund_gap', 0):,}",
        f"- Investable surplus beyond reserve: Rs{snapshot.get('investable_surplus', 0):,}",
        f"- Income strength: {snapshot.get('income_strength', 'unknown')}",
        f"- Debt pressure: {snapshot.get('debt_pressure', 'unknown')}",
    ]
    if rule_output.get("tax_tips"):
        tax = rule_output["tax_tips"]
        lines.append(f"- Section 80C room reference: Rs{tax.get('80C_limit', 0):,}")
        lines.append(f"- Additional NPS deduction reference: Rs{tax.get('nps_80ccd', 0):,}")
    return "\n".join(lines)


def _portfolio_section(portfolio_context: dict) -> str:
    summary = portfolio_context.get("summary", {})
    winners = portfolio_context.get("winners", [])
    losers = portfolio_context.get("losers", [])
    allocation = portfolio_context.get("allocation", [])
    health = portfolio_context.get("health_score", {})
    news = portfolio_context.get("news", [])

    lines = [
        "Current investments snapshot:",
        f"- Total invested: Rs{summary.get('total_invested', 0):,}",
        f"- Current value: Rs{summary.get('current_value', 0):,}",
        f"- Gain/loss: Rs{summary.get('gain_loss', 0):,} ({summary.get('gain_loss_percent', 0)}%)",
        f"- Portfolio health score: {health.get('score', 0)}/100",
    ]

    if winners:
        lines.append(
            "- Winners: " + ", ".join(
                f"{item['name']} ({item.get('gain_loss_percent', 0)}%)" for item in winners[:3]
            )
        )
    if losers:
        lines.append(
            "- Laggards: " + ", ".join(
                f"{item['name']} ({item.get('gain_loss_percent', 0)}%)" for item in losers[:3]
            )
        )
    if allocation:
        lines.append(
            "- Allocation: " + ", ".join(
                f"{item['type']} {item.get('allocation_percent', 0)}%" for item in allocation[:5]
            )
        )
    if news:
        lines.append(
            "- Recent news: " + " | ".join(
                f"{item['asset_name']}: {item['headline']} ({item.get('sentiment', 'neutral')})"
                for item in news[:3]
            )
        )

    return "\n".join(lines)


def _select_knowledge_facts(intents: list[str], profile_summary: dict, strategy: dict) -> list[str]:
    sections = []
    for intent_type in intents:
        for item in KNOWLEDGE_INTENT_MAP.get(intent_type, []):
            if item not in sections:
                sections.append(item)
    facts = []

    for section_name in sections:
        section = _knowledge.get(section_name, {})
        facts.extend(_extract_facts(section_name, section, profile_summary))
        if len(facts) >= 3:
            break

    if any(intent_type in {"buy_house", "reduce_risk"} for intent_type in intents) and profile_summary.get("goal_horizon") == "short_term":
        facts.insert(0, "Near-term goals favor capital safety and liquidity over aggressive return-seeking.")

    return facts[:3]


def _response_structure_instruction(intent: dict, multi_intent: bool) -> str:
    intents = intent.get("intents", [intent.get("intent", "general_advice")])
    wants_allocation = bool(intent.get("amounts")) or any(item in intents for item in ["invest_savings", "invest_lumpsum", "allocate_money", "how_much_to_invest", "buy_house"])
    wants_portfolio_review = any(item in intents for item in ["good_portfolio", "rebalance_portfolio", "diversify_portfolio"])
    wants_stocks = any(item in intents for item in ["best_stocks", "invest_now"])
    savings_template = "invest_savings" in intents and bool(intent.get("amounts"))
    market_movers = "invest_now" in intents
    multi_goal = "multi_goal_planning" in intents

    if market_movers:
        return (
            "Use this exact structure: Market Movers Today:, Disclaimer:, What Not To Do:. "
            "In Market Movers Today, list 3-5 names with price and percentage move."
        )
    if multi_goal:
        return (
            "Use this exact structure: Priority:, Capital Allocation:, Investment Strategy:, Monthly Plan:, "
            "Stock Suggestions:, What Not To Do:. You must mention both goals explicitly."
        )
    if wants_portfolio_review:
        return "Use this exact structure: Priority:, Why:, Action Plan:, What Not To Do:."
    if savings_template:
        return (
            "Use this exact structure: Capital Allocation:, Monthly Plan:, Stock Suggestions:, What Not To Do:. "
            "Do not replace Capital Allocation with a generic priority summary."
        )
    if multi_intent or (wants_allocation and wants_stocks):
        return (
            "Use this exact structure: Priority:, Capital Allocation:, Monthly Plan:, "
            "Stock Suggestions:, What Not To Do:. You must answer every intent in the query."
        )
    if wants_allocation:
        return "Use this exact structure: Priority:, Capital Allocation:, Monthly Plan:, What Not To Do:."
    if wants_stocks:
        return "Use this exact structure: Priority:, Stock Suggestions:, What Not To Do:."
    return "Use this exact structure: Priority:, Why:, Action Plan:, What Not To Do:."


def _playbook_lines(intents: list[str]) -> list[str]:
    lines = []
    for intent_type in intents:
        instructions = INTENT_PLAYBOOKS.get(intent_type, [])
        for instruction in instructions:
            lines.append(f"- {intent_type}: {instruction}")
    return lines or ["- general_advice: Keep the answer practical and tied to the user's profile."]


def _template_contract(intent: dict, strategy: dict) -> str:
    intents = intent.get("intents", [intent.get("intent", "general_advice")])
    amounts = intent.get("amounts", [])
    lines = []

    if "multi_goal_planning" in intents:
        lines.extend([
            "Mandatory multi-goal requirements:",
            "Mention both goals explicitly and prioritize them.",
            "Allocate savings across emergency fund, house goal, car goal, and investment bucket.",
            "Give a separate monthly split for each goal and SIPs.",
        ])

    if "invest_savings" in intents and amounts:
        lines.extend([
            "Mandatory savings template requirements:",
            "Allocate 100% of the stated savings corpus.",
            "Capital Allocation must include emergency fund, goal-safe bucket, and investment bucket.",
            "Monthly Plan must include a house/goal contribution and SIP amount with instrument type when monthly savings exist.",
            "Stock Suggestions must include index funds plus 3-5 stock or sector examples for the small allocation bucket.",
        ])

    if "best_stocks" in intents:
        lines.extend([
            "Mandatory stock template requirements:",
            "Do not answer with only 'diversify' or 'use index funds'.",
            "Include sectors and concrete examples such as Reliance, TCS, Infosys, and HDFC Bank when relevant.",
            "Say direct stocks should stay a limited part of the portfolio.",
        ])

    if "invest_now" in intents:
        lines.extend([
            "Mandatory market-movers requirements:",
            "Use live market data if available.",
            "Show price and percentage move for 3-5 names.",
            "Add a disclaimer that short-term movement is not long-term quality.",
        ])

    if any(item in intents for item in ["good_portfolio", "rebalance_portfolio", "diversify_portfolio"]):
        lines.extend([
            "Mandatory portfolio-review requirements:",
            "Mention overall portfolio gain or loss and at least one winner and one laggard when available.",
            "Use tracked allocation or concentration to support any rebalancing suggestion.",
            "Do not give direct buy/sell commands based only on news or short-term price moves.",
        ])

    if not lines:
        return ""
    return " ".join(lines)


def _extract_facts(section_name: str, section: dict, profile_summary: dict) -> list[str]:
    if not isinstance(section, dict):
        return []

    risk = profile_summary.get("risk_profile", "medium")
    facts = []

    if section_name == "risk_categories":
        selected = section.get(risk)
        if selected:
            facts.append(
                f"For {risk} risk, common instruments are {', '.join(selected.get('instruments', [])[:3])}."
            )
            if selected.get("suitable_for"):
                facts.append(selected["suitable_for"])

    elif section_name == "sip_strategies":
        if risk == "low":
            key = "beginner"
        elif risk == "high":
            key = "aggressive"
        else:
            key = "moderate"
        selected = section.get(key)
        if selected:
            if selected.get("recommended_allocation"):
                facts.append(f"Typical SIP mix reference: {selected['recommended_allocation']}.")
            if selected.get("tip"):
                facts.append(selected["tip"])

    elif section_name == "index_funds":
        if "nifty_50" in section:
            nifty = section["nifty_50"]
            facts.append(f"{nifty.get('name')}: {nifty.get('best_for', '')}.")
        if risk in {"medium", "high"} and "nifty_midcap_150" in section:
            mid = section["nifty_midcap_150"]
            facts.append(f"{mid.get('name')}: {mid.get('risk', '')}.")

    elif section_name == "tax_saving_instruments":
        elss = section.get("elss")
        nps = section.get("nps")
        if elss:
            facts.append(f"ELSS offers {elss.get('tax_benefit', '')} with {elss.get('lock_in', '')}.")
        if nps:
            facts.append(f"NPS gives {nps.get('extra_deduction', '')}.")

    return [fact for fact in facts if fact]
