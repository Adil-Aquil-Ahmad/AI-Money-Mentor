"""
Canonical intent registry for the chat pipeline.
All intents should be normalized to this set before rule execution.
"""

CANONICAL_INTENTS = [
    "multi_goal_planning",
    "next_steps",
    "invest_savings",
    "best_stocks",
    "sip_advice",
    "emergency_fund",
    "budgeting",
    "goal_planning",
    "tax_saving",
    "beginner_investing",
    "debt_management",
    "how_much_to_invest",
    "am_i_saving_enough",
    "diversify_portfolio",
    "invest_lumpsum",
    "sip_vs_stocks",
    "best_mutual_funds",
    "invest_or_save",
    "buy_house",
    "reduce_risk",
    "good_portfolio",
    "start_investing",
    "invest_now",
    "manage_income",
    "allocate_money",
    "grow_wealth",
    "bonus_money",
    "rebalance_portfolio",
    "efund_amount",
    "general_advice",
]

INTENT_PRIORITY = {
    "multi_goal_planning": 110,
    "invest_savings": 100,
    "goal_planning": 95,
    "next_steps": 90,
    "buy_house": 88,
    "invest_lumpsum": 85,
    "how_much_to_invest": 82,
    "allocate_money": 80,
    "bonus_money": 78,
    "best_mutual_funds": 60,
    "start_investing": 58,
    "beginner_investing": 56,
    "best_stocks": 45,
    "sip_advice": 40,
}


LEGACY_INTENT_MAP = {
    "salary_received": "manage_income",
    "new_job": "manage_income",
    "bonus_received": "bonus_money",
    "savings_query": "am_i_saving_enough",
    "expense_query": "budgeting",
    "investment_query": "invest_savings",
    "stock_query": "best_stocks",
    "goal_setting": "goal_planning",
    "tax_query": "tax_saving",
    "insurance_query": "reduce_risk",
    "loan_query": "debt_management",
    "general_finance": "general_advice",
}


def normalize_intent(raw_intent: str) -> str:
    """Map legacy and parser intents into the canonical vocabulary."""
    if not raw_intent:
        return "general_advice"
    raw_intent = raw_intent.strip().lower()
    mapped = LEGACY_INTENT_MAP.get(raw_intent, raw_intent)
    return mapped if mapped in CANONICAL_INTENTS else "general_advice"


def rank_intents(intents: list[str], amounts: list[float] | None = None) -> list[str]:
    """Rank intents and force allocation-related intents when money is explicitly mentioned."""
    amounts = amounts or []
    normalized = []
    seen = set()
    for intent in intents:
        mapped = normalize_intent(intent)
        if mapped not in seen:
            normalized.append(mapped)
            seen.add(mapped)

    if amounts and not any(intent in seen for intent in {"invest_savings", "invest_lumpsum", "allocate_money", "how_much_to_invest"}):
        normalized.insert(0, "invest_savings")
        seen.add("invest_savings")

    if "buy_house" in seen and "goal_planning" not in seen:
        normalized.insert(0, "goal_planning")
        seen.add("goal_planning")

    def _effective_priority(intent: str) -> int:
        base = INTENT_PRIORITY.get(intent, 10)
        if not amounts and "best_stocks" in seen and intent in {"invest_lumpsum", "invest_savings", "how_much_to_invest", "allocate_money"}:
            return 5
        return base

    return sorted(
        normalized,
        key=lambda intent: (-_effective_priority(intent), intent),
    ) or ["general_advice"]


def augment_intent_with_profile(intent: dict, profile: dict) -> dict:
    """Inject profile-driven intents after parsing."""
    enriched = dict(intent or {})
    goals = [str(goal).strip().lower() for goal in profile.get("goals", []) if str(goal).strip()]
    intents = list(enriched.get("intents", [])) or [enriched.get("intent", "general_advice")]

    if len(goals) >= 2:
        if "multi_goal_planning" not in intents:
            intents.append("multi_goal_planning")
        if "goal_planning" not in intents:
            intents.append("goal_planning")

    if any("house" in goal or "home" in goal for goal in goals) and "buy_house" not in intents:
        intents.append("buy_house")

    ranked = sorted(
        {normalize_intent(item) for item in intents},
        key=lambda item: (-INTENT_PRIORITY.get(item, 10), item),
    ) or ["general_advice"]

    enriched["intents"] = ranked
    enriched["intent"] = ranked[0]
    return enriched
