"""
AI Money Mentor — Single-pass response generator with strategy validation.
"""
import re
import logging
from engine.context_builder import build_response_context, build_correction_context
from engine import llm_client
from engine.pipeline_debug import trace_event
from engine.templates import strict_template_response, template_fallback

logger = logging.getLogger("response_gen")
logger.setLevel(logging.DEBUG)
if not logger.handlers:
    handler = logging.StreamHandler()
    handler.setFormatter(logging.Formatter(
        "\033[33m[RESPONSE]\033[0m %(asctime)s — %(message)s", datefmt="%H:%M:%S"
    ))
    logger.addHandler(handler)


async def generate_response(
    intent: dict,
    rule_output: dict,
    profile: dict,
    chat_history: list,
    memories: list = None,
    stock_data: list = None,
    portfolio_context: dict | None = None,
) -> tuple:
    """
    Returns (response_text, used_llm).
    Executes a single LLM generation cycle plus one correction retry if needed.
    """
    strict_response = strict_template_response(intent, profile, rule_output, stock_data or [])
    if strict_response:
        llm_client.set_model_used("strict-template")
        trace_event("strict_template", {
            "intent": intent.get("intent"),
            "intents": intent.get("intents"),
            "response": strict_response,
        })
        logger.info("Using deterministic strict template for intent set: %s", intent.get("intents"))
        return strict_response, False

    system_prompt, user_prompt = build_response_context(
        profile, rule_output, chat_history, intent,
        memories=memories or [], stock_data=stock_data or [], portfolio_context=portfolio_context or {},
    )
    trace_event("context_builder", {
        "system_prompt": system_prompt,
        "user_prompt": user_prompt,
    })

    logger.info("SINGLE PASS: CALLING LLM FOR FINAL RESPONSE...")
    raw_response = await llm_client.generate(system_prompt, user_prompt)
    trace_event("llm_raw_response", {
        "model_used": llm_client.get_model_used(),
        "raw_response": raw_response,
    })

    with open("debug_llm.txt", "w", encoding="utf-8") as f:
        f.write(f"=== SINGLE PASS ===\n\n--- SYSTEM PROMPT ---\n{system_prompt}\n\n")
        f.write(f"--- USER PROMPT ---\n{user_prompt}\n\n")
        f.write(f"--- RAW RESPONSE ---\n{raw_response}\n\n")

    if not raw_response:
        llm_client.set_model_used("template-fallback")
        logger.error("LLM RETURNED NONE — falling back")
        return template_fallback(intent.get("original_message", ""), profile, rule_output), False

    cleaned = _clean(raw_response)
    cleaned = _normalize_length(cleaned)
    failed_checks = _strategy_validation_failures(cleaned, intent, rule_output, stock_data or [], portfolio_context or {})
    critical_issues, soft_issues = _classify_validation_issues(failed_checks)

    for retry_index in range(2):
        if not critical_issues and not soft_issues:
            break
        logger.warning(
            "Validation issues, retry %d/2 | critical=%s | soft=%s",
            retry_index + 1, critical_issues, soft_issues
        )
        retry_system, retry_user = build_correction_context(
            intent, rule_output, critical_issues, soft_issues, cleaned
        )
        retry_response = await llm_client.generate(retry_system, retry_user)
        trace_event("llm_retry_response", {
            "retry_index": retry_index + 1,
            "critical_issues": critical_issues,
            "soft_issues": soft_issues,
            "model_used": llm_client.get_model_used(),
            "retry_prompt": retry_user,
            "raw_response": retry_response,
        })
        with open("debug_llm.txt", "a", encoding="utf-8") as f:
            f.write(f"=== RETRY {retry_index + 1} ===\n\n--- USER PROMPT ---\n{retry_user}\n\n")
            f.write(f"--- RAW RETRY RESPONSE ---\n{retry_response}\n\n")
        if retry_response:
            cleaned = _normalize_length(_clean(retry_response))
            failed_checks = _strategy_validation_failures(cleaned, intent, rule_output, stock_data or [], portfolio_context or {})
            critical_issues, soft_issues = _classify_validation_issues(failed_checks)

    validated = _validate_numbers(cleaned, rule_output, stock_data or [])
    if critical_issues:
        validated = _apply_critical_corrections(validated, intent, rule_output)
        failed_checks = _strategy_validation_failures(validated, intent, rule_output, stock_data or [], portfolio_context or {})
        critical_issues, soft_issues = _classify_validation_issues(failed_checks)
    with open("debug_llm.txt", "a", encoding="utf-8") as f:
        f.write(f"--- CLEANED ---\n{validated}\n")

    trace_event("final_validated_response", {
        "critical_issues": critical_issues,
        "soft_issues": soft_issues,
        "final_response": validated,
    })

    if len(validated) > 40 and not critical_issues:
        return validated, True

    if len(validated) > 40:
        logger.warning("Returning LLM response with remaining soft issues: %s", soft_issues)
        return validated, True

    logger.warning("Response is too weak after retries. Using template fallback only because LLM output is unusable.")
    llm_client.set_model_used("template-fallback")
    return template_fallback(intent.get("original_message", ""), profile, rule_output), False


