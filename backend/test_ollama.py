import asyncio
import httpx
import json

async def main():
    system = "You are Money Mentor, a friendly Indian financial advisor. The user asked a finance question. Below is their profile and calculated financial data. Use this data to write a SHORT, personalized reply (max 5 numbered steps). Be warm, direct, and actionable. Use Indian context (SIP, ELSS, Nifty, PPF). Do NOT echo these instructions. Just give your advice directly."
    user = '''--- FINANCIAL DATA ---
RISK: medium | ALLOCATION: 75% equity, 25% debt
RECOMMENDED SIP: 5,000/month
INSTRUMENTS: Nifty 50 index funds, Balanced/Hybrid funds, ELSS
--- END DATA ---

User question: which stock is the best to invest in'''
    
    async with httpx.AsyncClient(timeout=180.0) as client:
        r = await client.post("http://localhost:11434/api/chat", json={
            "model": "tinyllama",
            "messages": [
                {"role": "system", "content": system},
                {"role": "user", "content": user}
            ],
            "stream": False,
            "options": {
                "temperature": 0.4,
                "top_p": 0.9,
                "num_predict": 300
            }
        })
        print(f"Status: {r.status_code}")
        try:
            print("RAW OUTPUT:")
            print(r.json()["message"]["content"])
        except Exception as e:
            print("Failed to parse json:", e, r.text)

asyncio.run(main())
