"""Protocolo serie con el Arduino (líneas CSV; ver docs/hardware_protocolo.md)."""
from __future__ import annotations

import math
from dataclasses import dataclass


@dataclass(frozen=True)
class Sample:
    weight_kg: float | None
    temperature_c: float | None
    humidity_pct: float | None


@dataclass(frozen=True)
class Button:
    id: int


@dataclass(frozen=True)
class Hello:
    firmware: str


@dataclass(frozen=True)
class RawValue:
    value: float


@dataclass(frozen=True)
class Ack:
    what: str


@dataclass(frozen=True)
class DeviceError:
    code: str


Message = Sample | Button | Hello | RawValue | Ack | DeviceError


def _num(text: str) -> float | None:
    try:
        value = float(text)
    except ValueError:
        return None
    return value if math.isfinite(value) else None


def parse_line(line: str) -> Message | None:
    """Convierte una línea del Arduino en un mensaje; None si no se entiende."""
    parts = line.strip().split(",")
    kind = parts[0] if parts else ""
    if kind == "R" and len(parts) == 4:
        return Sample(_num(parts[1]), _num(parts[2]), _num(parts[3]))
    if kind == "B" and len(parts) == 2 and parts[1].isdigit():
        return Button(int(parts[1]))
    if kind == "H" and len(parts) == 2:
        return Hello(parts[1])
    if kind == "X" and len(parts) == 2:
        value = _num(parts[1])
        return RawValue(value) if value is not None else None
    if kind == "K" and len(parts) == 2:
        return Ack(parts[1])
    if kind == "E" and len(parts) == 2:
        return DeviceError(parts[1])
    return None


def cmd_light(on: bool, brightness: int, speed: int) -> str:
    clamp = lambda v: max(0, min(100, int(v)))  # noqa: E731
    return f"LIGHT,{1 if on else 0},{clamp(brightness)},{clamp(speed)}"


def cmd_buzz(ms: int) -> str:
    return f"BUZ,{max(1, min(5000, int(ms)))}"


def cmd_cal(factor: float) -> str:
    return f"CAL,{factor:.4f}"


CMD_TARE = "TARE"
CMD_RAW = "RAW"
CMD_PING = "PING"
