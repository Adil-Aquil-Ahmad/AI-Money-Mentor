"""
Chrysos — SQLite Database Layer (v2 — Auth + Memory)
Tables: users (with firebase_uid), chat_history, response_cache, memory.
"""
import aiosqlite
import os

DB_PATH = os.path.join(os.path.dirname(__file__), "data", "mentor.db")


async def get_db():
    """Get an async database connection."""
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    db = await aiosqlite.connect(DB_PATH)
    db.row_factory = aiosqlite.Row
    return db


async def init_db():
    """Initialize all tables."""
    db = await get_db()
    await db.executescript("""
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            firebase_uid TEXT UNIQUE,
            email TEXT,
            name TEXT NOT NULL DEFAULT 'User',
            age TEXT,
            monthly_income TEXT DEFAULT '0',
            monthly_expenses TEXT DEFAULT '0',
            current_savings TEXT DEFAULT '0',
            current_investments TEXT DEFAULT '0',
            current_debt TEXT DEFAULT '0',
            has_insurance TEXT DEFAULT '0',
            has_emergency_fund TEXT DEFAULT '0',
            emergency_fund_months TEXT DEFAULT '0',
            risk_profile TEXT DEFAULT 'medium',
            goals TEXT DEFAULT '[]',
            fcm_token TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS chat_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER DEFAULT 1,
            role TEXT NOT NULL,
            content TEXT NOT NULL,
            intent TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id)
        );

        CREATE TABLE IF NOT EXISTS response_cache (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            cache_key TEXT UNIQUE NOT NULL,
            response TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS memory (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            type TEXT NOT NULL DEFAULT 'insight',
            content TEXT NOT NULL,
            importance_score INTEGER DEFAULT 3,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id)
        );

        CREATE TABLE IF NOT EXISTS current_investments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            type TEXT NOT NULL,
            name TEXT NOT NULL,
            symbol TEXT,
            amount_invested REAL NOT NULL DEFAULT 0,
            quantity REAL,
            avg_price REAL,
            sip_amount REAL,
            purchase_date TEXT,
            currency TEXT DEFAULT 'INR',
            meta_json TEXT DEFAULT '{}',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id)
        );

        CREATE TABLE IF NOT EXISTS investment_news (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            investment_id INTEGER,
            symbol TEXT,
            headline TEXT NOT NULL,
            source TEXT,
            url TEXT,
            published_at TEXT,
            sentiment TEXT DEFAULT 'neutral',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE(user_id, symbol, headline),
            FOREIGN KEY (user_id) REFERENCES users(id),
            FOREIGN KEY (investment_id) REFERENCES current_investments(id)
        );

        CREATE TABLE IF NOT EXISTS portfolio_notifications (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            investment_id INTEGER,
            symbol TEXT,
            notification_type TEXT NOT NULL,
            title TEXT NOT NULL,
            message TEXT NOT NULL,
            event_key TEXT UNIQUE,
            is_read INTEGER DEFAULT 0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id),
            FOREIGN KEY (investment_id) REFERENCES current_investments(id)
        );

        CREATE TABLE IF NOT EXISTS watchlist (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            stock_symbol TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE(user_id, stock_symbol),
            FOREIGN KEY (user_id) REFERENCES users(id)
        );

        CREATE TABLE IF NOT EXISTS alerts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            stock_symbol TEXT NOT NULL,
            type TEXT NOT NULL,
            message TEXT NOT NULL,
            confidence REAL DEFAULT 0.0,
            is_read INTEGER DEFAULT 0,
            timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            last_triggered_at TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id)
        );

        CREATE TABLE IF NOT EXISTS daily_greetings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            greeting_text TEXT NOT NULL,
            date_str TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE(user_id, date_str),
            FOREIGN KEY (user_id) REFERENCES users(id)
        );

        CREATE TABLE IF NOT EXISTS stock_price_cache (
            symbol TEXT PRIMARY KEY,
            price REAL NOT NULL,
            prev_close REAL,
            date_str TEXT NOT NULL,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );

        CREATE INDEX IF NOT EXISTS idx_current_investments_user_id
        ON current_investments(user_id);

        CREATE INDEX IF NOT EXISTS idx_investment_news_user_id
        ON investment_news(user_id);

        CREATE INDEX IF NOT EXISTS idx_portfolio_notifications_user_id
        ON portfolio_notifications(user_id);
        
        CREATE INDEX IF NOT EXISTS idx_alerts_user_id
        ON alerts(user_id);
        
        CREATE INDEX IF NOT EXISTS idx_watchlist_user_id
        ON watchlist(user_id);
    """)

    # --- MIGRATIONS ---
    # Safe migrations to dynamically add columns if running against an older mentor.db
    try:
        await db.execute("ALTER TABLE users ADD COLUMN fcm_token TEXT")
    except Exception:
        pass  # Column already exists

    # Seed a default user if table is empty (for unauthenticated dev mode)
    cursor = await db.execute("SELECT COUNT(*) FROM users")
    count = (await cursor.fetchone())[0]
    if count == 0:
        await db.execute("INSERT INTO users (name) VALUES (?)", ("User",))

    await db.commit()
    await db.close()

async def get_cached_greeting(user_id: int, date_str: str) -> str | None:
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT greeting_text FROM daily_greetings WHERE user_id = ? AND date_str = ?",
            (user_id, date_str)
        )
        row = await cursor.fetchone()
        return row[0] if row else None
    finally:
        await db.close()

async def set_cached_greeting(user_id: int, date_str: str, greeting_text: str):
    db = await get_db()
    try:
        await db.execute(
            "INSERT OR REPLACE INTO daily_greetings (user_id, greeting_text, date_str) VALUES (?, ?, ?)",
            (user_id, greeting_text, date_str)
        )
        await db.commit()
    finally:
        await db.close()

async def get_cached_stock_price(symbol: str) -> dict | None:
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT price, prev_close, date_str FROM stock_price_cache WHERE symbol = ? ORDER BY updated_at DESC LIMIT 1",
            (symbol,)
        )
        row = await cursor.fetchone()
        if row:
            return {"price": row[0], "prev_close": row[1], "date_str": row[2]}
        return None
    finally:
        await db.close()

async def set_cached_stock_price(symbol: str, price: float, prev_close: float | None, date_str: str):
    db = await get_db()
    try:
        await db.execute(
            "INSERT OR REPLACE INTO stock_price_cache (symbol, price, prev_close, date_str) VALUES (?, ?, ?, ?)",
            (symbol, price, prev_close, date_str)
        )
        await db.commit()
    finally:
        await db.close()
