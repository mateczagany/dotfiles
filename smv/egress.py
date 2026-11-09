"""smv egress proxy: smolvm's mediated-egress decider inside a mitmproxy addon.

bin/smv runs it as `mitmdump --listen-port PORT+1 -s egress.py` and starts every
machine with `--mediated-egress --egress-interceptor 127.0.0.1:PORT`. smolvm
then hands each outbound TCP flow to the decider below (protocol: smolvm's
docs/mediated-egress.md). The decider answers "redirect" and feeds the flow to
mitmproxy as a CONNECT to the address the machine dialed. mitmproxy terminates
TLS with its CA, which the machines trust, and the hooks below:

- log every request to $SMV_STATE/egress.log, one JSON object per line
- refuse requests that contain a line of $SMV_STATE/personal
- put the real Claude and GitHub tokens in place of the placeholders the
  machines hold, only on connections whose certificate mitmproxy verified
- drop anything that isn't HTTP

The real tokens stay on the Mac, in Keychain and in this process.
"""

import asyncio
import base64
import hmac
import html
import ipaddress
import json
import logging
import logging.handlers
import os
import re
import subprocess
import time
from dataclasses import dataclass
from urllib.parse import unquote_plus

from mitmproxy import ctx, http

STATE = os.environ["SMV_STATE"]
PORT = int(os.environ["SMV_EGRESS_PORT"])

# Hosts that get a token, each with its subdomains. Requests to the Claude hosts
# skip the personal-info check: they carry the whole conversation, which holds
# your name and email as soon as Claude reads a `git log`.
CLAUDE_HOSTS = ("anthropic.com", "claude.ai", "claude.com")
GITHUB_HOSTS = ("github.com", "githubusercontent.com")
CREDENTIALS = (  # placeholder variable, Keychain item variable, hosts
    ("SMV_CLAUDE_PLACEHOLDER", "SMV_TOKEN_ITEM", CLAUDE_HOSTS),
    ("SMV_GH_PLACEHOLDER", "SMV_GH_ITEM", GITHUB_HOSTS),
)

REDIRECT, DENY = b"\x02", b"\x01"
BLOCKED = (
    b"Blocked by the smv egress proxy: this request contains the user's personal "
    b"information. Do not send it again in another form or encoding; tell the user "
    b"what you were trying to send.\n"
)

LOG = logging.getLogger("smv.egress")
if not LOG.handlers:  # mitmproxy re-runs this file when it changes
    _handler = logging.handlers.RotatingFileHandler(
        os.path.join(STATE, "egress.log"), maxBytes=50 << 20, backupCount=3
    )
    _handler.setFormatter(logging.Formatter("%(message)s"))
    LOG.addHandler(_handler)
    LOG.setLevel(logging.INFO)
    LOG.propagate = False


def record(**fields):
    fields = {k: v for k, v in fields.items() if v not in (None, "")}
    LOG.info(json.dumps({"ts": time.strftime("%Y-%m-%dT%H:%M:%S"), **fields}))


# --- Personal information -----------------------------------------------------


@dataclass
class Rule:
    line: int
    rx: re.Pattern
    b64: tuple


