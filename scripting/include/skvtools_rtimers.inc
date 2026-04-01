
#if defined _skvtools_rtimers_included
 #endinput
#endif

#define _skvtools_rtimers_included

#include <version>

// tx to @Localia and @Dragokas
#if SOURCEMOD_V_MAJOR > 1 || \
    (SOURCEMOD_V_MAJOR == 1 && SOURCEMOD_V_MINOR > 13) || \
    (SOURCEMOD_V_MAJOR == 1 && SOURCEMOD_V_MINOR == 13 && SOURCEMOD_V_REV >= 7304)
    
    native bool IsValidHandle(Handle hndl);

#endif 

#define RTIMERS_VERSION 				"1.8"
#define TIMER_FLAG_NO_ROUNDCHANGE   	(1<<2)	/* < Timer will not carry over round */

/**
 * Any of the following prototypes will work for a timed function.
 */
typeset RTimer
{
	/**
	 * Called when the timer interval has elapsed.
	 *
	 * @param timer     Handle to the timer object.
	 * @param data      Handle or value passed when timer was created.
	 *
	 * @return          Plugin_Stop to stop a repeating timer, any other value for
	 *                  default behavior.
	 *                  Ignored for non-repeating timers (use void return type).
	 */
	function Action(Handle timer, any data);

	/**
	 * Called when the timer interval has elapsed.
	 * For repeating timers, use the callback with return value.
	 *
	 * @param timer     Handle to the timer object.
	 * @param data      Handle or value passed when timer was created.
	 */
	function void(Handle timer, any data);

	/**
	 * Called when the timer interval has elapsed.
	 *
	 * @param timer     Handle to the timer object.
	 *
	 * @return          Plugin_Stop to stop a repeating timer, any other value for
	 *                  default behavior.
	 *                  Ignored for non-repeating timers (use void return type).
	 */
	function Action(Handle timer);
	
	/**
	 * Called when the timer interval has elapsed.
	 * For repeating timers, use the callback with return value.
	 *
	 * @param timer     Handle to the timer object.
	 */
	function void(Handle timer);
};

/**
 * Creates a round timer.  Calling CloseHandle() on a timer will end the timer.
 *
 * @param interval      Timer interval in seconds.
 * @param func          Function to execute once the given interval has elapsed.
 * @param value         Any value (int or float) passed when creating the timer. 
 *                      If a handle is passed, it must be deleted in the callback
 *                      function or the TIMER_DATA_HNDL_CLOSE flag must be specified.
 * @param flags         Timer flags.
 *
 * @return              Handle to the timer object. You do not need to call CloseHandle(). 
 *                      If the timer could  not be created, INVALID_HANDLE will be returned.
 *
 * @error               Attempt to create a timer outside of a round.
*/

stock Handle RTimerCreate(float interval, RTimer func, any value = 0, int flags = 0)
{
	Handle timer = CreateDataPack();
	if (CreateRTimer(interval, func, value, flags, RTimerClose, timer))
	{
		return timer;
	}
	
	delete timer;
	
	if (flags & TIMER_DATA_HNDL_CLOSE)
	{
		delete view_as<Handle>(value);
	}
	
	return null;
}

/**
 * Creates a round timer associated with a new datapack, and returns the datapack.
 *
 * @param interval      Timer interval in seconds.
 * @param func          Function to execute once the given interval has elapsed.
 * @param datapack      DataPack passed when creating the timer, 
 *                      you do not need to call CloseHandle().
 * @param flags         Timer flags.
 *
 * @return              Handle to the timer object. You do not need to call CloseHandle(). 
 *                      If the timer could  not be created, INVALID_HANDLE will be returned.
 *
 * @error               Attempt to create a timer outside of a round.
*/
stock Handle RTimerDataCreate(float interval, RTimer func, Handle &datapack, int flags = 0)
{
	datapack = CreateDataPack();
	flags |= TIMER_DATA_HNDL_CLOSE;
	
	Handle timer = CreateDataPack();
	if (CreateRTimer(interval, func, datapack, flags, RTimerClose, timer))
	{
		return timer;
	}
	
	if (flags & TIMER_DATA_HNDL_CLOSE)
	{
		delete datapack;
	}
	
	delete timer;
			
	return null;
}

/**
 * Manually starts the timer to call its function.
 *
 * @param timer         Handle to the timer object.
*/
native bool RTimerTrigger(Handle timer);

