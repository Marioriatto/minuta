from __future__ import annotations

import os
import tomllib
from dataclasses import dataclass
from pathlib import Path


class ConfigError(Exception):
    pass


@dataclass(frozen=True)
class Tuning:
    sample_interval_s: float = 10
    flush_interval_s: float = 10
    poll_interval_s: float = 3
    presence_threshold_kg: float = 1.0
    absence_confirm_s: float = 10
    movement_delta_kg: float = 0.15
    movement_cooldown_s: float = 30


@dataclass(frozen=True)
class Config:
    base_url: str
    timeout_s: float
    serial_port: str
    baud: int
    tokens: dict[str, str]  # solo los módulos con token
    tuning: Tuning


def load_config(path: Path, env: dict[str, str] | None = None) -> Config:
    env = os.environ if env is None else env
    try:
        raw = tomllib.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as e:
        raise ConfigError(f"No existe {path}. Copia bridge.example.toml a bridge.toml.") from e
    except tomllib.TOMLDecodeError as e:
        raise ConfigError(f"{path} no es TOML válido: {e}") from e

    api = raw.get("api", {})
    base_url = str(api.get("base_url", "")).rstrip("/")
    if not base_url.startswith("https://") or "TU-PROYECTO" in base_url:
        raise ConfigError("api.base_url debe ser la URL https de tu Edge Function `device`.")

    tokens: dict[str, str] = {}
    for name in ("mattress", "cradle", "lights"):
        token = env.get(f"COLCHON_TOKEN_{name.upper()}") or str(raw.get("devices", {}).get(name, ""))
        token = token.strip()
        if token:
            if len(token) != 64:
                raise ConfigError(f"El token de `{name}` no tiene el formato esperado (64 caracteres).")
            tokens[name] = token
    if "mattress" not in tokens or "cradle" not in tokens:
        raise ConfigError("Faltan los tokens de `mattress` y `cradle` (peso y ambiente).")

    serial = raw.get("serial", {})
    tuning_raw = raw.get("tuning", {})
    allowed = Tuning.__dataclass_fields__.keys()
    unknown = set(tuning_raw) - set(allowed)
    if unknown:
        raise ConfigError(f"Parámetros desconocidos en [tuning]: {', '.join(sorted(unknown))}")

    return Config(
        base_url=base_url,
        timeout_s=float(api.get("timeout_s", 10)),
        serial_port=str(serial.get("port", "")),
        baud=int(serial.get("baud", 115200)),
        tokens=tokens,
        tuning=Tuning(**tuning_raw),
    )
