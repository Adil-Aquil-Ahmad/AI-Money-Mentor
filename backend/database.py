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

        CREATE INDEX IF NOT EXISTS idx_current_investments_user_id
        ON current_investments(user_id);

        CREATE INDEX IF NOT EXISTS idx_investment_news_user_id
        ON investment_news(user_id);

        CREATE INDEX IF NOT EXISTS idx_portfolio_notifications_user_id
        ON portfolio_notifications(user_id);
    """)

    # Seed a default user if table is empty (for unauthenticated dev mode)
    cursor = await db.execute("SELECT COUNT(*) FROM users")
    count = (await cursor.fetchone())[0]
    if count == 0:
        await db.execute("INSERT INTO users (name) VALUES (?)", ("User",))

    await db.commit()
    await db.close()
