"""
AI Money Mentor — Memory Router
GET    /api/memory      — List user's memories
POST   /api/memory      — Manually add a memory
DELETE /api/memory/{id}  — Delete a memory
"""
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from typing import Optional
from auth_middleware import get_current_user
from database import get_db

router = APIRouter()


class MemoryCreate(BaseModel):
    type: str = "insight"  # goal, preference, event, insight
    content: str
    importance_score: int = 3


@router.get("/memory")
async def list_memories(user_id: int = Depends(get_current_user)):
    """Get all memories for the current user, ordered by importance."""
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT id, type, content, importance_score, created_at "
            "FROM memory WHERE user_id = ? ORDER BY importance_score DESC, created_at DESC",
            (user_id,),
        )
        rows = await cursor.fetchall()
        return {
            "memories": [
                {
                    "id": r[0],
                    "type": r[1],
                    "content": r[2],
                    "importance_score": r[3],
                    "created_at": r[4],
                }
                for r in rows
            ]
        }
    finally:
        await db.close()


@router.post("/memory")
async def add_memory(mem: MemoryCreate, user_id: int = Depends(get_current_user)):
    """Manually add a memory."""
    db = await get_db()
    try:
        cursor = await db.execute(
            "INSERT INTO memory (user_id, type, content, importance_score) VALUES (?, ?, ?, ?)",
            (user_id, mem.type, mem.content, min(max(mem.importance_score, 1), 5)),
        )
        await db.commit()
        return {"id": cursor.lastrowid, "status": "created"}
    finally:
        await db.close()


@router.delete("/memory/{memory_id}")
async def delete_memory(memory_id: int, user_id: int = Depends(get_current_user)):
    """Delete a memory (only if it belongs to the user)."""
    db = await get_db()
    try:
        await db.execute(
            "DELETE FROM memory WHERE id = ? AND user_id = ?",
            (memory_id, user_id),
        )
        await db.commit()
        return {"status": "deleted"}
    finally:
        await db.close()
