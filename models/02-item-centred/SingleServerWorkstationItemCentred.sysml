// Single-server workstation, item-centred (the Arena / SimPy view).
// Each work item performs its own route, an action. The server is a
// resource: items request it, wait for a grant, use it, release it.
// The server serialises grants in a state machine with a FIFO queue,
// so two items can never seize it at once.
package SingleServerWorkstationItemCentred {
    private import ScalarValues::*;
    private import SequenceFunctions::*;
    private import ISQ::DurationValue;
    private import SI::s;

    attribute def Request { ref part requester : WorkItem; }
    attribute def Grant;
    attribute def Release;

    part def Server {
        attribute processingTime : DurationValue;
        ref part queue : WorkItem[0..*] ordered nonunique;

        exhibit state serverBehaviour {
            entry; then idle;
            state idle;
            state busy;

            transition grantAtOnce
                first idle
                accept req : Request
                do send new Grant() to req.requester
                then busy;
            transition enqueue
                first busy
                accept req : Request
                do assign queue := including(queue, req.requester)
                then busy;
            transition releaseToIdle
                first busy
                accept Release
                if isEmpty(queue)
                then idle;
            transition releaseToNext
                first busy
                accept Release
                if notEmpty(queue)
                do action grantNext {
                    first start;
                    then send new Grant() to head(queue);
                    then assign queue := tail(queue);
                    then done;
                }
                then busy;
        }
    }

    // The route every item follows. Successions in an action may carry
    // guards ("first a if g then b", see 00-restriction). This route needs
    // none: the server's state machine decides who goes next.
    action def Route {
        in workItem : WorkItem;

        first start;
        then action arrive accept after workItem.arrivalTime;
        then action request send new Request(workItem) to workItem.station;
        then action waitForGrant accept Grant;
        then action process accept after workItem.station.processingTime;
        then action release send new Release() to workItem.station;
        then done;
    }

    part def WorkItem {
        attribute arrivalTime : DurationValue;   // offset from the start of the run
        ref part station : Server;
        perform action route : Route {
            in workItem = that;
        }
    }

    part itemCentredSystem {
        part workStation : Server { :>> processingTime = 4 [s]; }
        // A burst, so a queue forms. Known answer (reference/):
        // processing starts at 0, 4, 8, 12 s; waits 0, 3, 6, 2 s.
        part item1 : WorkItem { :>> arrivalTime = 0 [s];  :>> station = workStation; }
        part item2 : WorkItem { :>> arrivalTime = 1 [s];  :>> station = workStation; }
        part item3 : WorkItem { :>> arrivalTime = 2 [s];  :>> station = workStation; }
        part item4 : WorkItem { :>> arrivalTime = 10 [s]; :>> station = workStation; }
    }
}
