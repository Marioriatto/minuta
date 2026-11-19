import pytest

from colchon_bridge.calibrate import calibrate
from tests.test_bridge import ListLink


class RawLink(ListLink):
    def __init__(self, raw):
        super().__init__()
        self.raw = raw

    def write(self, line):
        super().write(line)
        if line == "RAW":
            self.inbox.append(f"X,{self.raw}")


def test_calibrate_computes_and_sends_factor():
    link = RawLink(21000.0)
    factor = calibrate(link, 2.0, prompt=lambda _: "", sleep=lambda _: None)
    assert factor == 10500.0
    assert link.written == ["TARE", "RAW", "CAL,10500.0000"]


def test_calibrate_rejects_near_zero():
    with pytest.raises(ValueError):
        calibrate(RawLink(3.0), 2.0, prompt=lambda _: "", sleep=lambda _: None)
