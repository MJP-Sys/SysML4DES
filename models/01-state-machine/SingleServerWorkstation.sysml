// Single-server workstation, station-centred.
// The station's own behaviour is a state machine the part exhibits.
// "An arrival starts processing only if the station is available" is
// a guarded, triggered transition: legal in a part, no annotation needed.
package SingleServerWorkstation {
    private import ScalarValues::*;
    private import ISQ::DurationValue;
    private import SI::s;

    attribute def Arrival;

    part def WorkStation {
        attribute processingTime : DurationValue;
        attribute waiting : Integer := 0;

        exhibit state workStationBehaviour parallel {
            // Region 1: the input buffer counts arrivals.
            state inputBuffer {
                entry; then holding;
                state holding;
                transition holdOnArrival
                    first holding
                    accept Arrival
                    do assign waiting := waiting + 1
                    then holding;
            }
            // Region 2: the server takes the next item when one is waiting.
            state server {
                entry; then available;
                state available;
                state busy;
                transition startProcessing
                    first available
                    accept when waiting > 0
                    do assign waiting := waiting - 1
                    then busy;
                transition endAndIdle
                    first busy
                    accept after processingTime
                    if waiting == 0
                    then available;
                transition endAndStartNext
                    first busy
                    accept after processingTime
                    if waiting > 0
                    do assign waiting := waiting - 1
                    then busy;
            }
        }
    }

    part def ArrivalSource {
        attribute interarrivalTime : DurationValue;
        ref part target : WorkStation;
        exhibit state arrivals {
            entry; then running;
            state running;
            transition arrive
                first running
                accept after interarrivalTime
                do send new Arrival() to target
                then running;
        }
    }

    part singleWorkStationSystem {
        part workStation : WorkStation { :>> processingTime = 4 [s]; }
        part source : ArrivalSource {
            :>> interarrivalTime = 5 [s];
            :>> target = workStation;
        }
    }
}
