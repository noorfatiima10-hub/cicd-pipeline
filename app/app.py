from flask import Flask, jsonify
import os
import time

app = Flask(__name__)
START_TIME = time.time()

@app.route("/")
def home():
    return jsonify({
        "message": "Hello from CI/CD Pipeline Demo App",
        "version": os.getenv("APP_VERSION", "1.0.0"),
        "status": "running"
    })

@app.route("/health")
def health():
    """
    Health check endpoint for zero-downtime rolling updates.
    Returns 200 OK when the app is ready to serve traffic.
    """
    uptime = round(time.time() - START_TIME, 2)
    return jsonify({
        "status": "healthy",
        "uptime_seconds": uptime,
        "version": os.getenv("APP_VERSION", "1.0.0")
    }), 200

@app.route("/ready")
def ready():
    """Readiness probe — confirms app has fully initialized."""
    return jsonify({"ready": True}), 200

if __name__ == "__main__":
    port = int(os.getenv("PORT", 5000))
    app.run(host="0.0.0.0", port=port)
