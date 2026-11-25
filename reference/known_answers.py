"""Known answers for the single-server workstation.

Three independent computations of when each item starts processing:

1. ``lindley``         - the textbook recursion for a single FIFO server,
                         W[n+1] = max(0, W[n] + S - (A[n+1] - A[n])).
2. ``station_centred`` - a hand translation of the state machine in
                         models/01-state-machine (waiting counter, server
                         regions available/busy, guarded transitions).
3. ``item_centred``    - a hand translation of the request / grant / release
                         protocol in models/02-item-centred (each item runs
                         its route; the server keeps a FIFO queue).

2 and 3 are written by hand from the models; they are NOT generated from the
SysML files. They give the numbers any SysML v2 executor should reproduce
when it runs those models. Times are in seconds, service time is constant.
"""

from __future__ import annotations

import heapq
import itertools
from collections import deque


def lindley(arrivals: list[float], service: float) -> list[float]:
    """Waiting time in queue of each item (arrivals sorted ascending)."""
    waits: list[float] = []
    w = 0.0
    for n, a in enumerate(arrivals):
        if n > 0:
            w = max(0.0, w + service - (a - arrivals[n - 1]))
        waits.append(w)
    return waits


class _Events:
    """Minimal event list: (time, sequence, callback)."""

    def __init__(self) -> None:
        self._heap: list = []
        self._seq = itertools.count()
        self.now = 0.0

    def at(self, t: float, fn) -> None:
        heapq.heappush(self._heap, (t, next(self._seq), fn))

    def run(self) -> None:
        while self._heap:
            self.now, _, fn = heapq.heappop(self._heap)
            fn()


def station_centred(arrivals: list[float], service: float) -> list[float]:
    """Processing start times, following SingleServerWorkstation.sysml.

    The counter `waiting` does not record which item is which; with a
    constant service time the start times do not depend on the order
    items are taken in, so the k-th start belongs to the k-th arrival.
    """
    ev = _Events()
    state = {"waiting": 0, "server": "available"}
    starts: list[float] = []

    def start_processing() -> None:            # do assign waiting := waiting - 1
        state["waiting"] -= 1
        state["server"] = "busy"
        starts.append(ev.now)
        ev.at(ev.now + service, end_processing)  # accept after processingTime

    def on_arrival() -> None:                  # holdOnArrival
        state["waiting"] += 1
        # startProcessing: accept when waiting > 0, from 'available'
        if state["server"] == "available" and state["waiting"] > 0:
            start_processing()

    def end_processing() -> None:
        if state["waiting"] == 0:              # endAndIdle   [waiting == 0]
            state["server"] = "available"
        else:                                  # endAndStartNext [waiting > 0]
            start_processing()

    for a in arrivals:
        ev.at(a, on_arrival)
    ev.run()
    return starts


def item_centred(arrivals: list[float], service: float) -> list[float]:
    """Processing start times per item, following the item-centred model."""
    ev = _Events()
    server = {"state": "idle", "queue": deque()}
    starts: dict[int, float] = {}

    def grant(item: int) -> None:              # item: accept Grant
        starts[item] = ev.now
        ev.at(ev.now + service, lambda: release())  # accept after processingTime

    def request(item: int) -> None:            # server: accept req : Request
        if server["state"] == "idle":          # grantAtOnce
            server["state"] = "busy"
            grant(item)
        else:                                  # enqueue
            server["queue"].append(item)

    def release() -> None:                     # server: accept Release
        if not server["queue"]:                # releaseToIdle [isEmpty(queue)]
            server["state"] = "idle"
        else:                                  # releaseToNext [notEmpty(queue)]
            grant(server["queue"].popleft())

    for i, a in enumerate(arrivals):
        ev.at(a, lambda i=i: request(i))       # arrive; then request
    ev.run()
    return [starts[i] for i in range(len(arrivals))]


def waits_from_starts(arrivals: list[float], starts: list[float]) -> list[float]:
    return [s - a for a, s in zip(arrivals, starts)]


def pollaczek_khinchine_md1(arrival_rate: float, service: float) -> float:
    """Mean wait in queue for M/D/1: Wq = rho * S / (2 * (1 - rho))."""
    rho = arrival_rate * service
    return rho * service / (2.0 * (1.0 - rho))


if __name__ == "__main__":
    for name, arrivals in {
        "state-machine instance (every 5 s)": [5.0 * k for k in range(1, 7)],
        "item-centred instance (burst)": [0.0, 1.0, 2.0, 10.0],
    }.items():
        print(name)
        print("  arrivals      ", arrivals)
        print("  Lindley waits ", lindley(arrivals, 4.0))
        print("  station starts", station_centred(arrivals, 4.0))
        print("  item starts   ", item_centred(arrivals, 4.0))
