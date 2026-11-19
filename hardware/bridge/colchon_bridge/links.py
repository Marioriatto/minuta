"""Enlaces con el Arduino: puerto serie real y simulador."""
from __future__ import annotations

import math
import queue
import random
import threading
import time
from typing import Callable, Protocol


class Link(Protocol):
    def read_lines(self) -> list[str]: ...
    def write(self, line: str) -> None: ...
    def close(self) -> None: ...


class SerialLink:
    """Lee el puerto en un hilo y entrega las líneas completas sin bloquear."""

    def __init__(self, port: str, baud: int):
        import serial  # import tardío: los tests y el simulador no lo necesitan

        self._serial = serial.Serial(port, baud, timeout=0.5)
        self._lines: queue.Queue[str] = queue.Queue()
        self._stop = threading.Event()
        self._error: Exception | None = None
        self._thread = threading.Thread(target=self._reader, daemon=True)
        self._thread.start()

    def _reader(self) -> None:
        while not self._stop.is_set():
            try:
                raw = self._serial.readline()
            except Exception as e:  # cable desconectado, puerto tomado por otro programa
                self._error = e
                return
            if raw:
                self._lines.put(raw.decode("ascii", errors="ignore").strip())

    def read_lines(self) -> list[str]:
        if self._error:
            raise ConnectionError(f"Se perdió el puerto serie: {self._error}")
        out = []
        while True:
            try:
                out.append(self._lines.get_nowait())
            except queue.Empty:
                return out

    def write(self, line: str) -> None:
        self._serial.write((line + "\n").encode("ascii"))

    def close(self) -> None:
        self._stop.set()
        self._serial.close()


class FakeLink:
    """Hardware simulado para demostrar el flujo completo sin Arduino.

    normal: bebé sobre el colchón desde los 10 s, con un movimiento cada ~45 s.
    alarm:  el bebé se levanta a los 60 s y la temperatura sube hasta pasar 26 °C.
    """

    def __init__(self, scenario: str = "normal", clock: Callable[[], float] = time.time,
                 period_s: float = 2.0, seed: int | None = None):
        if scenario not in ("normal", "alarm"):
            raise ValueError("scenario debe ser 'normal' o 'alarm'")
        self.scenario = scenario
        self._clock = clock
        self._period = period_s
        self._t0 = clock()
        self._next = self._t0
        self._rng = random.Random(seed)
        self._pending: list[str] = ["H,sim-0.1.0"]
        self.written: list[str] = []
        self.light = (0, 0, 0)

    def _values(self, t: float) -> tuple[float, float, float]:
        weight = 0.0 if t < 10 else 5.84
        if self.scenario == "alarm" and t >= 60:
            weight = 0.0
        elif t >= 10 and (t % 45) < 4 and t >= 40:
            weight += 0.3  # movimiento breve
        temp = 24.0 + (0.04 * t if self.scenario == "alarm" else 0.0)
        temp += 0.05 * math.sin(t / 7)
        hum = 50.0 + 0.5 * math.sin(t / 11)
        n = self._rng.gauss
        return max(0.0, weight + n(0, 0.01)), temp + n(0, 0.02), hum + n(0, 0.1)

    def read_lines(self) -> list[str]:
        now = self._clock()
        while now >= self._next:
            w, t, h = self._values(self._next - self._t0)
            self._pending.append(f"R,{w:.3f},{t:.2f},{h:.2f}")
            self._next += self._period
        out, self._pending = self._pending, []
        return out

    def write(self, line: str) -> None:
        self.written.append(line)
        if line.startswith("LIGHT,"):
            self.light = tuple(int(x) for x in line.split(",")[1:4])
        self._pending.append("K," + line.split(",")[0])

    def close(self) -> None:
        pass
