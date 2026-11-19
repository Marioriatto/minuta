import pytest
import requests

from colchon_bridge.api import ApiError, DeviceApi
from colchon_bridge.config import ConfigError, load_config

TOKEN = "a" * 64
BASE = """
[api]
base_url = "https://abc.supabase.co/functions/v1/device/"
[serial]
port = "COM3"
[devices]
mattress = "%s"
cradle = "%s"
""" % (TOKEN, TOKEN)


def test_load_ok(tmp_path):
    f = tmp_path / "b.toml"
    f.write_text(BASE)
    cfg = load_config(f, env={})
    assert cfg.base_url == "https://abc.supabase.co/functions/v1/device"
    assert set(cfg.tokens) == {"mattress", "cradle"}


def test_env_overrides_and_validates(tmp_path):
    f = tmp_path / "b.toml"
    f.write_text(BASE.replace(TOKEN, ""))
    with pytest.raises(ConfigError):
        load_config(f, env={})
    cfg = load_config(f, env={"COLCHON_TOKEN_MATTRESS": TOKEN, "COLCHON_TOKEN_CRADLE": TOKEN})
    assert len(cfg.tokens) == 2
    with pytest.raises(ConfigError):
        load_config(f, env={"COLCHON_TOKEN_MATTRESS": "corto", "COLCHON_TOKEN_CRADLE": TOKEN})


def test_rejects_placeholder_url_and_unknown_tuning(tmp_path):
    f = tmp_path / "b.toml"
    f.write_text(BASE.replace("abc", "TU-PROYECTO"))
    with pytest.raises(ConfigError):
        load_config(f, env={})
    f.write_text(BASE + "\n[tuning]\ntypo = 1\n")
    with pytest.raises(ConfigError):
        load_config(f, env={})


class StubSession:
    def __init__(self, status=200, body=None, exc=None):
        self.status, self.body, self.exc, self.calls = status, body or {}, exc, []

    def request(self, method, url, json=None, timeout=None, headers=None):
        self.calls.append((method, url, json, headers))
        if self.exc:
            raise self.exc
        outer = self

        class R:
            status_code = outer.status

            def json(self):
                return outer.body
        return R()


def test_api_sends_bearer_and_url():
    s = StubSession(body={"readings": 1})
    api = DeviceApi("https://x/functions/v1/device/", TOKEN, session=s)
    api.ingest([{"metric": "weight"}], [], {"a": 1}, "0.1.0")
    method, url, body, headers = s.calls[0]
    assert (method, url) == ("POST", "https://x/functions/v1/device/ingest")
    assert headers["Authorization"] == f"Bearer {TOKEN}"
    assert body["firmware"] == "0.1.0"


def test_api_error_classification():
    with pytest.raises(ApiError) as e:
        DeviceApi("https://x", TOKEN, session=StubSession(409, {"error": "device_not_claimed"})).poll()
    assert e.value.code == "device_not_claimed" and not e.value.retryable
    with pytest.raises(ApiError) as e:
        DeviceApi("https://x", TOKEN, session=StubSession(exc=requests.ConnectionError())).poll()
    assert e.value.retryable
    with pytest.raises(ApiError) as e:
        DeviceApi("https://x", TOKEN, session=StubSession(503, {})).poll()
    assert e.value.retryable
