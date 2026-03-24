/**
 * AI Money Mentor — Health Score Module
 * Fetches score from API, renders animated ring + categories + suggestions.
 */
import { getHealthScore } from './api.js';

const scoreNumber = document.getElementById('score-number');
const scoreGrade = document.getElementById('score-grade');
const scoreMessage = document.getElementById('score-message');
const scoreRingFill = document.getElementById('score-ring-fill');
const categoriesEl = document.getElementById('health-categories');
const suggestionsEl = document.getElementById('health-suggestions');
const btnRefresh = document.getElementById('btn-refresh-health');

const CIRCUMFERENCE = 2 * Math.PI * 52; // r=52

export function initHealth() {
  btnRefresh.addEventListener('click', loadHealthScore);
}

export async function loadHealthScore() {
  const data = await getHealthScore();
  if (!data || data.score === undefined) {
    scoreNumber.textContent = '--';
    scoreMessage.textContent = 'Could not load score. Is the backend running?';
    return;
  }

  // Animate score number
  animateNumber(scoreNumber, data.score);

  // Ring fill
  const pct = data.score / data.max_score;
  const offset = CIRCUMFERENCE * (1 - pct);
  scoreRingFill.style.strokeDasharray = CIRCUMFERENCE;
  scoreRingFill.style.strokeDashoffset = offset;

  // Colour ring by score
  if (data.score >= 70) {
    scoreRingFill.style.stroke = 'var(--success)';
  } else if (data.score >= 40) {
    scoreRingFill.style.stroke = 'var(--warning)';
  } else {
    scoreRingFill.style.stroke = 'var(--danger)';
  }

  scoreGrade.textContent = `Grade ${data.grade}`;
  scoreMessage.textContent = data.message;

  // Categories
  categoriesEl.innerHTML = '';
  if (data.categories) {
    for (const [name, cat] of Object.entries(data.categories)) {
      const ratio = cat.score / cat.max;
      const cls = ratio >= 0.7 ? 'good' : ratio >= 0.4 ? 'fair' : 'poor';
      categoriesEl.innerHTML += `
        <div class="health-cat-card">
          <div class="cat-info">
            <span class="cat-name">${name}</span>
            <span class="cat-status">${cat.status}${cat.detail ? ' — ' + cat.detail : ''}</span>
          </div>
          <span class="cat-score ${cls}">${cat.score}/${cat.max}</span>
        </div>
      `;
    }
  }

  // Suggestions
  suggestionsEl.innerHTML = '';
  if (data.suggestions && data.suggestions.length) {
    data.suggestions.forEach(s => {
      suggestionsEl.innerHTML += `
        <div class="suggestion-item">
          <span class="sug-icon">💡</span>
          <span>${s}</span>
        </div>
      `;
    });
  }
}

function animateNumber(el, target) {
  const duration = 1200;
  const start = parseInt(el.textContent) || 0;
  const startTime = performance.now();

  function tick(now) {
    const elapsed = now - startTime;
    const progress = Math.min(elapsed / duration, 1);
    const eased = 1 - Math.pow(1 - progress, 3); // ease-out cubic
    el.textContent = Math.round(start + (target - start) * eased);
    if (progress < 1) requestAnimationFrame(tick);
  }
  requestAnimationFrame(tick);
}
