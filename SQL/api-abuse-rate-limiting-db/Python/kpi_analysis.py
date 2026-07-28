import os
import pandas as pd

def load_cleaned_data():
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    clean_dir = os.path.join(base_dir, 'Data', 'cleaned')
    
    try:
        df_clients = pd.read_csv(os.path.join(clean_dir, 'clients_cleaned.csv'))
        df_requests = pd.read_csv(os.path.join(clean_dir, 'requests_cleaned.csv'))
        df_violations = pd.read_csv(os.path.join(clean_dir, 'violations_cleaned.csv'))
        df_blocks = pd.read_csv(os.path.join(clean_dir, 'blocks_cleaned.csv'))
        
        # Restore datetime types
        if 'request_time' in df_requests.columns:
            df_requests['request_time'] = pd.to_datetime(df_requests['request_time'])
        if 'violation_time' in df_violations.columns:
            df_violations['violation_time'] = pd.to_datetime(df_violations['violation_time'])
        if 'unblocked_at' in df_blocks.columns:
            df_blocks['unblocked_at'] = pd.to_datetime(df_blocks['unblocked_at'])
        if 'blocked_at' in df_blocks.columns:
            df_blocks['blocked_at'] = pd.to_datetime(df_blocks['blocked_at'])
            
        return df_clients, df_requests, df_violations, df_blocks
    except Exception as e:
        print(f"Error loading cleaned data for KPI calculation: {e}")
        return None, None, None, None

def calculate_kpis(df_clients, df_requests, df_violations, df_blocks):
    kpis = {}
    
    # 1. Total requests & Top 10 clients by volume
    total_requests = len(df_requests)
    kpis['Total Requests'] = total_requests
    top_10_volume = df_requests['client_id'].value_counts().head(10).to_dict()
    kpis['Top 10 Clients by Volume'] = top_10_volume
    
    # 2. Violation rate
    total_violations = len(df_violations)
    kpis['Violation Rate (%)'] = (total_violations / total_requests) * 100 if total_requests > 0 else 0
    
    # 3. Block rate
    distinct_clients = df_clients['client_id'].nunique()
    blocked_clients = df_blocks['client_id'].nunique()
    kpis['Block Rate (%)'] = (blocked_clients / distinct_clients) * 100 if distinct_clients > 0 else 0
    
    # 4. Top offenders
    top_offenders = df_violations['client_id'].value_counts().head(10).to_dict()
    kpis['Top Offenders (Violation Count)'] = top_offenders
    
    # 5. Error rate by endpoint
    if 'is_error' in df_requests.columns:
        error_by_endpoint = df_requests.groupby('endpoint')['is_error'].mean() * 100
        kpis['Error Rate by Endpoint (%)'] = error_by_endpoint.to_dict()
    
    # 6. Peak abuse windows
    if 'violation_time' in df_violations.columns and not df_violations.empty:
        peak_windows = df_violations.copy()
        peak_windows['hour_of_day'] = peak_windows['violation_time'].dt.hour
        peak_windows['day_of_week'] = peak_windows['violation_time'].dt.day_name()
        peak_abuse = peak_windows.groupby(['day_of_week', 'hour_of_day']).size().sort_values(ascending=False).head(5).to_dict()
        kpis['Peak Abuse Windows (Day, Hour)'] = peak_abuse
    
    # 7. Repeat offender rate
    if not df_blocks.empty:
        block_counts = df_blocks['client_id'].value_counts()
        repeat_offenders = len(block_counts[block_counts > 1])
        kpis['Repeat Offender Rate (%)'] = (repeat_offenders / blocked_clients) * 100 if blocked_clients > 0 else 0
        
        # 8. Avg time-to-reblock (for repeat offenders)
        df_blocks_sorted = df_blocks.sort_values(by=['client_id', 'blocked_at'])
        df_blocks_sorted['prev_unblocked_at'] = df_blocks_sorted.groupby('client_id')['unblocked_at'].shift(1)
        df_blocks_sorted['time_to_reblock'] = (df_blocks_sorted['blocked_at'] - df_blocks_sorted['prev_unblocked_at']).dt.total_seconds()
        avg_reblock_time = df_blocks_sorted['time_to_reblock'].mean()
        kpis['Avg Time to Reblock (seconds)'] = avg_reblock_time if not pd.isna(avg_reblock_time) else 0
    
    return kpis

def save_kpis(kpis):
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    results_dir = os.path.join(base_dir, 'Output', 'Results')
    os.makedirs(results_dir, exist_ok=True)
    
    # Flatten dict for CSV
    flattened_kpis = []
    for k, v in kpis.items():
        if isinstance(v, dict):
            for sub_k, sub_v in v.items():
                flattened_kpis.append({'KPI': f"{k} - {sub_k}", 'Value': sub_v})
        else:
            flattened_kpis.append({'KPI': k, 'Value': v})
            
    df_kpi = pd.DataFrame(flattened_kpis)
    df_kpi.to_csv(os.path.join(results_dir, 'kpi_summary.csv'), index=False)
    print("KPIs calculated and saved to Output/Results/kpi_summary.csv")

def main():
    df_clients, df_requests, df_violations, df_blocks = load_cleaned_data()
    if df_clients is not None:
        try:
            kpis = calculate_kpis(df_clients, df_requests, df_violations, df_blocks)
            save_kpis(kpis)
        except Exception as e:
            print(f"Error calculating KPIs: {e}")

if __name__ == '__main__':
    main()
