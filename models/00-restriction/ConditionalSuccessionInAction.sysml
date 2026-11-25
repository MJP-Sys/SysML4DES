// POSITIVE CONTROL: the same guarded succession inside an action is accepted.
package ConditionalSuccessionInAction {
    private import ScalarValues::Boolean;

    action def HandleArrival {
        in attribute available : Boolean;

        action arrival;
        action processingStart;

        first arrival if available then processingStart;
    }
}
