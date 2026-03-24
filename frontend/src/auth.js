/**
 * AI Money Mentor — Firebase Auth Module
 * Handles email/password + Google OAuth login via Firebase.
 * Stores JWT token and provides it to API client.
 */
import { initializeApp } from 'firebase/app';
import {
  getAuth,
  signInWithEmailAndPassword,
  createUserWithEmailAndPassword,
  signInWithPopup,
  GoogleAuthProvider,
  onAuthStateChanged,
  signOut,
  updateProfile,
} from 'firebase/auth';

// Firebase config (from user's Firebase project)
const firebaseConfig = {
  apiKey: "AIzaSyBdAivhi38vFrHYVEU3LSFZVTE-OvPF_Og",
  authDomain: "ai-money-mentor-18e6a.firebaseapp.com",
  projectId: "ai-money-mentor-18e6a",
  storageBucket: "ai-money-mentor-18e6a.firebasestorage.app",
  messagingSenderId: "165470090988",
  appId: "1:165470090988:web:77383aaa9883af390017c9",
  measurementId: "G-8K0SB42ZDK",
};

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const googleProvider = new GoogleAuthProvider();

// Current JWT token (refreshed on auth state change)
let _currentToken = null;
let _currentUser = null;

/**
 * Get the current Firebase JWT token for API calls.
 */
export function getToken() {
  return _currentToken;
}

/**
 * Get current user info.
 */
export function getCurrentUser() {
  return _currentUser;
}

/**
 * Sign up with email + password.
 */
export async function signupWithEmail(email, password, displayName) {
  const cred = await createUserWithEmailAndPassword(auth, email, password);
  if (displayName) {
    await updateProfile(cred.user, { displayName });
  }
  _currentToken = await cred.user.getIdToken();
  _currentUser = cred.user;

  // Verify with backend
  await _verifyWithBackend(_currentToken);
  return cred.user;
}

/**
 * Login with email + password.
 */
export async function loginWithEmail(email, password) {
  const cred = await signInWithEmailAndPassword(auth, email, password);
  _currentToken = await cred.user.getIdToken();
  _currentUser = cred.user;

  await _verifyWithBackend(_currentToken);
  return cred.user;
}

/**
 * Login with Google OAuth popup.
 */
export async function loginWithGoogle() {
  const cred = await signInWithPopup(auth, googleProvider);
  _currentToken = await cred.user.getIdToken();
  _currentUser = cred.user;

  await _verifyWithBackend(_currentToken);
  return cred.user;
}

/**
 * Sign out.
 */
export async function logout() {
  await signOut(auth);
  _currentToken = null;
  _currentUser = null;
}

/**
 * Listen for auth state changes.
 * @param {Function} callback - (user) => void. user is null when logged out.
 */
export function onAuthChange(callback) {
  onAuthStateChanged(auth, async (user) => {
    if (user) {
      _currentToken = await user.getIdToken();
      _currentUser = user;
    } else {
      _currentToken = null;
      _currentUser = null;
    }
    callback(user);
  });
}

/**
 * Verify token with backend and create/get user.
 */
async function _verifyWithBackend(token) {
  try {
    const res = await fetch('/api/auth/verify', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ id_token: token }),
    });
    const data = await res.json();
    console.log('[AUTH] Backend verification:', data);
    return data;
  } catch (err) {
    console.error('[AUTH] Backend verification failed:', err);
    return null;
  }
}
