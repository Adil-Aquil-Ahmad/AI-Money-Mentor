"""
AI Money Mentor — Intent Parser
Hybrid intent detection: LLM-based classification (primary) with keyword-based fallback.
Extracts monetary amounts from messages for financial context.
"""
import re
import httpx
from typing import Optional
from engine.intent_registry import CANONICAL_INTENTS, normalize_intent, rank_intents

# All recognized parser categories are normalized into the canonical set.
INTENT_CATEGORIES = CANONICAL_INTENTS + [
    "salary_received",
    "new_job",
    "bonus_received",
    "savings_query",
    "expense_query",
    "investment_query",
    "stock_query",
    "goal_setting",
    "tax_query",
    "insurance_query",
    "loan_query",
    "general_finance",
]

# Keyword patterns for fallback detection
KEYWORD_PATTERNS = {
    "next_steps": [r"next\s+step", r"what\s+should\s+i\s+do\s+next", r"what\s+to\s+do"],
    "multi_goal_planning": [
        r"multiple\s+goals?",
        r"more\s+than\s+one\s+goal",
        r"along\s+with",
        r"house.*car",
        r"car.*house",
        r"add\s+a\s+car\s+goal",
        r"purchase\s+a\s+car.*house",
    ],
    "invest_savings": [r"invest.*sav", r"put\s+my\s+savings", r"what\s+should\s+i\s+do\s+with.*sav", r"savings\s+of\s+[\d,]+", r"what\s+to\s+do\s+with.*money"],
    "best_stocks": [r"best\s+stock", r"which\s+stocks?", r"stock\s+recommendation", r"what\s+stocks?\s+should\s+i\s+invest\s+in", r"stocks?\s+should\s+i\s+invest"],
    "how_much_to_invest": [r"how\s+much.*invest", r"invest\s+monthly"],
    "emergency_fund": [r"build.*emergency", r"start.*emergency\s+fund", r"rainy\s+day"],
    "am_i_saving_enough": [r"sav(e|ing).*(enough|good)", r"is.*my\s+saving"],
    "diversify_portfolio": [r"diversify", r"spread.*risk", r"asset\s+allocation"],
    "invest_lumpsum": [r"invest.*?lakh", r"invest.*?lakhs", r"invest.*?crore", r"got\s+.*money", r"lump\s*sum"],
    "sip_vs_stocks": [r"sip.*vs.*stock", r"sip.*better.*stock"],
    "best_mutual_funds": [r"best.*mutual\s+fund", r"which.*mutual\s+fund", r"top.*fund"],
    "invest_or_save": [r"should\s+i\s+invest\s+or\s+save", r"save\s+vs\s+invest"],
    "buy_house": [r"buy.*house", r"home.*loan", r"save\s+for.*house"],
    "goal_planning": [r"long-term\s+goal", r"plan.*future", r"retire", r"child.*education", r"goal", r"house", r"car"],
    "reduce_risk": [r"reduce\s+risk", r"safe\s+investment", r"low\s+risk"],
    "good_portfolio": [
        r"good\s+portfolio",
        r"is\s+my\s+portfolio",
        r"review.*portfolio",
        r"how\s+is\s+my\s+portfolio",
        r"how\s+is\s+it\s+going",
        r"current\s+investments?",
        r"portfolio\s+doing",
        r"my\s+holdings",
    ],
    "start_investing": [r"how\s+to\s+start\s+investing", r"start\s+invest", r"begin.*invest"],
    "invest_now": [r"invest\s+in\s+stocks\s+now", r"right\s+time.*invest", r"market.*high", r"going\s+up\s+today", r"today'?s?\s+stocks", r"top\s+gainers", r"most\s+active"],
    "manage_income": [r"manage.*income", r"manage.*salary", r"budget.*salary"],
    "allocate_money": [r"allocate.*money", r"split.*salary", r"divide.*income"],
    "grow_wealth": [r"grow.*wealth", r"rich", r"make\s+more\s+money"],
    "bonus_money": [r"bonus", r"extra\s+money", r"windfall"],
    "beginner_investing": [r"invest.*beginner", r"new.*to.*invest"],
    "rebalance_portfolio": [r"rebalance", r"adjust\s+portfolio"],
    "efund_amount": [r"how\s+much\s+emergency", r"emergency\s+fund.*enough"],
    "tax_saving": [r"tax", r"80c", r"deduction", r"itr"],
    "debt_management": [r"loan", r"emi", r"borrow", r"debt", r"repay"],
    "budgeting": [r"budget", r"expense", r"spend", r"cost"],
}


