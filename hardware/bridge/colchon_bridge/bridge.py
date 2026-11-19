"""Orquesta el enlace serie, las reglas del colchón y la subida a la Edge Function."""
from __future__ import annotations

import logging
from collections import deque
from datetime import datetime, timezone
from typing import Callable

from . import protocol as p
from .api import ApiError, DeviceApi
from .config import Tuning
from .links import Link
from .logic import DetectedEvent, MattressLogic

log = logging.getLogger("colchon.bridge")

MAX_BUFFERED = 2000
DROP_STATUSES = {400, 401, 403, 404, 413, 422}  # reintentar no arreglaría nada


def iso(epoch: float) -> str:
    return datetime.fromtimestamp(int(epoch), tz=timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _parse_time(value: object) -> datetime | None:
    if not isinstance(value, str) or not value:
        return None
    try:
        parsed = datetime.fromisoformat(value)
    except ValueError:
        return None
    return parsed if parsed.tzinfo else parsed.replace(tzinfo=timezone.utc)


class Outbox:
    """Lotes pendientes de un módulo; se conservan si la red falla."""

    def __init__(self) -> None:
        self.readings: deque[dict] = deque(maxlen=MAX_BUFFERED)
        self.events: deque[dict] = deque(maxlen=MAX_BUFFERED)
        self.state: dict = {}

    def empty(self) -> bool:
        return not self.readings and not self.events

    def take(self) -> tuple[list[dict], list[dict], dict]:
        batch = (list(self.readings)[:500], list(self.events)[:100], dict(self.state))
        for _ in batch[0]:
            self.readings.popleft()
        for _ in batch[1]:
            self.events.popleft()
        return batch

    def restore(self, readings: list[dict], events: list[dict]) -> None:
        self.readings.extendleft(reversed(readings))
        self.events.extendleft(reversed(events))


class Bridge:
    def __init__(self, link: Link, apis: dict[str, DeviceApi], tuning: Tuning,
                 clock: Callable[[], float]):
        self.link, self.apis, self.tuning, self.clock = link, apis, tuning, clock
        self.mattress = MattressLogic(
            presence_threshold_kg=tuning.presence_threshold_kg,
            absence_confirm_s=tuning.absence_confirm_s,
            movement_delta_kg=tuning.movement_delta_kg,
            movement_cooldown_s=tuning.movement_cooldown_s)
        self.outbox = {name: Outbox() for name in apis}
        self.detection_active = False
        self.firmware: str | None = None
        self._last_stored: dict[str, float] = {}
        self._last_flush = 0.0
        self._last_poll = 0.0
        self._last_light: tuple[int, int, int] | None = None
        self._claimed_warned: set[str] = set()
        self.last_raw: float | None = None

    # ---- entrada serie -----------------------------------------------------
    def process_serial(self) -> None:
        for line in self.link.read_lines():
            msg = p.parse_line(line)
            now = self.clock()
            if isinstance(msg, p.Sample):
                self._on_sample(msg, now)
            elif isinstance(msg, p.Hello):
                self.firmware = msg.firmware
                self._last_light = None  # el Arduino se reinició: reenviar las luces
                log.info("Arduino listo (firmware %s)", msg.firmware)
            elif isinstance(msg, p.Button):
                log.info("Botón %d pulsado", msg.id)
            elif isinstance(msg, p.RawValue):
                self.last_raw = msg.value
            elif isinstance(msg, p.DeviceError):
                log.warning("Arduino reporta: %s", msg.code)
            elif msg is None and line:
                log.debug("Línea ignorada: %r", line)

    def _store(self, device: str, metric: str, value: float | None, now: float) -> None:
        if value is None or device not in self.outbox:
            return
        if now - self._last_stored.get(metric, -1e12) < self.tuning.sample_interval_s:
            return
        self._last_stored[metric] = now
        self.outbox[device].readings.append(
            {"metric": metric, "value": round(value, 3), "recorded_at": iso(now)})

    def _on_sample(self, s: p.Sample, now: float) -> None:
        if s.weight_kg is not None:
            weight = max(0.0, s.weight_kg)
            self.outbox["mattress"].state["weight_kg"] = round(weight, 3)
            self._store("mattress", "weight", weight, now)
            for ev in self.mattress.update(weight, now, self.detection_active):
                self._queue_event("mattress", ev)
        if s.temperature_c is not None:
            self.outbox["cradle"].state["temperature_c"] = round(s.temperature_c, 2)
        if s.humidity_pct is not None:
            self.outbox["cradle"].state["humidity_pct"] = round(s.humidity_pct, 2)
        self._store("cradle", "temperature", s.temperature_c, now)
        self._store("cradle", "humidity", s.humidity_pct, now)

    def _queue_event(self, device: str, ev: DetectedEvent) -> None:
        log.info("Evento %s", ev.type)
        self.outbox[device].events.append({
            "type": ev.type, "description": ev.description, "payload": ev.payload,
            "occurred_at": iso(ev.at),
            "dedupe_key": f"{device}:{ev.type}:{int(ev.at)}"})

    # ---- subida ------------------------------------------------------------
    def flush(self, force: bool = False) -> None:
        now = self.clock()
        if not force and now - self._last_flush < self.tuning.flush_interval_s:
            return
        self._last_flush = now
        for name, box in self.outbox.items():
            if box.empty():
                continue
            readings, events, state = box.take()
            try:
                result = self.apis[name].ingest(readings, events, state, self.firmware)
                log.debug("%s: subido %s", name, result)
            except ApiError as e:
                if e.status in DROP_STATUSES:
                    log.error("%s: el servidor rechazó el lote (%s); se descarta", name, e)
                else:
                    box.restore(readings, events)
                    self._warn_unclaimed(name, e)

    def _warn_unclaimed(self, name: str, e: ApiError) -> None:
        if e.code == "device_not_claimed":
            if name not in self._claimed_warned:
                log.warning("%s aún no está vinculado a una cuenta: vincúlalo en la app. "
                            "Los datos se guardan aquí mientras tanto.", name)
                self._claimed_warned.add(name)
        else:
            log.warning("%s: no se pudo subir (%s); se reintentará", name, e)

    # ---- comandos y configuración -------------------------------------------
    def poll(self, force: bool = False) -> None:
        now = self.clock()
        if not force and now - self._last_poll < self.tuning.poll_interval_s:
            return
        self._last_poll = now
        for name, api in self.apis.items():
            try:
                data = api.poll()
            except ApiError as e:
                self._warn_unclaimed(name, e)
                continue
            self._claimed_warned.discard(name)
            if name == "mattress":
                self.detection_active = data.get("detection") is not None
            if name == "lights":
                self._apply_lights(data)
            for cmd in data.get("commands", []):
                self._run_command(name, api, cmd)

    def _apply_lights(self, data: dict) -> None:
        """Estado efectivo = configuración + temporizador (RF-20, RF-21, RF-22).

        La hora que cuenta es la del servidor (`server_time`), no la de esta PC.
        """
        cfg = data.get("config") or {}
        on = bool(cfg.get("on", False))
        ends_at = _parse_time(cfg.get("ends_at"))
        server_now = _parse_time(data.get("server_time"))
        if on and ends_at is not None and server_now is not None and server_now >= ends_at:
            on = False
        brightness = cfg.get("brightness", 50)
        speed = cfg.get("speed", 50)
        if not all(isinstance(v, (int, float)) for v in (brightness, speed)):
            return
        state = (1 if on else 0, int(brightness), int(speed))
        if state != self._last_light:
            self._last_light = state
            self.link.write(p.cmd_light(*state))

    def _run_command(self, name: str, api: DeviceApi, cmd: dict) -> None:
        cid, kind, params = cmd.get("id"), cmd.get("command"), cmd.get("params") or {}
        try:
            if name == "mattress" and kind == "tare":
                self.link.write(p.CMD_TARE)
                self.mattress.present = False
            elif name == "cradle" and kind == "buzz":
                self.link.write(p.cmd_buzz(int(params.get("ms", 500))))
            else:
                api.ack(cid, "failed", {"error": "unsupported_command"})
                return
            api.ack(cid, "done")
        except (ApiError, ValueError, TypeError) as e:
            log.warning("Comando %s falló: %s", kind, e)
            try:
                api.ack(cid, "failed", {"error": "bridge_error"})
            except ApiError:
                pass

    def step(self) -> None:
        self.process_serial()
        self.flush()
        self.poll()
