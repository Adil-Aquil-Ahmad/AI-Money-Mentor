# AI Money Mentor 💰

**AI-powered personal finance mentor for Indian users** — mobile-first chat interface with rule-based financial engine + LLM intelligence.

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| 💬 **Chat Advisor** | WhatsApp-style AI chat for life-event financial advice |
| 📊 **Money Health Score** | 0–100 score with category breakdown & improvement tips |
| 🔥 **FIRE Calculator** | Financial Independence projections with interactive charts |
| 🔮 **What-If Simulator** | SIP growth, lumpsum, expense cut, loan prepayment scenarios |
| 👤 **Risk Profiling** | Low / Medium / High risk-adapted recommendations |
| 🧠 **Hybrid LLM** | llama.cpp → Ollama → API fallback → rule-engine offline mode |
| 📱 **Mobile Ready** | Capacitor config for Android APK builds |

---

## 🏗️ Architecture

```
User Input → Intent Parser (LLM+keyword) → Rule Engine → Context Builder → LLM → Response Generator
```

- **Frontend**: Vite (vanilla JS/CSS), Capacitor for mobile
- **Backend**: Python FastAPI + SQLite
- **AI**: Hybrid chain — llama.cpp server → Ollama → External API → rule-engine fallback

---

## 📁 Project Structure

```
AI Money Mentor/
├── frontend/
│   ├── index.html                 # App shell (all views)
│   ├── package.json               # Vite + Capacitor deps
│   ├── vite.config.js             # Dev server + API proxy
│   ├── capacitor.config.ts        # Android build config
│   └── src/
│       ├── main.js                # Entry point + navigation
│       ├── chat.js                # Chat engine + bubbles
│       ├── profile.js             # Profile modal
│       ├── health-score.js        # Health score view
│       ├── fire-calculator.js     # FIRE calculator + chart
│       ├── whatif.js              # What-if simulator + chart
│       ├── api.js                 # API client
│       └── styles/
│           ├── main.css           # Design system (dark theme)
│           ├── chat.css           # Chat bubble styles
│           └── components.css     # Shared components
│
├── backend/
│   ├── main.py                    # FastAPI app entry
│   ├── database.py                # SQLite setup
│   ├── requirements.txt           # Python deps
│   ├── engine/
│   │   ├── intent_parser.py       # LLM + keyword intent detection
│   │   ├── rule_engine.py         # Deterministic financial rules
│   │   ├── context_builder.py     # LLM prompt assembly
│   │   ├── llm_client.py          # Hybrid LLM provider chain
│   │   └── response_generator.py  # Final response formatting
│   └── routers/
│       ├── chat.py                # Chat pipeline endpoint
│       ├── profile.py             # Profile CRUD + risk assessment
│       ├── health_score.py        # Health score calculation
│       ├── fire.py                # FIRE calculator
│       └── whatif.py              # What-if simulator
│
└── README.md
```

---

## 🚀 Quick Start

### Prerequisites

- **Python 3.10+**
- **Node.js 18+**
- (Optional) **Ollama** or **llama.cpp** for LLM features

### 1. Start the Backend

```powershell
cd backend
pip install -r requirements.txt
python main.py
```

Backend runs at `http://localhost:8000`. API docs at `http://localhost:8000/docs`.

### 2. Start the Frontend

```powershell
cd frontend
npm install
npm run dev
```

Frontend runs at `http://localhost:3000` (opens browser automatically).

### 3. (Optional) Start an LLM

**Option A — Ollama:**
```powershell
ollama pull tinyllama
ollama serve
```

**Option B — llama.cpp server:**
```powershell
./server -m models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf --port 8080
```

**Option C — External API (Groq, OpenRouter, etc.):**
Set environment variables before starting the backend:
```powershell
$env:LLM_API_URL = "https://api.groq.com/openai/v1/chat/completions"
$env:LLM_API_KEY = "your-api-key"
$env:LLM_API_MODEL = "llama3-8b-8192"
```

> **Note:** The app works fully without any LLM — it falls back to the rule-based financial engine which provides deterministic, reliable advice.

---

## 📱 Building Mobile APK (Capacitor)

```powershell
cd frontend

# Build the web app
npm run build

# Initialize Capacitor (first time only)
npx cap init "AI Money Mentor" "com.aimoneymentor.app" --web-dir dist

# Add Android platform
npx cap add android

# Sync web assets to native project
npx cap sync

# Open in Android Studio
npx cap open android
```

In Android Studio: **Build → Build Bundle(s) / APK(s) → Build APK(s)**

For development with live reload, edit `capacitor.config.ts`:
```typescript
server: {
  url: 'http://YOUR_PC_IP:3000',
  cleartext: true,
}
```

---

## ⚙️ Configuration

| Environment Variable | Default | Description |
|---------------------|---------|-------------|
| `LLAMACPP_URL` | `http://localhost:8080` | llama.cpp server URL |
| `OLLAMA_URL` | `http://localhost:11434` | Ollama server URL |
| `OLLAMA_MODEL` | `tinyllama` | Ollama model name |
| `LLM_API_URL` | (empty) | External API endpoint |
| `LLM_API_KEY` | (empty) | External API key |
| `LLM_API_MODEL` | (empty) | External API model name |

---

## 💡 Sample Prompts to Try

- "I just started my first job with ₹40k salary"
- "I got ₹1 lakh bonus, what should I do?"
- "How should I start investing?"
- "Help me build an emergency fund"
- "How can I save tax?"
- "I have ₹5 lakh debt, how to repay?"
- "What insurance do I need?"
- "I want to save for a car"

---

## 🔒 Privacy

- All data stored locally in SQLite — no cloud sync
- LLM inference runs locally (llama.cpp / Ollama)
- No telemetry or analytics
- Your financial data never leaves your device
