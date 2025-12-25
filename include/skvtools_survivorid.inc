
#if defined _skvtools_survivorid_included
 #endinput
#endif

#define _skvtools_survivorid_included

#define MAX_SURVIVORID 18

/**
 * Возвращает user id
 *
 * survivorid 	- survivor id
 * return 		- user id или 0, если не действующий
*/
native int GetSurvivorUserId(int survivorid);

/**
 * Возвращает survivor id
 *
 * userid 		- user id 
 * return 		- survivor id или 0, если не действующий
*/
native int GetSurvivorOfUserId(int userid); 

/**
 * Возвращает survivor id
 *
 * client 		- client id 
 * return 		- survivor id или 0, если не действующий
*/
native int GetClientSurvivorId(int client);

/**
 * Возвращает client id
 *
 * survivorid	- survivor id
 * return 		- client id или 0, если не действующий
*/
native int GetClientOfSurvivorId(int survivorid);
