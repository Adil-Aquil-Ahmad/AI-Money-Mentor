# Chrysos: Personal AI Financial Advisor

## Project Overview

Chrysos is an advanced, personalized, and privacy-first AI financial advisor application. It combines a state-of-the-art Flutter frontend with a robust Python FastAPI backend, utilizing a sophisticated multi-tier Large Language Model (LLM) routing pipeline. The application provides dynamic portfolio tracking, real-time market data analysis, sentiment evaluation on financial news, and conversational financial advice tailored to the user's specific investments.

Privacy is a core pillar of Chrysos. The system employs End-to-End Encryption (E2EE) for user data, ensuring that personal financial information is decrypted locally on the device and only transmitted to the backend as transient payloads for processing without being permanently stored in plain text.

## Core Features and AI Strategy

The cornerstone of the Chrysos intelligence is its Multi-Tier LLM Routing System. Instead of relying on a single monolithic model for every request, Chrysos decomposes tasks and routes them to the most appropriate model based on complexity, cost, and latency requirements.

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
