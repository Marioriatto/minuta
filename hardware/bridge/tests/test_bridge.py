from colchon_bridge.api import ApiError
from colchon_bridge.bridge import Bridge
from colchon_bridge.config import Tuning
from colchon_bridge.links import FakeLink


class Clock:
    def __init__(self, t=1_800_000_000.0):
        self.t = t

    def __call__(self):
        return self.t


class FakeApi:
    def __init__(self, poll_data=None):
        self.ingested, self.acks = [], []
        self.fail_with: ApiError | None = None
        self.poll_data = poll_data or {"detection": None, "commands": [], "config": {}, "config_version": 1}

    def ingest(self, readings, events, state=None, firmware=None):
        if self.fail_with:
            raise self.fail_with
        self.ingested.append((readings, events, state, firmware))
        return {"readings": len(readings), "events": len(events), "skipped": 0}

    def poll(self):
        if self.fail_with:
            raise self.fail_with
        return self.poll_data

    def ack(self, cid, status, result=None):
        self.acks.append((cid, status, result))


class ListLink:
    def __init__(self):
        self.inbox, self.written = [], []

    def read_lines(self):
        out, self.inbox = self.inbox, []
        return out

    def write(self, line):
        self.written.append(line)

    def close(self):
        pass


def make(tuning=None, **apis):
    clock, link = Clock(), ListLink()
    apis = apis or {"mattress": FakeApi(), "cradle": FakeApi()}
    b = Bridge(link, apis, tuning or Tuning(sample_interval_s=10, flush_interval_s=10, poll_interval_s=3), clock)
    return b, link, clock, apis


def test_readings_are_split_per_device_and_throttled():
    b, link, clock, apis = make()
    link.inbox = ["R,5.84,24.1,50.0"]
    b.process_serial()
    clock.t += 2
    link.inbox = ["R,5.85,24.2,50.1"]
    b.process_serial()                      # dentro de 10 s: no se guarda otra
    clock.t += 9
    b.flush()
    m = apis["mattress"].ingested[0][0]
    c = apis["cradle"].ingested[0][0]
    assert [r["metric"] for r in m] == ["weight"]
    assert sorted(r["metric"] for r in c) == ["humidity", "temperature"]
    assert apis["mattress"].ingested[0][2]["weight_kg"] == 5.85


def test_failed_upload_is_kept_and_retried():
    b, link, clock, apis = make()
    link.inbox = ["R,5.84,24.1,50.0"]
    b.process_serial()
    apis["cradle"].fail_with = ApiError(None, "ConnectionError")
    clock.t += 10
    b.flush()
    assert apis["mattress"].ingested and not apis["cradle"].ingested
    apis["cradle"].fail_with = None
    clock.t += 10
    b.flush()
    assert len(apis["cradle"].ingested[0][0]) == 2


def test_unclaimed_device_keeps_data():
    b, link, clock, apis = make()
    link.inbox = ["R,5.84,24.1,50.0"]
    b.process_serial()
    apis["mattress"].fail_with = ApiError(409, "device_not_claimed")
    clock.t += 10
    b.flush()
    assert len(b.outbox["mattress"].readings) == 1


def test_rejected_batch_is_dropped():
    b, link, clock, apis = make()
    link.inbox = ["R,5.84,24.1,50.0"]
    b.process_serial()
    apis["mattress"].fail_with = ApiError(422, "invalid_json")
    clock.t += 10
    b.flush()
    assert len(b.outbox["mattress"].readings) == 0


def test_detection_flag_drives_absence_event():
    b, link, clock, apis = make(Tuning(absence_confirm_s=5, sample_interval_s=1))
    apis["mattress"].poll_data = {"detection": {"id": "x"}, "commands": []}
    b.poll(force=True)
    assert b.detection_active
    for w in (5.8, 5.8, 0.0, 0.0, 0.0):
        link.inbox = [f"R,{w},24,50"]
        b.process_serial()
        clock.t += 3
    types = [e["type"] for e in b.outbox["mattress"].events]
    assert types == ["presence_detected", "absence_detected"]
    keys = [e["dedupe_key"] for e in b.outbox["mattress"].events]
    assert len(set(keys)) == 2


def test_commands_are_executed_and_acked():
    cradle = FakeApi({"commands": [
        {"id": 7, "command": "buzz", "params": {"ms": 800}},
        {"id": 8, "command": "explode", "params": {}}], "detection": None})
    mattress = FakeApi({"commands": [{"id": 9, "command": "tare", "params": {}}], "detection": None})
    b, link, clock, apis = make(mattress=mattress, cradle=cradle)
    b.poll(force=True)
    assert "BUZ,800" in link.written and "TARE" in link.written
    assert (7, "done", None) in cradle.acks
    assert cradle.acks[1][:2] == (8, "failed")
    assert (9, "done", None) in mattress.acks


def _lights(cfg, server_time="2026-11-19T19:00:00+00:00"):
    return FakeApi({"commands": [], "detection": None, "config": cfg, "server_time": server_time})


def test_lights_sent_once_and_again_only_when_state_changes():
    lights = _lights({"on": True, "brightness": 70, "speed": 30})
    b, link, clock, apis = make(mattress=FakeApi(), cradle=FakeApi(), lights=lights)
    b.poll(force=True)
    b.poll(force=True)
    assert link.written.count("LIGHT,1,70,30") == 1
    lights.poll_data["config"] = {"on": True, "brightness": 20, "speed": 30}
    b.poll(force=True)
    assert link.written[-1] == "LIGHT,1,20,30"