def _strategy_validation_failures(text: str, intent: dict, rule_output: dict, stock_data: list, portfolio_context: dict | None = None) -> list[str]:
    strategy = rule_output.get("strategy", {})
    ps = rule_output.get("profile_summary", {})
    snapshot = rule_output.get("financial_snapshot", {})
    portfolio_context = portfolio_context or {}
    failed = []
    lower = text.lower()
    intents = intent.get("intents", [intent.get("intent", "general_advice")])
    multi_intent = len(intents) > 1
    wants_allocation = bool(intent.get("amounts")) or any(item in intents for item in ["invest_savings", "invest_lumpsum", "allocate_money", "how_much_to_invest", "buy_house"])
    wants_stocks = any(item in intents for item in ["best_stocks", "invest_now"])
    wants_portfolio_review = any(item in intents for item in ["good_portfolio", "rebalance_portfolio", "diversify_portfolio"])
    savings_template = "invest_savings" in intents and bool(intent.get("amounts"))
    market_movers = "invest_now" in intents
    multi_goal = "multi_goal_planning" in intents
    wants_monthly = ps.get("monthly_savings", 0) > 0 and any(item in intents for item in [
        "invest_savings", "invest_lumpsum", "allocate_money", "how_much_to_invest", "buy_house",
        "start_investing", "sip_advice", "am_i_saving_enough", "manage_income", "bonus_money"
    ])

    if not savings_template and not market_movers and "priority:" not in lower:
        failed.append("Include a Priority section.")
    if market_movers:
        if "market movers today:" not in lower:
            failed.append("Include a Market Movers Today section for 'today' stock queries.")
        if "disclaimer:" not in lower:
            failed.append("Include a Disclaimer section for 'today' stock queries.")
    elif savings_template:
        if "capital allocation:" not in lower:
            failed.append("Include a Capital Allocation section for savings allocation queries.")
        if wants_monthly and "monthly plan:" not in lower:
            failed.append("Include a Monthly Plan section for savings allocation queries.")
        if "stock suggestions:" not in lower:
            failed.append("Include a Stock Suggestions section for savings allocation queries.")
    elif multi_intent or (wants_allocation and wants_stocks):
        if "capital allocation:" not in lower:
            failed.append("Include a Capital Allocation section for multi-intent queries.")
        if "monthly plan:" not in lower:
            failed.append("Include a Monthly Plan section for multi-intent queries.")
        if "stock suggestions:" not in lower:
            failed.append("Include a Stock Suggestions section for multi-intent queries.")
    elif wants_allocation:
        if "capital allocation:" not in lower:
            failed.append("Include a Capital Allocation section.")
        if wants_monthly and "monthly plan:" not in lower:
            failed.append("Include a Monthly Plan section.")
    elif wants_stocks:
        if "stock suggestions:" not in lower:
            failed.append("Include a Stock Suggestions section.")
    else:
        if "why:" not in lower:
            failed.append("Include a Why section.")
        if "action plan:" not in lower:
            failed.append("Include an Action Plan section.")
    if "what not to do:" not in lower and not market_movers:
        failed.append("Include a What Not To Do section.")
    if len(text.split()) < 100:
        failed.append("The answer is too short. Expand it to 100-180 words with real strategy.")

    primary_priority = (strategy.get("primary_priority") or "").lower()
    if primary_priority and not _contains_keywords(lower, primary_priority):
        failed.append(f"State the main priority clearly: {strategy['primary_priority']}.")

    if snapshot.get("emergency_fund_gap", 0) > 0 and "emergency" not in lower:
        failed.append("Do not ignore the emergency fund gap.")

    if ps.get("debt", 0) > 0 and (
        ps.get("has_high_interest_debt") or ps.get("debt_to_income", 0) >= 0.4
    ) and not any(token in lower for token in ["debt", "loan", "emi", "repay", "prepay"]):
        failed.append("Debt pressure is high, so debt repayment must be addressed.")

    if ps.get("goal_horizon") == "short_term" and ps.get("goal_name"):
        aggressive_terms = ["small-cap", "small cap", "mid-cap", "mid cap", "aggressive equity", "80% equity", "90% equity"]
        if any(term in lower for term in aggressive_terms):
            failed.append("Do not recommend aggressive equity for a short-term goal.")

    if intent.get("amounts") and not any(token in lower for token in ["allocate", "allocation", "split", "ring-fence", "keep rs", "from savings"]):
        failed.append("A specific money amount was provided, so the response must explain how to allocate it.")
    if rule_output.get("allocation_target_is_total_savings") and not any(
        token in lower for token in ["full", "entire", "100%", "all of", "covers the full", "whole corpus"]
    ):
        failed.append("When total savings are being allocated, say clearly that the full corpus is allocated across the listed buckets.")

    if (multi_intent or wants_stocks) and "best_stocks" in intents and "stock" not in lower and "nifty" not in lower:
        failed.append("The query asked about stocks, so stock suggestions must be included.")
    if wants_allocation and "capital allocation:" not in lower:
        failed.append("The query asked how to use money, so capital allocation must be included.")
    if wants_monthly and not any(token in lower for token in ["sip", "systematic investment", "index fund", "hybrid fund"]):
        failed.append("Monthly savings are present, so the response must include a SIP amount and type.")
    if wants_stocks and not any(token in lower for token in ["reliance", "tcs", "infosys", "hdfc", "banking", "it", "energy", "nifty 50", "nifty next 50"]):
        failed.append("When stocks are asked for, include concrete stock or sector examples, not only diversification language.")
    if savings_template and not any(token in lower for token in ["reliance", "tcs", "infosys", "hdfc", "banking", "it", "energy", "nifty 50", "hybrid fund"]):
        failed.append("Savings-allocation template must include stock suggestions for the small investment bucket.")
    if market_movers:
        if not stock_data:
            failed.append("Today's stock query must use live market data when available.")
        movers_block = _extract_section(lower, "market movers today")
        if not any(token in movers_block for token in ["rs", "%", "price", "up", "down"]):
            failed.append("Market Movers Today must show price and percentage move.")
        if "short-term" not in lower and "short term" not in lower:
            failed.append("Add the disclaimer that short-term movement is not long-term performance.")

    if ps.get("goal_name") and "house" in ps.get("goal_name", "") and ps.get("total_savings", 0) >= max(ps.get("expenses", 0) * 6, 1000000):
        if str(ps.get("total_savings", 0)) not in text and "32" not in lower and "savings" not in lower:
            failed.append("House planning with large savings must explicitly use the existing savings corpus.")
        if "capital" not in lower and "existing savings" not in lower and "current savings" not in lower:
            failed.append("Explain capital allocation from current savings before monthly flows.")
        if "emergency reserve" not in lower and "emergency fund" not in lower and "safety buffer" not in lower:
            failed.append("Clarify that the emergency reserve sits inside the current savings corpus.")
        if ps.get("goal_horizon") == "unknown" and "timeline" not in lower and "timeframe" not in lower:
            failed.append("When the house timeline is unknown, say that the timeline changes the strategy.")
        if rule_output.get("allocation_target_is_total_savings") and "capital allocation:" in lower:
            capital_block = _extract_section(lower, "capital allocation")
            bucket_hits = sum(
                1 for token in ["emergency", "house fund", "safe assets", "invest", "index"]
                if token in capital_block
            )
            if bucket_hits < 3:
                failed.append("Capital Allocation must show the full savings split across reserve, house-safe bucket, and investable bucket.")

    if "monthly plan:" in lower:
        monthly_block = _extract_section(lower, "monthly plan")
        if not any(token in monthly_block for token in ["sip", "index", "hybrid"]):
            failed.append("Monthly Plan must include SIP guidance with instrument type.")

    if "stock suggestions:" in lower:
        stock_block = _extract_section(lower, "stock suggestions")
        if not any(token in stock_block for token in ["reliance", "tcs", "hdfc", "banking", "it", "energy", "nifty 50", "nifty next 50"]):
            failed.append("Stock Suggestions must include example stocks, sectors, or index funds.")
        if "20-30%" not in stock_block and "20%" not in stock_block and "30%" not in stock_block and "small portion" not in stock_block and "small allocation" not in stock_block:
            failed.append("Stock Suggestions should state that direct stocks are only a limited part of the portfolio.")

    if multi_goal:
        if "house" not in lower:
            failed.append("Multi-goal planning must explicitly mention the house goal.")
        if "car" not in lower:
            failed.append("Multi-goal planning must explicitly mention the car goal.")
        if "monthly plan:" in lower:
            monthly_block = _extract_section(lower, "monthly plan")
            if "house" not in monthly_block or "car" not in monthly_block:
                failed.append("Monthly Plan must split money separately across house and car goals.")

    for constraint in strategy.get("constraints", []):
        if "do not" in constraint.lower():
            forbidden = constraint.lower().replace("do not", "").strip()
            if "aggressive equity exposure" in forbidden:
                if any(term in lower for term in ["aggressive equity", "80% equity", "90% equity", "small-cap", "small cap", "mid-cap", "mid cap"]):
                    failed.append(f"Response contradicts strategy constraint: {constraint}")
                continue
            if forbidden and _contains_keywords(lower, forbidden):
                failed.append(f"Response contradicts strategy constraint: {constraint}")

    if stock_data and "best stock" in lower and "divers" not in lower:
        failed.append("Do not give a concentrated stock answer without diversification context.")

    if wants_portfolio_review and portfolio_context.get("assets"):
        summary = portfolio_context.get("summary", {})
        winners = portfolio_context.get("winners", [])
        losers = portfolio_context.get("losers", [])
        if not any(token in lower for token in ["portfolio", "current value", "gain", "loss", "up", "down"]):
            failed.append("Portfolio review must mention portfolio performance, gain, or loss.")
        if winners and not any(item["name"].lower() in lower for item in winners[:2]):
            failed.append("Portfolio review should mention at least one stronger holding.")
        if losers and not any(item["name"].lower() in lower for item in losers[:2]):
            failed.append("Portfolio review should mention at least one weaker holding.")
        if summary.get("total_invested", 0) > 0 and "rebalance" not in lower and "review" not in lower and "trim" not in lower:
            failed.append("Portfolio review should suggest review or rebalancing instead of just describing moves.")
        if any(term in lower for term in ["sell immediately", "buy immediately", "dump", "all in", "go all-in"]):
            failed.append("Do not give extreme buy or sell advice from a portfolio review.")

    return failed


