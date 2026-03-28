"""
Run the backend pipeline locally for a single message and print every stage.
Usage:
    python debug_pipeline.py "what should i do with my savings of 3200000"
    python debug_pipeline.py --user-id 3 "what should i do with my savings of 3200000"
"""
import asyncio
import json
import sys

from database import get_db
from engine.intent_parser import parse_intent
from engine.profile_normalizer import normalize_profile
from engine.rule_engine import apply_rules
from engine.context_builder import build_response_context
from engine.response_generator import generate_response
from engine import llm_client


def _parse_args() -> tuple[int | None, str]:
    args = sys.argv[1:]
    user_id = None
    if len(args) >= 2 and args[0] == "--user-id":
        user_id = int(args[1])
        args = args[2:]
    message = " ".join(args).strip() or "what should i do with my savings of 3200000"
    return user_id, message


async def _load_profile(user_id: int | None = None) -> dict:
    db = await get_db()
    try:
        if user_id is not None:
            cursor = await db.execute("SELECT * FROM users WHERE id = ?", (user_id,))
        else:
            cursor = await db.execute(
                "SELECT * FROM users ORDER BY "
                "(current_savings > 0 OR monthly_income > 0) DESC, id DESC LIMIT 1"
            )
        row = await cursor.fetchone()
        return dict(row) if row else {}
    finally:
        await db.close()


async def main():
    user_id, message = _parse_args()
    raw_profile = await _load_profile(user_id)
    profile = normalize_profile(raw_profile, message, [])
    intent = await parse_intent(message)
    rule_output = apply_rules(intent, profile)
    system_prompt, user_prompt = build_response_context(profile, rule_output, [], intent, [], [])
    response, used_llm = await generate_response(intent, rule_output, profile, [], [], [])

    print("\n=== MODEL ROUTING ===")
    print(json.dumps({
        "model_used": llm_client.get_model_used(),
        "used_llm": used_llm,
    }, indent=2))

    print("\n=== INTENT PARSER ===")
    print(json.dumps(intent, indent=2))

    print("\n=== RULE ENGINE ===")
    print(json.dumps({
        "profile_summary": rule_output.get("profile_summary"),
        "financial_snapshot": rule_output.get("financial_snapshot"),
        "strategy": rule_output.get("strategy"),
    }, indent=2))

    print("\n=== CONTEXT BUILDER / USER PROMPT ===")
    print(user_prompt)

    print("\n=== FINAL OUTPUT ===")
    print(response)


if __name__ == "__main__":
    asyncio.run(main())
