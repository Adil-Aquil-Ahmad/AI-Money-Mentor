/**
 * Current Investments module.
 * Loads portfolio summary, alerts, and individual tracked assets.
 */
import {
  addInvestment,
  deleteInvestment,
  getInvestmentPortfolio,
  markInvestmentNotificationRead,
} from './api.js';

const formEl = document.getElementById('investments-form');
const summaryEl = document.getElementById('portfolio-summary');
const healthEl = document.getElementById('portfolio-health');
const allocationEl = document.getElementById('portfolio-allocation');
const notificationsEl = document.getElementById('portfolio-notifications');
const assetsEl = document.getElementById('portfolio-assets');
const newsEl = document.getElementById('portfolio-news');
const btnRefresh = document.getElementById('btn-refresh-investments');

let initialized = false;

export function initInvestments() {
  if (initialized) return;
  initialized = true;

  if (formEl) formEl.addEventListener('submit', handleAddInvestment);
  if (btnRefresh) btnRefresh.addEventListener('click', loadInvestments);
  if (assetsEl) assetsEl.addEventListener('click', handleAssetActions);
  if (notificationsEl) notificationsEl.addEventListener('click', handleNotificationActions);
}

export async function loadInvestments() {
  if (!summaryEl) return;

  summaryEl.innerHTML = renderLoadingCards();
  healthEl.innerHTML = '';
  allocationEl.innerHTML = '';
  notificationsEl.innerHTML = '';
  assetsEl.innerHTML = '';
  newsEl.innerHTML = '';

  const data = await getInvestmentPortfolio();
  if (!data) {
    summaryEl.innerHTML = renderEmptyState('Could not load portfolio data right now.');
    return;
  }

  renderSummary(data.summary || {});
  renderHealth(data.health_score || {});
  renderAllocation(data.allocation || []);
  renderNotifications(data.notifications || []);
  renderAssets(data.assets || []);
  renderNews(data.news || []);
}

async function handleAddInvestment(e) {
  e.preventDefault();
  const payload = {
    type: document.getElementById('inv-type').value,
    name: document.getElementById('inv-name').value.trim(),
    symbol: document.getElementById('inv-symbol').value.trim() || undefined,
    amount_invested: parseFloat(document.getElementById('inv-amount').value || '0'),
    quantity: parseOptionalNumber('inv-quantity'),
    avg_price: parseOptionalNumber('inv-avg-price'),
    sip_amount: parseOptionalNumber('inv-sip-amount'),
  };

  if (!payload.name || !payload.amount_invested) return;

  const result = await addInvestment(payload);
  if (result && result.status === 'created') {
    formEl.reset();
    document.getElementById('inv-type').value = 'stock';
    await loadInvestments();
  }
}

async function handleAssetActions(e) {
  const deleteBtn = e.target.closest('[data-delete-investment]');
  if (!deleteBtn) return;

  const investmentId = deleteBtn.dataset.deleteInvestment;
  if (!investmentId) return;
  if (!confirm('Delete this tracked investment?')) return;

  await deleteInvestment(investmentId);
  await loadInvestments();
}

async function handleNotificationActions(e) {
  const notificationBtn = e.target.closest('[data-notification-id]');
  if (!notificationBtn) return;
  await markInvestmentNotificationRead(notificationBtn.dataset.notificationId);
  await loadInvestments();
}

function renderSummary(summary) {
  const cards = [
    { label: 'Total Invested', value: formatCurrency(summary.total_invested || 0) },
    { label: 'Current Value', value: formatCurrency(summary.current_value || 0) },
    {
      label: 'Gain / Loss',
      value: `${formatSignedCurrency(summary.gain_loss || 0)} (${formatSignedPercent(summary.gain_loss_percent || 0)})`,
      tone: (summary.gain_loss || 0) >= 0 ? 'positive' : 'negative',
    },
    { label: 'Tracked Assets', value: String(summary.asset_count || 0) },
  ];

  summaryEl.innerHTML = cards.map(card => `
    <div class="summary-card ${card.tone || ''}">
      <div class="card-label">${card.label}</div>
      <div class="card-value">${card.value}</div>
    </div>
  `).join('');
}