def b64_forms(s: bytes) -> tuple:
    """s base64-encoded at each of the three byte alignments, without the edge
    characters that depend on neighbouring bytes, in both alphabets."""
    forms = set()
    for pad in range(3):
        enc = base64.b64encode(bytes(pad) + s).decode()
        form = enc[-(-pad * 8 // 6) : (pad + len(s)) * 8 // 6]
        forms |= {form, form.translate(str.maketrans("+/", "-_"))}
    return tuple(forms)


def parse_rules(text: str) -> list:
    rules = []
    for n, line in enumerate(text.splitlines(), 1):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("re:"):
            try:
                rules.append(Rule(n, re.compile(line[3:], re.I), ()))
            except re.error as e:
                logging.warning("smv egress: personal line %d is not a valid regex: %s", n, e)
            continue
        # "Jane Doe" also matches Jane+Doe, jane_doe, jane.doe and Jane-Doe.
        rx = re.compile(r"[\s+_.\-]+".join(map(re.escape, line.split())), re.I)
        b64 = b64_forms(line.encode()) + b64_forms(line.lower().encode()) if len(line) >= 6 else ()
        rules.append(Rule(n, rx, b64))
    return rules


JSON_ESCAPE = re.compile(r"\\u([0-9a-fA-F]{4})")


def decoded(text: str) -> str:
    """text with JSON \\u escapes, URL encoding and HTML entities undone."""
    text = JSON_ESCAPE.sub(lambda m: chr(int(m[1], 16)), text)
    return html.unescape(unquote_plus(text))


class Personal:
    """The lines of $SMV_STATE/personal, re-read whenever the file changes."""

    def __init__(self, path):
        self.path, self.stamp, self.rules = path, None, []

    def current(self) -> list:
        try:
            st = os.stat(self.path)
        except FileNotFoundError:
            return []
        if (st.st_mtime_ns, st.st_size) != self.stamp:
            with open(self.path, encoding="utf-8") as f:
                self.rules = parse_rules(f.read())
            self.stamp = (st.st_mtime_ns, st.st_size)
        return self.rules

    def find(self, text: str):
        rules = self.current()
        views = (text, decoded(text)) if rules else ()
        for rule in rules:
            if any(rule.rx.search(v) for v in views) or any(f in text for f in rule.b64):
                return rule
        return None


def request_text(req: http.Request) -> str:
    lines = [f"{req.method} {req.pretty_url}"]
    lines += [f"{k}: {v}" for k, v in req.headers.items(multi=True)]
    body = req.get_content(strict=False) or b""
    return "\n".join(lines) + "\n" + body.decode("utf-8", "replace")


# --- Tokens -------------------------------------------------------------------


@dataclass
class Credential:
    placeholder: str
    token: str
    hosts: tuple


def keychain(item: str):
    try:
        out = subprocess.run(
            ["security", "find-generic-password", "-s", item, "-w"],
            capture_output=True, text=True, timeout=30,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    return out.stdout.strip() if out.returncode == 0 else None


def load_credentials() -> list:
    creds = []
    for placeholder, item, hosts in CREDENTIALS:
        token = keychain(os.environ[item])
        if token:
            creds.append(Credential(os.environ[placeholder], token, hosts))
        else:
            logging.warning("smv egress: no token in Keychain item %s", os.environ[item])
    return creds


def swap(headers, cred: Credential):
    value = headers.get("authorization", "")
    if cred.placeholder in value:
        headers["authorization"] = value.replace(cred.placeholder, cred.token)
    elif value[:6].lower() == "basic ":  # git sends user:token
        try:
            pair = base64.b64decode(value[6:]).decode()
        except ValueError:
            return
        if cred.placeholder in pair:
            pair = pair.replace(cred.placeholder, cred.token)
            headers["authorization"] = "Basic " + base64.b64encode(pair.encode()).decode()


def under(host, domains) -> bool:
    return bool(host) and any(host == d or host.endswith("." + d) for d in domains)


def verified_host(flow: http.HTTPFlow):
    """The host this request is for, when it goes over TLS that mitmproxy
    verified for that same name; otherwise None."""
    sni = flow.server_conn.sni
    if flow.request.scheme != "https" or not sni or ctx.options.ssl_insecure:
        return None
    sni = sni.lower().rstrip(".")
    return sni if flow.request.pretty_host.lower().rstrip(".") == sni else None


# --- Flows from the machines --------------------------------------------------


@dataclass
class Origin:
    vm: str
    ip: ipaddress.IPv4Address | ipaddress.IPv6Address
    port: int
    tunnel_open: bool = False
    streams: tuple = ()  # the decider's writers, to the guest and to mitmproxy

    def close(self):
        for writer in self.streams:
            writer.close()


# The decider's connection into mitmproxy, by its local port, to where the
# machine was going. mitmproxy sees that port as the client's. Kept on ctx so
# open tunnels survive mitmproxy reloading this file after an edit.
ORIGINS: dict[int, Origin] = getattr(ctx, "smv_origins", {})
ctx.smv_origins = ORIGINS


def origin_of(client):
    peer = client.peername
    return ORIGINS.get(peer[1]) if peer and peer[0] in ("127.0.0.1", "::ffff:127.0.0.1") else None


def same_address(host, port, origin: Origin) -> bool:
    try:
        return ipaddress.ip_address(host) == origin.ip and port == origin.port
    except ValueError:
        return False


def address(addr) -> str:
    if not addr:
        return ""
    host, port = addr[0], addr[1]
    return f"[{host}]:{port}" if ":" in host else f"{host}:{port}"


def vm_name(machine_id: str) -> str:
    """bin/smv writes $SMV_STATE/machines/<mediation ID> at each start."""
    try:
        with open(os.path.join(STATE, "machines", machine_id)) as f:
            return f.read().strip()
    except OSError:
        return machine_id[:12]


async def pipe(reader, writer, other):
    try:
        while data := await reader.read(1 << 16):
            writer.write(data)
            await writer.drain()
        if writer.can_write_eof():
            writer.write_eof()
    except (OSError, RuntimeError):
        writer.close()
        other.close()


class Egress:
    def __init__(self):
        self.server = None
        self.personal = Personal(os.path.join(STATE, "personal"))
        self.creds = load_credentials()

    def running(self):  # sync: mitmproxy calls it that way after a reload
        with open(os.path.join(STATE, "token")) as f:
            self.token = bytes.fromhex(f.read().strip())
        asyncio.get_running_loop().create_task(self.serve())

    async def serve(self):
        try:
            self.server = await asyncio.start_server(self.decide, "127.0.0.1", PORT)
        except OSError as e:
            logging.error("smv egress: cannot listen on 127.0.0.1:%d: %s", PORT, e)

    def done(self):
        if self.server:
            self.server.close()

    async def decide(self, guest_r, guest_w):
        """One guest TCP flow: check the prelude smolvm sends, answer, relay."""
        try:
            head = await asyncio.wait_for(guest_r.readexactly(75), 5)
            if (
                head[:8] != b"SMOLMEG2"
                or not hmac.compare_digest(head[8:40], self.token)
                or head[72] not in (4, 6)
            ):
                return
            ip = ipaddress.ip_address(await guest_r.readexactly(4 if head[72] == 4 else 16))
            port = int.from_bytes(head[73:75], "big")
            first = await guest_r.readexactly(int.from_bytes(await guest_r.readexactly(2), "big"))
            vm = vm_name(head[40:56].hex())
            if not ip.is_global:
                record(vm=vm, verdict="blocked", dest=address((str(ip), port)), reason="private address")
                guest_w.write(DENY)
                return
            guest_w.write(REDIRECT)
            await guest_w.drain()
            await self.relay(guest_r, guest_w, Origin(vm, ip, port), first)
        except (asyncio.IncompleteReadError, asyncio.TimeoutError, OSError):
            pass
        finally:
            guest_w.close()

    async def relay(self, guest_r, guest_w, origin: Origin, first: bytes):
        mitm_r, mitm_w = await asyncio.open_connection("127.0.0.1", ctx.options.listen_port)
        local_port = mitm_w.get_extra_info("sockname")[1]
        ORIGINS[local_port] = origin
        origin.streams = (guest_w, mitm_w)
        try:
            dest = address((str(origin.ip), origin.port))
            mitm_w.write(f"CONNECT {dest} HTTP/1.1\r\nHost: {dest}\r\n\r\n".encode())
            reply = await mitm_r.readuntil(b"\r\n\r\n")
            if reply.split(b" ", 2)[1:2] != [b"200"]:
                status = reply.split(b"\r\n", 1)[0].decode("latin-1")
                record(vm=origin.vm, verdict="error", dest=dest, reason=status)
                return
            mitm_w.write(first)  # smolvm doesn't replay what it put in the prelude
            await asyncio.gather(pipe(guest_r, mitm_w, guest_w), pipe(mitm_r, guest_w, mitm_w))
        finally:
            ORIGINS.pop(local_port, None)
            mitm_w.close()

    # mitmproxy hooks. Anything not from the decider is refused.

    def http_connect(self, flow: http.HTTPFlow):
        origin = origin_of(flow.client_conn)
        if (
            origin is None
            or origin.tunnel_open
            or not same_address(flow.request.host, flow.request.port, origin)
        ):
            flow.response = http.Response.make(403)
            return
        origin.tunnel_open = True

    def server_connect(self, data):
        # Only ever to where the machine dialed, so an absolute-form request or
        # a CONNECT inside the tunnel can't reach the Mac or the LAN.
        origin = origin_of(data.client)
        if origin is None or not data.server.address or not same_address(*data.server.address, origin):
            data.server.error = "smv egress: not the address the machine dialed"

    def request(self, flow: http.HTTPFlow):
        origin = origin_of(flow.client_conn)
        if origin is None:
            flow.metadata["smv_blocked"] = "not from a machine"
            flow.response = http.Response.make(403)
            return
        flow.metadata["smv_vm"] = origin.vm
        host = verified_host(flow)
        if not under(host, CLAUDE_HOSTS):
            rule = self.personal.find(request_text(flow.request))
            if rule:
                flow.metadata["smv_blocked"] = f"personal info, line {rule.line}"
                flow.response = http.Response.make(403, BLOCKED, {"content-type": "text/plain"})
                return
        for cred in self.creds:
            if under(host, cred.hosts):
                swap(flow.request.headers, cred)

    def responseheaders(self, flow: http.HTTPFlow):
        flow.response.stream = True  # server-sent events, large downloads

    def response(self, flow: http.HTTPFlow):
        if flow.request.method == "CONNECT":
            return
        blocked = flow.metadata.get("smv_blocked")
        end = flow.response.timestamp_end or time.time()
        record(
            vm=flow.metadata.get("smv_vm"),
            verdict="blocked" if blocked else "allowed",
            method=flow.request.method,
            url=flow.request.pretty_url,
            status=flow.response.status_code,
            sent=len(flow.request.raw_content or b""),
            ms=int((end - flow.request.timestamp_start) * 1000),
            reason=blocked,
        )

    def error(self, flow: http.HTTPFlow):
        if flow.request.method == "CONNECT" or flow.metadata.get("smv_logged"):
            return
        record(
            vm=flow.metadata.get("smv_vm"),
            verdict="error",
            method=flow.request.method,
            url=flow.request.pretty_url,
            reason=flow.error.msg if flow.error else None,
        )

    def websocket_message(self, flow: http.HTTPFlow):
        msg = flow.websocket.messages[-1]
        if not msg.from_client or under(verified_host(flow), CLAUDE_HOSTS):
            return
        rule = self.personal.find(msg.content.decode("utf-8", "replace"))
        if rule:
            msg.drop()
            flow.metadata["smv_logged"] = True
            record(
                vm=flow.metadata.get("smv_vm"),
                verdict="blocked",
                method="WEBSOCKET",
                url=flow.request.pretty_url,
                reason=f"personal info, line {rule.line}",
            )
            flow.kill()

    # bin/smv runs mitmdump with rawtcp=false, so non-HTTP fails in the HTTP
    # parser. If a raw TCP relay starts anyway, kill() would not stop it, so
    # empty every message and close both ends.

    def tcp_start(self, flow):
        origin = origin_of(flow.client_conn)
        record(
            vm=origin.vm if origin else None,
            verdict="blocked",
            dest=address(flow.server_conn.address),
            sni=flow.client_conn.sni,
            reason="not HTTP",
        )
        if origin:
            origin.close()

    def tcp_message(self, flow):
        flow.messages[-1].content = b""

    def tls_failed_client(self, data):
        origin = origin_of(data.context.client)
        record(
            vm=origin.vm if origin else None,
            verdict="error",
            dest=address(data.context.server.address),
            sni=data.context.client.sni,
            reason=data.conn.error,
        )


addons = [Egress()]
