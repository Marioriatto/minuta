from colchon_bridge.logic import MattressLogic


def types(events):
    return [e.type for e in events]


def test_presence_when_weight_appears():
    m = MattressLogic()
    assert types(m.update(0.0, 0, True)) == []
    assert types(m.update(5.8, 2, True)) == ["presence_detected"]
    assert types(m.update(5.8, 4, True)) == []


def test_absence_only_after_confirmation_and_with_detection():
    m = MattressLogic(absence_confirm_s=10)
    m.update(5.8, 0, True)
    assert types(m.update(0.0, 5, True)) == []
    assert types(m.update(0.0, 14, True)) == []          # 9 s
    assert types(m.update(0.0, 16, True)) == ["absence_detected"]
    assert types(m.update(0.0, 30, True)) == []          # no se repite


def test_brief_dip_does_not_raise_absence():
    m = MattressLogic(absence_confirm_s=10)
    m.update(5.8, 0, True)
    m.update(0.5, 4, True)
    assert types(m.update(5.8, 8, True)) == []
    assert types(m.update(0.5, 20, True)) == []          # el contador se reinició


def test_no_absence_without_detection_period():
    m = MattressLogic(absence_confirm_s=1)
    m.update(5.8, 0, False)
    assert types(m.update(0.0, 5, False)) == []
    assert types(m.update(0.0, 8, False)) == []
    assert m.present is False


def test_movement_with_cooldown():
    m = MattressLogic(movement_delta_kg=0.15, movement_cooldown_s=30)
    m.update(5.8, 0, True)
    assert types(m.update(6.1, 2, True)) == ["movement_detected"]
    assert types(m.update(5.8, 10, True)) == []          # dentro del enfriamiento
    assert types(m.update(6.5, 40, True)) == ["movement_detected"]


def test_no_movement_without_detection_period():
    m = MattressLogic()
    m.update(5.8, 0, False)
    assert types(m.update(6.5, 2, False)) == []


def test_slow_drift_is_not_movement():
    m = MattressLogic(movement_delta_kg=0.15)
    m.update(5.8, 0, True)
    w, t = 5.8, 0
    for _ in range(40):
        w += 0.01
        t += 10
        assert types(m.update(w, t, True)) == []