/**
 * Removes the timer.
 *
 * @param timer         Timer Handle to kill.
 * @param autoClose     If autoClose is true, the data that was passed to CreateTimer() will be closed.
 *
 * @error               Invalid timer handle or invalid data handle.
*/
stock bool RTimerKill(Handle &timer, bool autoClose = false)
{
	if (autoClose)
	{
		int flags = RTimerGetFlags(timer);
		flags |= TIMER_DATA_HNDL_CLOSE;
		
		RTimerSetFlags(timer, flags);
	}
	
	if (RTimerRemove(timer))
	{
		timer = null;
		return true;
	}
	
	timer = null;
	return false;
}

/**
 * Pauses the timer.
 *
 * @param timer         Handle to the timer object.
 * @param pause         1 and the timer is paused and 0 is unpaused.
*/
native bool RTimerPause(Handle timer, int pause);

/**
 * Returns the remaining time, or 0 if unsuccessful.
 *
 * @param timer         Handle to the timer object.
*/
native float RTimerGetRemaining(Handle timer);

/**
 * Returns the timer interval, or 0 if unsuccessful.
 *
 * @param timer         Handle to the timer object.
*/
native float RTimerGetInterval(Handle timer);

/**
 * Sets a new timer interval.
 *
 * @param timer         Handle to the timer object.
 * @param interval      Interval in seconds.
*/
native bool RTimerSetInterval(Handle timer, float interval);

/**
 * Returns the timer flags, or -1 if unsuccessful.
 *
 * @param timer         Handle to the timer object.
*/
native int RTimerGetFlags(Handle timer); 

/**
 * Returns the timer flags, or -1 if unsuccessful.
 *
 * @param timer         Handle to the timer object.
 * @param value         Flags.
*/
native int RTimerSetFlags(Handle timer, int flags);

/**
 * Returns the value passed to the timer callback function, or 0 if unsuccessful.
 *
 * @param timer         Handle to the timer object.
*/
native any RTimerGetValue(Handle timer); 

/**
 * Sets a new timer value.
 *
 * @param timer         Handle to the timer object.
 * @param value         Any value.
*/
stock bool RTimerSetValue(Handle timer, any value)
{
	if (RTimerGetFlags(timer) & TIMER_DATA_HNDL_CLOSE)
	{
		delete view_as<Handle>(RTimerGetValue(timer));
	}
	
	return RTimerValueSet(timer, value);
}

/**
 * Adds a timer interval (for repeating timers, until the next expiration).
 *
 * @param timer         Handle to the timer object.
 * @param seconds       Number of seconds.
*/
native bool RTimerAddInterval(Handle timer, float seconds);

/**
 * Decrements the timer interval (for repeating timers, until the next expiration), 
 * if the received interval is less than 0, the timer fires.
 *
 * @param timer         Handle to the timer object.
 * @param seconds       Number of seconds.
*/
native bool RTimerSubInterval(Handle timer, float seconds);

/**
 * Shift the timer's expiration
 *
 * @param timer         Handle to the timer object.
 * @param seconds       Number of seconds.
*/
native bool RTimerShift(Handle timer, float seconds);

/**
 * Warning! 
 * The functions described below are designed only to support the native functions described above. 
 * Using them directly does not guarantee proper operation!
*/

/**
 * Creates a round timer.
 *
 * @param interval      Timer interval in seconds.
 * @param func          Function to execute once the given interval has elapsed.
 * @param value         Any value (int or float) passed when creating the timer 
 *                      if a Handle is passed, it must be removed in the callback.
 * @param flags         Timer flags.
 * @param func_close    Handle deletion callback function (RTimerClose).
 * @param timer         Handle to the timer object.
 *
 * @return              true or false if unsuccessful. You do not need to call delete view_as<Handle>(). 
 *                      If the timer could  not be created, INVALID_HANDLE will be returned.
 *
 * @error               Attempt to create a timer outside of a round.
*/
native bool CreateRTimer(float interval, RTimer func, any value = 0, int flags = 0, Function func_close, Handle timer);

/**
 * Removes the timer.
 *
 * @param timer         Handle to the timer object.
*/
native bool RTimerRemove(Handle timer);

/**
 * Sets a new timer value.
 *
 * @param timer         Handle to the timer object.
 * @param value         If a Handle type value is passed, you must dispose of it yourself 
 *                      in the callback function.
*/
native bool RTimerValueSet(Handle timer, any value);

/**
 * Closes the timer and deletes the data if the TIMER_DATA_HNDL_CLOSE flag was set.
 *
 * @param timer         Handle to the timer object.
 * @param data          Handle passed when creating the timer.
 * @param flags         Timer flags.
 *
 * @error               Invalid timer handle or invalid data handle.
*/
void RTimerClose(Handle timer, any data, int flags = 0)
{
	if (timer)
	{
		delete timer;
	}
	
	if (flags & TIMER_DATA_HNDL_CLOSE)
	{
		if (data)
		{
			delete view_as<Handle>(data);
		}
	}
}