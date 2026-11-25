// Single-server workstation as Schruben's event graph, declared on the part.
// The graph lives in an action the part performs. Guarded successions are
// legal there (they are TransitionUsages, i.e. Action::transitions), so each
// conditional scheduling edge is written as-is, with no annotation.
//
//   Arrival         --(ta)-->                 Arrival
//   Arrival         --(0, if not busy)-->     ProcessingStart
//   ProcessingStart --(ts)-->                 ProcessingEnd
//   ProcessingEnd   --(0, if queue > 0)-->    ProcessingStart
//
// Vertices change state; edges carry a delay (an accept after) and a guard.
// Vertices reached by more than one edge are merge nodes, so the cycles
// of the graph are ordinary control-flow loops.
package WorkstationEventGraph {
    private import ScalarValues::*;
    private import ISQ::DurationValue;
    private import SI::s;

    part def WorkStation {
        attribute interarrivalTime : DurationValue;
        attribute processingTime : DurationValue;
        attribute queueLength : Integer := 0;
        attribute busy : Boolean := false;

        perform action eventGraph {
            first start;
            then merge toArrival;

            // Vertex: Arrival  { Q := Q + 1 }
            then action arrival assign queueLength := queueLength + 1;
            then fork afterArrival;
                then scheduleNextArrival;
                then checkServer;

            // Edge: Arrival -> Arrival, delay ta
            action scheduleNextArrival accept after interarrivalTime;
            then toArrival;

            // Edge: Arrival -> ProcessingStart, if server not busy
            decide checkServer;
                if not busy then toStart;
                else serverBusy;
            action serverBusy;   // edge condition false: nothing scheduled

            // Vertex: ProcessingStart  { Q := Q - 1; S := busy }
            merge toStart;
            then action processingStart {
                first start;
                then assign queueLength := queueLength - 1;
                then assign busy := true;
                then done;
            }

            // Edge: ProcessingStart -> ProcessingEnd, delay ts
            then action serviceDelay accept after processingTime;

            // Vertex: ProcessingEnd  { S := idle }
            then action processingEnd assign busy := false;

            // Edge: ProcessingEnd -> ProcessingStart, if queue not empty
            then decide checkQueue;
                if queueLength > 0 then toStart;
                else queueEmpty;
            action queueEmpty;
        }
    }

    part workstation : WorkStation {
        :>> interarrivalTime = 5 [s];
        :>> processingTime = 4 [s];
    }
}