async def parse_intent_with_llm(message: str, llm_base_url: str) -> Optional[list[str]]:
    """Use LLM to classify user intent into one or more categories."""
    categories_str = ", ".join(INTENT_CATEGORIES)
    prompt = (
        f"Classify the following user message into one or more of these categories:\n"
        f"{categories_str}\n\n"
        f'User message: "{message}"\n\n'
        "Respond with ONLY category names separated by commas. "
        "Include every relevant category and do not add explanations."
    )

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.post(
                f"{llm_base_url}/api/generate",
                json={
                    "model": "qwen2.5:7b",
                    "prompt": prompt,
                    "stream": False,
                    "options": {"temperature": 0.1, "num_predict": 20},
                },
            )
            if response.status_code == 200:
                result = response.json().get("response", "").strip().lower()
                found = []
                for cat in INTENT_CATEGORIES:
                    if cat in result and cat not in found:
                        found.append(cat)
                return found or None
    except:
        pass

    return None


def parse_intent_with_keywords(message: str) -> list[str]:
    """Keyword-based fallback intent detection."""
    message_lower = message.lower()
    matches = []

    for intent, patterns in KEYWORD_PATTERNS.items():
        score = sum(1 for p in patterns if re.search(p, message_lower))
        if score > 0:
            matches.append((intent, score))

    if not matches:
        return ["general_advice"]

    matches.sort(key=lambda item: (-item[1], item[0]))
    return [intent for intent, _ in matches[:4]]


def extract_amounts(message: str) -> list:
    """Extract monetary amounts (₹) from a user message."""
    amounts = []
    patterns = [
        (r"₹?\s*([\d,]+(?:\.\d+)?)\s*(?:lakh|lac)", 100000),
        (r"₹?\s*([\d,]+(?:\.\d+)?)\s*(?:cr|crore)", 10000000),
        (r"₹?\s*([\d,]+(?:\.\d+)?)\s*[kK]\b", 1000),
        (r"₹\s*([\d,]+(?:\.\d+)?)", 1),
        (r"([\d,]+(?:\.\d+)?)\s*(?:rupees|rs\.?|inr)", 1),
    ]

    for pattern, multiplier in patterns:
        for m in re.finditer(pattern, message, re.IGNORECASE):
            num = float(m.group(1).replace(",", ""))
            amounts.append(num * multiplier)

    if not amounts:
        for n in re.findall(r"\b(\d{4,})\b", message):
            amounts.append(float(n))

    return amounts


async def parse_intent(message: str, llm_base_url: str = "http://localhost:11434") -> dict:
    """Parse user intent with deterministic keyword routing first, then LLM fallback."""
    amounts = extract_amounts(message)
    keyword_intents = parse_intent_with_keywords(message)

    if keyword_intents and keyword_intents != ["general_advice"]:
        raw_intents = keyword_intents
    else:
        raw_intents = await parse_intent_with_llm(message, llm_base_url)
        if not raw_intents:
            raw_intents = keyword_intents

    intents = rank_intents(raw_intents, amounts)

    return {
        "raw_intent": raw_intents[0] if raw_intents else "general_advice",
        "raw_intents": raw_intents,
        "intent": intents[0],
        "intents": intents,
        "amounts": amounts,
        "original_message": message,
    }
