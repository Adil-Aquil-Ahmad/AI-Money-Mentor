/**
 * AI Money Mentor — What-If Simulator Module
 * Dynamic form based on scenario type, Chart.js chart, and insight card.
 */
import { simulateWhatIf } from './api.js';

const typeSelect = document.getElementById('whatif-type');
const fieldsEl = document.getElementById('whatif-fields');
const btnCalc = document.getElementById('btn-calc-whatif');
const resultsEl = document.getElementById('whatif-results');
const summaryEl = document.getElementById('whatif-summary');
const insightEl = document.getElementById('whatif-insight');

let whatifChart = null;

// Field definitions per scenario
const SCENARIO_FIELDS = {
  sip_growth: [
    { id: 'wi-amount', label: 'Monthly SIP (₹)', type: 'number', value: 5000, key: 'monthly_amount' },
    { id: 'wi-years', label: 'Duration (years)', type: 'number', value: 10, key: 'duration_years' },
    { id: 'wi-return', label: 'Expected Return (%/yr)', type: 'number', value: 12, key: 'expected_return', step: 0.5 },
  ],
  lumpsum: [
    { id: 'wi-lumpsum', label: 'Lumpsum Amount (₹)', type: 'number', value: 100000, key: 'lumpsum_amount' },
    { id: 'wi-years', label: 'Duration (years)', type: 'number', value: 10, key: 'duration_years' },
    { id: 'wi-return', label: 'Expected Return (%/yr)', type: 'number', value: 12, key: 'expected_return', step: 0.5 },
  ],
  expense_cut: [
    { id: 'wi-cut', label: 'Monthly Expense Cut (₹)', type: 'number', value: 2000, key: 'expense_reduction' },
    { id: 'wi-years', label: 'Duration (years)', type: 'number', value: 10, key: 'duration_years' },
    { id: 'wi-return', label: 'Investment Return (%/yr)', type: 'number', value: 12, key: 'expected_return', step: 0.5 },
  ],
  loan_prepay: [
    { id: 'wi-loan', label: 'Loan Amount (₹)', type: 'number', value: 1000000, key: 'loan_amount' },
    { id: 'wi-rate', label: 'Interest Rate (%/yr)', type: 'number', value: 10, key: 'loan_rate', step: 0.25 },
    { id: 'wi-years', label: 'Loan Tenure (years)', type: 'number', value: 15, key: 'duration_years' },
    { id: 'wi-extra', label: 'Extra EMI (₹/month)', type: 'number', value: 5000, key: 'extra_emi' },
  ],
};

export function initWhatIf() {
  typeSelect.addEventListener('change', renderFields);
  btnCalc.addEventListener('click', handleSimulate);
  renderFields();
}

function renderFields() {
  const type = typeSelect.value;
  const fields = SCENARIO_FIELDS[type] || [];
  fieldsEl.innerHTML = '';

  fields.forEach(f => {
    fieldsEl.innerHTML += `
      <div class="form-group">
        <label for="${f.id}">${f.label}</label>
        <input type="${f.type}" id="${f.id}" value="${f.value}" ${f.step ? `step="${f.step}"` : ''} />
      </div>
    `;
  });
}

async function handleSimulate() {
  const type = typeSelect.value;
  const fields = SCENARIO_FIELDS[type] || [];
  const payload = { scenario_type: type };

  fields.forEach(f => {
    const el = document.getElementById(f.id);
    payload[f.key] = parseFloat(el?.value) || f.value;
  });

  btnCalc.textContent = 'Simulating...';
  const result = await simulateWhatIf(payload);
  btnCalc.textContent = 'Simulate';

  if (!result || result.error) {
    return alert(result?.error || 'Could not run simulation.');
  }

  resultsEl.classList.remove('hidden');
  renderSummary(result);
  renderChart(result);
  renderInsight(result);
}

function renderSummary(r) {
  const res = r.result || {};
  summaryEl.innerHTML = '';

  const entries = Object.entries(res).filter(([k]) => k !== 'return_multiple');
  entries.forEach(([key, val]) => {
    const label = key.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase());
    const isHighlight = key.includes('final') || key.includes('wealth') || key.includes('saved');
    let display = typeof val === 'number' ? '₹' + formatNum(val) : val;

    summaryEl.innerHTML += `
      <div class="summary-card ${isHighlight ? 'highlight' : ''}">
        <div class="card-label">${label}</div>
        <div class="card-value ${isHighlight ? 'accent' : ''}">${display}</div>
      </div>
    `;
  });
}

function renderChart(r) {
  const yearly = r.yearly;
  if (!yearly || !yearly.length) {
    const canvas = document.getElementById('whatif-chart');
    canvas.style.display = 'none';
    return;
  }

  const canvas = document.getElementById('whatif-chart');
  canvas.style.display = 'block';
  const ctx = canvas.getContext('2d');

  if (whatifChart) whatifChart.destroy();

  const labels = yearly.map(p => `Year ${p.year}`);
  const invested = yearly.map(p => p.invested);
  const values = yearly.map(p => p.value);

  whatifChart = new Chart(ctx, {
    type: 'bar',
    data: {
      labels,
      datasets: [
        {
          label: 'Invested',
          data: invested,
          backgroundColor: 'rgba(148, 163, 184, 0.3)',
          borderColor: '#94a3b8',
          borderWidth: 1,
          borderRadius: 4,
        },
        {
          label: 'Total Value',
          data: values,
          backgroundColor: 'rgba(20, 196, 189, 0.4)',
          borderColor: '#14c4bd',
          borderWidth: 1,
          borderRadius: 4,
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
          callbacks: {
            label: (ctx) => `${ctx.dataset.label}: ₹${formatNum(ctx.parsed.y)}`,
          },
        },
      },
      scales: {
        x: {
          ticks: { color: '#64748b', font: { size: 10 }, maxTicksLimit: 10 },
          grid: { display: false },
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

function renderInsight(r) {
  insightEl.textContent = r.insight || '';
}

function formatNum(n) {
  if (n >= 10000000) return (n / 10000000).toFixed(2) + ' Cr';
  if (n >= 100000) return (n / 100000).toFixed(2) + ' L';
  if (n >= 1000) return (n / 1000).toFixed(1) + 'K';
  return Math.round(n).toLocaleString('en-IN');
}
