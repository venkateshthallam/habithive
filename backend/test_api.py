#!/usr/bin/env python3
"""
Test script for HabitHive API endpoints
Run the backend first: cd backend && ./run.sh
Then run this test: python test_api.py
"""

import requests
import json
from datetime import datetime, date

BASE_URL = "http://localhost:8002"

# Test data
test_phone = "+15555551234"
test_otp = "123456"
token = None
user_id = None
habit_id = None
hive_id = None
invite_code = None

def print_response(title, response):
    print(f"\n{'='*50}")
    print(f"🐝 {title}")
    print(f"{'='*50}")
    print(f"Status: {response.status_code}")
    try:
        print(f"Response: {json.dumps(response.json(), indent=2)}")
    except:
        print(f"Response: {response.text}")

def test_health():
    """Test health endpoint"""
    response = requests.get(f"{BASE_URL}/health")
    print_response("Health Check", response)
    return response.status_code == 200

def test_auth():
    """Test authentication flow"""
    global token, user_id
    
    # Send OTP
    response = requests.post(
        f"{BASE_URL}/api/auth/send-otp",
        json={"phone": test_phone}
    )
    print_response("Send OTP", response)
    
    # Verify OTP
    response = requests.post(
        f"{BASE_URL}/api/auth/verify-otp",
        json={"phone": test_phone, "otp": test_otp}
    )
    print_response("Verify OTP", response)
    
    if response.status_code == 200:
        data = response.json()
        token = data["access_token"]
        user_id = data["user_id"]
        print(f"✅ Got token: {token[:20]}...")
        print(f"✅ User ID: {user_id}")
        return True
    return False

def test_profile():
    """Test profile endpoints"""
    headers = {"Authorization": f"Bearer {token}"}
    
    # Get profile
    response = requests.get(f"{BASE_URL}/api/profiles/me", headers=headers)
    print_response("Get Profile", response)
    
    # Update profile
    response = requests.patch(
        f"{BASE_URL}/api/profiles/me",
        headers=headers,
        json={
            "display_name": "Test Bee 🐝",
            "theme": "honey",
            "day_start_hour": 5
        }
    )
    print_response("Update Profile", response)
    
    return response.status_code == 200

def test_habits():
    """Test habit endpoints"""
    global habit_id
    headers = {"Authorization": f"Bearer {token}"}
    
    # Create habit
    response = requests.post(
        f"{BASE_URL}/api/habits/",
        headers=headers,
        json={
            "name": "Drink Water",
            "emoji": "💧",
            "color_hex": "#34C8ED",
            "type": "counter",
            "target_per_day": 8
        }
    )
    print_response("Create Habit", response)
    
    if response.status_code == 200:
        habit_id = response.json()["id"]
        print(f"✅ Created habit: {habit_id}")
    
    # Get habits
    response = requests.get(f"{BASE_URL}/api/habits/", headers=headers)
    print_response("Get Habits", response)
    
    # Log habit
    if habit_id:
        response = requests.post(
            f"{BASE_URL}/api/habits/{habit_id}/log",
            headers=headers,
            json={"value": 3}
        )
        print_response("Log Habit", response)
    
    return response.status_code == 200

def test_hives():
    """Test hive endpoints"""
    global hive_id, invite_code
    headers = {"Authorization": f"Bearer {token}"}
    
    # Create hive from habit
    if habit_id:
        response = requests.post(
            f"{BASE_URL}/api/hives/from-habit",
            headers=headers,
            json={
                "habit_id": habit_id,
                "name": "Hydration Squad",
                "backfill_days": 7
            }
        )
        print_response("Create Hive from Habit", response)
        
        if response.status_code == 200:
            hive_id = response.json()["id"]
            print(f"✅ Created hive: {hive_id}")
    
    # Create invite
    if hive_id:
        response = requests.post(
            f"{BASE_URL}/api/hives/{hive_id}/invite",
            headers=headers,
            json={"ttl_minutes": 1440, "max_uses": 5}
        )
        print_response("Create Hive Invite", response)
        
        if response.status_code == 200:
            invite_code = response.json()["code"]
            print(f"✅ Invite code: {invite_code}")
    
    # Get hives
    response = requests.get(f"{BASE_URL}/api/hives/", headers=headers)
    print_response("Get Hives", response)
    
    # Get hive detail
    if hive_id:
        response = requests.get(f"{BASE_URL}/api/hives/{hive_id}", headers=headers)
        print_response("Get Hive Detail", response)
        
        # Log hive day
        response = requests.post(
            f"{BASE_URL}/api/hives/{hive_id}/log",
            headers=headers,
            json={"hive_id": hive_id, "value": 1}
        )
        print_response("Log Hive Day", response)
    
    return response.status_code == 200

def test_activity():
    """Test activity endpoints"""
    headers = {"Authorization": f"Bearer {token}"}
    
    # Get activity feed
    response = requests.get(f"{BASE_URL}/api/activity/feed", headers=headers)
    print_response("Activity Feed", response)
    
    # Get milestones
    response = requests.get(f"{BASE_URL}/api/activity/milestones", headers=headers)
    print_response("Milestones", response)
    
    return response.status_code == 200

def test_insights():
    """Test insights endpoint"""
    headers = {"Authorization": f"Bearer {token}"}
    
    response = requests.get(f"{BASE_URL}/api/habits/insights/summary", headers=headers)
    print_response("Insights Summary", response)
    dashboard = requests.get(f"{BASE_URL}/api/habits/insights/dashboard", headers=headers)
    print_response("Insights Dashboard", dashboard)

    return response.status_code == 200 and dashboard.status_code == 200

def main():
    print("\n" + "="*60)
    print("🐝 HabitHive API Test Suite")
    print("="*60)
    
    tests = [
        ("Health Check", test_health),
        ("Authentication", test_auth),
        ("Profile", test_profile),
        ("Habits", test_habits),
        ("Hives", test_hives),
        ("Activity", test_activity),
        ("Insights", test_insights)
    ]
    
    results = []
    for name, test_func in tests:
        try:
            success = test_func()
            results.append((name, success))
        except Exception as e:
            print(f"\n❌ {name} failed with error: {e}")
            results.append((name, False))
    
    print("\n" + "="*60)
    print("🐝 Test Results Summary")
    print("="*60)
    
    for name, success in results:
        status = "✅" if success else "❌"
        print(f"{status} {name}")
    
    passed = sum(1 for _, s in results if s)
    total = len(results)
    print(f"\nPassed: {passed}/{total}")
    
    if invite_code:
        print(f"\n📋 Invite code to share: {invite_code}")

if __name__ == "__main__":
    main()
