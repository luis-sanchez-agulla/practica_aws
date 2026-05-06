from flask import Flask, jsonify, render_template
import psycopg2
import os

app = Flask(__name__)

def get_db():
    return psycopg2.connect(
        host=os.environ.get('DB_HOST', '10.20.2.45'),
        database=os.environ.get('DB_NAME', 'universidad'),
        user=os.environ.get('DB_USER', 'app_user'),
        password=os.environ.get('DB_PASS', 'app_password')
    )

@app.route('/health', strict_slashes=False)
def health():
    return jsonify({"status": "ok"})

@app.route('/profesores', strict_slashes=False)
def profesores():
    try:
        conn = get_db()
        cur = conn.cursor()
        cur.execute("SELECT * FROM profesores;")
        rows = cur.fetchall()
        cols = [desc[0] for desc in cur.description]
        return jsonify([dict(zip(cols, row)) for row in rows])
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/', strict_slashes=False)
@app.route('/profesores/index', strict_slashes=False)
def index():
    return render_template('index.html')

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
