
#if defined _skvtools_timers_round_included
 #endinput
#endif

#define _skvtools_timers_round_included

#define SKVTOOLS_TIMERS_ROUND_VERSION	"1.0"

#define MAX_TIMERS 						1024 	// set max timers

/**
 * Creates a controlled timer
 *
 * interval 		- timer interval in seconds
 * value 			- transmitted value
 * flags 			- timer flag
 *
 * return  			- timer ID or 0 if unsuccessful	
*/
native int RTimerCreate(float interval, Function func, any value = 0, int flags = 0);

/**
 * Manually starts the timer to call its function, returns the timer ID or 0 if unsuccessful
 *
 * timerid	 		- timer ID
*/
native bool RTimerTrigger(int timerid);

/**
 * Removes the timer, returns the timer ID or 0 if unsuccessful
 *
 * timerid	 		- timer ID
*/
native bool RTimerRemove(int timerid);

/**
 * Returns the remaining time, or 0 if unsuccessful
 *
 * timerid	 		- timer ID
*/
native float RTimerGetRemaining(int timerid);

/**
 * Returns the timer interval, or 0 if unsuccessful
 *
 * timerid	 		- timer ID
*/
native float RTimerGetInterval(int timerid);

/**
 * Returns the value passed to the timer callback function, or 0 if unsuccessful
 *
 * timerid	 		- timer ID
*/
native any RTimerGetValue(int timerid); 

/**
 * Shift the timer's expiration, returning the timer ID or 0 on failure.
 *
 * timerid	 		- timer ID
 * seconds 			- number of seconds
*/
native bool RTimerShift(int timerid, float seconds);

/**
 * Adds a timer interval (for repeating timers, until the next expiration), 
 * returns the timer ID, or 0 on failure.
 *
 * timerid	 		- timer ID
 * seconds 			- number of seconds
*/
native bool RTimerAddInterval(int timerid, float seconds);

/**
 * Decrements the timer interval (for repeating timers, until the next expiration), 
 * if the received interval is less than 0, the timer fires, returns the timer ID or 0 on failure.
 *
 * timerid	 		- timer ID
 * seconds 			- number of seconds
*/
native bool RTimerSubInterval(int timerid, float seconds);

/**
 * Sets a new timer interval, returns the timer ID or 0 if unsuccessful
 *
 * timerid	 		- timer ID
 * interval 		- interval in seconds
*/
native bool RTimerSetInterval(int timerid, float interval);

/**
 * Sets a new timer value, returns the timer ID or 0 if unsuccessful
 *
 * timerid	 		- timer ID
 * value 			- any value
*/
native bool RTimerSetValue(int timerid, any value);