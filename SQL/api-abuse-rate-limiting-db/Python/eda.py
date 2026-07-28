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
        return df_clients, df_requests, df_violations, df_blocks
    except Exception as e:
        print(f"Error loading cleaned data: {e}")
        return None, None, None, None

def perform_eda(df_clients, df_requests, df_violations, df_blocks):
    print("="*50)
    print("EXPLORATORY DATA ANALYSIS (EDA)")
    print("="*50)
    
    # Shape & Dtypes
    print("\n--- SHAPES ---")
    print(f"Clients: {df_clients.shape}")
    print(f"Requests: {df_requests.shape}")
    print(f"Violations: {df_violations.shape}")
    print(f"Blocks: {df_blocks.shape}")
    
    print("\n--- REQUESTS MISSING VALUES ---")
    print(df_requests.isnull().sum())
    
    # Value Counts
    print("\n--- ENDPOINT DISTRIBUTION ---")
    print(df_requests['endpoint'].value_counts().head(10))
    
    print("\n--- STATUS CODE DISTRIBUTION ---")
    print(df_requests['status_code'].value_counts())
    
    print("\n--- VIOLATION TYPE DISTRIBUTION ---")
    if 'violation_type' in df_violations.columns:
        print(df_violations['violation_type'].value_counts())
    
    print("\n--- ACTION TAKEN DISTRIBUTION ---")
    if 'action_taken' in df_violations.columns:
        print(df_violations['action_taken'].value_counts())
    
    # Describe numericals
    print("\n--- REQUESTS NUMERICAL DESCRIBE ---")
    cols_to_describe = ['response_time_ms', 'requests_per_min_window']
    avail_cols = [c for c in cols_to_describe if c in df_requests.columns]
    print(df_requests[avail_cols].describe())
    
    print("\nEDA complete. Review the outputs above for data anomalies.")

def main():
    df_clients, df_requests, df_violations, df_blocks = load_cleaned_data()
    if df_clients is not None:
        perform_eda(df_clients, df_requests, df_violations, df_blocks)

if __name__ == '__main__':
    main()
