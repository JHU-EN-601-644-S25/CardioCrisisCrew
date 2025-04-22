import sqlite3
import json

DB_NAME = ‘sensor_data.db’

def create_db():
    conn = sqlite3.connect('sensor_data.db')
    c = conn.cursor()
    c.execute('''
        CREATE TABLE IF NOT EXISTS sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
            data TEXT
        )
    ''')
    conn.commit()
    conn.close()


def save_data_session(sensor_data):
    conn = sqlite3.connect('sensor_data.db')
    c = conn.cursor()
    json_data = json.dumps(sensor_data)  #convert list of ints to JSON string
    c.execute('INSERT INTO sessions (data) VALUES (?)', (json_data,))
    conn.commit()
    conn.close()


def get_latest_session():
    conn = sqlite3.connect('sensor_data.db')
    c = conn.cursor()
    c.execute('SELECT data FROM sessions ORDER BY timestamp DESC LIMIT 1')
    row = c.fetchone()
    conn.close()
    if row:
        return json.loads(row[0])  #JSON string back to list of ints hopefully
    else:
        return None
