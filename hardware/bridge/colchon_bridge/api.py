"""Cliente HTTPS de la Edge Function `device`."""
from __future__ import annotations

from typing import Any

import requests


class ApiError(Exception):
    def __init__(self, status: int | None, code: str):
        super().__init__(f"{status or 'red'}: {code}")
        self.status = status
        self.code = code

    @property
    def retryable(self) -> bool:
        """Errores de red o del servidor se reintentan; los 4xx no."""
        return self.status is None or self.status >= 500 or self.status == 429


class DeviceApi:
    def __init__(self, base_url: str, token: str, timeout_s: float = 10,
                 session: requests.Session | None = None):
        self._base = base_url.rstrip("/")
        self._token = token
        self._timeout = timeout_s
        self._http = session or requests.Session()

    def _call(self, method: str, route: str, body: dict | None = None) -> Any:
        try:
            resp = self._http.request(
                method, f"{self._base}/{route}", json=body, timeout=self._timeout,
                headers={"Authorization": f"Bearer {self._token}"})
        except requests.RequestException as e:
            raise ApiError(None, type(e).__name__) from e
        if resp.status_code >= 400:
            try:
                code = resp.json().get("error", "unknown")
            except ValueError:
                code = "unknown"
            raise ApiError(resp.status_code, str(code))
        return resp.json()

    def ingest(self, readings: list[dict], events: list[dict],
               state: dict | None = None, firmware: str | None = None) -> dict:
        body: dict[str, Any] = {"readings": readings, "events": events}
        if state:
            body["state"] = state
        if firmware:
            body["firmware"] = firmware
        return self._call("POST", "ingest", body)

    def poll(self) -> dict:
        return self._call("GET", "poll")

    def ack(self, command_id: int, status: str, result: dict | None = None) -> None:
        self._call("POST", "ack", {"command_id": command_id, "status": status, "result": result})
