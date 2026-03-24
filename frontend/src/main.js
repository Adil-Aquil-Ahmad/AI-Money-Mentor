/**
 * AI Money Mentor — Main Entry Point (v2 — Auth)
 * Auth gate: shows login or app based on Firebase auth state.
 * Initializes all modules after successful authentication.
 */
import { onAuthChange, loginWithEmail, signupWithEmail, loginWithGoogle, logout } from './auth.js';
import { initChat, clearChat } from './chat.js';
import { initProfile } from './profile.js';
import { initHealth, loadHealthScore } from './health-score.js';
import { initFire } from './fire-calculator.js';
import { initWhatIf } from './whatif.js';
import { initInvestments, loadInvestments } from './investments.js';

if (import.meta.env.DEV && window.location.hostname === '127.0.0.1') {
  const redirectUrl = new URL(window.location.href);
  redirectUrl.hostname = 'localhost';
  window.location.replace(redirectUrl.toString());
}

// -- DOM Elements ----------------------------------------------------------
const loginView = document.getElementById('login-view');
const appShell = document.getElementById('app');
const loginForm = document.getElementById('login-form');
const loginError = document.getElementById('login-error');
const btnToggleSignup = document.getElementById('btn-toggle-signup');
const btnGoogleLogin = document.getElementById('btn-google-login');
const signupNameGroup = document.getElementById('signup-name-group');
const btnLogin = document.getElementById('btn-login');
const btnLogout = document.getElementById('btn-logout');

// Navigation
const btnMenu = document.getElementById('btn-menu');
const sideNav = document.getElementById('side-nav');
const navOverlay = document.getElementById('nav-overlay');
const navItems = document.querySelectorAll('.nav-item[data-view]');
const views = document.querySelectorAll('.view');
const btnClearChat = document.getElementById('btn-clear-chat');
const btnTheme = document.getElementById('btn-theme');

let isSignupMode = false;
let appInitialized = false;

// -- Theme Toggle ----------------------------------------------------------
function initTheme() {
  const saved = localStorage.getItem('mm-theme') || 'dark';
  document.documentElement.setAttribute('data-theme', saved);
  updateThemeIcon(saved);
}

function toggleTheme() {
  const current = document.documentElement.getAttribute('data-theme') || 'dark';
  const next = current === 'dark' ? 'light' : 'dark';
  document.documentElement.setAttribute('data-theme', next);
  localStorage.setItem('mm-theme', next);
  updateThemeIcon(next);
}

function updateThemeIcon(theme) {
  if (!btnTheme) return;
  if (theme === 'light') {
    btnTheme.innerHTML = '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/></svg>';
  } else {
    btnTheme.innerHTML = '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="5"/><line x1="12" y1="1" x2="12" y2="3"/><line x1="12" y1="21" x2="12" y2="23"/><line x1="4.22" y1="4.22" x2="5.64" y2="5.64"/><line x1="18.36" y1="18.36" x2="19.78" y2="19.78"/><line x1="1" y1="12" x2="3" y2="12"/><line x1="21" y1="12" x2="23" y2="12"/><line x1="4.22" y1="19.78" x2="5.64" y2="18.36"/><line x1="18.36" y1="5.64" x2="19.78" y2="4.22"/></svg>';
  }
}

initTheme();
if (btnTheme) btnTheme.addEventListener('click', toggleTheme);

// -- Auth Gate -------------------------------------------------------------
onAuthChange(async (user) => {
  if (user) {
    console.log('[Auth] Authenticated:', user.email);
    showApp();
    if (!appInitialized) {
      await bootApp();
    }
  } else {
    console.log('[Auth] Not authenticated — showing login');
    showLogin();
  }
});

function showLogin() {
  loginView.classList.remove('hidden');
  appShell.classList.add('hidden');
}

function showApp() {
  loginView.classList.add('hidden');
  appShell.classList.remove('hidden');
}

