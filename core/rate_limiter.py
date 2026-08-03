from datetime import timedelta
from core.db import SessionLocal, RequestLog, RateLimitEvent, RulesConfig

def get_active_rules(db):
    rules = db.query(RulesConfig).filter(RulesConfig.is_active == True).all()
    if not rules:
        # Create default rule
        rule = RulesConfig(rule_name="Default IP Limit", threshold_value=60, window_seconds=60)
        db.add(rule)
        db.commit()
        return [rule]
    return rules

def apply_rate_limits():
    db = SessionLocal()
    rules = get_active_rules(db)
    
    # Simple simulation of Fixed Window for demonstration
    logs = db.query(RequestLog).filter(RequestLog.decision == 'allowed').order_by(RequestLog.timestamp).all()
    
    window_state = {}
    
    for log in logs:
        for rule in rules:
            key = f"{log.ip_address}_{rule.id}"
            
            # Simple fixed window based on minute
            window_start = log.timestamp.replace(second=0, microsecond=0)
            
            if key not in window_state or window_state[key]['window_start'] != window_start:
                window_state[key] = {'window_start': window_start, 'count': 0}
                
            window_state[key]['count'] += 1
            
            if window_state[key]['count'] > rule.threshold_value:
                log.decision = 'blocked'
                
                event = RateLimitEvent(
                    request_id=log.id,
                    algorithm="Fixed Window",
                    window_start=window_start,
                    window_end=window_start + timedelta(seconds=rule.window_seconds),
                    request_count=window_state[key]['count'],
                    threshold=rule.threshold_value,
                    action='blocked'
                )
                db.add(event)
                break # Blocked by at least one rule
                
    db.commit()
    db.close()
