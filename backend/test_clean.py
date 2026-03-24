import asyncio
from engine.response_generator import _clean

raw = """Money Mentor: Alright user, here is your investment plan based on your profile and financial data:
--- FINANCIAL DATA ---
RISK: medium | ALLOCATION: 75% equity, 25% debt
RECOMMENDED SIP: 5,000/month
INSTRUMENTS: Nifty 50 index funds, Balanced/Hybrid funds, ELSS
--- END DATA ---
1. Start a monthly SIP of Rs. 5000 in Nifty 50 index funds for long term growth.
2. Invest remaining amount in Balanced/Hybrid funds and ELSS for better returns with tax benefits.
"""

cleaned = _clean(raw)
print(f"RAW LEN: {len(raw)}")
print(f"CLEANED LEN: {len(cleaned)}")
print(f"CLEANED:\n{cleaned}")
