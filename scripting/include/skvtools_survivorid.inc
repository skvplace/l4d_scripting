
#if defined _skvtools_survivorid_included
 #endinput
#endif

#define MAX_SURVIVORID MAXPLAYERS

#define _skvtools_survivorid_included

methodmap Survivor
{
	public Survivor(int survivorid) 
	{
		return view_as<Survivor>(survivorid);
	}

	/**
	* Returns client index if successful otherwise 0.
	* (survivor.Client)
 */
	property int Client 
	{
		public get() 
		{
			return GetClientOfSurvivorId(view_as<int>(this));
		}
	}

	/**
 * Returns user id  if successful otherwise 0.
	* (survivor.UserId)
	*/
	property int UserId 
	{
		public get() 
		{
			return GetSurvivorUserId(view_as<int>(this));
		}
	}

	/**
 * Returns survivor id if successful otherwise 0.
	* Survivor.OfClient(client)
 */
	public static Survivor OfClient(int client)
	{
		return view_as<Survivor>(GetClientSurvivorId(client));
	}

	/**
 * Returns survivor id if successful otherwise 0.
	* Survivor.OfUserId(userid)
 */
	public static Survivor OfUserId(int userid)
	{
		return view_as<Survivor>(GetSurvivorOfUserId(userid));
	}
}

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
