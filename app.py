from flask import Flask, jsonify
import config

app = Flask(__name__)

@app.route("/")
def index():
    return jsonify(status="ok", service="guardrail-demo")

@app.route("/health")
def health():
    return jsonify(healthy=True, token_configured=bool(config.API_TOKEN))

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
    #main