import pandas as pd
from core.db import engine

def get_kpi_metrics():
    df = pd.read_sql("SELECT COUNT(*) as total, AVG(response_time_ms) as avg_resp FROM requests", engine)
    blocked = pd.read_sql("SELECT COUNT(*) as total FROM requests WHERE decision = 'blocked'", engine)
    
    total = df['total'][0] if not pd.isna(df['total'][0]) else 0
    blocked_count = blocked['total'][0] if not pd.isna(blocked['total'][0]) else 0
    
    try:
        active = pd.read_sql("SELECT COUNT(*) as total FROM flagged_entities WHERE abuse_score > 50", engine)['total'][0]
    except:
        active = 0
        
    return {
        "total_requests": total,
        "blocked_pct": (blocked_count / total * 100) if total > 0 else 0,
        "avg_response_time": df['avg_resp'][0] if not pd.isna(df['avg_resp'][0]) else 0,
        "active_threats": active
    }

def get_traffic_time_series():
    query = """
    SELECT strftime('%Y-%m-%d %H:%M', timestamp) as minute, decision, COUNT(*) as count
    FROM requests
    GROUP BY minute, decision
    ORDER BY minute
    """
    return pd.read_sql(query, engine)

def get_flagged_entities():
    return pd.read_sql("SELECT * FROM flagged_entities ORDER BY abuse_score DESC", engine)

def get_logs(limit=1000):
    return pd.read_sql(f"SELECT timestamp, ip_address, api_key, endpoint, method, status_code, response_time_ms, decision FROM requests ORDER BY timestamp DESC LIMIT {limit}", engine)

def get_settings():
    try:
        return pd.read_sql("SELECT * FROM rules_config WHERE is_active=1", engine)
    except:
        return pd.DataFrame()
