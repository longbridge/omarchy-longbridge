import importlib.machinery
import importlib.util
import io
import json
from pathlib import Path
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "longbridge-quotes"
FIXTURE = (ROOT / "tests/fixtures/yahoo_chart.json").read_bytes()


def load_helper():
    loader = importlib.machinery.SourceFileLoader("longbridge_quotes", str(HELPER))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


class Response:
    def __init__(self, body):
        self.body = body

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return False

    def read(self):
        return self.body


class HelperPresenceTest(unittest.TestCase):
    def test_helper_exists(self):
        self.assertTrue(HELPER.exists(), "public quote helper is missing")


@unittest.skipUnless(HELPER.exists(), "public quote helper is missing")
class LongbridgeQuotesTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.module = load_helper()

    def test_maps_supported_longbridge_symbols(self):
        cases = {
            "AAPL.US": "AAPL",
            "BRK-B.US": "BRK-B",
            "700.HK": "0700.HK",
            "D05.SG": "D05.SI",
            "600519.SH": "600519.SS",
            "000001.SZ": "000001.SZ",
        }
        for canonical, provider in cases.items():
            with self.subTest(canonical=canonical):
                self.assertEqual(self.module.provider_symbol(canonical), provider)

    def test_rejects_unknown_or_malformed_symbols(self):
        for symbol in ["", "AAPL", "AAPL.CA", "../AAPL.US", "12345.HK"]:
            with self.subTest(symbol=symbol):
                with self.assertRaises(ValueError):
                    self.module.provider_symbol(symbol)

    def test_parses_chart_fixture_as_decimal_strings(self):
        quote = self.module.parse_chart("AAPL.US", json.loads(FIXTURE))
        self.assertEqual(quote["symbol"], "AAPL.US")
        self.assertEqual(quote["name"], "Apple Inc.")
        self.assertEqual(quote["last"], "232.18")
        self.assertEqual(quote["prev_close"], "230.0")
        self.assertEqual(quote["volume"], "1234567")
        self.assertEqual(quote["trade_status"], "REGULAR")

    def test_main_emits_partial_result_without_losing_success(self):
        def opener(request, timeout):
            self.assertEqual(timeout, 10)
            if "BAD" in request.full_url:
                raise OSError("private upstream detail")
            return Response(FIXTURE)

        stdout = io.StringIO()
        stderr = io.StringIO()
        with patch("sys.stdout", stdout), patch("sys.stderr", stderr):
            result = self.module.main(
                ["AAPL.US", "BAD.US"], opener=opener, now_ms=lambda: 1000
            )

        payload = json.loads(stdout.getvalue())
        self.assertEqual(result, 0)
        self.assertEqual(payload["state"], "partial")
        self.assertEqual(payload["fetched_at_ms"], 1000)
        self.assertEqual(payload["quotes"][0]["symbol"], "AAPL.US")
        self.assertEqual(payload["errors"], [{
            "symbol": "BAD.US",
            "code": "network_error",
            "message": "Quote unavailable."
        }])
        self.assertNotIn("private upstream detail", stderr.getvalue())

    def test_main_returns_error_when_every_symbol_fails(self):
        def opener(_request, _timeout):
            raise TimeoutError("secret diagnostic")

        stdout = io.StringIO()
        with patch("sys.stdout", stdout), patch("sys.stderr", io.StringIO()):
            result = self.module.main(["BAD.US"], opener=opener, now_ms=lambda: 2000)

        payload = json.loads(stdout.getvalue())
        self.assertEqual(result, 1)
        self.assertEqual(payload["state"], "error")
        self.assertEqual(payload["quotes"], [])


if __name__ == "__main__":
    unittest.main()