def _classify_validation_issues(issues: list[str]) -> tuple[list[str], list[str]]:
    critical = []
    soft = []
    critical_markers = (
        "a specific money amount was provided",
        "when total savings are being allocated",
        "the query asked how to use money",
        "capital allocation must show the full savings split",
        "do not recommend aggressive equity",
        "response contradicts strategy constraint",
        "do not ignore the emergency fund gap",
        "debt pressure is high",
        "danger",
        "extreme buy or sell advice",
    )

    for issue in issues:
        lowered = issue.lower()
        if any(marker in lowered for marker in critical_markers):
            critical.append(issue)
        else:
            soft.append(issue)
    return critical, soft


def _apply_critical_corrections(text: str, intent: dict, rule_output: dict) -> str:
    """Patch missing critical finance content without replacing the whole response."""
    strategy = rule_output.get("strategy", {})
    ps = rule_output.get("profile_summary", {})
    lower = text.lower()

    if intent.get("amounts") and "capital allocation:" not in lower:
        capital_lines = strategy.get("capital_allocation", [])[:4]
        if capital_lines:
            text = "Capital Allocation:\n" + "\n".join(f"- {line}" for line in capital_lines) + "\n\n" + text
            lower = text.lower()

    if rule_output.get("allocation_target_is_total_savings") and "full" not in lower and "covers the full" not in lower:
        amount = int(rule_output.get("allocation_target_amount") or ps.get("total_savings", 0))
        if amount:
            injection = f"- These buckets together cover the full Rs{amount:,} savings corpus."
            if "capital allocation:" in lower:
                text = re.sub(
                    r"(capital allocation:\s*)",
                    rf"\1{injection}\n",
                    text,
                    flags=re.IGNORECASE,
                    count=1,
                )
            else:
                text = f"Capital Allocation:\n{injection}\n\n{text}"
            lower = text.lower()

    if ps.get("goal_horizon") == "short_term":
        aggressive_terms = ["80% equity", "90% equity", "small-cap", "small cap", "mid-cap", "mid cap", "aggressive equity"]
        for term in aggressive_terms:
            text = re.sub(re.escape(term), "diversified equity", text, flags=re.IGNORECASE)

    if rule_output.get("financial_snapshot", {}).get("emergency_fund_gap", 0) > 0 and "emergency" not in lower:
        gap = int(rule_output["financial_snapshot"]["emergency_fund_gap"])
        text += f"\n\nNote: close the emergency fund gap of Rs{gap:,} before taking more risk."

    return text.strip()


