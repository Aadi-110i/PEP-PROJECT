import mysql.connector
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import warnings

class APIAbuseDetector:
    def __init__(self, host="localhost", user="root", password="", database="api_abuse_db"):
        self.host = host
        self.user = user
        self.password = password
        self.database = database
        
        # Connect to MySQL server first to create the database if it doesn't exist
        temp_conn = mysql.connector.connect(
            host=self.host,
            user=self.user,
            password=self.password
        )
        temp_cursor = temp_conn.cursor()
        temp_cursor.execute(f"CREATE DATABASE IF NOT EXISTS {self.database}")
        temp_conn.close()

        # Now connect specifically to that database
        self.conn = mysql.connector.connect(
            host=self.host,
            user=self.user,
            password=self.password,
            database=self.database
        )
        self.setup_database()
        
    def setup_database(self):
        """Creates the necessary tables in MySQL if they don't exist."""
        cursor = self.conn.cursor()
        
        # 1. Base tables (Note: AUTOINCREMENT is AUTO_INCREMENT in MySQL)
        cursor.execute('''
        CREATE TABLE IF NOT EXISTS clients (
            client_id INT PRIMARY KEY AUTO_INCREMENT,
            client_name VARCHAR(255) NOT NULL,
            plan_type VARCHAR(255) NOT NULL
        )
        ''')

        cursor.execute('''
        CREATE TABLE IF NOT EXISTS endpoints (
            endpoint_id INT PRIMARY KEY AUTO_INCREMENT,
            path VARCHAR(255) NOT NULL,
            method VARCHAR(10) NOT NULL
        )
        ''')

        cursor.execute('''
        CREATE TABLE IF NOT EXISTS request_logs (
            log_id INT PRIMARY KEY AUTO_INCREMENT,
            client_id INT,
            endpoint_id INT,
            status_code INT,
            request_time DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY(client_id) REFERENCES clients(client_id),
            FOREIGN KEY(endpoint_id) REFERENCES endpoints(endpoint_id)
        )
        ''')
        
        # 2. Action Taking table
        cursor.execute('''
        CREATE TABLE IF NOT EXISTS banned_clients (
            ban_id INT PRIMARY KEY AUTO_INCREMENT,
            client_id INT UNIQUE,
            reason TEXT,
            banned_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY(client_id) REFERENCES clients(client_id)
        )
        ''')
        self.conn.commit()
        
    def generate_seed_data(self):
        """Seeds the database with fake traffic for testing."""
        cursor = self.conn.cursor()
        
        # Insert clients and endpoints (INSERT OR IGNORE becomes INSERT IGNORE in MySQL)
        cursor.execute('''
        INSERT IGNORE INTO clients (client_id, client_name, plan_type) VALUES 
            (1, 'Normal User', 'basic'),
            (2, 'Spam Bot', 'free'),
            (3, 'Scraper', 'premium')
        ''')

        cursor.execute('''
        INSERT IGNORE INTO endpoints (endpoint_id, path, method) VALUES 
            (1, '/api/v1/login', 'POST'),
            (2, '/api/v1/data', 'GET')
        ''')
        
        # Clear existing logs/bans so we get fresh data every time we run the script
        cursor.execute("DELETE FROM request_logs")
        cursor.execute("DELETE FROM banned_clients")

        base_time = datetime.now() - timedelta(days=1)
        
        # Normal user: 50 requests over the last 24 hours
        normal_times = base_time + pd.to_timedelta(np.random.randint(1, 1440, size=50), unit='m')
        normal_logs = [(1, 2, 200, t.strftime('%Y-%m-%d %H:%M:%S')) for t in normal_times]
        
        # Spam Bot: 500 requests in a tight timeframe
        spam_times = base_time + pd.to_timedelta(np.random.randint(1, 60, size=500), unit='m')
        spam_logs = [(2, 1, 401, t.strftime('%Y-%m-%d %H:%M:%S')) for t in spam_times]
        
        # Scraper: 2000 requests over the last 24 hours
        scraper_times = base_time + pd.to_timedelta(np.random.randint(1, 1440, size=2000), unit='m')
        scraper_logs = [(3, 2, 200, t.strftime('%Y-%m-%d %H:%M:%S')) for t in scraper_times]
        
        all_logs = normal_logs + spam_logs + scraper_logs
        
        # MySQL uses %s for parameterized queries instead of ?
        cursor.executemany(
            'INSERT INTO request_logs (client_id, endpoint_id, status_code, request_time) VALUES (%s, %s, %s, %s)',
            all_logs
        )
        self.conn.commit()
        print("Sample data successfully generated and inserted!")

    def analyze_traffic(self):
        """Analyzes logs using SQL and Pandas to find RPM and error rates."""
        print("\n--- Analytics ---")
        
        # MySQL syntax update: strftime becomes DATE_FORMAT
        query = '''
        WITH ClientStats AS (
            SELECT 
                client_id,
                COUNT(log_id) as total_requests,
                SUM(CASE WHEN status_code >= 400 THEN 1 ELSE 0 END) as error_count
            FROM request_logs
            GROUP BY client_id
        ),
        RequestsPerMinute AS (
            SELECT 
                client_id,
                DATE_FORMAT(request_time, '%Y-%m-%d %H:%i') as minute,
                COUNT(log_id) as requests_in_minute
            FROM request_logs
            GROUP BY client_id, minute
        ),
        MaxRequestsPerMinute AS (
            SELECT 
                client_id,
                MAX(requests_in_minute) as peak_rpm
            FROM RequestsPerMinute
            GROUP BY client_id
        )
        SELECT 
            c.client_id,
            c.client_name,
            s.total_requests,
            s.error_count,
            m.peak_rpm
        FROM clients c
        JOIN ClientStats s ON c.client_id = s.client_id
        JOIN MaxRequestsPerMinute m ON c.client_id = m.client_id
        '''
        
        # Ignore warning from Pandas about passing a DBAPI connection directly
        with warnings.catch_warnings():
            warnings.simplefilter('ignore')
            df = pd.read_sql_query(query, self.conn)
        
        # Calculate error rate safely
        df['error_rate'] = np.where(df['total_requests'] > 0, df['error_count'] / df['total_requests'], 0)
        
        # Display analytics cleanly
        display_df = df[['client_name', 'total_requests', 'error_count', 'error_rate', 'peak_rpm']]
        print(display_df.to_string(index=False))
        return df
        
    def detect_and_ban_abusers(self, df, rpm_threshold=50, error_rate_threshold=0.5):
        """Flags abusers based on thresholds and bans them."""
        print("\n--- Abuse Detection & Action Taking ---")
        
        # Find abusers
        abusers = df[(df['peak_rpm'] > rpm_threshold) | (df['error_rate'] > error_rate_threshold)].copy()
        
        if abusers.empty:
            print("No abusers detected based on current thresholds.")
            return

        print("Flagged Abusers:")
        
        cursor = self.conn.cursor()
        
        for index, row in abusers.iterrows():
            reasons = []
            if row['peak_rpm'] > rpm_threshold:
                reasons.append(f"High RPM ({row['peak_rpm']} > {rpm_threshold})")
            if row['error_rate'] > error_rate_threshold:
                reasons.append(f"High Error Rate ({row['error_rate']:.2f} > {error_rate_threshold})")
            
            ban_reason = " & ".join(reasons)
            print(f"- {row['client_name']} banned for: {ban_reason}")
            
            # Action Taking: Insert into banned_clients table
            cursor.execute('''
                INSERT IGNORE INTO banned_clients (client_id, reason)
                VALUES (%s, %s)
            ''', (row['client_id'], ban_reason))
            
        self.conn.commit()
        print("\nBanned clients successfully recorded in the database table 'banned_clients'.")
        
    def close(self):
        self.conn.close()

if __name__ == '__main__':
    # =========================================================================
    # IMPORTANT: Update these with your local MySQL credentials!
    # =========================================================================
    detector = APIAbuseDetector(
        host="localhost",
        user="root",          # Your MySQL Username
        password="Aadi1829!!",          # Your MySQL Password
        database="api_abuse_rate_limiting_db"
    )
    
    print("Setting up the database and generating data...")
    detector.generate_seed_data()
    
    # Run analytics
    analytics_df = detector.analyze_traffic()
    
    # Run detection (flags users exceeding 60 requests/minute OR 50% error rate)
    detector.detect_and_ban_abusers(analytics_df, rpm_threshold=60, error_rate_threshold=0.5)
    
    detector.close()
