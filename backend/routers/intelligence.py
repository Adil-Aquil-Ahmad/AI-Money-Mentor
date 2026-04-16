from fastapi import APIRouter, Query, HTTPException
from typing import Optional
from services.intelligence_service import get_finance_intelligence

router = APIRouter()

@router.get("/stock")
async def get_stock_intelligence(
    symbol: str = Query(..., description="Stock ticker symbol (e.g., TCS.NS)"),
    investment: float = Query(10000.0, description="Initial investment amount for calculation"),
    days: int = Query(9, description="Number of historical days to look back for performance")
):
    """
    Generates a full intelligence brief for a stock holding including multi-day P&L,
    LLM sentiment analysis, news trends, and risk alerts.
    """
    if not symbol:
        raise HTTPException(status_code=400, detail="Symbol is required")
        
    try:
        data = await get_finance_intelligence(symbol, investment, days)
        return data
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
