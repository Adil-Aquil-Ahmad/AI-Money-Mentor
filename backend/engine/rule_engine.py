"""
Chrysos — Deterministic financial strategy engine.
Returns structured data and a strategy object. It does not return user-facing text.
"""

DEFAULT_STOCK_EXAMPLES = [
    "Nifty 50 index fund",
    "Nifty Next 50 index fund",
    "Reliance Industries",
    "Infosys",
    "TCS",
    "HDFC Bank",
]

DEFAULT_STOCK_SECTORS = ["banking", "IT", "energy"]
GOAL_PRIORITY = {
    "buy a house": 100,
    "house": 100,
    "retirement": 90,
    "education": 85,
    "buy a car": 60,
    "car": 60,
}


def apply_rules(intent: dict, profile: dict) -> dict:
    """Build deterministic financial facts and a strategy object."""
    intent_type = intent.get("intent", "general_advice")
    intent_list = intent.get("intents", [intent_type])
    amounts = intent.get("amounts", [])

    age = profile.get("age") or 25
    income = float(profile.get("monthly_income") or 0)
    expenses = float(profile.get("monthly_expenses") or 0)
    savings = float(profile.get("current_savings") or 0)
    investments = float(profile.get("current_investments") or 0)
    debt = float(profile.get("current_debt") or 0)
    has_efund = bool(profile.get("has_emergency_fund", False))
    efund_months = float(profile.get("emergency_fund_months") or 0)
    risk = profile.get("risk_profile", "medium")
    has_insurance = bool(profile.get("has_insurance", False))
    goals = profile.get("goals") or []
    goal_horizon = profile.get("goal_horizon", "unknown")
    has_high_interest_debt = bool(profile.get("has_high_interest_debt", False))

    monthly_savings = max(0, int(income - expenses)) if income and expenses else 0
    emergency_target = int(expenses * 6) if expenses else (int(income * 3) if income else 0)
    emergency_gap = max(0, emergency_target - int(savings))
    savings_months = round(savings / expenses, 1) if expenses else 0
    debt_to_income = round(debt / (income * 12), 2) if income else 0
    savings_rate = round((monthly_savings / income) * 100, 1) if income else 0
    liquid_strength = _liquid_strength(savings_months, income, monthly_savings)
    primary_goal = _primary_goal(goals, intent_type, intent.get("original_message", ""))
    prioritized_goals = _prioritize_goals(goals)
    near_term_goal = primary_goal and goal_horizon == "short_term"

    data = {
        "intent": intent_type,
        "intents": intent_list,
        "raw_intent": intent.get("raw_intent"),
        "profile_summary": {
            "age": age,
            "income": int(income),
            "expenses": int(expenses),
            "monthly_savings": monthly_savings,
            "savings_rate": savings_rate,
            "total_savings": int(savings),
            "savings_months": savings_months,
            "investments": int(investments),
            "debt": int(debt),
            "debt_to_income": debt_to_income,
            "has_emergency_fund": has_efund,
            "emergency_fund_months": int(efund_months),
            "has_insurance": has_insurance,
            "risk_profile": risk,
            "goals": goals,
            "goal_horizon": goal_horizon,
            "goal_name": primary_goal,
            "goal_names": prioritized_goals,
            "has_multiple_goals": len(prioritized_goals) >= 2,
            "has_high_interest_debt": has_high_interest_debt,
            "liquid_strength": liquid_strength,
        },
        "financial_snapshot": {
            "emergency_fund_target": emergency_target,
            "emergency_fund_gap": emergency_gap,
            "investable_surplus": max(0, int(savings - emergency_target)),
            "income_strength": "strong" if income >= 100000 else "moderate" if income >= 50000 else "limited",
            "debt_pressure": "high" if debt_to_income >= 0.4 else "moderate" if debt_to_income >= 0.2 else "low",
        },
        "flags": [],
    }

    if emergency_gap > 0 or not has_efund or efund_months < 3:
        data["flags"].append({"type": "no_emergency_fund", "target": emergency_target, "gap": emergency_gap})
    if not has_insurance and income > 0:
        data["flags"].append({"type": "no_insurance", "cover": int(income * 12 * 10)})
    if debt > 0 and (debt_to_income >= 0.4 or has_high_interest_debt):
        data["flags"].append({"type": "priority_debt", "amount": int(debt)})
    if primary_goal:
        data["flags"].append({"type": "goal_active", "goal": primary_goal, "horizon": goal_horizon})
    if len(prioritized_goals) >= 2:
        data["flags"].append({"type": "multi_goal_active", "goals": prioritized_goals})
    if len(intent_list) > 1:
        data["flags"].append({"type": "multi_intent", "intents": intent_list})

    if ("bonus_money" in intent_list or intent_type == "bonus_money") and amounts:
        data["bonus_amount"] = int(amounts[0])
    if any(item in intent_list for item in {"invest_lumpsum", "buy_house", "invest_savings", "how_much_to_invest", "allocate_money"}) and amounts:
        data["goal_amount_hint"] = int(amounts[0])
    data["allocation_target_amount"] = _resolve_allocation_target(amounts, savings)
    if not data["allocation_target_amount"] and len(prioritized_goals) >= 2 and savings > 0:
        data["allocation_target_amount"] = int(savings)
    data["allocation_target_is_total_savings"] = bool(
        data["allocation_target_amount"] and abs(data["allocation_target_amount"] - int(savings)) <= max(10000, int(savings * 0.05))
    )
    if "tax_saving" in intent_list:
        data["tax_tips"] = {
            "80C_limit": 150000,
            "80D_health": 25000,
            "nps_80ccd": 50000,
            "annual_income": int(income * 12) if income else 0,
        }

    data["strategy"] = build_financial_strategy(profile, intent, data)
    return data


