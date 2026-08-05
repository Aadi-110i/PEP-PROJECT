import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from datetime import datetime

# Import your existing core modules
from core.db import init_db, SessionLocal, RulesConfig
from core.queries import (
    get_kpi_metrics,
    get_traffic_time_series,
    get_flagged_entities,
    get_logs,
    get_settings
)
from core.log_generator import generate_synthetic_logs
from core.rate_limiter import apply_rate_limits
from core.abuse_scoring import calculate_abuse_scores

# Initialize DB on startup
init_db()

# Page config
st.set_page_config(
    page_title="API Abuse Detection Dashboard",
    page_icon="🛡️",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Custom CSS
st.markdown("""
<style>
    .metric-card {
        background-color: #f0f2f6;
        padding: 1rem;
        border-radius: 0.5rem;
        border-left: 4px solid #1f77b4;
    }
    .stAlert > div {
        padding: 0.5rem 1rem;
    }
</style>
""", unsafe_allow_html=True)

# Header
st.title("🛡️ API Abuse Detection Dashboard")
st.markdown("Real-time monitoring of API traffic, rate limiting, and abuse detection")

# Sidebar Controls
with st.sidebar:
    st.header("⚙️ Controls")

    # Data Generation
    st.subheader("Data Management")
    col1, col2 = st.columns(2)
    with col1:
        if st.button("🔄 Generate Data", use_container_width=True, type="primary"):
            with st.spinner("Generating synthetic logs..."):
                generate_synthetic_logs(num_requests=500, inject_abuse=True)
            with st.spinner("Applying rate limits..."):
                apply_rate_limits()
            with st.spinner("Calculating abuse scores..."):
                calculate_abuse_scores()
            st.success("✅ Data generated & processed!")
            st.rerun()

    with col2:
        if st.button("🗑️ Clear DB", use_container_width=True):
            with st.spinner("Clearing database..."):
                db = SessionLocal()
                from core.db import RequestLog, RateLimitEvent, FlaggedEntity
                db.query(RequestLog).delete()
                db.query(RateLimitEvent).delete()
                db.query(FlaggedEntity).delete()
                db.commit()
                db.close()
            st.success("✅ Database cleared!")
            st.rerun()

    # Settings
    st.subheader("Rate Limit Settings")
    db = SessionLocal()
    rule = db.query(RulesConfig).filter(RulesConfig.is_active == True).first()
    current_rpm = rule.threshold_value if rule else 60
    db.close()

    new_rpm = st.number_input(
        "Requests per Minute Threshold",
        min_value=1,
        max_value=1000,
        value=current_rpm,
        step=10
    )

    if st.button("💾 Save Settings", use_container_width=True):
        db = SessionLocal()
        rule = db.query(RulesConfig).filter(RulesConfig.is_active == True).first()
        if not rule:
            rule = RulesConfig(rule_name="Default IP Limit", threshold_value=int(new_rpm), window_seconds=60)
            db.add(rule)
        else:
            rule.threshold_value = int(new_rpm)
        db.commit()
        db.close()
        st.success(f"Threshold updated to {new_rpm} RPM!")
        st.rerun()

    # Export
    st.subheader("Export Data")
    if st.button("📥 Export Logs as CSV", use_container_width=True):
        df = get_logs(limit=10000)
        csv = df.to_csv(index=False)
        st.download_button(
            label="Download CSV",
            data=csv,
            file_name=f"traffic_logs_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv",
            mime="text/csv",
            use_container_width=True
        )

# Main Dashboard
# KPI Metrics Row
metrics = get_kpi_metrics()

col1, col2, col3, col4 = st.columns(4)

def safe_metric(value, default=0):
    if pd.isna(value):
        return default
    elif hasattr(value, 'item'):
        return value.item()
    return value

with col1:
    st.metric(
        label="📊 Total Requests",
        value=f"{safe_metric(metrics.get('total_requests'), 0):,}",
        delta=None
    )

with col2:
    st.metric(
        label="🔴 Blocked %",
        value=f"{safe_metric(metrics.get('blocked_pct'), 0):.1f}%",
        delta=None
    )

with col3:
    st.metric(
        label="⚡ Avg Response (ms)",
        value=f"{safe_metric(metrics.get('avg_response_time'), 0):.0f}",
        delta=None
    )

with col4:
    active = safe_metric(metrics.get('active_threats'), 0)
    st.metric(
        label="🚨 Active Threats",
        value=f"{active:,}",
        delta=None
    )

st.divider()

# Charts Row 1: Traffic Time Series + Flagged Entities
col_left, col_right = st.columns([2, 1])

with col_left:
    st.subheader("📈 Traffic Over Time")
    df_traffic = get_traffic_time_series()

    if not df_traffic.empty:
        # Create time series chart with plotly
        fig = go.Figure()

        # Normal traffic (allowed)
        normal = df_traffic[df_traffic['decision'] == 'allowed']
        if not normal.empty:
            fig.add_trace(go.Scatter(
                x=normal['minute'],
                y=normal['count'],
                mode='lines',
                name='Allowed',
                line=dict(color='#2ca02c', width=2),
                fill='tozeroy',
                fillcolor='rgba(44, 160, 44, 0.1)'
            ))

        # Throttled traffic
        throttled = df_traffic[df_traffic['decision'] == 'throttled']
        if not throttled.empty:
            fig.add_trace(go.Scatter(
                x=throttled['minute'],
                y=throttled['count'],
                mode='lines',
                name='Throttled',
                line=dict(color='#ff7f0e', width=2),
                fill='tozeroy',
                fillcolor='rgba(255, 127, 14, 0.1)'
            ))

        # Blocked traffic
        blocked = df_traffic[df_traffic['decision'] == 'blocked']
        if not blocked.empty:
            fig.add_trace(go.Scatter(
                x=blocked['minute'],
                y=blocked['count'],
                mode='lines',
                name='Blocked',
                line=dict(color='#d62728', width=2),
                fill='tozeroy',
                fillcolor='rgba(214, 39, 40, 0.1)'
            ))

        fig.update_layout(
            height=400,
            hovermode='x unified',
            showlegend=True,
            legend=dict(orientation="h", yanchor="bottom", y=1.02, xanchor="right", x=1),
            margin=dict(l=0, r=0, t=30, b=0),
            xaxis_title="Time",
            yaxis_title="Request Count"
        )
        st.plotly_chart(fig, use_container_width=True)
    else:
        st.info("No traffic data available. Click 'Generate Data' to create sample data.")

with col_right:
    st.subheader("🚩 Flagged Entities")
    df_flagged = get_flagged_entities()

    if not df_flagged.empty:
        # Show as styled dataframe - columns from flagged_entities table
        display_cols = ['entity_value', 'entity_type', 'abuse_score', 'risk_tier', 'reason']
        available_cols = [c for c in display_cols if c in df_flagged.columns]

        if available_cols:
            styled_df = df_flagged[available_cols].head(10).copy()
            if 'abuse_score' in styled_df.columns:
                styled_df['abuse_score'] = styled_df['abuse_score'].apply(lambda x: f"{x:.1f}")

            st.dataframe(
                styled_df,
                use_container_width=True,
                hide_index=True,
                column_config={
                    "entity_value": "IP / API Key",
                    "entity_type": "Type",
                    "abuse_score": "Abuse Score",
                    "risk_tier": "Risk Tier",
                    "reason": "Reason"
                }
            )
    else:
        st.info("No flagged entities yet.")

# Charts Row 2: Request Logs
st.subheader("📋 Recent Request Logs")
df_logs = get_logs(limit=50)

if not df_logs.empty:
    # Add color coding for status
    display_cols = ['timestamp', 'ip_address', 'endpoint', 'method', 'status_code', 'decision']
    available_cols = [c for c in display_cols if c in df_logs.columns]

    if available_cols:
        styled_logs = df_logs[available_cols].copy()

        # Format columns
        if 'timestamp' in styled_logs.columns:
            styled_logs['timestamp'] = pd.to_datetime(styled_logs['timestamp']).dt.strftime('%H:%M:%S')
        if 'decision' in styled_logs.columns:
            styled_logs['decision'] = styled_logs['decision'].apply(
                lambda x: "✅ Allowed" if x == 'allowed' else ("⏱️ Throttled" if x == 'throttled' else "🔴 Blocked")
            )
        if 'status_code' in styled_logs.columns:
            styled_logs['status_code'] = styled_logs['status_code'].astype(str)

        st.dataframe(
            styled_logs,
            use_container_width=True,
            hide_index=True,
            column_config={
                "timestamp": "Time",
                "ip_address": "IP Address",
                "endpoint": "Endpoint",
                "method": "Method",
                "status_code": "Status",
                "decision": "Decision"
            }
        )
else:
    st.info("No request logs available. Click 'Generate Data' to create sample data.")

# Settings Display
with st.expander("⚙️ Current Rate Limit Rules"):
    df_settings = get_settings()
    if not df_settings.empty:
        st.dataframe(df_settings, use_container_width=True, hide_index=True)
    else:
        st.info("No rules configured yet.")

# Auto-refresh
st.markdown("---")
col1, col2, col3 = st.columns([1, 2, 1])
with col2:
    if st.button("🔄 Refresh Dashboard", use_container_width=True):
        st.rerun()

# Footer
st.caption(f"Last updated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} | Data refreshes on button click")