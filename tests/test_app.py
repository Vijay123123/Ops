import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from app.app import app


def test_health():
    client = app.test_client()
    r = client.get("/health")
    assert r.status_code == 200
    assert r.get_json()["status"] == "healthy"