function renderHealth(health) {
  if (!healthEl) return;
  healthEl.innerHTML = `
    <div class="portfolio-health-card">
      <div class="portfolio-health-header">
        <div>
          <div class="portfolio-section-title">Portfolio Health</div>
          <p class="portfolio-health-summary">${escapeHtml(health.summary || 'Portfolio signals will appear here.')}</p>
        </div>
        <div class="portfolio-health-score">${health.score || 0}<span>/100</span></div>
      </div>
      <div class="portfolio-health-grid">
        <div class="portfolio-health-pill"><strong>Diversification</strong>${escapeHtml(health.diversification || 'Not enough data')}</div>
        <div class="portfolio-health-pill"><strong>Concentration</strong>${escapeHtml(health.concentration || 'Not enough data')}</div>
        <div class="portfolio-health-pill"><strong>Risk</strong>${escapeHtml(health.risk || 'Not enough data')}</div>
        <div class="portfolio-health-pill"><strong>Performance</strong>${escapeHtml(health.performance || 'Not enough data')}</div>
      </div>
    </div>
  `;
}

function renderAllocation(allocation) {
  if (!allocationEl) return;
  if (!allocation.length) {
    allocationEl.innerHTML = '';
    return;
  }

  allocationEl.innerHTML = `
    <div class="portfolio-section-title">Allocation</div>
    <div class="portfolio-allocation-list">
      ${allocation.map(item => `
        <div class="allocation-row">
          <div class="allocation-label">${escapeHtml(humanize(item.type))}</div>
          <div class="allocation-bar">
            <span style="width:${Math.min(100, item.allocation_percent || 0)}%"></span>
          </div>
          <div class="allocation-value">${item.allocation_percent || 0}%</div>
        </div>
      `).join('')}
    </div>
  `;
}

function renderNotifications(items) {
  if (!notificationsEl) return;
  notificationsEl.innerHTML = `
    <div class="portfolio-section-title">Alerts</div>
    ${items.length ? items.map(item => `
      <button class="portfolio-alert ${item.is_read ? 'read' : ''}" data-notification-id="${item.id}">
        <div class="portfolio-alert-title">${escapeHtml(item.title)}</div>
        <div class="portfolio-alert-body">${escapeHtml(item.message)}</div>
      </button>
    `).join('') : '<div class="portfolio-empty-card">No current alerts. Major moves and important headlines will appear here.</div>'}
  `;
}

function renderAssets(items) {
  if (!assetsEl) return;
  if (!items.length) {
    assetsEl.innerHTML = renderEmptyState('Add your stocks, SIPs, gold, or other holdings to start tracking them.');
    return;
  }

  assetsEl.innerHTML = `
    <div class="portfolio-section-title">Tracked Assets</div>
    <div class="portfolio-assets-grid">
      ${items.map(item => {
        const gainTone = (item.gain_loss || 0) >= 0 ? 'positive' : 'negative';
        return `
          <article class="portfolio-asset-card">
            <div class="portfolio-asset-header">
              <div>
                <div class="portfolio-asset-name">${escapeHtml(item.name)}</div>
                <div class="portfolio-asset-meta">${escapeHtml(humanize(item.type))}${item.symbol ? ` • ${escapeHtml(item.symbol)}` : ''}</div>
              </div>
              <button class="asset-delete-btn" data-delete-investment="${item.id}" aria-label="Delete investment">Remove</button>
            </div>
            <div class="portfolio-asset-stats">
              <div>
                <span>Invested</span>
                <strong>${formatCurrency(item.amount_invested || 0)}</strong>
              </div>
              <div>
                <span>Current</span>
                <strong>${formatCurrency(item.current_value || 0)}</strong>
              </div>
              <div class="${gainTone}">
                <span>Gain / Loss</span>
                <strong>${formatSignedCurrency(item.gain_loss || 0)} (${formatSignedPercent(item.gain_loss_percent || 0)})</strong>
              </div>
            </div>
            <div class="portfolio-asset-tags">
              ${item.current_price ? `<span class="portfolio-tag">Price ${formatCurrency(item.current_price)}</span>` : ''}
              ${item.change_percent || item.change_percent === 0 ? `<span class="portfolio-tag ${gainTone}">${formatSignedPercent(item.change_percent)} today</span>` : ''}
              ${item.trend ? `<span class="portfolio-tag">${escapeHtml(humanize(item.trend))}</span>` : ''}
              ${item.allocation_percent ? `<span class="portfolio-tag">${item.allocation_percent}% of portfolio</span>` : ''}
            </div>
            ${renderAssetNews(item.news || [])}
          </article>
        `;
      }).join('')}
    </div>
  `;
}

