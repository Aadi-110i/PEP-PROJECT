import os
import mysql.connector
from mysql.connector import Error
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

def get_connection():
    """
    Establishes a connection to the MySQL database using environment variables.
    Returns the connection object if successful, None otherwise.
    """
    try:
        connection = mysql.connector.connect(
            host=os.getenv('DB_HOST', 'localhost'),
            user=os.getenv('DB_USER', 'root'),
            password=os.getenv('DB_PASSWORD', ''),
            database=os.getenv('DB_NAME', 'api_abuse_rate_limiting_db'),
            port=os.getenv('DB_PORT', '3306')
        )
        if connection.is_connected():
            print("Successfully connected to the database")
            return connection
    except Error as e:
        print(f"Error while connecting to MySQL: {e}")
        return None

if __name__ == '__main__':
    # Test connection when run directly
    conn = get_connection()
    if conn:
        conn.close()
