#!/bin/bash

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "🐝 Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
source venv/bin/activate

# Install dependencies
echo "📦 Installing dependencies..."
pip install -r requirements.txt

# Create .env file if it doesn't exist
if [ ! -f ".env" ]; then
    echo "📝 Creating .env file from .env.example..."
    cp .env.example .env
    echo "⚠️  Please update .env with your Supabase credentials (optional for test mode)"
fi

# Run the FastAPI server
echo "🚀 Starting HabitHive API server on port 8002..."
echo "📱 Test mode enabled - Phone OTP bypassed"
echo "🔑 Test OTP codes: 123456 or 000000"
echo ""
python main.py