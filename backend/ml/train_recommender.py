import sqlite3
import os
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, TensorDataset

DB_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'data', 'mentor.db')

# Define a simple Neural Network to evaluate Investment Strategies
class PortfolioRecommender(nn.Module):
    def __init__(self, input_size, hidden_size, output_size):
        super(PortfolioRecommender, self).__init__()
        self.fc1 = nn.Linear(input_size, hidden_size)
        self.relu = nn.ReLU()
        self.fc2 = nn.Linear(hidden_size, output_size)
        
    def forward(self, x):
        out = self.fc1(x)
        out = self.relu(out)
        out = self.fc2(out)
        return out

def prepare_data():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # We fetch all investments to train our conceptual model
    cursor.execute("""
        SELECT amount_invested, avg_price, quantity, symbol 
        FROM current_investments
    """)
    rows = cursor.fetchall()
    conn.close()
    
    if not rows:
        print("Error: No data available to train on. Run seed script first.")
        return None, None
        
    features = []
    labels = []
    
    # We create a simple pseudo-score (like predicted growth factor) based on dummy logic
    for row in rows:
        amount_invested, avg_price, quantity, symbol = row
        # Normalize features roughly, defaulting None values to 0 to prevent crashes
        safe_amount = float(amount_invested) if amount_invested else 0.0
        safe_price = float(avg_price) if avg_price else 0.0
        safe_qty = float(quantity) if quantity else 0.0
        
        f = [
            safe_amount / 10000.0,
            safe_price / 1000.0,
            safe_qty / 100.0
        ]
        features.append(f)
        
        # Label: Higher score for NVDA/SPY to conceptually map to "best method"
        if symbol == "NVDA":
            labels.append([0.9])
        elif symbol == "SPY":
            labels.append([0.65])
        else:
            labels.append([0.4])
            
    X = torch.tensor(features, dtype=torch.float32)
    y = torch.tensor(labels, dtype=torch.float32)
    
    return X, y

def train():
    print("--- Chrysler Neural Engine Training Sequence ---")
    X, y = prepare_data()
    if X is None:
        return
        
    dataset = TensorDataset(X, y)
    dataloader = DataLoader(dataset, batch_size=2, shuffle=True)
    
    # Hyperparameters
    input_size = 3
    hidden_size = 8
    output_size = 1
    num_epochs = 100
    learning_rate = 0.01
    
    model = PortfolioRecommender(input_size, hidden_size, output_size)
    criterion = nn.MSELoss()
    optimizer = optim.Adam(model.parameters(), lr=learning_rate)
    
    print(f"Data ingested. Found {len(X)} portfolio nodes. Starting compilation...")
    
    # Training Loop
    for epoch in range(num_epochs):
        for inputs, targets in dataloader:
            outputs = model(inputs)
            loss = criterion(outputs, targets)
            
            optimizer.zero_grad()
            loss.backward()
            optimizer.step()
            
        if (epoch+1) % 20 == 0:
            print(f'Epoch [{epoch+1}/{num_epochs}], Core Loss Variance: {loss.item():.4f}')
            
    # Serialize model weights to .pt
    pt_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'financial_recommender.pt')
    torch.save(model.state_dict(), pt_path)
    
    print(f"\n[✓] PyTorch Tensor Compilation Complete.")
    print(f"Model exported successfully natively at: {pt_path}")

if __name__ == "__main__":
    train()
