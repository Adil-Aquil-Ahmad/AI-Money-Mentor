import asyncio
from services.intelligence_service import get_finance_intelligence

async def main():
    res = await get_finance_intelligence("AAPL", 10000, 9)
    print("AAPL intelligence:")
    for k, v in res.items():
        print(f"{k}: {v}")

asyncio.run(main())
