from flask import Flask, render_template, jsonify, request
import pandas as pd
from core.db import init_db
from core.queries import get_kpi_metrics, get_traffic_time_series, get_flagged_entities, get_logs, get_settings

app = Flask(__name__)

# Initialize DB on startup
init_db()

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/api/kpis')
def api_kpis():
    metrics = get_kpi_metrics()
    safe_metrics = {}
    for k, v in metrics.items():
        if pd.isna(v): safe_metrics[k] = 0
        elif hasattr(v, 'item'): safe_metrics[k] = v.item()
        else: safe_metrics[k] = v
    return jsonify(safe_metrics)

@app.route('/api/traffic')
def api_traffic():
    df = get_traffic_time_series()
    return jsonify(df.to_dict(orient='records'))

@app.route('/api/flagged')
def api_flagged():
    df = get_flagged_entities()
    return jsonify(df.to_dict(orient='records'))

@app.route('/api/logs')
def api_logs():
    df = get_logs()
    return jsonify(df.to_dict(orient='records'))

@app.route('/api/settings', methods=['GET', 'POST'])
def api_settings():
    from core.db import SessionLocal, RulesConfig
    if request.method == 'GET':
        df = get_settings()
        return jsonify(df.to_dict(orient='records'))
    else:
        data = request.json
        db = SessionLocal()
        rule = db.query(RulesConfig).filter(RulesConfig.is_active == True).first()
        if not rule:
            rule = RulesConfig(rule_name="Default IP Limit", threshold_value=int(data.get('rpm', 60)), window_seconds=60)
            db.add(rule)
        else:
            rule.threshold_value = int(data.get('rpm', 60))
        db.commit()
        db.close()
        return jsonify({"status": "success"})

@app.route('/api/export')
def api_export():
    from flask import Response
    from core.queries import get_logs
    df = get_logs(limit=10000)
    return Response(
        df.to_csv(index=False),
        mimetype="text/csv",
        headers={"Content-disposition": "attachment; filename=traffic_logs.csv"}
    )

@app.route('/api/clear', methods=['POST'])
def api_clear():
    from core.db import SessionLocal, RequestLog, RateLimitEvent, FlaggedEntity
    db = SessionLocal()
    db.query(RequestLog).delete()
    db.query(RateLimitEvent).delete()
    db.query(FlaggedEntity).delete()
    db.commit()
    db.close()
    return jsonify({"status": "success"})

@app.route('/api/seed', methods=['POST'])
def api_seed():
    from core.log_generator import generate_synthetic_logs
    from core.rate_limiter import apply_rate_limits
    from core.abuse_scoring import calculate_abuse_scores
    
    generate_synthetic_logs(num_requests=500, inject_abuse=True)
    apply_rate_limits()
    calculate_abuse_scores()
    return jsonify({"status": "success"})

if __name__ == '__main__':
    app.run(debug=True, port=5000)
