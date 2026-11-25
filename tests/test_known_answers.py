"""Both formulations must agree with Lindley's recursion, and with the
Pollaczek-Khinchine mean for M/D/1 over a long run. Run: python -m pytest"""

import random
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "reference"))

from known_answers import (  # noqa: E402
    item_centred,
    lindley,
    pollaczek_khinchine_md1,
    station_centred,
    waits_from_starts,
)

SERVICE = 4.0


def _random_arrivals(n: int, mean_gap: float, seed: int) -> list[float]:
    rng = random.Random(seed)
    t, out = 0.0, []
    for _ in range(n):
        t += rng.expovariate(1.0 / mean_gap)
        out.append(t)
    return out


SCENARIOS = {
    "periodic-5s (state-machine instance)": [5.0 * k for k in range(1, 21)],
    "burst (item-centred instance)": [0.0, 1.0, 2.0, 10.0],
    "simultaneous arrivals": [0.0, 0.0, 0.0, 4.0, 4.0],
    "poisson-200": _random_arrivals(200, 5.0, seed=1),
}


@pytest.mark.parametrize("name", SCENARIOS)
@pytest.mark.parametrize("model", [station_centred, item_centred])
def test_matches_lindley(name, model):
    arrivals = SCENARIOS[name]
    expected = lindley(arrivals, SERVICE)
    got = waits_from_starts(arrivals, model(arrivals, SERVICE))
    assert got == pytest.approx(expected, abs=1e-9)


def test_burst_values_written_in_the_model():
    arrivals = [0.0, 1.0, 2.0, 10.0]
    assert item_centred(arrivals, SERVICE) == [0.0, 4.0, 8.0, 12.0]
    assert lindley(arrivals, SERVICE) == [0.0, 3.0, 6.0, 2.0]


def test_periodic_instance_never_queues():
    arrivals = SCENARIOS["periodic-5s (state-machine instance)"]
    assert all(w == 0.0 for w in lindley(arrivals, SERVICE))


@pytest.mark.parametrize("model", [station_centred, item_centred])
def test_md1_mean_wait_matches_pollaczek_khinchine(model):
    # lambda = 0.2 /s, S = 4 s, rho = 0.8 -> Wq = 8 s
    arrivals = _random_arrivals(200_000, 5.0, seed=7)
    waits = waits_from_starts(arrivals, model(arrivals, SERVICE))
    mean = sum(waits) / len(waits)
    assert mean == pytest.approx(pollaczek_khinchine_md1(0.2, SERVICE), rel=0.05)
