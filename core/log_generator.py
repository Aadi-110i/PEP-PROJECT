import random
from datetime import datetime, timedelta
from faker import Faker
from core.db import SessionLocal, RequestLog

fake = Faker()

ENDPOINTS = ['/api/v1/users', '/api/v1/data', '/api/v1/login', '/api/v1/status', '/api/v1/settings']
METHODS = ['GET', 'POST', 'PUT', 'DELETE']
STATUS_CODES = [200, 201, 400, 401, 403, 404, 429, 500]

def generate_synthetic_logs(num_requests=200, inject_abuse=True):
    db = SessionLocal()
    logs = []
    
    base_time = datetime.utcnow() - timedelta(hours=1)
    
    burst_ip = fake.ipv4()
    scraper_ip = fake.ipv4()
    
    for i in range(num_requests):
        # Inject Abuse
        if inject_abuse and random.random() < 0.15:
            # Burst / Credential Stuffing
            ip = burst_ip
            endpoint = '/api/v1/login'
            status = 401
            method = 'POST'
        elif inject_abuse and random.random() < 0.15:
            # Scraper
            ip = scraper_ip
            endpoint = random.choice(ENDPOINTS)
            status = 200
            method = 'GET'
        else:
            # Normal
            ip = fake.ipv4()
            endpoint = random.choice(ENDPOINTS)
            status = random.choices(STATUS_CODES, weights=[70, 10, 5, 5, 2, 5, 2, 1])[0]
            method = random.choice(METHODS)
            
        req_time = base_time + timedelta(seconds=random.randint(1, 3600))
        
        log = RequestLog(
            timestamp=req_time,
            ip_address=ip,
            api_key=f"key_{random.randint(1, 50)}",
            endpoint=endpoint,
            method=method,
            status_code=status,
            response_time_ms=random.randint(10, 1000),
            user_agent=fake.user_agent(),
            decision='allowed' # Will be updated by rate limiter
        )
        logs.append(log)
    
    # Sort chronologically
    logs.sort(key=lambda x: x.timestamp)
    
    db.bulk_save_objects(logs)
    db.commit()
    db.close()
    return True