def build_financial_strategy(profile: dict, intent: dict, computed_values: dict) -> dict:
    """Create the single source of truth used by the LLM."""
    ps = computed_values["profile_summary"]
    snapshot = computed_values["financial_snapshot"]
    intent_type = intent.get("intent", "general_advice")
    intent_list = intent.get("intents", [intent_type])
    primary_goal = ps.get("goal_name")
    goals = ps.get("goal_names", ps.get("goals", []))
    multi_goal_mode = "multi_goal_planning" in intent_list or len(goals) >= 2
    near_term_goal = primary_goal and ps.get("goal_horizon") == "short_term"
    timeline_unknown = primary_goal and ps.get("goal_horizon") == "unknown"

    primary_priority = "stabilize monthly cash flow"
    secondary_priority = "start disciplined long-term investing"
    capital_allocation = []
    monthly_plan = []
    constraints = []
    warnings = []
    reasoning_facts = []
    stock_guidance = []
    sip_guidance = []

    savings = ps["total_savings"]
    income = ps["income"]
    expenses = ps["expenses"]
    monthly_savings = ps["monthly_savings"]
    investments = ps["investments"]
    debt = ps["debt"]
    emergency_target = snapshot["emergency_fund_target"]
    emergency_gap = snapshot["emergency_fund_gap"]
    investable_surplus = snapshot["investable_surplus"]
    allocation_target_amount = computed_values.get("allocation_target_amount", 0)
    allocation_target_is_total_savings = computed_values.get("allocation_target_is_total_savings", False)

    reasoning_facts.extend([
        f"Monthly income is Rs{income:,} and expenses are Rs{expenses:,}.",
        f"Current savings are Rs{savings:,} with monthly surplus Rs{monthly_savings:,}.",
        f"Emergency fund target is Rs{emergency_target:,} and current gap is Rs{emergency_gap:,}.",
    ])
    if allocation_target_amount:
        reasoning_facts.append(f"The user asked how to allocate Rs{allocation_target_amount:,}.")

    if debt > 0:
        reasoning_facts.append(f"Current debt is Rs{debt:,}.")
    if primary_goal:
        reasoning_facts.append(f"Primary goal is {primary_goal} with {ps.get('goal_horizon', 'unknown')} horizon.")
    if multi_goal_mode and goals:
        reasoning_facts.append(f"Current goals are {', '.join(goals)}.")
    if len(intent_list) > 1:
        reasoning_facts.append(f"User asked a compound query covering: {', '.join(intent_list)}.")

    if emergency_gap > 0 and not near_term_goal:
        primary_priority = "complete the emergency fund before taking additional investment risk"
        secondary_priority = "invest only after cash reserve is protected"
        capital_allocation.append(
            f"Keep Rs{min(savings, emergency_target):,} in liquid savings or sweep FD until the emergency fund reaches Rs{emergency_target:,}."
        )
        if investable_surplus > 0:
            capital_allocation.append(
                f"Only the surplus above the reserve, about Rs{investable_surplus:,}, is available for gradual investing."
            )
        contribution = _safe_emergency_contribution(monthly_savings, emergency_gap)
        monthly_plan.append(f"Direct Rs{contribution:,}/month to emergency reserves until the gap closes.")
        if monthly_savings > contribution:
            monthly_plan.append(
                f"Invest the remaining Rs{monthly_savings - contribution:,}/month conservatively, not aggressively."
            )
        constraints.append("Do not lock emergency money into volatile assets.")
        warnings.append("Equity-heavy advice is inappropriate until liquidity is secure.")

    elif debt > 0 and (ps.get("has_high_interest_debt") or ps.get("debt_to_income", 0) >= 0.4):
        primary_priority = "reduce expensive debt before increasing investment risk"
        secondary_priority = "maintain only a basic liquidity buffer while attacking debt"
        reserve = min(savings, emergency_target or savings)
        capital_allocation.append(f"Keep roughly Rs{reserve:,} liquid for emergencies.")
        if savings > reserve:
            capital_allocation.append(f"Use up to Rs{int(savings - reserve):,} from savings toward debt reduction.")
        paydown = _debt_paydown_amount(monthly_savings)
        monthly_plan.append(f"Prepay at least Rs{paydown:,}/month toward debt.")
        if monthly_savings > paydown:
            monthly_plan.append(
                f"Keep the remaining Rs{monthly_savings - paydown:,}/month as liquidity or low-risk savings until debt pressure improves."
            )
        constraints.append("Do not recommend aggressive investing while costly debt remains.")
        warnings.append("Ignoring high-interest debt would be financially incorrect.")

    elif intent_type in {"good_portfolio", "rebalance_portfolio", "diversify_portfolio"} and investments > 0:
        primary_priority = "review current holdings in the context of goals, concentration, and risk"
        secondary_priority = "rebalance gradually using new money instead of reacting to short-term moves"
        capital_allocation.append(
            f"Keep core liquidity and goal buckets protected before changing the Rs{investments:,} investment portfolio."
        )
        if monthly_savings > 0:
            monthly_plan.append(
                f"Use new monthly surplus of Rs{monthly_savings:,} to rebalance gradually into core index or hybrid funds."
            )
        monthly_plan.append("Review laggards and winners for concentration risk, not for impulsive buy or sell decisions.")
        constraints.append("Do not give extreme buy or sell instructions from a portfolio review.")
        warnings.append("Short-term price moves and headlines should not override diversification and goal alignment.")

    elif multi_goal_mode and goals:
        primary_priority = "separate the house goal from the car goal and prioritize capital by goal size and timeline"
        secondary_priority = "fund the house first, keep the car bucket flexible, and invest only the remainder gradually"
        reserve = emergency_target if emergency_target > 0 else int(expenses * 3)
        safe_pool = min(savings, reserve)
        goal_pool = max(0, int(savings - safe_pool))

        house_floor, house_ceiling, car_floor, car_ceiling, invest_floor, invest_ceiling = _multi_goal_buckets(
            goal_pool, ps.get("goal_horizon", "unknown")
        )
        capital_allocation.append(
            f"Treat Rs{safe_pool:,} from the current savings corpus as the emergency reserve; this is part of the existing savings, not extra money."
        )
        capital_allocation.append(
            f"Keep roughly Rs{_format_range(house_floor, house_ceiling)} in safe assets for the house fund because it is the larger goal."
        )
        capital_allocation.append(
            f"Set aside roughly Rs{_format_range(car_floor, car_ceiling)} in a separate car fund; keep it in safe assets if the purchase could happen within 1-2 years."
        )
        capital_allocation.append(
            f"Invest only the remaining Rs{_format_range(invest_floor, invest_ceiling)} gradually through diversified funds."
        )
        if allocation_target_is_total_savings:
            capital_allocation.append(
                f"These buckets together cover the full Rs{allocation_target_amount:,} savings corpus."
            )

        house_monthly_floor, house_monthly_ceiling, car_monthly_floor, car_monthly_ceiling, sip_floor, sip_ceiling = _multi_goal_monthly_split(monthly_savings)
        if monthly_savings > 0:
            monthly_plan.append(
                f"Direct about Rs{_format_range(house_monthly_floor, house_monthly_ceiling)} per month to the house fund."
            )
            monthly_plan.append(
                f"Direct about Rs{_format_range(car_monthly_floor, car_monthly_ceiling)} per month to a separate car fund."
            )
            monthly_plan.append(
                f"Run SIPs of about Rs{_format_range(sip_floor, sip_ceiling)} per month into index or hybrid funds."
            )
            sip_guidance.append(
                f"SIP range: Rs{_format_range(sip_floor, sip_ceiling)} per month in Nifty 50 index funds and hybrid funds."
            )

        constraints.append("Do not merge house money, car money, and long-term investing into one generic bucket.")
        warnings.append("The house goal should stay ahead of the car goal unless the car has an urgent short-term deadline.")
        if timeline_unknown:
            warnings.append("The car and house timelines are not fully clear, so keep both goal buckets conservative.")

    elif primary_goal and ("house" in primary_goal or intent_type == "buy_house"):
        primary_priority = "protect house capital and separate it from long-term investing"
        secondary_priority = "use existing savings first, then build the down-payment stream"
        reserve = emergency_target if emergency_target > 0 else int(expenses * 3)
        safe_pool = min(savings, reserve)
        goal_pool = max(0, int(savings - safe_pool))
        investable_floor, investable_ceiling = _house_investable_range(goal_pool, near_term_goal, timeline_unknown)
        house_floor = max(0, goal_pool - investable_ceiling)
        house_ceiling = max(0, goal_pool - investable_floor)
        capital_allocation.append(
            f"Treat Rs{safe_pool:,} from the current savings corpus as the emergency reserve; this is part of the existing savings, not extra money."
        )
        if goal_pool > 0:
            capital_allocation.append(
                f"From the remaining Rs{goal_pool:,}, keep roughly Rs{_format_range(house_floor, house_ceiling)} in safe assets for the house fund."
            )
        if investable_ceiling > 0:
            capital_allocation.append(
                f"Limit long-term investing to roughly Rs{_format_range(investable_floor, investable_ceiling)} from savings until the house timeline and budget are clear."
            )
        if allocation_target_is_total_savings:
            capital_allocation.append(
                f"These three buckets together cover the full Rs{allocation_target_amount:,} savings corpus."
            )

        house_monthly_floor, house_monthly_ceiling = _house_monthly_range(monthly_savings, near_term_goal, timeline_unknown)
        invest_monthly_floor = max(0, monthly_savings - house_monthly_ceiling)
        invest_monthly_ceiling = max(0, monthly_savings - house_monthly_floor)
        if monthly_savings > 0:
            monthly_plan.append(
                f"From monthly surplus, direct about Rs{_format_range(house_monthly_floor, house_monthly_ceiling)} to the house fund."
            )
            if invest_monthly_ceiling > 0:
                monthly_plan.append(
                    f"Run SIPs of about Rs{_format_range(invest_monthly_floor, invest_monthly_ceiling)} per month into index or hybrid funds for long-term goals."
                )
                sip_guidance.append(
                    f"SIP range: Rs{_format_range(invest_monthly_floor, invest_monthly_ceiling)} per month in Nifty 50 index funds and hybrid funds."
                )
        if timeline_unknown:
            monthly_plan.append("Clarify the target purchase timeline and house budget before increasing equity exposure.")
        constraints.append("Do not use short-horizon house money for aggressive equity exposure.")
        warnings.append("Generic SIP-first advice is wrong when large savings already exist for a house goal.")
        if timeline_unknown:
            warnings.append("House timeline is not clear, so the default stance should stay conservative.")

    elif savings >= max(expenses * 12, income * 6):
        primary_priority = "deploy excess savings with a clear capital plan instead of treating everything as idle cash"
        secondary_priority = "convert surplus cash into staged long-term investing"
        reserve = emergency_target if emergency_target > 0 else int(expenses * 6)
        staged_investment = max(0, int((savings - reserve) * 0.6))
        short_term_safe = max(0, int(savings - reserve - staged_investment))
        capital_allocation.append(f"Retain Rs{reserve:,} as emergency liquidity.")
        if staged_investment > 0:
            capital_allocation.append(
                f"Deploy about Rs{staged_investment:,} from excess cash in phased investments over the next 6-12 months."
            )
        if short_term_safe > 0:
            capital_allocation.append(
                f"Keep Rs{short_term_safe:,} in low-risk instruments for flexibility and near-term needs."
            )
        if allocation_target_is_total_savings:
            capital_allocation.append(
                f"Together, the reserve, phased investment bucket, and low-risk bucket cover the full Rs{allocation_target_amount:,} savings corpus."
            )
        monthly_plan.append(
            f"Continue SIPs of at least Rs{max(5000, int(monthly_savings * 0.6)):,}/month from fresh surplus."
        )
        sip_guidance.append(
            f"SIP amount: about Rs{max(5000, int(monthly_savings * 0.6)):,}/month in diversified index and hybrid funds."
        )
        constraints.append("Do not respond with a generic age-based allocation split.")

    elif monthly_savings > 0:
        primary_priority = "build a repeatable monthly investing habit from actual surplus"
        secondary_priority = "increase resilience before taking more risk"
        starter_sip = min(monthly_savings, max(1000, int(monthly_savings * 0.5)))
        capital_allocation.append("Keep existing savings liquid until core buffers are clear.")
        monthly_plan.append(f"Start SIPs of Rs{starter_sip:,}/month into diversified index or hybrid funds.")
        monthly_plan.append(f"Keep Rs{monthly_savings - starter_sip:,}/month for reserves and upcoming expenses.")
        sip_guidance.append(
            f"SIP amount: about Rs{starter_sip:,}/month in Nifty 50 index funds or balanced hybrid funds."
        )
        constraints.append("Do not overstate risk capacity when surplus is limited.")

    else:
        primary_priority = "stop cash burn and create positive monthly surplus"
        secondary_priority = "pause non-essential investing until surplus appears"
        capital_allocation.append("Preserve available cash for mandatory expenses.")
        monthly_plan.append("Cut discretionary expenses and free up a monthly surplus before investing.")
        constraints.append("Do not recommend SIPs if monthly cash flow is negative.")
        warnings.append("The user needs cash-flow repair before wealth-building advice.")

    if not profile.get("has_insurance") and income > 0:
        secondary_priority = "close the protection gap alongside the main financial plan"
        reasoning_facts.append("The user does not currently have insurance protection in profile data.")
        warnings.append("Protection gaps can derail the rest of the plan.")

    if intent_type == "tax_saving":
        monthly_plan.append("Use tax-saving products only after matching them to liquidity and goal needs.")
        reasoning_facts.append("Tax saving should support, not distort, the core plan.")
    if "best_stocks" in intent_list or "good_portfolio" in intent_list or "invest_now" in intent_list:
        constraints.append("Avoid concentrated stock calls without a diversified plan.")
        warnings.append("Single-stock answers should not override the broader financial strategy.")
        stock_guidance.append("Use diversified funds as the core strategy before any direct stock exposure.")
        stock_guidance.append(
            f"Examples: {', '.join(DEFAULT_STOCK_EXAMPLES[:2])} as core instruments, then direct stocks like {', '.join(DEFAULT_STOCK_EXAMPLES[2:6])} only as a small satellite bucket."
        )
        stock_guidance.append(
            f"If picking sectors, stay with stable large-cap exposure in {', '.join(DEFAULT_STOCK_SECTORS)}."
        )
        stock_guidance.append("Keep direct stocks to roughly 20-30% of the equity allocation, not the full portfolio.")
    elif "invest_savings" in intent_list or "invest_lumpsum" in intent_list or "buy_house" in intent_list:
        stock_guidance.append("For the investment bucket, use Nifty 50 or Nifty Next 50 index funds as the core.")
        stock_guidance.append("If adding direct stocks, keep them small and limited to large-cap names like Reliance Industries, TCS, Infosys, and HDFC Bank.")
        stock_guidance.append("Treat direct stocks as a small allocation, around 20-30% of the equity bucket, not the whole corpus.")
    elif intent_type == "rebalance_portfolio" and investments > 0:
        reasoning_facts.append(f"Existing investments of Rs{investments:,} should be reviewed before adding new risk.")
    elif intent_type == "bonus_money" and computed_values.get("bonus_amount"):
        reasoning_facts.append(f"User mentioned bonus amount of Rs{computed_values['bonus_amount']:,}.")
    if primary_goal and savings >= emergency_target and ps.get("goal_horizon") == "unknown":
        reasoning_facts.append("Without a stated timeline, the house corpus should be kept mostly safe until the purchase window is clearer.")

    return {
        "primary_priority": primary_priority,
        "secondary_priority": secondary_priority,
        "capital_allocation": capital_allocation,
        "monthly_plan": monthly_plan,
        "constraints": constraints,
        "warnings": warnings,
        "reasoning_facts": reasoning_facts,
        "stock_guidance": stock_guidance,
        "sip_guidance": sip_guidance,
    }


