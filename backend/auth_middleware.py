"""
Chrysos — Firebase Auth Middleware
Verifies Firebase ID tokens using Google's public keys (project-ID-only approach).
No service account needed — uses token verification via Google's token info endpoint.
"""
import httpx
import logging
from fastapi import Depends, HTTPException, Header
from typing import Optional
from database import get_db

logger = logging.getLogger("auth")
logger.setLevel(logging.DEBUG)
if not logger.handlers:
    handler = logging.StreamHandler()
    handler.setFormatter(logging.Formatter(
        "\033[35m[AUTH]\033[0m %(asctime)s — %(message)s", datefmt="%H:%M:%S"
    ))
    logger.addHandler(handler)

FIREBASE_PROJECT_ID = "ai-money-mentor-18e6a"
GOOGLE_TOKEN_INFO_URL = "https://www.googleapis.com/oauth2/v3/tokeninfo"
FIREBASE_SECURE_TOKEN_URL = (
    f"https://www.googleapis.com/identitytoolkit/v3/relyingparty/getAccountInfo"
    f"?key=AIzaSyBdAivhi38vFrHYVEU3LSFZVTE-OvPF_Og"
)


async def verify_firebase_token(id_token: str) -> dict:
    """
    Verify a Firebase ID token using Google's secure token API.
    Returns user info dict with uid, email, name.
    """
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            r = await client.post(
                FIREBASE_SECURE_TOKEN_URL,
                json={"idToken": id_token},
            )
            if r.status_code == 200:
                data = r.json()
                users = data.get("users", [])
                if users:
                    user = users[0]
                    return {
                        "uid": user.get("localId", ""),
                        "email": user.get("email", ""),
                        "name": user.get("displayName", ""),
                        "photo": user.get("photoUrl", ""),
                        "email_verified": user.get("emailVerified", False),
                    }
            logger.warning("Token verification failed: %s", r.text[:200])
    except Exception as e:
        logger.error("Token verification error: %s", e)

    return None


async def get_current_user(authorization: Optional[str] = Header(None)) -> int:
    """
    FastAPI dependency: extracts Firebase token from Authorization header,
    verifies it, and returns the local user_id.
    Falls back to user_id=1 for unauthenticated requests (dev mode).
    """
    if not authorization:
        # Dev mode: no auth header → use default user
        return 1

    # Extract Bearer token
    parts = authorization.split(" ")
    if len(parts) != 2 or parts[0].lower() != "bearer":
        return 1  # Graceful fallback

    token = parts[1]
    if not token or token == "null" or token == "undefined":
        return 1

    # Verify with Firebase
    firebase_user = await verify_firebase_token(token)
    if not firebase_user or not firebase_user["uid"]:
        logger.warning("Invalid token — falling back to default user")
        return 1

    # Find or create local user
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT id FROM users WHERE firebase_uid = ?",
            (firebase_user["uid"],),
        )
        row = await cursor.fetchone()

        if row:
            user_id = row[0]
            logger.info("Authenticated user_id=%d (uid=%s)", user_id, firebase_user["uid"][:8])
            return user_id

        # Create new user
        cursor = await db.execute(
            "INSERT INTO users (firebase_uid, email, name) VALUES (?, ?, ?)",
            (firebase_user["uid"], firebase_user["email"], firebase_user["name"] or "User"),
        )
        await db.commit()
        user_id = cursor.lastrowid
        logger.info("Created new user_id=%d for %s", user_id, firebase_user["email"])
        return user_id
    finally:
        await db.close()
