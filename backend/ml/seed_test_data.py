import asyncio
import sqlite3
import os
import sys

# Add backend directory to module search path so we can import services
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from services.stock_service import get_stock_data

DB_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'data', 'mentor.db')

def setup_user(cursor, email, name):
    cursor.execute("SELECT id FROM users WHERE email = ?", (email,))
    user = cursor.fetchone()
    if user:
        return user[0]
    
    cursor.execute(
        "INSERT INTO users (email, name, monthly_income, current_investments) VALUES (?, ?, ?, ?)",
        (email, name, '15000', '10000')
    )
    return cursor.lastrowid

def add_holding(cursor, user_id, type_, name, symbol, amount_invested, target_pct_increase, current_market_price):
    avg_price = current_market_price / (1.0 + (target_pct_increase / 100.0))
    quantity = amount_invested / avg_price
    
    cursor.execute("SELECT id FROM current_investments WHERE user_id = ? AND symbol = ?", (user_id, symbol))
    if cursor.fetchone():
        cursor.execute(
            "UPDATE current_investments SET amount_invested = ?, quantity = ?, avg_price = ? WHERE user_id = ? AND symbol = ?",
            (amount_invested, quantity, avg_price, user_id, symbol)
        )
    else:
        cursor.execute(
            "INSERT INTO current_investments (user_id, type, name, symbol, amount_invested, quantity, avg_price) VALUES (?, ?, ?, ?, ?, ?, ?)",
            (user_id, type_, name, symbol, amount_invested, quantity, avg_price)
        )
        
    print(f"[{name}] {symbol} -> Seeded with {target_pct_increase}% synthetic gain from ${avg_price:.2f} buying average.")

async def main():
    print("--- Chrysler SQLite Synthetic Seed Utility ---")
    
    print("Fetching LIVE market primitives...")
    tsla_data = await get_stock_data("TSLA")
    nvda_data = await get_stock_data("NVDA")
    spy_data = await get_stock_data("SPY")
    
    tsla_price = tsla_data["price"] if tsla_data else 170.0
    nvda_price = nvda_data["price"] if nvda_data else 850.0
    spy_price = spy_data["price"] if spy_data else 510.0
    
    print(f"Current Prices Validated: TSLA=${tsla_price}, NVDA=${nvda_price}, SPY=${spy_price}")
    
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    try:
        ayan_id = setup_user(cursor, "ayan@dummy.com", "Ayan")
        add_holding(cursor, ayan_id, "stock", "Tesla Inc.", "TSLA", amount_invested=10000, target_pct_increase=15.0, current_market_price=tsla_price)
        add_holding(cursor, ayan_id, "mutual_fund", "S&P 500 ETF", "SPY", amount_invested=5000, target_pct_increase=20.0, current_market_price=spy_price)
        
        aditya_id = setup_user(cursor, "aditya@dummy.com", "Aditya")
        add_holding(cursor, aditya_id, "stock", "Nvidia Corp.", "NVDA", amount_invested=15000, target_pct_increase=45.0, current_market_price=nvda_price)
        add_holding(cursor, aditya_id, "stock", "Tesla Inc.", "TSLA", amount_invested=2000, target_pct_increase=5.0, current_market_price=tsla_price)
        
        conn.commit()
        print("\n[✓] Success: Demo users Ayan and Aditya have been seeded into SQLite.")
    except Exception as e:
        conn.rollback()
        print(f"SQL Error: {e}")
    finally:
        conn.close()

if __name__ == "__main__":
    asyncio.run(main())
