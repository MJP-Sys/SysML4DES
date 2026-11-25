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
3. writes Wagner's event graph itself on the part, in a form the pilot
   accepts today;
4. gives known answers (Lindley's recursion, Pollaczek–Khinchine) that every
   formulation must reproduce;
5. proposes [a fix](#the-fix): the execution rules an executor needs, and a
   small language change.

## Contents

| Path | What it is |
|---|---|
| `models/00-restriction/ConditionalSuccessionInPart.sysml` | Negative test: a guarded succession in a part. The pilot must reject it. |
| `models/00-restriction/ConditionalSuccessionInAction.sysml` | Control: the same guarded succession in an action. Accepted. |
| `models/01-state-machine/SingleServerWorkstation.sysml` | Station-centred: the station's behaviour is a state machine the part exhibits. |
| `models/02-item-centred/SingleServerWorkstationItemCentred.sysml` | Item-centred (Arena / SimPy view): each item performs a route; the server is a resource with a FIFO queue. |
| `models/03-event-graph/WorkstationEventGraph.sysml` | Schruben's event graph declared on the part, inside an action the part performs. |
| `reference/known_answers.py` | Lindley's recursion and hand translations of models 01–03. |
| `tests/test_known_answers.py` | Every translation must match Lindley exactly, and the M/D/1 mean wait over a long run. |
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

It is a grammar-level rejection, not a validation rule, and it follows from
the semantics: `first a if g then b` parses as a `GuardedSuccession`, which
is a `TransitionUsage`. In the library a transition of that kind is a
`TransitionAction`, held in `Actions::Action::transitions :> subactions`.
Actions have that feature; parts do not. Only the guard is
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

This is the operational form of the event graph. Model 03 keeps the
event-graph form itself.

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

## 4. The event graph on the part, in a performed action

Model 03 keeps Wagner's event-graph view: the station owns its events, and
the scheduling edges carry conditions. The graph sits in
`perform action eventGraph { ... }` inside `part def WorkStation`, where
guarded successions are legal.

| Event graph | In `eventGraph` |
|---|---|
| Vertex with state change | an action, e.g. `action arrival assign queueLength := queueLength + 1` |
| Edge with delay *t* | `accept after t` on the path |
| Edge condition | `decide; if not busy then toStart; else serverBusy;` |
| Vertex with several incoming edges | a `merge` node; cycles become control-flow loops |
| Several outgoing edges | a `fork` |

Loops through merge nodes are standard SysML v2 (see the training example
`17. Control/Decision Example.sysml` in the pilot release).

## 5. Known answers

`reference/known_answers.py` computes processing start times four
independent ways:

- **Lindley's recursion** for a single FIFO server:
  W<sub>n+1</sub> = max(0, W<sub>n</sub> + S − (A<sub>n+1</sub> − A<sub>n</sub>));
- a hand translation of the **state machine** (model 01);
- a hand translation of the **request / grant / release** protocol (model 02);
- a hand translation of the **event graph** (model 03).

For the item-centred instance (service time 4 s):

| Item | Arrives | Starts | Waits |
|---|---|---|---|
| 1 | 0 | 0 | 0 |
| 2 | 1 | 4 | 3 |
| 3 | 2 | 8 | 6 |
| 4 | 10 | 12 | 2 |

The station-centred instance (arrival every 5 s, service 4 s) never queues.

The tests also run every translation on simultaneous arrivals and on Poisson
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
- In model 03, a vertex and the evaluation of its outgoing conditions happen
  as one step, and an edge with no delay completes in that same step, before
  any other event at the same instant. Otherwise two simultaneous arrivals
  both see the server free and start it twice; a test demonstrates this.

## The fix

What remains missing is the notation: Wagner's original text, with the
guarded successions written directly in the part body. Model 03 already
shows the meaning that text should have. So the proposal has two parts.

**1. Execution rules (no language change; an executor can adopt them now).**

- A vertex (an action between delays) and the evaluation of the guards on
  its outgoing successions are atomic.
- Control flow with no `accept` completes in the same step as its source, so
  zero-delay edges fire before any other event at that instant (Schruben's
  priority rule).
- `accept when` fires on a false-to-true change.
- A sub-action reached through a `merge` may be performed repeatedly within
  one performance of its owning action.

The hand translations in `reference/` follow these rules, and a test shows
what breaks when the zero-delay rule is dropped.

**2. Language change (for the SysML v2 RTF).** Allow guarded successions,
and the control nodes they need, in the bodies of occurrence definitions and
usages (parts included). Define them as notation: the behavioural members of
such a body (its actions, control nodes and successions) are the body of an
implicit `perform action`, exactly as model 03 writes by hand. This adds
grammar and one mapping rule, but no new semantics, because the result is
an ordinary performed action whose transitions already belong in
`Action::transitions`. An alternative is to give `Occurrence` its own
`transitions` feature, but that means new library semantics.

A condition should not live in a metadata annotation: a condition in an
annotation means whatever one simulator decides it means.

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
- Wagner's full event graph, in any of the three forms;
- further patterns: branching, rework loops, batching, multiple servers.

## License

Apache License 2.0. See [LICENSE](LICENSE).
