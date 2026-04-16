import asyncio
from database import get_db

async def run():
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT id, type, name, symbol, amount_invested, quantity, avg_price, "
            "sip_amount, COALESCE(purchase_date, DATE(created_at)) as purchase_date "
            "FROM current_investments WHERE user_id = ? ORDER BY id",
            (1,),
        )
        rows = await cursor.fetchall()
        print("Found rows:", len(rows))
        for row in rows:
            print(dict(row))
    except Exception as e:
        print("ERROR:", repr(e))

asyncio.run(run())
