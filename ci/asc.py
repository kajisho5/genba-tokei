#!/usr/bin/env python3
"""App Store Connect API の小さな道具（Python 標準ライブラリ＋openssl のみ）。

使い方（GitHub Actions から呼ぶ）:
  python3 ci/asc.py prepare   … Bundle ID を登録（無ければ）し、チーム ID を出力
  python3 ci/asc.py testers   … TestFlight の社内テスト用グループを作り、アカウントの全員を追加

必要な環境変数:
  ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH（.p8 のファイルパス）, BUNDLE_ID
"""
from __future__ import annotations

import base64
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

API = "https://api.appstoreconnect.apple.com"
GROUP_NAME = "現場時計 社内テスト"


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def der_to_raw_signature(der: bytes, size: int = 32) -> bytes:
    """openssl が出す DER 形式の ECDSA 署名を、JWT（ES256）用の r||s 64 バイトに変換する。"""
    if len(der) < 8 or der[0] != 0x30:
        raise ValueError("DER 署名ではありません")
    i = 2
    if der[1] & 0x80:  # 長さが長形式（P-256 では通常起きない）
        i = 2 + (der[1] & 0x7F)
    parts = []
    for _ in range(2):
        if der[i] != 0x02:
            raise ValueError("DER 署名の整数がありません")
        length = der[i + 1]
        value = der[i + 2 : i + 2 + length].lstrip(b"\x00")
        if len(value) > size:
            raise ValueError("署名の値が大きすぎます")
        parts.append(value.rjust(size, b"\x00"))
        i += 2 + length
    return parts[0] + parts[1]


def make_token(key_id: str, issuer: str, key_path: str, now: int | None = None) -> str:
    now = int(time.time()) if now is None else now
    header = {"alg": "ES256", "kid": key_id, "typ": "JWT"}
    payload = {"iss": issuer, "iat": now, "exp": now + 15 * 60, "aud": "appstoreconnect-v1"}
    signing_input = f"{b64url(json.dumps(header).encode())}.{b64url(json.dumps(payload).encode())}"
    der = subprocess.run(
        ["openssl", "dgst", "-sha256", "-sign", key_path],
        input=signing_input.encode(), capture_output=True, check=True,
    ).stdout
    return f"{signing_input}.{b64url(der_to_raw_signature(der))}"


class Client:
    def __init__(self, token: str):
        self.token = token

    def call(self, method: str, path: str, body: dict | None = None, query: dict | None = None) -> dict:
        url = API + path + ("?" + urllib.parse.urlencode(query) if query else "")
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(url, data=data, method=method)
        req.add_header("Authorization", f"Bearer {self.token}")
        if data is not None:
            req.add_header("Content-Type", "application/json")
        try:
            with urllib.request.urlopen(req, timeout=60) as res:
                raw = res.read()
                return json.loads(raw) if raw else {}
        except urllib.error.HTTPError as e:
            detail = e.read().decode(errors="replace")
            raise SystemExit(f"App Store Connect API エラー {e.code} {method} {path}\n{detail}") from None


def ensure_bundle_id(c: Client, identifier: str, name: str) -> dict:
    found = c.call("GET", "/v1/bundleIds", query={"filter[identifier]": identifier, "limit": 200})
    for item in found.get("data", []):
        if item["attributes"]["identifier"] == identifier:  # 部分一致を除外
            print(f"Bundle ID は登録済み: {identifier}")
            return item
    created = c.call("POST", "/v1/bundleIds", body={
        "data": {"type": "bundleIds", "attributes": {"identifier": identifier, "name": name, "platform": "IOS"}}
    })
    print(f"Bundle ID を登録しました: {identifier}")
    return created["data"]


def find_app(c: Client, bundle_id: str) -> dict | None:
    apps = c.call("GET", "/v1/apps", query={"filter[bundleId]": bundle_id})
    for app in apps.get("data", []):
        if app["attributes"]["bundleId"] == bundle_id:
            return app
    return None


def write_output(key: str, value: str) -> None:
    path = os.environ.get("GITHUB_OUTPUT")
    if path:
        with open(path, "a", encoding="utf-8") as f:
            f.write(f"{key}={value}\n")


def cmd_prepare(c: Client, bundle_id: str) -> None:
    main = ensure_bundle_id(c, bundle_id, "GenbaTokei")
    ensure_bundle_id(c, bundle_id + ".liveactivity", "GenbaTokei LiveActivity")
    team_id = main["attributes"].get("seedId") or ""
    if not team_id:
        raise SystemExit("チーム ID（seedId）を取得できませんでした")
    print(f"チーム ID: {team_id}")
    write_output("team_id", team_id)
    app = find_app(c, bundle_id)
    write_output("app_exists", "true" if app else "false")
    if not app:
        print(f"::warning::App Store Connect にアプリの枠がまだありません（Bundle ID: {bundle_id}）。"
              "https://appstoreconnect.apple.com/apps の「＋」→「新規 App」で作成してください。")


def cmd_testers(c: Client, bundle_id: str) -> None:
    app = find_app(c, bundle_id)
    if not app:
        raise SystemExit(f"App Store Connect にアプリの枠がありません（Bundle ID: {bundle_id}）")
    groups = c.call("GET", "/v1/betaGroups", query={"filter[app]": app["id"], "filter[isInternalGroup]": "true"})
    group = next((g for g in groups.get("data", []) if g["attributes"]["name"] == GROUP_NAME), None)
    if group is None:
        group = c.call("POST", "/v1/betaGroups", body={"data": {
            "type": "betaGroups",
            "attributes": {"name": GROUP_NAME, "isInternalGroup": True, "hasAccessToAllBuilds": True},
            "relationships": {"app": {"data": {"type": "apps", "id": app["id"]}}},
        }})["data"]
        print(f"社内テストグループを作りました: {GROUP_NAME}")
    else:
        print(f"社内テストグループは作成済み: {GROUP_NAME}")

    members = c.call("GET", f"/v1/betaGroups/{group['id']}/betaTesters", query={"limit": 200})
    member_emails = {m["attributes"].get("email", "").lower() for m in members.get("data", [])}
    users = c.call("GET", "/v1/users", query={"limit": 200}).get("data", [])
    added = 0
    for u in users:
        a = u["attributes"]
        email = (a.get("username") or "").lower()
        if not email or email in member_emails:
            continue
        c.call("POST", "/v1/betaTesters", body={"data": {
            "type": "betaTesters",
            "attributes": {"email": email, "firstName": a.get("firstName"), "lastName": a.get("lastName")},
            "relationships": {"betaGroups": {"data": [{"type": "betaGroups", "id": group["id"]}]}},
        }})
        added += 1
    # メールアドレスはログに出さない
    print(f"テスターを {added} 人追加しました（既存 {len(member_emails)} 人）")


def main() -> None:
    if len(sys.argv) != 2 or sys.argv[1] not in {"prepare", "testers"}:
        raise SystemExit(__doc__)
    env = os.environ
    missing = [k for k in ("ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_KEY_PATH", "BUNDLE_ID") if not env.get(k)]
    if missing:
        raise SystemExit("未設定: " + ", ".join(missing))
    c = Client(make_token(env["ASC_KEY_ID"], env["ASC_ISSUER_ID"], env["ASC_KEY_PATH"]))
    {"prepare": cmd_prepare, "testers": cmd_testers}[sys.argv[1]](c, env["BUNDLE_ID"])


if __name__ == "__main__":
    main()
