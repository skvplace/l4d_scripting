        <KeyWord name="RTimerCreate" func="yes">
            <Overload retVal="native Handle" descr="
Params:
    interval                Timer interval in seconds.
    func                    Function to execute once the given interval has elapsed.
    value                   Any value (int or float) passed when creating the timer.
                            If a handle is passed, it must be deleted in the callback
                            function or the TIMER_DATA_HNDL_CLOSE flag must be specified.
    flags                   Timer flags.
Notes:
    Creates a round timer.  Calling CloseHandle() on a timer will end the timer.
Return:
    Handle to the timer object.  You do not need to call CloseHandle().
    If the timer could not be created, INVALID_HANDLE will be returned.
Error:
    Attempt to create a timer outside of a round.
">
                <Param name="float interval"/>
                <Param name="Timer func"/>
                <Param name="any data=INVALID_HANDLE"/>
                <Param name="int flags=0"/>
            </Overload>
        </KeyWord>
        <KeyWord name="RTimerDataCreate" func="yes">
            <Overload retVal="stock Handle" descr="
Params:
    interval                Timer interval in seconds.
    func                    Function to execute once the given interval has elapsed.
    datapack                DataPack passed when creating the timer,
                            you do not need to call CloseHandle().
    flags                   Timer flags.
Notes:
    Creates a round timer associated with a new datapack, and returns the datapack.
    The datapack is automatically freed when the timer ends.
    The position of the datapack is not reset or changed for the timer function.
Return:
    Handle to the timer object. You do not need to call CloseHandle().
    If the timer could  not be created, INVALID_HANDLE will be returned.
Error:
    Attempt to create a timer outside of a round.
">
                <Param name="float interval"/>
                <Param name="Timer func"/>
                <Param name="Handle &amp;datapack"/>
                <Param name="int flags=0"/>
            </Overload>
        </KeyWord>
        <KeyWord name="RTimerKill" func="yes">
            <Overload retVal="native bool" descr="
Params:
    timer                   Timer Handle to kill.
    autoClose               If autoClose is true, the data that was passed to CreateTimer() will
                            be closed as a handle if TIMER_DATA_HNDL_CLOSE was not specified.
Notes:
    Kills a timer.  Use this instead of CloseHandle() if you need more options.
">
                <Param name="Handle timer"/>
                <Param name="bool autoClose=false"/>
            </Overload>
        </KeyWord>
        <KeyWord name="RTimerRemove" func="yes">
            <Overload retVal="native bool" descr="
Params:
    timer                   Handle to the timer object.
Notes:
    Removes the timer
">
                <Param name="Handle timer"/>
            </Overload>
        </KeyWord>
        <KeyWord name="RTimerTrigger" func="yes">
            <Overload retVal="native bool" descr="
Params:
    timer                   Handle to the timer object.
Notes:
    Manually triggers a timer so its function will be called.
">
                <Param name="Handle timer"/>
            </Overload>
        </KeyWord>
        <KeyWord name="RTimerPause" func="yes">
            <Overload retVal="native bool" descr="
Params:
    timer                   Handle to the timer object.
    pause                   1 and the timer is paused and 0 is unpaused.
Notes:
    Pauses the timer.
">
                <Param name="Handle timer"/>
                <Param name="int pause"/>
            </Overload>
        </KeyWord>
        <KeyWord name="RTimerGetRemaining" func="yes">
            <Overload retVal="native float" descr="
Params:
    timer                   Handle to the timer object.
Notes:
    Returns the remaining time, or 0 if unsuccessful.
">
                <Param name="Handle timer"/>
            </Overload>
        </KeyWord>
        <KeyWord name="RTimerGetInterval" func="yes">
            <Overload retVal="native float" descr="
Params:
    timer                   Handle to the timer object.
Notes:
    Returns the timer interval, or 0 if unsuccessful.
">
                <Param name="Handle timer"/>
            </Overload>
        </KeyWord>
        <KeyWord name="RTimerSetInterval" func="yes">
            <Overload retVal="native bool" descr="
Params:
    timer                   Handle to the timer object.
    interval                Interval in seconds.
Notes:
    Pauses the timer.
">
                <Param name="Handle timer"/>
                <Param name="float interval"/>
            </Overload>
        </KeyWord>
        <KeyWord name="RTimerGetId" func="yes">
            <Overload retVal="native int" descr="
Params:
    timer                   Handle to the timer object.
Notes:
    Returns the timer Id, or 0 if unsuccessful.
">
                <Param name="Handle timer"/>
            </Overload>
        </KeyWord>
        <KeyWord name="RTimerGetFlags" func="yes">
            <Overload retVal="native int" descr="
Params:
    timer                   Handle to the timer object.
Notes:
    Returns the timer flags, or -1 if unsuccessful.
">
                <Param name="Handle timer"/>
            </Overload>
        </KeyWord>
        <KeyWord name="RTimerGetValue" func="yes">
            <Overload retVal="native any" descr="
Params:
    timer                   Handle to the timer object.
Notes:
    Returns the value passed to the timer callback function, or 0 if unsuccessful.
">
                <Param name="Handle timer"/>
            </Overload>
        </KeyWord>
        <KeyWord name="RTimerSetValue" func="yes">
            <Overload retVal="native bool" descr="
Params:
    timer                   Handle to the timer object.
    value                   Any value.
Notes:
    Sets a new timer value.
">
                <Param name="Handle timer"/>
                <Param name="any value"/>
            </Overload>
        </KeyWord>
        <KeyWord name="RTimerAddInterval" func="yes">
            <Overload retVal="native bool" descr="
Params:
    timer                   Handle to the timer object.
    seconds                 Number of seconds.
Notes:
    Adds a timer interval (for repeating timers, until the next expiration)
">
                <Param name="Handle timer"/>
                <Param name="float seconds"/>
            </Overload>
        </KeyWord>
        <KeyWord name="RTimerSubInterval" func="yes">
            <Overload retVal="native bool" descr="
Params:
    timer                   Handle to the timer object.
    seconds                 Number of seconds.
Notes:
    Decrements the timer interval (for repeating timers, until the next expiration),
    if the received interval is less than 0, the timer fires.
">
                <Param name="Handle timer"/>
                <Param name="float seconds"/>
            </Overload>
        </KeyWord>
        <KeyWord name="RTimerShift" func="yes">
            <Overload retVal="native bool" descr="
Params:
    timer                   Handle to the timer object.
    seconds                 Number of seconds.
Notes:
    Shift the timer's expiration,
    if the received interval is less than 0, the timer fires.
">
                <Param name="Handle timer"/>
                <Param name="float seconds"/>
            </Overload>
        </KeyWord>