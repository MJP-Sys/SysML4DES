# SysML4DES

SysML v2 for discrete-event simulation (DES) modelling.

This repository holds complete, standard SysML v2 models of a single-server
workstation, written two ways, with **no control flow carried in metadata
annotations**, plus known answers that any SysML v2 executor can be checked
against.

## Background

Gerd Wagner set out to propose SysML v2 for DES modelling and got stuck
(LinkedIn, November 2026). In an event graph in Schruben's sense, the step
"an arrival leads to processing start *only if the station is available*" is
a conditional succession. SysML v2 accepts `first a if g then b;` inside an
action, but not inside a part, so the system-side event graph cannot be
written on the part that owns it. His workaround is a `@SuccessionCondition`
metadata annotation, whose meaning is then defined by whichever simulator
reads it.

This repository:

1. reproduces the restriction on the OMG pilot implementation;
2. writes the same workstation in standard SysML v2 in two ways that need no
   annotation;
3. gives known answers (Lindley's recursion, Pollaczek–Khinchine) that both
   formulations must reproduce;
4. states what is still missing from the language.

## Contents

| Path | What it is |
|---|---|
| `models/00-restriction/ConditionalSuccessionInPart.sysml` | Negative test: a guarded succession in a part. The pilot must reject it. |
| `models/00-restriction/ConditionalSuccessionInAction.sysml` | Control: the same guarded succession in an action. Accepted. |
| `models/01-state-machine/SingleServerWorkstation.sysml` | Station-centred: the station's behaviour is a state machine the part exhibits. |
| `models/02-item-centred/SingleServerWorkstationItemCentred.sysml` | Item-centred (Arena / SimPy view): each item performs a route; the server is a resource with a FIFO queue. |
| `reference/known_answers.py` | Lindley's recursion and hand translations of both models. |
| `tests/test_known_answers.py` | Both translations must match Lindley exactly, and the M/D/1 mean wait over a long run. |
| `tools/` | Pilot download, strict validator, and the script CI runs. |

## 1. The restriction

On the OMG SysML v2 pilot implementation 0.63.1:

```sysml
part def WorkStation {
    attribute available : Boolean;
    action arrival;
    action processingStart;
    first arrival if available then processingStart;   // rejected
}
```

```
ERROR: mismatched input 'if' expecting 'then'
```

It is a grammar-level rejection, not a validation rule. Only the guard is
refused: the unguarded `first arrival then processingStart;` is accepted in
the part, and the guarded line is accepted inside an `action def`, both with
no errors or warnings.

## 2. Station-centred: a state machine the part exhibits

Each event-graph vertex and edge maps to a guarded, triggered transition,
which SysML v2 allows on a part:

| Event graph | State machine (`WorkStation`) |
|---|---|
| Arrival event, `Q := Q + 1` | `holdOnArrival`: `accept Arrival do assign waiting := waiting + 1` |
| Arrival → ProcessingStart, *if server available* | `startProcessing`: from `available`, `accept when waiting > 0` |
| ProcessingStart → ProcessingEnd, delay *s* | `accept after processingTime` from `busy` |
| ProcessingEnd → ProcessingStart, *if Q > 0* | `endAndStartNext`: guard `if waiting > 0` |
| ProcessingEnd, *if Q = 0* | `endAndIdle`: guard `if waiting == 0` |

The two regions (input buffer, server) run in parallel. The instance
`singleWorkStationSystem` has an arrival every 5 s and a processing time of
4 s.

This is the operational form of the event graph, not the declarative one
Wagner was after (see [the gap](#the-gap)).

## 3. Item-centred: the route is an action, the server is a resource

This is the view Arena (Seize / Delay / Release) and SimPy
(`Resource.request()` / `release()`) take. Each `WorkItem` performs a
`Route`:

```
arrive (accept after arrivalTime) → send Request → accept Grant
       → process (accept after processingTime) → send Release
```

The `Server` serialises grants in its own state machine: grant at once when
idle, otherwise append the requester to an ordered queue; on release, grant
the head of the queue or go idle. Because only the server grants, two items
can never seize it at the same time, and the discipline is FIFO by
construction.

Guarded successions are legal inside `Route` (it is an action), so branches
such as "if inspection fails, go to rework" can be written there directly.
This single-server route does not need one.

The instance `itemCentredSystem` has four items arriving at 0, 1, 2 and 10 s,
so a queue forms.

## 4. Known answers

`reference/known_answers.py` computes processing start times three
independent ways:

- **Lindley's recursion** for a single FIFO server:
  W<sub>n+1</sub> = max(0, W<sub>n</sub> + S − (A<sub>n+1</sub> − A<sub>n</sub>));
- a hand translation of the **state machine** (model 01);
- a hand translation of the **request / grant / release** protocol (model 02).

For the item-centred instance (service time 4 s):

| Item | Arrives | Starts | Waits |
|---|---|---|---|
| 1 | 0 | 0 | 0 |
| 2 | 1 | 4 | 3 |
| 3 | 2 | 8 | 6 |
| 4 | 10 | 12 | 2 |

The station-centred instance (arrival every 5 s, service 4 s) never queues.

The tests also run both translations on simultaneous arrivals and on Poisson
arrivals, and check the mean wait over 200,000 arrivals against the
Pollaczek–Khinchine value for M/D/1 (λ = 0.2/s, S = 4 s, ρ = 0.8,
W<sub>q</sub> = 8 s).

## What this shows, and what it does not

**Shown.** All models parse and validate on the OMG pilot 0.63.1 in strict
mode (zero errors, zero warnings), and the negative test is rejected. CI
repeats this on every push.

**Not shown.** The models have not been executed by a SysML v2 engine. The
numbers come from hand translations in Python, not from the SysML files. If
you run the models on an executor (OpenSysML's MDK, for example, executes
action and state behaviour), please open an issue or a PR with the trace and
the start times; they should match the table above.

Points of semantics an executor has to get right for these models:

- `accept when` is a change trigger: it fires when the condition goes from
  false to true. Model 01 relies on `available` being entered only with
  `waiting == 0`, so no change is missed.
- When an arrival and the end of processing happen at the same instant,
  either order gives the same start times.
- In model 01, an assignment in one parallel region must be visible to the
  change trigger in the other.
- In model 02, `accept Grant` inside an item's route must receive the
  `Grant` the server sends to that item.

## The gap

A declarative event graph written on the part, with conditional scheduling
edges between its events, still has no first-class home in SysML v2. The
state machine above is the operational equivalent, not the same thing.

Two directions worth raising with the SysML v2 RTF (for discussion, not
settled here):

1. allow guarded successions between event occurrences in part (occurrence)
   bodies, with the same meaning they have in actions;
2. a standard library for DES primitives (resources, queues with a defined
   discipline, scheduled events with delays and conditions) whose semantics
   are given in KerML, so item-centred models do not depend on each tool's
   own definition of a queue.

Either way, a condition should not live in a metadata annotation: a
condition in an annotation means whatever one simulator decides it means.

## Running the checks

Requires Java 17+, Python 3.12+, `curl` and `unzip`.

```bash
pip install zstandard pytest
export SYSML_PILOT="$(tools/get-pilot.sh)"   # downloads pilot 0.63.1 from conda-forge
tools/validate.sh                             # strict validation + negative test
python -m pytest -q                           # known answers
python reference/known_answers.py             # print the tables
```

## Contributing

Issues and PRs are welcome, especially:

- execution traces from any SysML v2 executor;
- Wagner's full event graph written in either form;
- further patterns: branching, rework loops, batching, multiple servers.

## License

Apache License 2.0. See [LICENSE](LICENSE).
