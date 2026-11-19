from colchon_bridge import protocol as p


def test_sample_ok():
    assert p.parse_line("R,5.842,24.10,48.20") == p.Sample(5.842, 24.10, 48.20)


def test_sample_with_failed_sensors():
    assert p.parse_line("R,nan,24.1,nan") == p.Sample(None, 24.1, None)


def test_other_messages():
    assert p.parse_line("B,2") == p.Button(2)
    assert p.parse_line("H,0.1.0") == p.Hello("0.1.0")
    assert p.parse_line("X,-83211.5") == p.RawValue(-83211.5)
    assert p.parse_line("K,LED") == p.Ack("LED")
    assert p.parse_line("E,aht20_not_found") == p.DeviceError("aht20_not_found")


def test_garbage_is_ignored():
    for bad in ["", "R,1,2", "R,a,b,c,d", "B,x", "X,abc", "zzz", "R,inf,1,2"]:
        msg = p.parse_line(bad)
        assert msg is None or (isinstance(msg, p.Sample) and msg.weight_kg is None), bad


def test_commands_are_clamped():
    assert p.cmd_light(True, 150, -5) == "LIGHT,1,100,0"
    assert p.cmd_light(False, 40, 60) == "LIGHT,0,40,60"
    assert p.cmd_buzz(99999) == "BUZ,5000"
    assert p.cmd_buzz(0) == "BUZ,1"
