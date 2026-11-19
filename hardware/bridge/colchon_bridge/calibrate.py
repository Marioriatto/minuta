"""Calibración de la balanza con un peso conocido."""
from __future__ import annotations

import time
from typing import Callable

from . import protocol as p
from .links import Link


def read_raw(link: Link, timeout_s: float = 10, sleep: Callable[[float], None] = time.sleep,
             clock: Callable[[], float] = time.time) -> float:
    link.write(p.CMD_RAW)
    deadline = clock() + timeout_s
    while clock() < deadline:
        for line in link.read_lines():
            msg = p.parse_line(line)
            if isinstance(msg, p.RawValue):
                return msg.value
        sleep(0.1)
    raise TimeoutError("El Arduino no respondió a RAW")


def calibrate(link: Link, known_kg: float, prompt: Callable[[str], str] = input,
              sleep: Callable[[float], None] = time.sleep) -> float:
    if known_kg <= 0:
        raise ValueError("El peso conocido debe ser mayor que 0")
    prompt("Deja el colchón VACÍO y pulsa Enter...")
    link.write(p.CMD_TARE)
    sleep(2)
    prompt(f"Coloca {known_kg} kg exactos y pulsa Enter...")
    raw = read_raw(link)
    if abs(raw) < 100:
        raise ValueError("La lectura es casi cero: revisa el cableado del HX711 o el peso.")
    factor = raw / known_kg
    link.write(p.cmd_cal(factor))
    return factor