// -- Login Form Handlers ---------------------------------------------------
loginForm.addEventListener('submit', async (e) => {
  e.preventDefault();
  hideError();

  const email = document.getElementById('login-email').value.trim();
  const password = document.getElementById('login-password').value;

  if (!email || !password) {
    showError('Please enter email and password');
    return;
  }

  btnLogin.disabled = true;
  btnLogin.textContent = isSignupMode ? 'Creating account...' : 'Logging in...';

  try {
    if (isSignupMode) {
      const name = document.getElementById('login-name').value.trim() || 'User';
      await signupWithEmail(email, password, name);
    } else {
      await loginWithEmail(email, password);
    }
  } catch (err) {
    console.error('[AUTH]', err);
    const msg = _friendlyError(err.code || err.message);
    showError(msg);
  } finally {
    btnLogin.disabled = false;
    btnLogin.textContent = isSignupMode ? 'Sign Up' : 'Login';
  }
});

btnToggleSignup.addEventListener('click', () => {
  isSignupMode = !isSignupMode;
  signupNameGroup.classList.toggle('hidden', !isSignupMode);
  btnLogin.textContent = isSignupMode ? 'Sign Up' : 'Login';
  btnToggleSignup.textContent = isSignupMode
    ? 'Already have an account? Login'
    : "Don't have an account? Sign up";
  hideError();
});

btnGoogleLogin.addEventListener('click', async () => {
  hideError();
  try {
    await loginWithGoogle();
  } catch (err) {
    console.error('[AUTH] Google login:', err);
    showError(_friendlyError(err.code || err.message));
  }
});

// -- Logout ----------------------------------------------------------------
btnLogout.addEventListener('click', async () => {
  if (confirm('Log out?')) {
    await logout();
    appInitialized = false;
    closeNav();
  }
});

// -- Error Display ---------------------------------------------------------
function showError(msg) {
  loginError.textContent = msg;
  loginError.classList.remove('hidden');
}
function hideError() {
  loginError.classList.add('hidden');
}

function _friendlyError(code) {
  const map = {
    'auth/user-not-found': 'No account found with this email',
    'auth/wrong-password': 'Incorrect password',
    'auth/invalid-credential': 'Incorrect email or password',
    'auth/email-already-in-use': 'This email is already registered. Try logging in.',
    'auth/weak-password': 'Password must be at least 6 characters',
    'auth/invalid-email': 'Please enter a valid email address',
    'auth/popup-closed-by-user': 'Google login was cancelled',
    'auth/network-request-failed': 'Network error - check your internet connection',
    'auth/unauthorized-domain': 'Google login is blocked for this site origin. Add localhost and 127.0.0.1 to Firebase Authentication > Settings > Authorized domains.',
  };
  return map[code] || code || 'Something went wrong. Please try again.';
}

// -- Navigation ------------------------------------------------------------
function openNav() {
  sideNav.classList.add('open');
  navOverlay.classList.add('open');
}

function closeNav() {
  sideNav.classList.remove('open');
  navOverlay.classList.remove('open');
}

function switchView(viewId) {
  views.forEach(v => v.classList.remove('active'));
  navItems.forEach(n => n.classList.remove('active'));

  const target = document.getElementById(`view-${viewId}`);
  if (target) target.classList.add('active');

  const navBtn = document.querySelector(`.nav-item[data-view="${viewId}"]`);
  if (navBtn) navBtn.classList.add('active');

  if (viewId === 'health') loadHealthScore();
  if (viewId === 'investments') loadInvestments();
  closeNav();
}

btnMenu.addEventListener('click', openNav);
navOverlay.addEventListener('click', closeNav);

navItems.forEach(item => {
  item.addEventListener('click', () => switchView(item.dataset.view));
});

btnClearChat.addEventListener('click', async () => {
  if (confirm('Clear all chat history?')) {
    await clearChat();
    closeNav();
  }
});

document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') {
    closeNav();
    document.getElementById('profile-modal').classList.add('hidden');
  }
});

// -- Boot App (after auth) -------------------------------------------------
async function bootApp() {
  console.log('[App] Money Mentor starting...');
  initProfile();
  initHealth();
  initFire();
  initWhatIf();
  initInvestments();
  await initChat();
  appInitialized = true;
  console.log('[App] All modules initialised');
}
