/**
 * AI Money Mentor — FIRE Calculator Module
 * SIP-based FIRE projections with Chart.js visualisation and milestones.
 */
import { calculateFire } from './api.js';

const btnCalc = document.getElementById('btn-calc-fire');
const resultsEl = document.getElementById('fire-results');
const summaryEl = document.getElementById('fire-summary');
const milestonesEl = document.getElementById('fire-milestones');

let fireChart = null;

export function initFire() {
  btnCalc.addEventListener('click', handleCalculate);
}

async function handleCalculate() {
  const data = {
    monthly_sip: parseFloat(document.getElementById('fire-sip').value) || 10000,
    expected_return: parseFloat(document.getElementById('fire-return').value) || 12,
    target_corpus: parseFloat(document.getElementById('fire-target').value) || 10000000,
    current_investments: parseFloat(document.getElementById('fire-current').value) || 0,
    monthly_expenses: parseFloat(document.getElementById('fire-expenses').value) || 30000,
  };

  btnCalc.textContent = 'Calculating...';
  const result = await calculateFire(data);
  btnCalc.textContent = 'Calculate';

  if (!result) {
    return alert('Could not calculate. Is the backend running?');
  }

  resultsEl.classList.remove('hidden');
  renderSummary(result);
  renderChart(result.projection);
  renderMilestones(result.milestones);
}

function renderSummary(r) {
  summaryEl.innerHTML = `
    <div class="summary-card highlight">
      <div class="card-label">Years to Target</div>
      <div class="card-value">${r.years_to_target} yrs</div>
    </div>
    <div class="summary-card">
      <div class="card-label">FIRE Number</div>
      <div class="card-value accent">₹${formatNum(r.fire_number)}</div>
    </div>
    <div class="summary-card">
      <div class="card-label">Total Invested</div>
      <div class="card-value">₹${formatNum(r.total_invested)}</div>
    </div>
    <div class="summary-card highlight">
      <div class="card-label">Wealth Gained</div>
      <div class="card-value">₹${formatNum(r.wealth_gained)}</div>
    </div>
  `;
}

function renderChart(projection) {
  const ctx = document.getElementById('fire-chart').getContext('2d');

  if (fireChart) fireChart.destroy();

  const labels = projection.map(p => `Year ${p.year}`);
  const invested = projection.map(p => p.invested);
  const values = projection.map(p => p.value);

  fireChart = new Chart(ctx, {
    type: 'line',
    data: {
      labels,
      datasets: [
        {
          label: 'Total Value',
          data: values,
          borderColor: '#14c4bd',
          backgroundColor: 'rgba(20, 196, 189, 0.1)',
          fill: true,
          tension: 0.3,
          pointRadius: 0,
          pointHoverRadius: 5,
          borderWidth: 2,
        },
        {
          label: 'Amount Invested',
          data: invested,
          borderColor: '#94a3b8',
          backgroundColor: 'rgba(148, 163, 184, 0.05)',
          fill: true,
          tension: 0.1,
          pointRadius: 0,
          pointHoverRadius: 5,
          borderWidth: 1.5,
          borderDash: [5, 5],
        },
      ],
    },
    options: {
      responsive: true,
      maintainAspectRatio: true,
      interaction: { mode: 'index', intersect: false },
      plugins: {
        legend: {
          position: 'top',
          labels: { color: '#94a3b8', font: { size: 11 }, boxWidth: 12 },
        },
        tooltip: {
          backgroundColor: '#1f2937',
          titleColor: '#f1f5f9',
          bodyColor: '#94a3b8',
          borderColor: 'rgba(255,255,255,0.1)',
          borderWidth: 1,
          callbacks: {
            label: (ctx) => `${ctx.dataset.label}: ₹${formatNum(ctx.parsed.y)}`,
          },
        },
      },
      scales: {
        x: {
          ticks: { color: '#64748b', font: { size: 10 }, maxTicksLimit: 10 },
          grid: { color: 'rgba(255,255,255,0.04)' },
        },
        y: {
          ticks: {
            color: '#64748b',
            font: { size: 10 },
            callback: (v) => '₹' + formatNum(v),
          },
          grid: { color: 'rgba(255,255,255,0.04)' },
        },
      },
    },
  });
}

function renderMilestones(milestones) {
  if (!milestones || !milestones.length) {
    milestonesEl.innerHTML = '';
    return;
  }
  milestonesEl.innerHTML = '<h3 style="margin-bottom:10px;font-size:0.95rem;">🏆 Milestones</h3>';
  milestones.forEach(m => {
    milestonesEl.innerHTML += `
      <div class="milestone-item">
        <span class="ms-icon">🎯</span>
        <span class="ms-year">Year ${m.year}</span>
        <span class="ms-label">${m.label}</span>
      </div>
    `;
  });
}

function formatNum(n) {
  if (n >= 10000000) return (n / 10000000).toFixed(2) + ' Cr';
  if (n >= 100000) return (n / 100000).toFixed(2) + ' L';
  if (n >= 1000) return (n / 1000).toFixed(1) + 'K';
  return n.toLocaleString('en-IN');
}
