#!/usr/bin/env python3
"""
asc-api.py — minimal App Store Connect API helper.

Reads ASC_KEY_PATH, ASC_KEY_ID, ASC_KEY_ISSUER_ID env vars; signs ES256 JWT;
makes a single REST call; prints JSON response or exits non-zero with error.

Usage:
  asc-api.py GET  /v1/bundleIds
  asc-api.py POST /v1/bundleIds   < body.json
  asc-api.py PATCH /v1/apps/<id>  < body.json
  asc-api.py DELETE /v1/bundleIds/<id>

Pipe JSON request bodies on stdin for POST/PATCH.

Requires: pip install cryptography requests pyjwt
"""
import json
import os
import sys
import time

try:
    import jwt
    import requests
except ImportError:
    sys.stderr.write(
        "ERROR: missing deps. Run:\n"
        "  python3 -m pip install --user cryptography requests pyjwt\n"
    )
    sys.exit(1)


def make_jwt() -> str:
    key_path = os.environ.get("ASC_KEY_PATH")
    key_id = os.environ.get("ASC_KEY_ID")
    issuer_id = os.environ.get("ASC_KEY_ISSUER_ID")
    if not (key_path and key_id and issuer_id):
        sys.stderr.write(
            "ERROR: set ASC_KEY_PATH, ASC_KEY_ID, ASC_KEY_ISSUER_ID env vars\n"
        )
        sys.exit(1)
    with open(key_path, "rb") as f:
        private_key = f.read()
    payload = {
        "iss": issuer_id,
        "iat": int(time.time()),
        "exp": int(time.time()) + 1200,  # 20 min
        "aud": "appstoreconnect-v1",
    }
    return jwt.encode(payload, private_key, algorithm="ES256", headers={"kid": key_id})


def main() -> int:
    if len(sys.argv) < 3:
        sys.stderr.write("Usage: asc-api.py {GET|POST|PATCH|DELETE} /v1/...\n")
        return 1
    method = sys.argv[1].upper()
    path = sys.argv[2]
    if not path.startswith("/"):
        sys.stderr.write("ERROR: path must start with /\n")
        return 1
    url = f"https://api.appstoreconnect.apple.com{path}"
    token = make_jwt()
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
    body = None
    if method in ("POST", "PATCH"):
        raw = sys.stdin.read()
        if raw.strip():
            body = raw  # pass-through; assume caller wrote valid JSON
    resp = requests.request(method, url, headers=headers, data=body, timeout=30)
    # Print response (status + JSON body) so callers can pipe to jq
    if resp.status_code >= 400:
        sys.stderr.write(f"HTTP {resp.status_code}\n")
        sys.stderr.write(resp.text + "\n")
        return 2
    if resp.text:
        # Pretty-print for readability when not piped
        try:
            print(json.dumps(resp.json(), indent=2))
        except ValueError:
            print(resp.text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
