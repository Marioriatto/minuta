"""Reglas de detección del colchón (RF-11, RF-13, RF-14). Sin E/S: se prueba sola."""
from __future__ import annotations

from dataclasses import dataclass, field


@dataclass(frozen=True)
class DetectedEvent:
    type: str
    description: str
    payload: dict
    at: float  # epoch en segundos


@dataclass
class MattressLogic:
    presence_threshold_kg: float = 1.0
    absence_confirm_s: float = 10.0
    movement_delta_kg: float = 0.15
    movement_cooldown_s: float = 30.0

    present: bool = False
    _below_since: float | None = field(default=None, repr=False)
    _baseline: float | None = field(default=None, repr=False)
    _last_movement: float = field(default=-1e12, repr=False)

    def update(self, weight_kg: float, now: float, detection_active: bool) -> list[DetectedEvent]:
        events: list[DetectedEvent] = []
        occupied = weight_kg >= self.presence_threshold_kg

        if occupied:
            self._below_since = None
            if not self.present:
                self.present = True
                self._baseline = weight_kg
                events.append(DetectedEvent(
                    "presence_detected", "Se detecta peso sobre el colchón",
                    {"weight_kg": round(weight_kg, 3)}, now))
            else:
                events.extend(self._movement(weight_kg, now, detection_active))
        elif self.present:
            if self._below_since is None:
                self._below_since = now
            if now - self._below_since >= self.absence_confirm_s:
                self.present = False
                self._baseline = None
                self._below_since = None
                # Sin periodo de detección abierto no hay a quién atribuir la alerta (RF-12).
                if detection_active:
                    events.append(DetectedEvent(
                        "absence_detected", "Se dejó de detectar el peso del bebé",
                        {"weight_kg": round(weight_kg, 3)}, now))
        return events

    def _movement(self, weight_kg: float, now: float, detection_active: bool) -> list[DetectedEvent]:
        baseline = self._baseline if self._baseline is not None else weight_kg
        delta = weight_kg - baseline
        if (detection_active
                and abs(delta) >= self.movement_delta_kg
                and now - self._last_movement >= self.movement_cooldown_s):
            self._last_movement = now
            self._baseline = weight_kg
            return [DetectedEvent(
                "movement_detected", "Movimiento detectado en el colchón",
                {"delta_kg": round(delta, 3)}, now)]
        # La línea base sigue despacio al peso real (el bebé crece o cambia de postura).
        self._baseline = baseline + 0.1 * (weight_kg - baseline)
        return []