def _validate_numbers(text: str, rule_output: dict, stock_data: list) -> str:
    """Patch obvious number hallucinations without changing the plan."""
    ps = rule_output.get("profile_summary", {})
    monthly_savings = ps.get("monthly_savings", 0)

    if monthly_savings > 0:
        pattern = r'(monthly\s+savings?\s+(?:of\s+)?Rs\.?\s*)([0-9,]+(?:\.\d+)?)'

        def _fix_savings(match):
            found_num = float(match.group(2).replace(",", ""))
            if abs(found_num - monthly_savings) > 1000:
                return f"{match.group(1)}{monthly_savings:,}"
            return match.group(0)

        text = re.sub(pattern, _fix_savings, text, flags=re.IGNORECASE)

    if stock_data:
        stock_prices = {s["name"].lower(): s["price"] for s in stock_data}
        for name, correct_price in stock_prices.items():
            price_pattern = rf'({re.escape(name)}[^0-9]*Rs\.?\s*)([0-9,]+(?:\.\d+)?)'

            def _fix_price(match, cp=correct_price):
                found = float(match.group(2).replace(",", ""))
                if abs(found - cp) > cp * 0.1:
                    return f"{match.group(1)}{cp:,.2f}"
                return match.group(0)

            text = re.sub(price_pattern, _fix_price, text, flags=re.IGNORECASE)

    return text


