
#if defined _skvtools_survivorid_included
 #endinput
#endif

#define _skvtools_survivorid_included

#define MAX_SURVIVORID 18

/**
 * Возвращает userid выжившего
 *
 * survivorid 	- survivorid выжившего
 * return 	- userid выжившего или 0, если не действующий
*/
native int GetSurvivorUserId(int survivorid);

/**
 * Возвращает survivorid выжившего
 *
 * userid 	- userid выжившего
 * return 	- survivorid выжившего или 0, если не действующий
*/
native int GetSurvivorOfUserId(int userid); 

/**
 * Возвращает survivorid выжившего
 *
 * client 	- client id выжившего
 * return 	- survivorid выжившего или 0, если не действующий
*/
native int GetClientSurvivorId(int client);

/**
 * Возвращает client id выжившего
 *
 * survivorid	- survivorid выжившего
 * return 	- client id выжившего или 0, если не действующий
*/
native int GetClientOfSurvivorId(int survivorid);
