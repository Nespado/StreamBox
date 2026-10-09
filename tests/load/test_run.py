import unittest
from unittest.mock import patch
import run


class LoadTestChecks(unittest.TestCase):
    def test_p95_uses_nearest_rank_not_max_or_average(self):
        self.assertEqual(run.p95(list(range(1, 101))), 95)
        self.assertIsNone(run.p95([]))

    def test_stop_all_http_failures(self):
        self.assertTrue(run.must_stop([{"ok": False}] * 3))
        self.assertTrue(run.must_stop([{"ok": i not in (2, 12)} for i in range(20)]))
        self.assertFalse(run.must_stop([{"ok": i != 2} for i in range(20)]))

    def test_cycles_separate_api_media_and_exclude_failures(self):
        rows = [{"route": "api", "elapsed_ms": 100, "ok": True},
                {"route": "api", "elapsed_ms": 300, "ok": True},
                {"route": "api", "elapsed_ms": 5000, "ok": False},
                {"route": "media", "elapsed_ms": 80, "ok": True}]
        batch = run.cycle_metrics(rows, "test", 5, 1700000000)
        self.assertEqual([s["points"][0]["value"]["doubleValue"] for s in batch], [5, 200, 80])
        self.assertEqual(batch[1]["metric"]["labels"], {"run_id": "test", "route": "api"})
        self.assertEqual(batch[0]["resource"]["type"], "global")

    def test_per_series_timestamps_are_five_seconds_apart(self):
        first = run.series("users", {"run_id": "x"}, 1, 1700000000)
        next_ = run.series("users", {"run_id": "x"}, 1, 1700000005)
        a = run.dt.datetime.fromisoformat(first["points"][0]["interval"]["endTime"])
        b = run.dt.datetime.fromisoformat(next_["points"][0]["interval"]["endTime"])
        self.assertEqual((b - a).total_seconds(), 5)

    def test_request_limit_prevents_network(self):
        load = run.LoadTest()
        load.sent = run.MAX_REQUESTS
        with patch.object(run.urllib.request, "build_opener") as opener:
            load.request("api", 1, 0, 1)
            opener.assert_not_called()
        self.assertTrue(load.stop.is_set())

    def test_deadline_prevents_network(self):
        load = run.LoadTest()
        load.deadline = 0
        with patch.object(run.urllib.request, "build_opener") as opener:
            load.request("api", 1, 0, 1)
            opener.assert_not_called()

    def test_redirects_rejected(self):
        with self.assertRaises(OSError):
            run.NoRedirect().redirect_request(None, None, 302, None, None, "https://other.invalid")


if __name__ == "__main__":
    unittest.main()
