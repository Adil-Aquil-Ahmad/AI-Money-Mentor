"""
AI Money Mentor — What-If Simulator Router
POST /api/whatif — Simulate financial scenarios ("What if I invest ₹X for Y years?")
"""
from fastapi import APIRouter
from pydantic import BaseModel
from typing import Optional, List
import math

router = APIRouter()


class WhatIfScenario(BaseModel):
    scenario_type: str = "sip_growth"   # sip_growth | lumpsum | expense_cut | loan_prepay
    monthly_amount: float = 5000
    duration_years: int = 10
    expected_return: float = 12.0       # annual %
    lumpsum_amount: float = 0
    expense_reduction: float = 0        # monthly reduction
    loan_amount: float = 0
    loan_rate: float = 10.0             # annual %
    extra_emi: float = 0


@router.post("/whatif")
async def whatif_simulator(data: WhatIfScenario):
    """Run a what-if financial simulation."""
    if data.scenario_type == "sip_growth":
        return _simulate_sip(data)
    elif data.scenario_type == "lumpsum":
        return _simulate_lumpsum(data)
    elif data.scenario_type == "expense_cut":
        return _simulate_expense_cut(data)
    elif data.scenario_type == "loan_prepay":
        return _simulate_loan_prepay(data)
    else:
        return {"error": "Unknown scenario type. Use: sip_growth, lumpsum, expense_cut, loan_prepay"}


def _simulate_sip(data: WhatIfScenario) -> dict:
    """What if I invest ₹X/month for Y years?"""
    r = data.expected_return / 100 / 12
    n = data.duration_years * 12
    sip = data.monthly_amount

    if r > 0:
        fv = sip * ((1 + r) ** n - 1) / r * (1 + r)
    else:
        fv = sip * n

    invested = sip * n
    gains = fv - invested

    # Comparison scenarios
    scenarios = []
    for extra in [0, 1000, 2000, 5000]:
        total_sip = sip + extra
        if r > 0:
            total_fv = total_sip * ((1 + r) ** n - 1) / r * (1 + r)
        else:
            total_fv = total_sip * n
        scenarios.append({
            "monthly_sip": total_sip,
            "total_invested": total_sip * n,
            "final_value": round(total_fv),
            "gains": round(total_fv - total_sip * n),
        })

    # Year-by-year for chart
    yearly = []
    for y in range(data.duration_years + 1):
        m = y * 12
        if r > 0 and m > 0:
            val = sip * ((1 + r) ** m - 1) / r * (1 + r)
        elif m > 0:
            val = sip * m
        else:
            val = 0
        yearly.append({
            "year": y,
            "invested": round(sip * m),
            "value": round(val),
        })

    return {
        "scenario": "SIP Growth",
        "title": f"What if you invest ₹{int(sip):,}/month for {data.duration_years} years?",
        "result": {
            "total_invested": round(invested),
            "final_value": round(fv),
            "wealth_gained": round(gains),
            "return_multiple": round(fv / invested, 2) if invested > 0 else 0,
        },
        "comparison": scenarios,
        "yearly": yearly,
        "insight": _sip_insight(sip, fv, invested, data.duration_years),
    }


def _simulate_lumpsum(data: WhatIfScenario) -> dict:
    """What if I invest ₹X as lumpsum for Y years?"""
    amount = data.lumpsum_amount or data.monthly_amount * 12
    annual_r = data.expected_return / 100
    years = data.duration_years

    yearly = []
    for y in range(years + 1):
        val = amount * (1 + annual_r) ** y
        yearly.append({"year": y, "invested": round(amount), "value": round(val)})

    final = amount * (1 + annual_r) ** years

    return {
        "scenario": "Lumpsum Investment",
        "title": f"What if you invest ₹{int(amount):,} as lumpsum for {years} years?",
        "result": {
            "invested": round(amount),
            "final_value": round(final),
            "wealth_gained": round(final - amount),
            "return_multiple": round(final / amount, 2) if amount > 0 else 0,
        },
        "yearly": yearly,
        "insight": f"Your ₹{int(amount):,} could grow to ₹{int(final):,} — that's {final/amount:.1f}x your money!",
    }


def _simulate_expense_cut(data: WhatIfScenario) -> dict:
    """What if I cut ₹X/month expenses and invest the savings?"""
    cut = data.expense_reduction or data.monthly_amount
    r = data.expected_return / 100 / 12
    n = data.duration_years * 12

    if r > 0:
        fv = cut * ((1 + r) ** n - 1) / r * (1 + r)
    else:
        fv = cut * n

    saved = cut * n

    return {
        "scenario": "Expense Cut & Invest",
        "title": f"What if you cut ₹{int(cut):,}/month and invest it?",
        "result": {
            "monthly_savings": round(cut),
            "total_saved": round(saved),
            "invested_value": round(fv),
            "extra_wealth": round(fv - saved),
        },
        "insight": (
            f"Cutting just ₹{int(cut):,}/month and investing it could build "
            f"₹{int(fv):,} over {data.duration_years} years. Small changes, big results! 🚀"
        ),
    }


def _simulate_loan_prepay(data: WhatIfScenario) -> dict:
    """What if I prepay ₹X extra on my loan each month?"""
    principal = data.loan_amount or 1000000
    annual_rate = data.loan_rate / 100
    monthly_rate = annual_rate / 12
    extra = data.extra_emi or data.monthly_amount

    # Calculate original EMI (assuming data.duration_years tenure)
    n = data.duration_years * 12
    if monthly_rate > 0:
        emi = principal * monthly_rate * (1 + monthly_rate) ** n / ((1 + monthly_rate) ** n - 1)
    else:
        emi = principal / n

    # Simulate normal repayment
    normal_interest = _total_interest(principal, monthly_rate, emi, n)

    # Simulate with extra payment
    new_months, new_interest = _simulate_prepay(principal, monthly_rate, emi, extra)

    saved_interest = normal_interest - new_interest
    saved_months = n - new_months

    return {
        "scenario": "Loan Prepayment",
        "title": f"What if you pay ₹{int(extra):,} extra on your ₹{int(principal):,} loan?",
        "result": {
            "original_tenure": f"{n} months ({n//12} years)",
            "new_tenure": f"{new_months} months ({new_months//12} years {new_months%12} months)",
            "months_saved": saved_months,
            "interest_saved": round(saved_interest),
            "original_total_interest": round(normal_interest),
        },
        "insight": (
            f"Adding ₹{int(extra):,}/month extra could save you ₹{int(saved_interest):,} "
            f"in interest and close your loan {saved_months} months earlier!"
        ),
    }


def _total_interest(principal, monthly_rate, emi, max_months):
    balance = principal
    total_interest = 0
    for _ in range(max_months):
        if balance <= 0:
            break
        interest = balance * monthly_rate
        total_interest += interest
        balance = balance + interest - emi
    return total_interest


def _simulate_prepay(principal, monthly_rate, emi, extra):
    balance = principal
    total_interest = 0
    months = 0
    while balance > 0 and months < 600:  # safety cap
        interest = balance * monthly_rate
        total_interest += interest
        payment = min(emi + extra, balance + interest)
        balance = balance + interest - payment
        months += 1
    return months, total_interest


def _sip_insight(sip, fv, invested, years):
    multiple = fv / invested if invested > 0 else 0
    if multiple >= 5:
        emoji = "🚀"
    elif multiple >= 3:
        emoji = "💰"
    else:
        emoji = "📈"
    return (
        f"Your ₹{int(sip):,}/month SIP could grow to ₹{int(fv):,} in {years} years — "
        f"that's {multiple:.1f}x your invested amount! {emoji}"
    )
