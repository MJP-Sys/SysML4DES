// NEGATIVE TEST: the OMG pilot must REJECT this file.
// A conditional (guarded) succession written directly in a part,
// i.e. the system-side event graph Gerd Wagner wanted to write.
// The guarded form "first a if g then b;" is in the grammar for
// action bodies, but not for part bodies.
package ConditionalSuccessionInPart {
    private import ScalarValues::Boolean;

    part def WorkStation {
        attribute available : Boolean;

        action arrival;
        action processingStart;

        first arrival if available then processingStart;
    }
}