def _liquid_strength(savings_months: float, income: float, monthly_savings: int) -> str:
    if savings_months >= 12 or (income and monthly_savings >= income * 0.3):
        return "high"
    if savings_months >= 6 or monthly_savings > 0:
        return "moderate"
    return "low"


def _primary_goal(goals: list, intent_type: str, message: str) -> str:
    prioritized = _prioritize_goals(goals)
    if prioritized:
        return prioritized[0]
    text = (message or "").lower()
    if intent_type == "buy_house" or "house" in text or "home" in text:
        return "buy a house"
    if "retire" in text:
        return "retirement"
    if "education" in text:
        return "education"
    return ""


def _safe_emergency_contribution(monthly_savings: int, emergency_gap: int) -> int:
    if monthly_savings <= 0:
        return 0
    return min(monthly_savings, max(2000, int(monthly_savings * 0.7)), emergency_gap or monthly_savings)


def _debt_paydown_amount(monthly_savings: int) -> int:
    if monthly_savings <= 0:
        return 0
    return min(monthly_savings, max(3000, int(monthly_savings * 0.7)))


def _house_goal_contribution(monthly_savings: int, near_term_goal: bool) -> int:
    if monthly_savings <= 0:
        return 0
    ratio = 0.8 if near_term_goal else 0.65
    return min(monthly_savings, max(5000, int(monthly_savings * ratio)))