def test_lights_turn_off_when_server_time_passes_ends_at():
    cfg = {"on": True, "brightness": 70, "speed": 30, "ends_at": "2026-11-19T19:00:00.5+00:00"}
    lights = _lights(cfg, server_time="2026-11-19T18:59:59+00:00")
    b, link, clock, apis = make(mattress=FakeApi(), cradle=FakeApi(), lights=lights)
    b.poll(force=True)
    assert link.written[-1] == "LIGHT,1,70,30"
    lights.poll_data["server_time"] = "2026-11-19T19:00:01+00:00"
    b.poll(force=True)
    assert link.written[-1] == "LIGHT,0,70,30"


def test_lights_off_by_default_and_resent_after_arduino_restart():
    lights = _lights({"on": False, "brightness": 50, "speed": 50})
    b, link, clock, apis = make(mattress=FakeApi(), cradle=FakeApi(), lights=lights)
    b.poll(force=True)
    assert link.written == ["LIGHT,0,50,50"]
    link.inbox = ["H,0.2.0"]
    b.process_serial()
    b.poll(force=True)
    assert link.written == ["LIGHT,0,50,50", "LIGHT,0,50,50"]


def test_lights_ignore_malformed_config():
    lights = _lights({"on": True, "brightness": "alto", "speed": None, "ends_at": "no-es-fecha"})
    b, link, clock, apis = make(mattress=FakeApi(), cradle=FakeApi(), lights=lights)
    b.poll(force=True)
    assert link.written == []


def test_simulator_alarm_scenario_end_to_end():
    clock = Clock()
    link = FakeLink("alarm", clock=clock, seed=1)
    apis = {"mattress": FakeApi({"detection": {"id": "d"}, "commands": []}), "cradle": FakeApi()}
    b = Bridge(link, apis, Tuning(absence_confirm_s=10, sample_interval_s=10), clock)
    b.poll(force=True)
    for _ in range(100):                     # 100 s simulados
        clock.t += 1
        b.process_serial()
    b.flush(force=True)
    kinds = [e["type"] for e in apis["mattress"].ingested[0][1]]
    assert "presence_detected" in kinds and "absence_detected" in kinds
    temps = [r["value"] for r in apis["cradle"].ingested[0][0] if r["metric"] == "temperature"]
    assert max(temps) > 26


# ---- RNF-01: lo urgente se sube sin esperar el lote ---------------------------

def _cradle_with_max(max_c=26):
    return FakeApi({"commands": [], "detection": None,
                    "config": {"thresholds": {"temperature": {"min": 18, "max": max_c},
                                              "humidity": {"min": 30, "max": 60}}}})


def test_event_is_uploaded_immediately():
    b, link, clock, apis = make()
    b.flush()                                # primer lote (vacío) marca el intervalo
    clock.t += 1
    link.inbox = ["R,5.84,24.1,50.0"]        # presencia => evento
    b.process_serial()
    clock.t += 1                             # 1 s < intervalo de 10 s
    b.flush()
    assert [e["type"] for e in apis["mattress"].ingested[-1][1]] == ["presence_detected"]


def test_threshold_crossing_is_stored_and_uploaded_immediately():
    b, link, clock, apis = make(mattress=FakeApi(), cradle=_cradle_with_max())
    b.poll(force=True)
    assert b.thresholds["temperature"] == (18.0, 26.0)
    link.inbox = ["R,nan,25.0,50.0"]
    b.process_serial()
    b.flush(force=True)                      # sube la lectura normal
    clock.t += 2
    link.inbox = ["R,nan,26.4,50.0"]         # 2 s después: cruza el máximo
    b.process_serial()
    b.flush()
    temps = [r["value"] for r in apis["cradle"].ingested[-1][0] if r["metric"] == "temperature"]
    assert temps == [26.4]


def test_staying_out_of_range_does_not_upload_every_sample():
    b, link, clock, apis = make(mattress=FakeApi(), cradle=_cradle_with_max())
    b.poll(force=True)
    link.inbox = ["R,nan,27.0,50.0"]
    b.process_serial()
    b.flush(force=True)
    sent = len(apis["cradle"].ingested)
    clock.t += 2
    link.inbox = ["R,nan,27.2,50.0"]         # sigue alta: no es urgente
    b.process_serial()
    b.flush()
    assert len(apis["cradle"].ingested) == sent


def test_back_to_normal_is_urgent_too():
    b, link, clock, apis = make(mattress=FakeApi(), cradle=_cradle_with_max())
    b.poll(force=True)
    link.inbox = ["R,nan,27.0,50.0"]
    b.process_serial()
    b.flush(force=True)
    clock.t += 2
    link.inbox = ["R,nan,25.5,50.0"]         # vuelve al rango: reinicia alert_state
    b.process_serial()
    b.flush()
    temps = [r["value"] for r in apis["cradle"].ingested[-1][0] if r["metric"] == "temperature"]
    assert temps == [25.5]


def test_malformed_thresholds_are_ignored():
    cradle = FakeApi({"commands": [], "detection": None,
                      "config": {"thresholds": {"temperature": {"min": "x", "max": None},
                                                "humidity": "raro"}}})
    b, link, clock, apis = make(mattress=FakeApi(), cradle=cradle)
    b.poll(force=True)
    assert b.thresholds == {"temperature": (None, None)}
