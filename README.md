# Chrysos: Personal AI Financial Advisor

## Project Overview

Chrysos is an advanced, personalized, and privacy-first AI financial advisor application. It combines a state-of-the-art Flutter frontend with a robust Python FastAPI backend, utilizing a sophisticated multi-tier Large Language Model (LLM) routing pipeline. The application provides dynamic portfolio tracking, real-time market data analysis, sentiment evaluation on financial news, and conversational financial advice tailored to the user's specific investments.

Privacy is a core pillar of Chrysos. The system employs End-to-End Encryption (E2EE) for user data, ensuring that personal financial information is decrypted locally on the device and only transmitted to the backend as transient payloads for processing without being permanently stored in plain text.

## The Problem Chrysos Solves

Most people don’t fail at investing because they lack motivation — they fail because the workflow is fragmented and cognitively expensive:

- Portfolio data lives in one place, market context in another, and advice somewhere else.
- Decisions are made with incomplete context (allocation drift, risk exposure, cash-flow constraints, and recent news are rarely evaluated together).
- Generic advice ignores personal constraints (SIP capacity, time horizon, liquidity needs, and asset mix).
- Privacy concerns prevent users from sharing their real portfolio with “AI advisors”, forcing them into toy examples.

Chrysos solves this by unifying **portfolio tracking + market intelligence + personalized reasoning** into a single, privacy-first assistant. It aims to make financial guidance:

- **Context-aware**: grounded in the user’s actual holdings and allocation.
- **Actionable**: produces clear next steps (not just explanations).
- **Fast and cost-aware**: routes work to the smallest capable model.
- **Privacy-first by design**: sensitive details stay local and encrypted.

## Architecture Vision (What We’re Building Toward)

Chrysos is designed as a hybrid, privacy-preserving “reasoning system” rather than a single chatbot.

**Core design principles**

- **Offline-first planning**: the first pass (intent parsing + task decomposition) can run on-device to minimize latency and protect raw user prompts.
- **Model routing as a product primitive**: complexity determines which model runs each step, so we pay heavyweight costs only when it truly matters.
- **Separation of concerns**: UI/UX (Flutter), orchestration + policy (FastAPI), and financial/LLM logic (engine) are modular and testable.
- **Graceful degradation**: if APIs/models are unavailable, the system falls back to deterministic logic and cached/partial results.
- **Security boundaries**: user secrets and decrypted portfolio details should never be persistently stored server-side.

## Core Features and AI Strategy

The cornerstone of the Chrysos intelligence is its Multi-Tier LLM Routing System. Instead of relying on a single monolithic model for every request, Chrysos decomposes tasks and routes them to the most appropriate model based on complexity, cost, and latency requirements.

## Technical Depth & Architecture (Judge-Focused)

This project’s “AI” is not a single model call — it’s an orchestrated pipeline with explicit routing, tool-usage, and financial-domain responsibilities.

### 1) Multi-Stage Reasoning Pipeline

The backend is structured so that a user query can be transformed into:

1. **Intent → tasks** (planner)
2. **Tasks → tool calls** (market data fetch, portfolio metrics)
3. **Evidence → synthesis** (final response)

This architecture enables:

- **Latency control**: fast models handle most work; heavy models are reserved for synthesis.
- **Cost control**: expensive inference is minimized.
- **Better reliability**: deterministic steps (math/formatting) are not delegated to LLMs.

### 2) Privacy-First Data Handling

- The system is built around a principle that sensitive portfolio context can be decrypted locally and sent to the backend only as **transient payloads**.
- The backend focuses on computation and reasoning, not long-term storage of plaintext sensitive data.

### 3) Financial Domain Computing (Not Just Chat)

Chrysos treats the user’s holdings as a dataset and computes:

- Portfolio totals (invested value, current value)
- Allocation by asset class
- SIP totals and forward projections
- P&L framing that can be used by other experiences (e.g., “Morning Brief”)

### 4) Resilience & Fallbacks

The portfolio UI supports:

- Live backend portfolio snapshots
- Local demo/fallback data when the backend is unavailable

This matters in hackathon settings and real-world networks: the experience remains usable even under partial failure.

### 5) Extensibility (Why This Scales Beyond a Demo)

The codebase layout (routes → screens/services on Flutter, routers → engine/services on FastAPI) is designed so new capabilities can be added by:

- Adding a backend router + a corresponding engine capability
- Exposing a clean API contract
- Adding a frontend screen or component that consumes it

### The Multi-Tier Model Pipeline

1. **Task Planner (Offline / Edge Tier)**
   - **Model**: Qwen3 1.7B (via Ollama)
   - **Role**: Acts as the initial gatekeeper and task planner. It runs locally and offline, analyzing the user's query to decompose it into discrete tasks (e.g., retrieving stock data, calculating portfolio metrics, generating a summary).
   - **Advantage**: Zero latency cost for API calls, maximum privacy for the initial query parsing, and acts as a deterministic fallback if external APIs are unavailable.

2. **Lightweight Tier (Fast & Efficient)**
   - **Model**: LLaMA 3.1 8B / Groq Mini
   - **Role**: Handles straightforward calculations, data formatting, and simple queries.
   - **Advantage**: Extremely fast response times and low computational cost for tasks that do not require deep reasoning.

3. **Mid-Weight Tier (Balanced)**
   - **Model**: LLaMA 4 Scout / Mixtral
   - **Role**: Manages intermediate reasoning tasks, such as comparing multiple asset classes or providing standard financial definitions.
   - **Advantage**: Balances deeper contextual understanding with reasonable inference speed.