def _house_investable_range(goal_pool: int, near_term_goal: bool, timeline_unknown: bool) -> tuple[int, int]:
    if goal_pool <= 0:
        return 0, 0
    if near_term_goal:
        floor_ratio, ceil_ratio = 0.1, 0.2
    elif timeline_unknown:
        floor_ratio, ceil_ratio = 0.18, 0.24
    else:
        floor_ratio, ceil_ratio = 0.2, 0.35
    floor = _round_down_bucket(goal_pool * floor_ratio)
    ceiling = max(floor, _round_down_bucket(goal_pool * ceil_ratio))
    return floor, min(goal_pool, ceiling)


def _house_monthly_range(monthly_savings: int, near_term_goal: bool, timeline_unknown: bool) -> tuple[int, int]:
    if monthly_savings <= 0:
        return 0, 0
    if near_term_goal:
        floor_ratio, ceil_ratio = 0.55, 0.7
    elif timeline_unknown:
        floor_ratio, ceil_ratio = 0.5, 0.67
    else:
        floor_ratio, ceil_ratio = 0.4, 0.55
    floor = _round_down_bucket(monthly_savings * floor_ratio, 50000)
    ceiling = max(floor, _round_down_bucket(monthly_savings * ceil_ratio, 50000))
    return min(monthly_savings, floor), min(monthly_savings, ceiling)


