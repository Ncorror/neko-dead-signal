import http.client
import json
import threading
import unittest

from control_api import Handler
from http.server import ThreadingHTTPServer


class HealthTests(unittest.TestCase):
    def setUp(self):
        self.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=3)

    def fetch(self, path):
        conn = http.client.HTTPConnection("127.0.0.1", self.server.server_port, timeout=3)
        conn.request("GET", path)
        response = conn.getresponse()
        body = response.read()
        conn.close()
        return response.status, json.loads(body)

    def test_health_is_alive_but_not_match_server(self):
        code, payload = self.fetch("/healthz")
        self.assertEqual(200, code)
        self.assertEqual("neko-dead-signal", payload["service"])
        self.assertFalse(payload["match_server"])
        self.assertFalse(payload["online_gameplay"])

    def test_ready_is_unavailable_until_real_game_backend(self):
        code, payload = self.fetch("/readyz")
        self.assertEqual(503, code)
        self.assertFalse(payload["match_server"])


if __name__ == "__main__":
    unittest.main()
