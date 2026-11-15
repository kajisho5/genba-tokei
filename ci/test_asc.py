"""ci/asc.py の署名部分の自動テスト（openssl があれば動く）。実行: python3 ci/test_asc.py"""
import base64
import json
import os
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(__file__))
import asc  # noqa: E402


def raw_to_der(raw: bytes) -> bytes:
    def integer(v: bytes) -> bytes:
        v = v.lstrip(b"\x00") or b"\x00"
        if v[0] & 0x80:
            v = b"\x00" + v
        return b"\x02" + bytes([len(v)]) + v
    body = integer(raw[:32]) + integer(raw[32:])
    return b"\x30" + bytes([len(body)]) + body


class TokenTests(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.key = os.path.join(self.dir.name, "AuthKey.p8")
        self.pub = os.path.join(self.dir.name, "pub.pem")
        subprocess.run(["openssl", "genpkey", "-algorithm", "EC", "-pkeyopt", "ec_paramgen_curve:P-256",
                        "-out", self.key], check=True, capture_output=True)
        subprocess.run(["openssl", "pkey", "-in", self.key, "-pubout", "-out", self.pub], check=True, capture_output=True)

    def tearDown(self):
        self.dir.cleanup()

    def test_token_structure_and_signature(self):
        token = asc.make_token("KEYID12345", "issuer-uuid", self.key, now=1_800_000_000)
        h, p, s = token.split(".")
        pad = lambda x: x + "=" * (-len(x) % 4)
        header = json.loads(base64.urlsafe_b64decode(pad(h)))
        payload = json.loads(base64.urlsafe_b64decode(pad(p)))
        self.assertEqual(header, {"alg": "ES256", "kid": "KEYID12345", "typ": "JWT"})
        self.assertEqual(payload["aud"], "appstoreconnect-v1")
        self.assertEqual(payload["exp"] - payload["iat"], 900)
        raw = base64.urlsafe_b64decode(pad(s))
        self.assertEqual(len(raw), 64)
        # 生の r||s を DER に戻して openssl で検証できること
        sig = os.path.join(self.dir.name, "sig.der")
        with open(sig, "wb") as f:
            f.write(raw_to_der(raw))
        r = subprocess.run(["openssl", "dgst", "-sha256", "-verify", self.pub, "-signature", sig],
                           input=f"{h}.{p}".encode(), capture_output=True)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)

    def test_der_with_leading_zero_and_short_values(self):
        r = b"\x80" + b"\x11" * 31          # 先頭ビットが立つ → DER では 0x00 が付く
        s = b"\x00\x00" + b"\x22" * 30      # 先頭が 0 → DER では短くなる
        self.assertEqual(asc.der_to_raw_signature(raw_to_der(r + s)), r + s)

    def test_bad_der_is_rejected(self):
        with self.assertRaises(ValueError):
            asc.der_to_raw_signature(b"\x31\x00")


if __name__ == "__main__":
    unittest.main()
