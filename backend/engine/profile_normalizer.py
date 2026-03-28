"""
Shared helpers for normalizing profile state used by chat, prompting, and rules.
"""
import json
import re


GOAL_ALIASES = {
    "buy a house": ["house", "home", "down payment", "property"],
    "buy a car": ["car", "vehicle", "auto"],
    "retirement": ["retire", "retirement"],
    "education": ["education", "college", "school", "university"],
}


def _to_number(value, default=0.0):
    try:
        if value in (None, "", []):
            return float(default)
        return float(value)
    except (TypeError, ValueError):
        return float(default)


def _to_bool(value) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return value != 0
    if isinstance(value, str):
        return value.strip().lower() in {"1", "true", "yes", "y"}
    return False


def _parse_goals(raw_goals) -> list[str]:
    if raw_goals in (None, "", []):
        return []
    if isinstance(raw_goals, list):
        return [str(goal).strip() for goal in raw_goals if str(goal).strip()]
    if isinstance(raw_goals, str):
        try:
            parsed = json.loads(raw_goals)
            if isinstance(parsed, list):
                return [str(goal).strip() for goal in parsed if str(goal).strip()]
        except Exception:
            pass
        cleaned = raw_goals.strip()
        return [cleaned] if cleaned else []
    return [str(raw_goals).strip()]


def _canonicalize_goal(goal: str) -> str:
    text = str(goal or "").strip().lower()
    if not text:
        return ""
    for canonical, aliases in GOAL_ALIASES.items():
        if canonical in text or any(alias in text for alias in aliases):
            return canonical
    return text


def _extract_goals(text: str) -> list[str]:
    if not text:
        return []
    found = []
    lowered = text.lower()
    for canonical, aliases in GOAL_ALIASES.items():
        if canonical in lowered or any(alias in lowered for alias in aliases):
            if canonical not in found:
                found.append(canonical)
    return found


def _merge_goals(profile_goals: list[str], message_text: str) -> list[str]:
    merged = []
    for goal in profile_goals:
        canonical = _canonicalize_goal(goal)
        if canonical and canonical not in merged:
            merged.append(canonical)
    for goal in _extract_goals(message_text):
        if goal not in merged:
            merged.append(goal)
    return merged


def _extract_goal_horizon(text: str) -> str:
    if not text:
        return "unknown"

    text = text.lower()
    year_match = re.search(r"(\d+)\s*(year|yr)s?\b", text)
    month_match = re.search(r"(\d+)\s*month", text)

    if month_match:
        months = int(month_match.group(1))
        if months <= 24:
            return "short_term"
        if months <= 60:
            return "medium_term"
        return "long_term"

    if year_match:
        years = int(year_match.group(1))
        if years <= 3:
            return "short_term"
        if years <= 7:
            return "medium_term"
        return "long_term"

    if any(token in text for token in ["soon", "next year", "down payment", "house purchase soon"]):
        return "short_term"
    if any(token in text for token in ["retire", "retirement", "long term", "wealth building"]):
        return "long_term"
    return "unknown"


def _extract_debt_hint(text: str) -> dict:
    if not text:
        return {
            "debt_interest_rate": None,
            "debt_interest_level": "unknown",
            "has_high_interest_debt": False,
        }

    text = text.lower()
    rate_match = re.search(r"(\d+(?:\.\d+)?)\s*%", text)
    if rate_match:
        rate = float(rate_match.group(1))
        return {
            "debt_interest_rate": rate,
            "debt_interest_level": "high" if rate >= 12 else "moderate",
            "has_high_interest_debt": rate >= 12,
        }

    if any(token in text for token in ["credit card", "personal loan", "high interest"]):
        return {
            "debt_interest_rate": None,
            "debt_interest_level": "high",
            "has_high_interest_debt": True,
        }

    return {
        "debt_interest_rate": None,
        "debt_interest_level": "unknown",
        "has_high_interest_debt": False,
    }


def normalize_profile(profile: dict, message: str = "", memories: list | None = None) -> dict:
    """Normalize user profile fields and infer lightweight planning hints."""
    profile = dict(profile or {})
    memories = memories or []

    memory_text = " ".join(str(m.get("content", "")) for m in memories)
    combined_text = f"{message or ''} {memory_text}".strip()

    goals = _merge_goals(_parse_goals(profile.get("goals")), combined_text)
    planning_goal = goals[0].lower() if goals else ""
    if not planning_goal and "house" in combined_text.lower():
        goals = ["buy a house"]

    debt_hint = _extract_debt_hint(combined_text)
    goal_horizon = _extract_goal_horizon(combined_text)

    normalized = {
        "id": profile.get("id"),
        "firebase_uid": profile.get("firebase_uid"),
        "email": profile.get("email"),
        "name": profile.get("name") or "User",
        "age": int(_to_number(profile.get("age"), 25)),
        "monthly_income": _to_number(profile.get("monthly_income")),
        "monthly_expenses": _to_number(profile.get("monthly_expenses")),
        "current_savings": _to_number(profile.get("current_savings")),
        "current_investments": _to_number(profile.get("current_investments")),
        "current_debt": _to_number(profile.get("current_debt")),
        "has_insurance": _to_bool(profile.get("has_insurance")),
        "has_emergency_fund": _to_bool(profile.get("has_emergency_fund")),
        "emergency_fund_months": _to_number(profile.get("emergency_fund_months")),
        "risk_profile": (profile.get("risk_profile") or "medium").strip().lower(),
        "goals": goals,
        "has_multiple_goals": len(goals) >= 2,
        "goal_horizon": goal_horizon,
        "debt_interest_rate": debt_hint["debt_interest_rate"],
        "debt_interest_level": debt_hint["debt_interest_level"],
        "has_high_interest_debt": debt_hint["has_high_interest_debt"],
    }
    return normalized
