from flask import Flask, jsonify
import socket
import os
import datetime

app = Flask(__name__)

@app.route("/")
def index():
    hostname = socket.gethostname()
    return f"""
    <html>
    <head><title>DevOps Assignment</title></head>
    <body style="font-family:sans-serif;max-width:600px;margin:50px auto;padding:20px">
        <h1>Hello from {hostname}!</h1>
        <p><b>AWS DevOps Assignment v2</b> — Flask app running on EC2 behind ALB + ASG</p>
        <hr>
        <p>Instance: <code>{hostname}</code></p>
        <p>Time: <code>{datetime.datetime.utcnow().isoformat()} UTC</code></p>
        <p>Version: <code>{os.environ.get('APP_VERSION', 'local')}</code></p>
    </body>
    </html>
    """

@app.route("/health")
def health():
    return jsonify({"status": "ok"}), 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