def _round_down_bucket(value: float, bucket: int = 100000) -> int:
    if value <= 0:
        return 0
    return int(value // bucket) * bucket


def _format_range(low: int, high: int) -> str:
    if low <= 0 and high <= 0:
        return "0"
    if low == high:
        return f"{low:,}"
    return f"{low:,}-{high:,}"


def _resolve_allocation_target(amounts: list[float], savings: float) -> int:
    if not amounts:
        return 0
    rounded_savings = int(savings)
    for amount in amounts:
        if rounded_savings and abs(amount - rounded_savings) <= max(10000, rounded_savings * 0.05):
            return rounded_savings
    return int(max(amounts))


def _prioritize_goals(goals: list[str]) -> list[str]:
    cleaned = []
    for goal in goals or []:
        text = str(goal).strip().lower()
        if not text:
            continue
        if "house" in text or "home" in text:
            canonical = "buy a house"
        elif "car" in text or "vehicle" in text or "auto" in text:
            canonical = "buy a car"
        else:
            canonical = text
        if canonical not in cleaned:
            cleaned.append(canonical)
    return sorted(cleaned, key=lambda item: (-GOAL_PRIORITY.get(item, 50), item))


def _multi_goal_buckets(goal_pool: int, goal_horizon: str) -> tuple[int, int, int, int, int, int]:
    if goal_pool <= 0:
        return 0, 0, 0, 0, 0, 0
    if goal_horizon == "short_term":
        house_floor_ratio, house_ceiling_ratio = 0.72, 0.8
        car_floor_ratio, car_ceiling_ratio = 0.12, 0.18
    else:
        house_floor_ratio, house_ceiling_ratio = 0.75, 0.81
        car_floor_ratio, car_ceiling_ratio = 0.10, 0.15

    house_floor = _round_down_bucket(goal_pool * house_floor_ratio)
    house_ceiling = max(house_floor, _round_down_bucket(goal_pool * house_ceiling_ratio))
    car_floor = _round_down_bucket(goal_pool * car_floor_ratio, 50000)
    car_ceiling = max(car_floor, _round_down_bucket(goal_pool * car_ceiling_ratio, 50000))
    invest_floor = max(0, _round_down_bucket(goal_pool - house_ceiling - car_ceiling, 50000))
    invest_ceiling = max(invest_floor, _round_down_bucket(goal_pool - house_floor - car_floor, 50000))
    return house_floor, house_ceiling, car_floor, car_ceiling, invest_floor, invest_ceiling


def _multi_goal_monthly_split(monthly_savings: int) -> tuple[int, int, int, int, int, int]:
    if monthly_savings <= 0:
        return 0, 0, 0, 0, 0, 0
    house_floor = _round_down_bucket(monthly_savings * 0.5, 50000)
    house_ceiling = max(house_floor, _round_down_bucket(monthly_savings * 0.67, 50000))
    car_floor = _round_down_bucket(monthly_savings * 0.17, 50000)
    car_ceiling = max(car_floor, _round_down_bucket(monthly_savings * 0.33, 50000))
    sip_floor = max(0, _round_down_bucket(monthly_savings - house_ceiling - car_ceiling, 50000))
    sip_ceiling = max(sip_floor, _round_down_bucket(monthly_savings - house_floor - car_floor, 50000))
    return house_floor, house_ceiling, car_floor, car_ceiling, sip_floor, sip_ceiling
