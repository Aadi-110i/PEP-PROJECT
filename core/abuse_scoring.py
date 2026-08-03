from sqlalchemy import func
from datetime import datetime, timedelta
from core.db import SessionLocal, RequestLog, FlaggedEntity

def calculate_abuse_scores():
    db = SessionLocal()
    
    recent_logs = db.query(RequestLog).filter(RequestLog.timestamp >= datetime.utcnow() - timedelta(hours=24)).all()
    
    ip_stats = {}
    for log in recent_logs:
        ip = log.ip_address
        if ip not in ip_stats:
            ip_stats[ip] = {'total': 0, 'errors': 0, 'endpoints': set()}
        
        ip_stats[ip]['total'] += 1
        if log.status_code >= 400:
            ip_stats[ip]['errors'] += 1
        ip_stats[ip]['endpoints'].add(log.endpoint)
        
    for ip, stats in ip_stats.items():
        score = 0
        reasons = []
        
        error_rate = stats['errors'] / stats['total']
        if error_rate > 0.5 and stats['total'] > 10:
            score += 50
            reasons.append("High Error Rate (Credential Stuffing)")
            
        if len(stats['endpoints']) >= 3 and stats['total'] > 20:
            score += 40
            reasons.append("Multi-endpoint Scraping")
            
        if stats['total'] > 100:
            score += 20
            reasons.append("High Volume Burst")
            
        score = min(score, 100)
        
        if score > 0:
            tier = "Low"
            if score > 80: tier = "Critical"
            elif score > 50: tier = "High"
            elif score > 20: tier = "Medium"
            
            existing = db.query(FlaggedEntity).filter(FlaggedEntity.entity_value == ip).first()
            if existing:
                existing.abuse_score = score
                existing.risk_tier = tier
                existing.reason = " | ".join(reasons)
                existing.last_seen = datetime.utcnow()
            else:
                flag = FlaggedEntity(
                    entity_type="ip",
                    entity_value=ip,
                    abuse_score=score,
                    risk_tier=tier,
                    reason=" | ".join(reasons)
                )
                db.add(flag)
                
    db.commit()
    db.close()
