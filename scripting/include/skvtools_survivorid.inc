
#if defined _skvtools_survivorid_included
 #endinput
#endif

#define _skvtools_survivorid_included

#define MAX_SURVIVORID 18

/**
 * Returns user id  if successful otherwise 0.
 *
 * @param survivorid 	survivor id
*/
native int GetSurvivorUserId(int survivorid);

/**
 * Returns survivor id if successful otherwise 0.
 *
 * @param userid 		user id 
*/
native int GetSurvivorOfUserId(int userid); 

/**
 * Returns survivor id if successful otherwise 0.
 *
 * @param client 		client id 
*/
native int GetClientSurvivorId(int client);

/**
 * Returns client index if successful otherwise 0.
 *
 * @param survivorid	survivor id
*/
native int GetClientOfSurvivorId(int survivorid);