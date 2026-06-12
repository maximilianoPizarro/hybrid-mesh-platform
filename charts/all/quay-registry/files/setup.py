import base64, json, os, ssl, sys, time, urllib.error, urllib.parse, urllib.request, subprocess

quay_host = os.environ["QUAY_HOST"]
base = "https://" + quay_host
org, robot = os.environ["QUAY_ORG"], os.environ["ROBOT_NAME"]
user, password = os.environ["QUAY_ADMIN_USER"], os.environ["QUAY_ADMIN_PASSWORD"]
ctx = ssl.create_default_context()
ctx.check_hostname, ctx.verify_mode = False, ssl.CERT_NONE


def parse_json(raw):
    if not raw:
        return {}
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return {"raw": raw.decode(errors="replace")[:200]}


def request(method, path, headers=None, data=None, json_body=None):
    url = base + "/api/v1" + path
    hdrs = dict(headers or {})
    body = None
    if json_body is not None:
        body = json.dumps(json_body).encode()
        hdrs["Content-Type"] = "application/json"
    elif data is not None:
        body = urllib.parse.urlencode(data).encode()
        hdrs["Content-Type"] = "application/x-www-form-urlencoded"
    req = urllib.request.Request(url, data=body, headers=hdrs, method=method)
    try:
        with urllib.request.urlopen(req, context=ctx, timeout=60) as resp:
            raw = resp.read()
            return resp.status, parse_json(raw)
    except urllib.error.HTTPError as e:
        return e.code, parse_json(e.read())


def wait_for_quay():
    for attempt in range(90):
        status, _ = request("GET", "/discovery")
        if status == 200:
            print("Quay discovery OK", file=sys.stderr)
            return
        print("Quay not ready ({0}), retry {1}/90".format(status, attempt + 1), file=sys.stderr)
        time.sleep(10)
    print("Quay API not ready", file=sys.stderr)
    sys.exit(1)


def initialize_admin():
    status, body = request(
        "POST",
        "/user/initialize",
        json_body={
            "username": user,
            "password": password,
            "email": user + "@quay.local",
            "access_token": True,
        },
    )
    if status == 200 and body.get("access_token"):
        print("Initialized Quay admin user", file=sys.stderr)
        return body["access_token"]
    if status == 400 and "non-empty" in body.get("message", ""):
        return None
    print("initialize: {0} {1}".format(status, body), file=sys.stderr)
    sys.exit(1)


def load_bearer_token():
    token = os.environ.get("QUAY_ADMIN_TOKEN", "").strip()
    if not token:
        return None
    status, body = request("GET", "/user/", headers={"Authorization": "Bearer " + token})
    if status == 200 and body.get("username") == user:
        print("Using Quay admin bearer token", file=sys.stderr)
        return token
    return None


def save_bearer_token(token):
    manifest = subprocess.check_output(
        [
            "oc", "create", "secret", "generic", "quay-admin-api-token",
            "--from-literal=token=" + token,
            "-n", "quay-registry",
            "--dry-run=client", "-o", "yaml",
        ]
    )
    subprocess.run(
        ["oc", "apply", "-f", "-"],
        input=manifest,
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
    )


wait_for_quay()
bearer = load_bearer_token()
if not bearer:
    bearer = initialize_admin()
if not bearer:
    print(
        "Quay already initialized; set secret quay-admin-api-token with a valid OAuth token",
        file=sys.stderr,
    )
    sys.exit(1)
try:
    save_bearer_token(bearer)
except Exception as exc:
    print("Warning: could not persist admin token: {0}".format(exc), file=sys.stderr)

auth_headers = {"Authorization": "Bearer " + bearer}


def api(method, path, json_body=None):
    return request(method, path, headers=auth_headers, json_body=json_body)


status, _ = api("POST", "/organization/", json_body={"name": org})
if status not in (200, 201, 400, 409):
    print("create org: {0}".format(status), file=sys.stderr)
    sys.exit(1)
status, body = api("PUT", "/organization/" + org + "/robots/" + robot)
if status == 400 and "Existing robot" in body.get("detail", ""):
    status, body = api("GET", "/organization/" + org + "/robots/" + robot)
if status not in (200, 201):
    print("create robot: {0} {1}".format(status, body), file=sys.stderr)
    sys.exit(1)
robot_user = body.get("name") or (org + "+" + robot)
robot_token = body.get("token")
if not robot_token:
    print("robot token missing: {0}".format(body), file=sys.stderr)
    sys.exit(1)
auth = base64.b64encode((robot_user + ":" + robot_token).encode()).decode()
print(json.dumps({"auths": {quay_host: {"auth": auth, "email": robot_user + "@quay.local"}}}))