4. **Heavyweight Tier (High Intelligence & Synthesis)**
   - **Model**: LLaMA 3.3 70B (via Groq)
   - **Role**: Reserved for complex synthesis and deep analysis. It handles tasks such as sentiment analysis on market news (e.g., determining if recent headlines about a stock are bullish or bearish) and formulating the final, comprehensive response to the user.
   - **Advantage**: Superior reasoning, nuance detection, and high-quality natural language generation.

## Real Business Impact

Chrysos is built for outcomes that matter to real users (and to any fintech product):

- **Reduces decision friction**: users don’t need to manually assemble context from multiple apps and websites.
- **Improves clarity and confidence**: allocation, SIP contributions, and projections are presented alongside an advisor that can explain “why” in plain language.
- **Creates a repeatable habit loop**: portfolio tracking + morning-style briefings + conversational Q&A supports consistent financial hygiene.
- **Privacy as a differentiator**: E2EE-first handling makes it feasible to use real portfolio data, which is essential for personalization.

In a production setting, these translate into measurable product metrics (activation, retention, portfolio engagement) and reduced support burden (fewer “what should I do?” dead-ends).

## Innovation

What’s novel here is the combination of multiple hard things into a coherent system:

- **Hybrid on-device + backend AI**: local planning (privacy + speed) paired with cloud synthesis (quality) when needed.
- **Model routing as a first-class feature**: systematically picks the right model per task instead of “always call the biggest model”.
- **Tool-augmented reasoning for finance**: deterministic computation and live market data are treated as evidence for LLM synthesis.
- **Privacy-first product architecture**: sensitive context is designed to stay encrypted and ephemeral.

## Codebase Architecture

The repository is structured into two main components: the Frontend (Flutter) and the Backend (Python FastAPI).

### Frontend (Flutter)
Located in the root directory and `lib/` folder.
- `lib/main.dart`: Application entry point and theme initialization.
- `lib/config/routes.dart`: Manages application navigation and screens.
- `lib/screens/portfolio_tracker/`: Contains the UI and logic for tracking investments, displaying allocations, and managing the dynamic "Add Investment" modals.
- `lib/screens/chat_advisor/`: The conversational interface where users interact with the AI. Includes the dynamic "Morning Brief" greeting sequence.
- `lib/services/`: Handles secure API communication with the backend.

### Backend (Python FastAPI)
Located in the `backend/` directory.
- `backend/main.py`: The FastAPI application entry point, configuring CORS, database connections, and registering routers.
- `backend/routers/greeting.py`: Powers the "Morning Brief". Calculates real-time portfolio P&L (daily and since-invested) and integrates with the heavyweight LLM for news sentiment analysis.
- `backend/engine/`: Contains the core AI logic, including the multi-tier routing pipeline (`task_executor.py`, `llm_client.py`) and the offline planner integration.
- `backend/services/stock_service.py`: Interfaces with `yfinance` to fetch real-time market data, historical prices, and relevant news headlines. Resolves both Indian (NSE) and US (NASDAQ/NYSE) ticker symbols.
- `backend/database.py`: Manages the SQLite/Cloud SQL connections and schema migrations for persistent storage.

## Prerequisites and Installation

To run Chrysos locally, you must install the required dependencies for both the frontend and backend, as well as the local LLM runtime.

### 1. Database and Environment
The application currently utilizes SQLite for local development but is architected to support Google Cloud SQL. Ensure you have Python 3.10+ installed.

### 2. Local LLM (Ollama)
Chrysos requires Ollama to run the offline task planner.
1. Download and install Ollama from `https://ollama.com/`.
2. Open a terminal and download the required model:
   ```bash
   ollama pull qwen
   ```
   *(Note: Adjust the tag to specifically pull `qwen3:1.7b` or the equivalent available small Qwen model depending on the Ollama registry.)*
3. Ensure the Ollama service is running in the background.

### 3. Backend Setup
1. Navigate to the backend directory:
   ```bash
   cd backend
   ```
2. Create and activate a Virtual Environment:
   ```bash
   python3 -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```
3. Install Python dependencies:
   ```bash
   pip install -r requirements.txt
   ```
4. Configure Environment Variables:
   Create a `.env` file in the `backend/` directory based on specific requirements. You will need obtaining API keys for LLM providers (e.g., Groq API key).
   ```text
   GROQ_API_KEY=your_api_key_here
   ```

### 4. Frontend Setup
1. Ensure the Flutter SDK (version 3.x) is installed on your system.
2. From the root of the project, fetch the Dart packages:
   ```bash
   flutter pub get
   ```

## Running the Application

To experience Chrysos, you must run both the backend server and the frontend client simultaneously.

### Starting the Backend
1. Open a terminal and navigate to the `backend/` directory.
2. Activate the virtual environment.
3. Start the FastAPI server:
   ```bash
   python3 main.py
   ```
   The backend will be available at `http://localhost:8000`.

### Starting the Frontend
1. Open a separate terminal in the root project directory.
2. Run the Flutter application. For web development, use Chrome:
   ```bash
   flutter run -d chrome
   ```
   Alternatively, you can run it on iOS or Android simulators if properly configured:
   ```bash
   flutter run -d ios
   ```

The application will launch, connect to the local backend, and initialize the AI routing pipeline to serve your financial queries.
