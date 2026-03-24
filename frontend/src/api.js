/**
 * AI Money Mentor — API Client (v2 — Auth-aware)
 * All fetch calls to the FastAPI backend.
 * Automatically attaches Firebase JWT token to all requests.
 */
import { getToken } from './auth.js';

const BASE = '/api';

async function request(path, options = {}) {
  const url = `${BASE}${path}`;
  const token = getToken();

  const headers = {
    'Content-Type': 'application/json',
    ...(options.headers || {}),
  };

  // Attach auth token if available
  if (token) {
    headers['Authorization'] = `Bearer ${token}`;
  }

  const config = { ...options, headers };

  try {
    const res = await fetch(url, config);
    if (!res.ok) throw new Error(`API error: ${res.status}`);
    return await res.json();
  } catch (err) {
    console.error(`[API] ${path}:`, err);
    return null;
  }
}

// -- Chat -----------------------------------------------------------------
export async function sendMessage(message) {
  return request('/chat', {
    method: 'POST',
    body: JSON.stringify({ message }),
  });
}

export async function getChatHistory(limit = 50) {
  return request(`/chat/history?limit=${limit}`);
}

export async function clearChatHistory() {
  return request('/chat/history', { method: 'DELETE' });
}

// -- Profile --------------------------------------------------------------
export async function getProfile() {
  return request('/profile');
}

export async function updateProfile(data) {
  return request('/profile', {
    method: 'POST',
    body: JSON.stringify(data),
  });
}

export async function getRiskAssessment() {
  return request('/profile/risk-assessment');
}

// -- Current Investments ---------------------------------------------------
export async function getInvestmentPortfolio() {
  return request('/investments/portfolio');
}

export async function getInvestments() {
  return request('/investments');
}

export async function addInvestment(data) {
  return request('/investments', {
    method: 'POST',
    body: JSON.stringify(data),
  });
}

export async function updateInvestment(id, data) {
  return request(`/investments/${id}`, {
    method: 'PUT',
    body: JSON.stringify(data),
  });
}

export async function deleteInvestment(id) {
  return request(`/investments/${id}`, { method: 'DELETE' });
}

export async function getInvestmentNews(limit = 12) {
  return request(`/investments/news?limit=${limit}`);
}

export async function getInvestmentNotifications(limit = 12, unreadOnly = false) {
  return request(`/investments/notifications?limit=${limit}&unread_only=${unreadOnly}`);
}

export async function markInvestmentNotificationRead(id) {
  return request(`/investments/notifications/${id}/read`, { method: 'POST' });
}

// -- Health Score ----------------------------------------------------------
export async function getHealthScore() {
  return request('/health-score');
}

// -- FIRE Calculator -------------------------------------------------------
export async function calculateFire(data) {
  return request('/fire', {
    method: 'POST',
    body: JSON.stringify(data),
  });
}

// -- What-If Simulator -----------------------------------------------------
export async function simulateWhatIf(data) {
  return request('/whatif', {
    method: 'POST',
    body: JSON.stringify(data),
  });
}

// -- Memory ----------------------------------------------------------------
export async function getMemories() {
  return request('/memory');
}

export async function addMemory(type, content, importance = 3) {
  return request('/memory', {
    method: 'POST',
    body: JSON.stringify({ type, content, importance_score: importance }),
  });
}

export async function deleteMemory(id) {
  return request(`/memory/${id}`, { method: 'DELETE' });
}

// -- Auth ------------------------------------------------------------------
export async function getMe() {
  return request('/auth/me');
}