function renderNews(items) {
  if (!newsEl) return;
  newsEl.innerHTML = `
    <div class="portfolio-section-title">Recent News</div>
    ${items.length ? items.map(item => `
      <a class="portfolio-news-card" href="${escapeHtml(item.url || '#')}" target="_blank" rel="noreferrer">
        <div class="portfolio-news-asset">${escapeHtml(item.asset_name || item.symbol || 'Asset')} • ${escapeHtml(item.sentiment || 'neutral')}</div>
        <div class="portfolio-news-headline">${escapeHtml(item.headline)}</div>
        <div class="portfolio-news-source">${escapeHtml(item.source || 'Yahoo Finance')}</div>
      </a>
    `).join('') : '<div class="portfolio-empty-card">Recent market news for tracked assets will appear here.</div>'}
  `;
}

function renderAssetNews(items) {
  if (!items.length) return '';
  return `
    <div class="portfolio-asset-news">
      ${items.slice(0, 2).map(item => `
        <a href="${escapeHtml(item.url || '#')}" target="_blank" rel="noreferrer" class="portfolio-asset-news-item">
          ${escapeHtml(item.headline)} <span>${escapeHtml(item.sentiment || 'neutral')}</span>
        </a>
      `).join('')}
    </div>
  `;
}

function renderLoadingCards() {
  return `
    <div class="summary-card"><div class="card-label">Loading</div><div class="card-value">...</div></div>
    <div class="summary-card"><div class="card-label">Loading</div><div class="card-value">...</div></div>
    <div class="summary-card"><div class="card-label">Loading</div><div class="card-value">...</div></div>
    <div class="summary-card"><div class="card-label">Loading</div><div class="card-value">...</div></div>
  `;
}

function renderEmptyState(message) {
  return `<div class="portfolio-empty-card">${escapeHtml(message)}</div>`;
}

function parseOptionalNumber(id) {
  const value = document.getElementById(id)?.value;
  if (!value) return undefined;
  const parsed = parseFloat(value);
  return Number.isFinite(parsed) ? parsed : undefined;
}

function formatCurrency(value) {
  return new Intl.NumberFormat('en-IN', {
    style: 'currency',
    currency: 'INR',
    maximumFractionDigits: 0,
  }).format(value || 0);
}

function formatSignedCurrency(value) {
  const prefix = value >= 0 ? '+' : '-';
  return `${prefix}${formatCurrency(Math.abs(value || 0))}`;
}

function formatSignedPercent(value) {
  const number = Number(value || 0);
  const prefix = number > 0 ? '+' : '';
  return `${prefix}${number.toFixed(2)}%`;
}

function humanize(value) {
  return String(value || '')
    .replace(/_/g, ' ')
    .replace(/\b\w/g, char => char.toUpperCase());
}

function escapeHtml(text) {
  return String(text || '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}
