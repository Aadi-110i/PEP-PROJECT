import os
import pandas as pd
from db_connection import get_connection

def load_data(conn):
    """Load data from database into pandas DataFrames via targeted queries."""
    
    # Load clients
    # Adjust column names if your actual schema differs (e.g., plan_name -> tier)
    clients_query = """
    SELECT client_id, tier, created_at 
    FROM clients
    """
    df_clients = pd.read_sql(clients_query, conn)
    
    # Load requests
    requests_query = """
    SELECT request_id, client_id, endpoint, request_time, status_code, response_time_ms, ip_address 
    FROM requests
    """
    df_requests = pd.read_sql(requests_query, conn)
    
    # Load violations
    violations_query = """
    SELECT violation_id, client_id, endpoint, violation_time, violation_type, action_taken 
    FROM violations
    """
    df_violations = pd.read_sql(violations_query, conn)
    
    # Load blocks
    blocks_query = """
    SELECT block_id, client_id, blocked_at, unblocked_at, reason 
    FROM blocks
    """
    df_blocks = pd.read_sql(blocks_query, conn)
    
    return df_clients, df_requests, df_violations, df_blocks

def clean_and_engineer(df_clients, df_requests, df_violations, df_blocks):
    """Clean data, handle missing values, set dtypes, and engineer features."""
    
    # --- Clients Cleaning ---
    df_clients['created_at'] = pd.to_datetime(df_clients['created_at'], errors='coerce')
    df_clients.drop_duplicates(subset=['client_id'], inplace=True)
    
    # --- Requests Cleaning & Feature Engineering ---
    df_requests['request_time'] = pd.to_datetime(df_requests['request_time'], errors='coerce')
    # Fill missing status codes and enforce int type
    df_requests['status_code'] = df_requests['status_code'].fillna(200).astype(int)
    
    # Drop records with missing vital info
    df_requests.dropna(subset=['request_time', 'client_id'], inplace=True)
    
    # Extract temporal features
    df_requests['hour_of_day'] = df_requests['request_time'].dt.hour
    df_requests['day_of_week'] = df_requests['request_time'].dt.day_name()
    
    # Create is_error flag (4xx and 5xx are errors)
    df_requests['is_error'] = df_requests['status_code'] >= 400
    
    # Create is_blocked flag (simplified: whether this client has ever been blocked)
    blocked_clients = set(df_blocks['client_id'].dropna().unique())
    df_requests['is_blocked'] = df_requests['client_id'].isin(blocked_clients)
    
    # Standardize string endpoints
    df_requests['endpoint'] = df_requests['endpoint'].astype(str).str.lower().str.strip()
    
    # Detect bursts: Rolling request count per client per minute
    # First, sort values
    df_requests = df_requests.sort_values(by=['client_id', 'request_time'])
    # Set index to time for rolling window
    df_req_indexed = df_requests.set_index('request_time')
    # Group by client and count rolling requests in a 1-minute window
    rolling_counts = df_req_indexed.groupby('client_id')['request_id'].rolling('1min').count()
    # Reset index to map back
    rolling_counts = rolling_counts.reset_index(name='requests_per_min_window')
    # Merge back to original requests dataframe
    df_requests = pd.merge(
        df_requests, 
        rolling_counts[['client_id', 'request_time', 'requests_per_min_window']], 
        on=['client_id', 'request_time'], 
        how='left'
    )
    
    # --- Violations Cleaning ---
    df_violations['violation_time'] = pd.to_datetime(df_violations['violation_time'], errors='coerce')
    df_violations['violation_type'] = df_violations['violation_type'].astype(str).str.lower().str.strip()
    df_violations['action_taken'] = df_violations['action_taken'].astype(str).str.lower().str.strip()
    df_violations.dropna(subset=['violation_time', 'client_id'], inplace=True)
        
    # --- Blocks Cleaning ---
    df_blocks['blocked_at'] = pd.to_datetime(df_blocks['blocked_at'], errors='coerce')
    df_blocks['unblocked_at'] = pd.to_datetime(df_blocks['unblocked_at'], errors='coerce')
    df_blocks.dropna(subset=['blocked_at', 'client_id'], inplace=True)
    
    return df_clients, df_requests, df_violations, df_blocks

def save_data(df_clients, df_requests, df_violations, df_blocks):
    """Save cleaned DataFrames to CSV files."""
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    clean_dir = os.path.join(base_dir, 'Data', 'cleaned')
    
    os.makedirs(clean_dir, exist_ok=True)
    
    df_clients.to_csv(os.path.join(clean_dir, 'clients_cleaned.csv'), index=False)
    df_requests.to_csv(os.path.join(clean_dir, 'requests_cleaned.csv'), index=False)
    df_violations.to_csv(os.path.join(clean_dir, 'violations_cleaned.csv'), index=False)
    df_blocks.to_csv(os.path.join(clean_dir, 'blocks_cleaned.csv'), index=False)
    print(f"Cleaned data successfully saved to {clean_dir}")

def main():
    conn = get_connection()
    if not conn:
        print("Failed to connect to database. Exiting...")
        return
        
    try:
        print("Loading data from database...")
        df_clients, df_requests, df_violations, df_blocks = load_data(conn)
        
        print("Data loaded. Cleaning and engineering features...")
        df_clients, df_requests, df_violations, df_blocks = clean_and_engineer(
            df_clients, df_requests, df_violations, df_blocks
        )
        
        print("Feature engineering complete. Saving cleaned data...")
        save_data(df_clients, df_requests, df_violations, df_blocks)
        
        print("Phase 3 complete! Cleaned CSVs are in Data/cleaned/")
        
    except Exception as e:
        print(f"An error occurred during data cleaning: {e}")
    finally:
        if conn.is_connected():
            conn.close()

if __name__ == '__main__':
    main()
