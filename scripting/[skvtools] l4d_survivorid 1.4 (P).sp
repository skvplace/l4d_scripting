/**
 * ========================================================================
 * Plugin [skvtools] survivorid
 * Creates and manages survivorid - the survivor's body identifier
 * ========================================================================
 *
 * This program is free software; you can redistribute it and/or modify it.
 *
**/

#pragma semicolon 1
#include <sourcemod>

#include <skvtools_survivorid>

public Plugin:myinfo = 
{
	name 		= "[skvtools] l4d_survivorid",
	author 		= "Skv",
	description = "Creates and manages survivorid - the survivor's body identifier",
	version 	= "1.4 (Public)",
	url 		= ""
}

#define MAX_PLAYERS 	18
int 	gi_user			[MAX_SURVIVORID + 1];

public APLRes AskPluginLoad2(Handle plugin, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_Left4Dead && GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left4Dead and Left4Dead2");
		return APLRes_SilentFailure;
	}
	
	RegPluginLibrary("[skvtools] l4d_survivorid");
	
	CreateNative("GetSurvivorUserId", native_GetSurvivorUserId);
	CreateNative("GetSurvivorOfUserId", native_GetSurvivorOfUserId);
	
	CreateNative("GetClientSurvivorId", native_GetClientSurvivorId);
	CreateNative("GetClientOfSurvivorId", native_GetClientOfSurvivorId);
		
	return APLRes_Success;
}

public OnPluginStart()
{
	HookEvent("player_team", Event_player_team, EventHookMode_Pre);
	
	HookEvent("player_bot_replace", Event_player_bot_replace, EventHookMode_Pre);
	HookEvent("bot_player_replace", Event_bot_player_replace, EventHookMode_Pre);
}

public OnMapStart()
{
	ClearAllSurvivorId();
}

public OnServerEmpty()
{
	ClearAllSurvivorId();
}

void Event_player_team(Handle:event, const String:name[], bool:dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsValidClient(client)) {return;}
	
	if (!IsClientSurvivor(client))
	{
		return;
	}
	
	int oldteam = GetEventInt(event, "oldteam");
	int team = GetEventInt(event, "team");
		
	if (oldteam == 0 && team == 2)
	{
		SetSurvivorID(client);
	}
		
	if (team == 0)
	{
		int slot = RemoveSurvivorID(client);
		
		if (IsFakeClient(client))
		{
			for (int i = 1; i <= MAX_PLAYERS; i ++)
			{
				if (IsValidClientTeam2(i) && !IsFakeClient(i))
				{
					if (!GetClientUserId(i))
					{
						gi_user[slot] = GetClientUserId(i);
						
						break;
					}
				}
			}
		}
	}
}


bool IsClientSurvivor(int client)
{
	if (!IsValidClient(client)) {return false;}
	
	if (IsFakeClient(client))
	{
		char client_name[MAX_NAME_LENGTH];
		FormatEx(client_name, sizeof(client_name), "%N", client);
		
		if (StrContains(client_name, "smoker", false) > -1 ||
			StrContains(client_name, "boomer", false) > -1 ||
			StrContains(client_name, "hunter", false) > -1 ||
			StrContains(client_name, "tank", false) > -1)
		{
			return false;
		}
	}
	
	return true;
}

void ClearAllSurvivorId()
{
	for (int i = 1; i <= MAX_SURVIVORID; i++)
	{
		gi_user[i] = 0;
	}
}

//бот заменил игрока
void Event_player_bot_replace(Handle:event, const String:name[], bool:dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "player"));
	if (!IsValidClient(client)) {return;}
	
	int bot = GetClientOfUserId(GetEventInt(event, "bot"));
	if (!IsValidClient(client)) {return;}
	
	int i = GetSurvivorID(client);
	if (i)
	{	
		RemoveSurvivorID(bot);
		
		gi_user[i] = GetClientUserId(bot);
				
		return;
	}
}

//игрок заменил бота
void Event_bot_player_replace(Handle:event, const String:name[], bool:dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "player"));
	if (!IsValidClient(client)) {return;}
	
	int bot = GetClientOfUserId(GetEventInt(event, "bot"));
	if (!IsValidClient(client)) {return;}
	
	int i = GetSurvivorID(bot);
	if (i)
	{	
		RemoveSurvivorID(client);

		gi_user[i] = GetClientUserId(client);
				
		return;
	}
	
	i = GetSurvivorID(client);
	if (i)
	{
		RemoveSurvivorID(bot);

		return;
	}
}

int SetSurvivorID(int client)
{
	int survivorid = GetSurvivorID(client);
	if (survivorid)
	{
		return 0;
	}
	
	if (!IsValidClient(client))
	{
		return 0;
	}
		
	for (int i = 1; i <= MAX_SURVIVORID; i++)
	{
		if (!gi_user[i])
		{
			gi_user[i] = GetClientUserId(client);
			return i;
		}
	}
	
	return 0;
}

int GetSurvivorID(int client)
{
	if (!IsValidClient(client))
	{
		return 0;
	}
	
	int userid = GetClientUserId(client);
	
	for (int i = 1; i <= MAX_SURVIVORID; i++)
	{
		if (gi_user[i] == userid)
		{
			return i;
		}
	}
	
	return 0;
}

int RemoveSurvivorID(int client)
{
	if (!IsValidClient(client))
	{
		return 0;
	}
	
	int userid = GetClientUserId(client);
	
	for (int i = 1; i <= MAX_SURVIVORID; i++)
	{
		if (gi_user[i] == userid)
		{
			gi_user[i] = 0;
						
			return i;
		}
	}
	
	return 0;
}

int native_GetSurvivorUserId(Handle plugin, int numParams)
{
	if (numParams != 1)
	{
		return 0;
	}
	
	int survivorid = GetNativeCell(1);
	
	for (int i = 1; i <= MAX_SURVIVORID; i++)
	{
		if (i == survivorid)
		{
			return gi_user[i];
		}
	}
	
	return 0;
}

int native_GetSurvivorOfUserId(Handle plugin, int numParams)
{
	if (numParams != 1)
	{
		return 0;
	}
	
	int userid = GetNativeCell(1);
	
	for (int i = 1; i <= MAX_SURVIVORID; i++)
	{
		if (gi_user[i] && gi_user[i] == userid)
		{
			return i;
		}
	}
	
	return 0;
}

int native_GetClientSurvivorId(Handle plugin, int numParams)
{
	if (numParams != 1)
	{
		return 0;
	}
	
	int client = GetNativeCell(1);
	
	if (!IsValidClient(client))
	{
		return 0;
	}
	
	int userid = GetClientUserId(client);
	
	for (int i = 1; i <= MAX_SURVIVORID; i++)
	{
		if (gi_user[i] && gi_user[i] == userid)
		{
			return i;
		}
	}
	
	return 0;
}

int native_GetClientOfSurvivorId(Handle plugin, int numParams)
{
	if (numParams != 1)
	{
		return 0;
	}
	
	int survivorid = GetNativeCell(1);
	
	for (int i = 1; i <= MAX_SURVIVORID; i++)
	{
		if (i == survivorid)
		{
			return GetClientOfUserId(gi_user[i]);
		}
	}
	
	return 0;
}

bool IsValidClient(int client)
{
	if (client > 0  && client <= MAX_PLAYERS)
	{
		if (IsClientInGame(client))
		{
			return true;
		}
	}
	return false;
}

bool IsValidClientTeam2(int client)
{
	if (IsValidClient(client))
	{
		if (GetClientTeam(client) == 2)
		{
			return true;
		}
	}
	return false;
}
