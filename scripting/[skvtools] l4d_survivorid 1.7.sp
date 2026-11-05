/**
 * ========================================================================
 * Plugin [skvtools] survivorid
 * Creates and manages survivorid - the survivor's identifier
 * ========================================================================
 *
 * This program is free software; you can redistribute it and/or modify it.
 *
**/

#pragma semicolon 1
#include <sourcemod>
#pragma newdecls required

#include <skvtools_survivorid>

public Plugin myinfo = 
{
	name 		= "[skvtools] l4d_survivorid",
	author 		= "Skv",
	description = "Creates and manages survivorid - the survivor's identifier",
	version 	= "1.7",
	url 		= ""
}

int 	g_iUserId[MAX_SURVIVORID + 2];

public APLRes AskPluginLoad2(Handle plugin, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_Left4Dead && GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left4Dead and Left4Dead2");
		return APLRes_SilentFailure;
	}
	
	CreateNative("GetSurvivorUserId", native_GetSurvivorUserId);
	CreateNative("GetSurvivorOfUserId", native_GetSurvivorOfUserId);
	
	CreateNative("GetClientSurvivorId", native_GetClientSurvivorId);
	CreateNative("GetClientOfSurvivorId", native_GetClientOfSurvivorId);
	
	return APLRes_Success;
}

public void OnPluginStart()
{
	HookEvent("player_team", Event_player_team, EventHookMode_Pre);
	
	HookEvent("player_bot_replace", Event_player_bot_replace, EventHookMode_Pre);
	HookEvent("bot_player_replace", Event_bot_player_replace, EventHookMode_Pre);
	
	RegConsoleCmd("sm_status", Cmd_status);
}

public Action Cmd_status(int iClient, int args)
{
	PrintToConsole(iClient, "# iSurvivorId name userid clientid");
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			PrintToConsole(iClient, "# %d \"%N\" %d %d %s", GetClientSurvivorId(i), 
															i,
															GetClientUserId(i),
															i,
															IsFakeClient(i) ? "BOT":"");
		}
	}
	
	return Plugin_Handled;
}

public void OnMapStart()
{
	ClearAllSurvivorId();
}

public void OnMapEnd()
{
	ClearAllSurvivorId();
}

void Event_player_team(Handle event, const char[] name, bool dontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsValidClient(iClient)) {return;}
	
	if (IsFakeClient(iClient))
	{
		char client_name[MAX_NAME_LENGTH];
		FormatEx(client_name, sizeof(client_name), "%N", iClient);
		
		if (StrContains(client_name, "smoker", false) > -1 ||
			StrContains(client_name, "boomer", false) > -1 ||
			StrContains(client_name, "hunter", false) > -1 ||
			StrContains(client_name, "charger", false) > -1 ||
			StrContains(client_name, "jockey", false) > -1 ||
			StrContains(client_name, "spitter", false) > -1 ||
			StrContains(client_name, "tank", false) > -1)
		{
			return;
		}
	}
	
	int iOldTeam 	= GetEventInt(event, "oldteam");
	int iTeam 		= GetEventInt(event, "team");
		
	if (iOldTeam == 0 && iTeam == 2)
	{
		SetSurvivorID(iClient);
	}
		
	if (iTeam == 0)
	{
		int iSlot = RemoveSurvivorID(iClient);
		
		if (IsFakeClient(iClient))
		{
			for (int i = 1; i <= MaxClients; i ++)
			{
				if (IsValidClientTeam2(i) && !IsFakeClient(i))
				{
					if (!GetSurvivorID(i))
					{
						g_iUserId[iSlot] = GetClientUserId(i);
						
						break;
					}
				}
			}
		}
	}
}

void ClearAllSurvivorId()
{
	for (int i = 1; i <= MAX_SURVIVORID; i++)
	{
		g_iUserId[i] = 0;
	}
}

//бот заменил игрока
void Event_player_bot_replace(Handle event, const char[] name, bool dontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(event, "player"));
	if (!IsValidClient(iClient)) {return;}
	
	int iBot = GetClientOfUserId(GetEventInt(event, "bot"));
	if (!IsValidClient(iBot)) {return;}
	
	int iSurvivorId = GetSurvivorID(iClient);
	if (iSurvivorId)
	{	
		RemoveSurvivorID(iBot);
		
		g_iUserId[iSurvivorId] = GetClientUserId(iBot);
				
		return;
	}
	
	SetSurvivorID(iBot);
}

//игрок заменил бота
void Event_bot_player_replace(Handle event, const char[] name, bool dontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(event, "player"));
	if (!IsValidClient(iClient)) {return;}
	
	int iBot = GetClientOfUserId(GetEventInt(event, "bot"));
	if (!IsValidClient(iBot)) {return;}
	
	int iSurvivorId = GetSurvivorID(iBot);
	if (iSurvivorId)
	{	
		RemoveSurvivorID(iClient);

		g_iUserId[iSurvivorId] = GetClientUserId(iClient);
				
		return;
	}
	
	if (GetSurvivorID(iClient))
	{
		RemoveSurvivorID(iBot);
		return;
	}
	
	SetSurvivorID(iClient);
}

int SetSurvivorID(int client)
{
	if (GetSurvivorID(client))
	{
		return 0;
	}
	
	if (!IsValidClient(client))
	{
		return 0;
	}
		
	for (int i = 1; i <= MAX_SURVIVORID; i++)
	{
		if (!g_iUserId[i])
		{
			g_iUserId[i] = GetClientUserId(client);
						
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
		if (g_iUserId[i] == userid)
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
		if (g_iUserId[i] == userid)
		{
			g_iUserId[i] = 0;
						
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
	
	int iSurvivorId = GetNativeCell(1);
	
	for (int i = 1; i <= MAX_SURVIVORID; i++)
	{
		if (i == iSurvivorId)
		{
			return g_iUserId[i];
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
		if (g_iUserId[i] && g_iUserId[i] == userid)
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
	
	int iClient = GetNativeCell(1);
	
	if (!IsValidClient(iClient))
	{
		return 0;
	}
	
	int userid = GetClientUserId(iClient);
	
	for (int i = 1; i <= MAX_SURVIVORID; i++)
	{
		if (g_iUserId[i] && g_iUserId[i] == userid)
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
	
	int iSurvivorId = GetNativeCell(1);
	
	for (int i = 1; i <= MAX_SURVIVORID; i++)
	{
		if (i == iSurvivorId)
		{
			return GetClientOfUserId(g_iUserId[i]);
		}
	}
	
	return 0;
}

/**
 * Проверяет клиента
 *
 * client 			- Client index.
 * return 			- true если client valid и false если нет
 */
bool IsValidClient(int client)
{
	if (client > 0  && client <= MaxClients)
	{
		if (IsClientInGame(client))
		{
			return true;
		}
	}
	
	return false;
}

/**
 * Проверяет клиента команды 2
 *
 * client 			- Client index.
 * return 			- true если client valid и false если нет
 */
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