import sqlite3
import json
import os
from cryptography.fernet import Fernet
from pathlib import Path
import base64

DB_NAME = 'sensor_data.db'
key = os.environ.get("SENSOR_DB_KEY")
fernet = Fernet(key)

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
    encrypted_data = fernet.encrypt(json_data.encode())
    encrypted_b64 = base64.urlsafe_b64encode(encrypted_data).decode()
    c.execute('INSERT INTO sessions (data) VALUES (?)', (encrypted_b64,))
    conn.commit()
    conn.close()


def get_latest_session():
    conn = sqlite3.connect('sensor_data.db')
    c = conn.cursor()
    c.execute('SELECT data FROM sessions ORDER BY timestamp DESC LIMIT 1')
    row = c.fetchone()
    conn.close()
    if row:
        encrypted_data = base64.urlsafe_b64decode(row[0])
        decrypted_data = fernet.decrypt(encrypted_data).decode()
        return json.loads(decrypted_data)  #JSON string back to list of ints hopefully
    else:
        return None
