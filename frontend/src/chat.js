/**
 * AI Money Mentor — Chat Module (v2 — Clean Professional)
 * No emojis. Direct responses. Clean rendering.
 */
import { sendMessage, getChatHistory, clearChatHistory } from './api.js';

const messagesEl = document.getElementById('chat-messages');
const formEl = document.getElementById('chat-form');
const inputEl = document.getElementById('chat-input');
const typingEl = document.getElementById('typing-indicator');

/** Initialize chat — show welcome + load history */
export async function initChat() {
  formEl.addEventListener('submit', handleSend);
  await loadHistory();
}

/** Load chat history from backend */
async function loadHistory() {
  const data = await getChatHistory();
  if (data && data.messages && data.messages.length > 0) {
    data.messages.forEach(msg => addBubble(msg.role, msg.content, false));
    scrollToBottom();
  } else {
    showWelcome();
  }
}

/** Show welcome card */
function showWelcome() {
  const card = document.createElement('div');
  card.className = 'welcome-card';
  card.innerHTML = `
    <div class="welcome-icon">
      <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="var(--primary)" stroke-width="1.5">
        <path d="M12 2L2 7l10 5 10-5-10-5z"/>
        <path d="M2 17l10 5 10-5"/>
        <path d="M2 12l10 5 10-5"/>
      </svg>
    </div>
    <h3>Welcome to Money Mentor</h3>
    <p>Your AI-powered financial advisor. Ask about investments, budgeting, tax planning, or any financial topic.</p>
    <div class="quick-actions">
      <button class="quick-action-btn" data-msg="I just started my first job">New Job</button>
      <button class="quick-action-btn" data-msg="I got ₹1 lakh bonus">Got Bonus</button>
      <button class="quick-action-btn" data-msg="How should I start investing?">Start Investing</button>
      <button class="quick-action-btn" data-msg="Help me build an emergency fund">Emergency Fund</button>
      <button class="quick-action-btn" data-msg="How can I save more money?">Save More</button>
      <button class="quick-action-btn" data-msg="Tell me about tax saving options">Save Tax</button>
    </div>
  `;
  messagesEl.appendChild(card);

  // Quick action buttons
  card.querySelectorAll('.quick-action-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      const msg = btn.dataset.msg;
      inputEl.value = msg;
      handleSend(new Event('submit'));
    });
  });
}

/** Handle form submit */
async function handleSend(e) {
  e.preventDefault();
  const text = inputEl.value.trim();
  if (!text) return;

  // Remove welcome card if present
  const welcome = messagesEl.querySelector('.welcome-card');
  if (welcome) welcome.remove();

  inputEl.value = '';
  addBubble('user', text);

  // Show typing indicator
  showTyping(true);

  const result = await sendMessage(text);

  showTyping(false);

  if (result && result.response) {
    addBubble('assistant', result.response);
  } else {
    addBubble('assistant',
      "I'm having trouble connecting right now. Please make sure the backend server is running."
    );
  }
}

/** Add a chat bubble */
function addBubble(role, content, animate = true) {
  const bubble = document.createElement('div');
  bubble.className = `chat-bubble ${role}`;
  if (animate) bubble.style.animationDelay = '0.05s';

  const html = role === 'assistant' ? renderAssistantContent(content) : renderMarkdown(content);
  const time = new Date().toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' });

  bubble.innerHTML = `${html}<span class="bubble-time">${time}</span>`;
  messagesEl.appendChild(bubble);
  scrollToBottom();
}

function renderAssistantContent(text) {
  const structured = parseResponseSections(text);
  if (!structured) {
    return renderMarkdown(text);
  }

  return `
    <div class="advisor-response">
      ${structured.map(section => `
        <section class="advisor-section advisor-section-${section.key}">
          <div class="advisor-label">${escapeHtml(section.title)}</div>
          <div class="advisor-body">${renderMarkdown(section.body)}</div>
        </section>
      `).join('')}
    </div>
  `;
}

function parseResponseSections(text) {
  const labels = ['Priority', 'Why', 'Action Plan', 'What Not To Do', 'Capital Allocation', 'Investment Strategy', 'Stock Guidance', 'Monthly Plan', 'Stock Suggestions', 'Market Movers Today', 'Disclaimer'];
  const pattern = new RegExp(`(${labels.join('|')}):\\s*([\\s\\S]*?)(?=(?:\\n(?:${labels.join('|')}):)|$)`, 'g');
  const sections = [];
  let match;

  while ((match = pattern.exec(text)) !== null) {
    sections.push({
      key: slugify(match[1]),
      title: match[1],
      body: match[2].trim(),
    });
  }

  if (sections.length < 3) return null;
  return sections;
}

/** Render basic markdown to HTML */
function renderMarkdown(text) {
  const escaped = escapeHtml(text);
  return escaped
    // Bold
    .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
    // Italic
    .replace(/_(.*?)_/g, '<em>$1</em>')
    // Numbered lists
    .replace(/^\d+\.\s+(.+)/gm, '<li>$1</li>')
    // Bullet points
    .replace(/^[•\-\*]\s+(.+)/gm, '<li>$1</li>')
    // Wrap consecutive <li> in <ul>
    .replace(/((?:<li>.*<\/li>\n?)+)/g, '<ul>$1</ul>')
    // Line breaks
    .replace(/\n/g, '<br>');
}

function escapeHtml(text) {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function slugify(text) {
  return text.toLowerCase().replace(/\s+/g, '-');
}

/** Toggle typing indicator */
function showTyping(show) {
  typingEl.classList.toggle('hidden', !show);
  if (show) scrollToBottom();
}

/** Scroll chat to bottom */
function scrollToBottom() {
  requestAnimationFrame(() => {
    messagesEl.scrollTop = messagesEl.scrollHeight;
  });
}

/** Clear all chat */
export async function clearChat() {
  await clearChatHistory();
  messagesEl.innerHTML = '';
  showWelcome();
}
