import os
import pandas as pd
import matplotlib.pyplot as plt

def load_cleaned_data():
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    clean_dir = os.path.join(base_dir, 'Data', 'cleaned')
    try:
        df_requests = pd.read_csv(os.path.join(clean_dir, 'requests_cleaned.csv'))
        df_violations = pd.read_csv(os.path.join(clean_dir, 'violations_cleaned.csv'))
        df_blocks = pd.read_csv(os.path.join(clean_dir, 'blocks_cleaned.csv'))
        
        if 'request_time' in df_requests.columns:
            df_requests['request_time'] = pd.to_datetime(df_requests['request_time'])
        if 'violation_time' in df_violations.columns:
            df_violations['violation_time'] = pd.to_datetime(df_violations['violation_time'])
        if 'unblocked_at' in df_blocks.columns:
            df_blocks['unblocked_at'] = pd.to_datetime(df_blocks['unblocked_at'])
        if 'blocked_at' in df_blocks.columns:
            df_blocks['blocked_at'] = pd.to_datetime(df_blocks['blocked_at'])
            
        return df_requests, df_violations, df_blocks
    except Exception as e:
        print(f"Error loading data for visualization: {e}")
        return None, None, None

def generate_charts(df_requests, df_violations, df_blocks):
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    charts_dir = os.path.join(base_dir, 'Output', 'Charts')
    os.makedirs(charts_dir, exist_ok=True)
    
    # 1. Bar chart: Top 10 clients by violation count
    if not df_violations.empty:
        plt.figure(figsize=(10, 6))
        top_violators = df_violations['client_id'].value_counts().head(10)
        top_violators.plot(kind='bar', color='salmon')
        plt.title('Top 10 Clients by Violation Count')
        plt.xlabel('Client ID')
        plt.ylabel('Violations')
        plt.xticks(rotation=45, ha='right')
        plt.tight_layout()
        plt.savefig(os.path.join(charts_dir, 'top_violators.png'))
        plt.close()

    # 2. Line chart: Request volume trend over time (by hour)
    if not df_requests.empty and 'request_time' in df_requests.columns:
        plt.figure(figsize=(12, 6))
        time_trend = df_requests.set_index('request_time').resample('h').size()
        time_trend.plot(kind='line', color='skyblue')
        plt.title('Request Volume Trend (Hourly)')
        plt.xlabel('Time')
        plt.ylabel('Number of Requests')
        plt.tight_layout()
        plt.savefig(os.path.join(charts_dir, 'request_volume_trend.png'))
        plt.close()

    # 3. Bar chart: Violations by hour of day
    if not df_violations.empty and 'violation_time' in df_violations.columns:
        plt.figure(figsize=(10, 6))
        df_violations['hour'] = df_violations['violation_time'].dt.hour
        hourly_violations = df_violations['hour'].value_counts().sort_index()
        hourly_violations.plot(kind='bar', color='orange')
        plt.title('Violations by Hour of Day')
        plt.xlabel('Hour of Day (0-23)')
        plt.ylabel('Violation Count')
        plt.xticks(rotation=0)
        plt.tight_layout()
        plt.savefig(os.path.join(charts_dir, 'violations_by_hour.png'))
        plt.close()

    # 4. Bar chart: Error rate by endpoint
    if not df_requests.empty and 'is_error' in df_requests.columns:
        plt.figure(figsize=(10, 6))
        error_rate = df_requests.groupby('endpoint')['is_error'].mean() * 100
        error_rate.sort_values(ascending=False).plot(kind='bar', color='crimson')
        plt.title('Error Rate by Endpoint (%)')
        plt.xlabel('Endpoint')
        plt.ylabel('Error Rate (%)')
        plt.xticks(rotation=45, ha='right')
        plt.tight_layout()
        plt.savefig(os.path.join(charts_dir, 'error_rate_by_endpoint.png'))
        plt.close()

    # 5. Pie chart: Action taken breakdown
    if not df_violations.empty and 'action_taken' in df_violations.columns:
        plt.figure(figsize=(8, 8))
        actions = df_violations['action_taken'].value_counts()
        if not actions.empty:
            actions.plot(kind='pie', autopct='%1.1f%%', colors=['#ff9999','#66b3ff','#99ff99', '#ffcc99'])
            plt.title('Action Taken Breakdown')
            plt.ylabel('')
            plt.tight_layout()
            plt.savefig(os.path.join(charts_dir, 'action_taken_breakdown.png'))
        plt.close()

    # 6. Histogram: Time-to-reblock for repeat offenders
    if not df_blocks.empty:
        plt.figure(figsize=(10, 6))
        df_blocks_sorted = df_blocks.sort_values(by=['client_id', 'blocked_at'])
        df_blocks_sorted['prev_unblocked_at'] = df_blocks_sorted.groupby('client_id')['unblocked_at'].shift(1)
        df_blocks_sorted['time_to_reblock_hrs'] = (df_blocks_sorted['blocked_at'] - df_blocks_sorted['prev_unblocked_at']).dt.total_seconds() / 3600.0
        reblock_times = df_blocks_sorted['time_to_reblock_hrs'].dropna()
        
        if not reblock_times.empty:
            reblock_times.plot(kind='hist', bins=20, color='purple', edgecolor='black')
            plt.title('Distribution of Time-to-Reblock for Repeat Offenders')
            plt.xlabel('Time (Hours)')
            plt.ylabel('Frequency')
        else:
            plt.text(0.5, 0.5, 'No Repeat Offender Data', ha='center', va='center')
            plt.title('Distribution of Time-to-Reblock (No Data)')
        
        plt.tight_layout()
        plt.savefig(os.path.join(charts_dir, 'time_to_reblock_hist.png'))
        plt.close()

    print("Charts generated and saved to Output/Charts/")

def main():
    df_requests, df_violations, df_blocks = load_cleaned_data()
    if df_requests is not None:
        try:
            generate_charts(df_requests, df_violations, df_blocks)
        except Exception as e:
            print(f"Error generating charts: {e}")

if __name__ == '__main__':
    main()
