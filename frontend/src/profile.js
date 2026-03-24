/**
 * AI Money Mentor — Profile Module
 * Profile modal open/close, load from API, save to API.
 */
import { getProfile, updateProfile } from './api.js';

const modal = document.getElementById('profile-modal');
const form = document.getElementById('profile-form');
const btnOpen = document.getElementById('btn-profile');
const btnClose = document.getElementById('btn-close-profile');

// Field mappings: form element id → API field name
const FIELD_MAP = {
  'p-name': 'name',
  'p-age': 'age',
  'p-risk': 'risk_profile',
  'p-income': 'monthly_income',
  'p-expenses': 'monthly_expenses',
  'p-savings': 'current_savings',
  'p-investments': 'current_investments',
  'p-debt': 'current_debt',
  'p-efund-months': 'emergency_fund_months',
  'p-insurance': 'has_insurance',
  'p-efund': 'has_emergency_fund',
  'p-goals': 'goals',
};

export function initProfile() {
  btnOpen.addEventListener('click', openProfile);
  btnClose.addEventListener('click', closeProfile);
  modal.addEventListener('click', (e) => {
    if (e.target === modal) closeProfile();
  });
  form.addEventListener('submit', handleSave);
}

async function openProfile() {
  modal.classList.remove('hidden');
  const data = await getProfile();
  if (data && !data.error) populateForm(data);
}

function closeProfile() {
  modal.classList.add('hidden');
}

function populateForm(data) {
  for (const [elId, field] of Object.entries(FIELD_MAP)) {
    const el = document.getElementById(elId);
    if (!el) continue;

    if (el.type === 'checkbox') {
      el.checked = !!data[field];
    } else if (field === 'goals') {
      const goals = Array.isArray(data[field]) ? data[field].join(', ') : (data[field] || '');
      el.value = goals;
    } else {
      el.value = data[field] || '';
    }
  }
}

async function handleSave(e) {
  e.preventDefault();
  const payload = {};

  for (const [elId, field] of Object.entries(FIELD_MAP)) {
    const el = document.getElementById(elId);
    if (!el) continue;

    if (el.type === 'checkbox') {
      payload[field] = el.checked;
    } else if (el.type === 'number') {
      const val = parseFloat(el.value);
      if (!isNaN(val)) payload[field] = val;
    } else if (field === 'goals') {
      const goals = el.value.split(',').map(g => g.trim()).filter(Boolean);
      if (goals.length) payload[field] = goals;
    } else {
      if (el.value.trim()) payload[field] = el.value.trim();
    }
  }

  const result = await updateProfile(payload);
  if (result && result.status === 'updated') {
    closeProfile();
    // Brief visual feedback
    const btn = form.querySelector('.btn-primary');
    const originalText = btn.textContent;
    btn.textContent = '✓ Saved!';
    setTimeout(() => { btn.textContent = originalText; }, 1500);
  }
}