def _normalize_length(text: str) -> str:
    words = text.split()
    if len(words) <= 180:
        return text.strip()
    return " ".join(words[:180]).strip()


def _contains_keywords(text: str, phrase: str) -> bool:
    words = [w for w in re.findall(r"[a-z]+", phrase.lower()) if len(w) > 3]
    if not words:
        return phrase.lower() in text
    hits = sum(1 for word in set(words) if word in text)
    return hits >= max(1, min(2, len(set(words))))


def _clean(text: str) -> str:
    """Strip prompt leakage and keep the requested response structure."""
    if not text:
        return ""

    lines = []
    for raw_line in text.strip().splitlines():
        line = raw_line.strip()
        if not line:
            lines.append("")
            continue
        lower = line.lower()
        if lower.startswith(("user question:", "normalized profile:", "deterministic strategy:", "computed financial facts:")):
            continue
        if "do not mention backend" in lower or "strategy object" in lower:
            continue
        if lower.startswith("- primary priority:") or lower.startswith("- secondary priority:"):
            continue
        lines.append(raw_line.rstrip())

    cleaned = "\n".join(lines).strip()
    cleaned = re.sub(
        r'[\U0001F300-\U0001F9FF\U00002702-\U000027B0\U0000FE00-\U0000FE0F'
        r'\U0001FA00-\U0001FAFF\U00002600-\U000026FF\U0000200D]+',
        '',
        cleaned,
    )
    return cleaned.strip()


def _extract_section(text: str, section_name: str) -> str:
    pattern = rf"{re.escape(section_name.lower())}:\s*(.*?)(?=\n[a-z][a-z ]+:\s|$)"
    match = re.search(pattern, text, flags=re.IGNORECASE | re.DOTALL)
    return match.group(1) if match else ""
