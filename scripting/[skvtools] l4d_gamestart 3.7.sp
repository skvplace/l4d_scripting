/**
 * ========================================================================
 * Plugin l4d_gamestart
 * Generates game forwards and natives, see skvtools_gamestartcoop.inc
 * All Left 4 Dead and Left 4 Dead 2 game modes are currently supported.
 * ========================================================================
 *
 * This program is free software; you can redistribute it and/or modify it.
 *
**/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#include <skvtools_rtimers>

public Plugin myinfo =
{
	name 		= "[skvtools] l4d_gamestart",
	author 		= "Skv",
	description = "Сreates a global forwards",
	version 	= "3.7",
	url 		= ""
}

#define 		MAX_STAGE 					18

int 			g_iStage;

bool 			g_bNewGame;
bool 			g_bGamePlay;
bool 			g_bServerEmpty;

char 			g_sGameMode					[MAX_NAME_LENGTH];

Handle 			g_tGameplayStart;
Handle 			g_tGameplayStage;

GlobalForward 	g_fwOnGameplayStart;
GlobalForward 	g_fwOnMapRestart;
GlobalForward 	g_fwOnMapTransit;
GlobalForward 	g_fwOnMissionChange;
GlobalForward 	g_fwOnMissionLost;
GlobalForward 	g_fwOnRoundEnd;
GlobalForward 	g_fwOnServerEmpty;
GlobalForward 	g_fwOnEscapeVehicleLeaving;

ConVar 			g_cServerConsole;

enum 			EventName
{
				player_spawn = 0,
				mission_lost,
				round_end
};

bool 			g_bEventHook[3];
int 			g_iUserId					[MAXPLAYERS + 1];

public APLRes AskPluginLoad2(Handle plugin, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_Left4Dead && GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left4Dead and Left4Dead2");
		return APLRes_SilentFailure;
	}
	
	RegPluginLibrary("[skvtools] l4d_gamestart");
	
	CreateNative("IsGameplayActive", 	native_IsGameplayActive);
	CreateNative("IsServerEmpty", 		native_IsServerEmpty);
	
	return APLRes_Success;
}

any native_IsGameplayActive(Handle plugin, int numParams)
{
	return g_bGamePlay;
}

any native_IsServerEmpty(Handle plugin, int numParams)
{
	return g_bServerEmpty;
}

public void OnPluginStart()
{
	HookEvent("player_connect", 		Event_player_connect, 			EventHookMode_Pre);
	HookEvent("player_disconnect", 		Event_player_disconnect, 		EventHookMode_Pre);
	HookEvent("player_team", 			Event_player_team, 				EventHookMode_Pre);
	
	HookEvent("vote_passed", 			Event_vote_passed);
	HookEvent("map_transition", 		Event_map_transition);
	HookEvent("finale_win", 			Event_finale_win);
	
	HookEvent("finale_vehicle_leaving", Event_finale_vehicle_leaving, 	EventHookMode_Pre);
	
	GetConVarString(FindConVar("mp_gamemode"), g_sGameMode, sizeof(g_sGameMode));
	
	g_fwOnGameplayStart 		= CreateGlobalForward("OnGameplayStart", 		ET_Ignore, Param_Cell);
	g_fwOnMapRestart 			= CreateGlobalForward("OnMapRestart", 			ET_Ignore);
	g_fwOnMapTransit 			= CreateGlobalForward("OnMapTransit", 			ET_Ignore);
	g_fwOnMissionChange 		= CreateGlobalForward("OnMissionChange", 		ET_Ignore);
	g_fwOnMissionLost 			= CreateGlobalForward("OnMissionLost", 			ET_Ignore);
	g_fwOnRoundEnd 				= CreateGlobalForward("OnRoundEnd", 			ET_Ignore);
	g_fwOnServerEmpty 			= CreateGlobalForward("OnServerEmpty", 			ET_Ignore);
	g_fwOnEscapeVehicleLeaving 	= CreateGlobalForward("OnEscapeVehicleLeaving", ET_Ignore);
	
	g_cServerConsole = CreateConVar("gamestart_server_console", "1", "Output messages to server console?", _, true, 0.0, true, 1.0);
	
	SetConVarFlags(g_cServerConsole, GetConVarFlags(g_cServerConsole) & ~FCVAR_NOTIFY);
	
	AutoExecConfig(true, "l4d_gamestart");
}

public void OnMapStart()
{
	g_bNewGame = false;
	g_bGamePlay = false;
	
	if (!g_bServerEmpty)
	{
		EventEnable(player_spawn);
	}
}

public void OnMapEnd()
{
	g_bNewGame = false;
	g_bGamePlay = false;
}

public void OnClientPostAdminCheck(int client)
{
	if (IsFakeClient(client))
	{
		return;
	}
	
	g_bServerEmpty = false;
	
	bool bFirst = true;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (g_iUserId[i])
		{
			bFirst = false;
		}
	}
	
	if (!SetUserConnect(GetClientUserId(client)))
	{
		return;
	}
	
	if (!bFirst)
	{
		return;
	}
	
	ServerConsole("FirstClientConnected");
		
	Delete_Timers();
	
	EventEnable(player_spawn);
}

void Event_player_connect(Handle event, const char [] name, bool dontBroadcast)
{
	int iBot = GetEventInt(event, "bot");
	if (iBot)
	{
		return;
	}
	
	g_bServerEmpty = false;
	
	bool bFirst = true;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (g_iUserId[i])
		{
			bFirst = false;
		}
	}
	
	if (!SetUserConnect(GetEventInt(event, "userid")))
	{
		return;
	}
	
	if (!bFirst)
	{
		return;
	}
	
	ServerConsole("FirstClientConnected");
		
	Delete_Timers();
	
	EventEnable(player_spawn);
}

void Event_player_disconnect(Handle event, const char [] name, bool dontBroadcast)
{
	if (!SetUserDisconnect(GetEventInt(event, "userid")))
	{
		return;
	}
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (g_iUserId[i])
		{
			return;
		}
	}
	
	if (g_bServerEmpty)
	{
		return;
	}
	
	SetServerEmpty();
}

void Event_player_team(Handle event, const char [] name, bool dontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsFakeClient(iClient)) {return;}
	
	if (GetEventInt(event, "team") != 0)
	{
		return;
	}
	
	if (!SetUserDisconnect(GetEventInt(event, "userid")))
	{
		return;
	}
		
	for (int i = 1; i <= MaxClients; i++)
	{
		if (g_iUserId[i])
		{
			return;
		}
	}
	
	if (g_bServerEmpty)
	{
		return;
	}
	
	SetServerEmpty();
}

void SetServerEmpty()
{	
	g_bNewGame 		= false;
	g_bGamePlay 	= false;
	g_bServerEmpty 	= true;
	
	EventDisable(player_spawn);
	EventDisable(mission_lost);
	EventDisable(round_end);
	
	Delete_Timers();
	
	ServerConsole("OnServerEmpty");
	
	Call_StartForward(g_fwOnServerEmpty);
	Call_Finish();
}

void Event_player_spawn(Handle event, const char [] name, bool dontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsValidClient(iClient)) {return;}
	if (GetClientTeam(iClient) != 2) {return;}
	
	g_bNewGame 	= false;
	g_bGamePlay = true;
	
	GetConVarString(FindConVar("mp_gamemode"), g_sGameMode, sizeof(g_sGameMode));
	
	if (!strcmp(g_sGameMode, "survival") ||
		!strcmp(g_sGameMode, "versus") ||
		!strcmp(g_sGameMode, "scavenge"))
	{
		EventEnable(round_end);
	}
	else
	{
		EventEnable(mission_lost);
	}
		
	EventDisable(player_spawn);
	Delete_Timers();
		
	g_tGameplayStart = RTimerCreate(0.1, GameplayStart);
	if (!g_tGameplayStart)
	{
		LogError("\"%s: Timer not created\"", name);
	}
}

void Event_mission_lost(Handle event, const char [] name, bool dontBroadcast)
{
	g_bNewGame 	= true;
	g_bGamePlay = false;
	
	Delete_Timers();
	
	EventEnable(player_spawn);
	EventDisable(mission_lost);
	
	ServerConsole("OnMissionLost");
	
	Call_StartForward(g_fwOnMissionLost);
	Call_Finish();
}

void Event_round_end(Handle event, const char [] name, bool dontBroadcast)
{
	g_bNewGame 	= true;
	g_bGamePlay = false;
	
	Delete_Timers();
	
	EventEnable(player_spawn);
	EventDisable(round_end);
	
	ServerConsole("OnRoundEnd");
	
	Call_StartForward(g_fwOnRoundEnd);
	Call_Finish();
}

public void OnEntityCreated(int entity,char [] classname)
{
	if (!strcmp(classname, "logic_auto"))
	{
		HookSingleEntityOutput(entity, "OnMapSpawn", OnHook_logic_auto);
	}
}

void Event_finale_vehicle_leaving(Handle event, const char [] name, bool dontBroadcast)
{
	ServerConsole("OnEscapeVehicleLeaving");
	
	Call_StartForward(g_fwOnEscapeVehicleLeaving);
	Call_Finish();
}

void OnHook_logic_auto(char [] output, int caller, int activator, float delay)
{
	if (!g_bNewGame)
	{
		return;
	}
	
	g_bNewGame 	= false;
	g_bGamePlay = true;
	
	EventEnable(player_spawn);
	
	Delete_Timers();
		
	g_tGameplayStart = RTimerCreate(0.1, GameplayStart);
	if (!g_tGameplayStart)
	{
		LogError("\"OnHook_logic_auto: Timer not created\"");
	}
}

void Event_vote_passed(Handle event, const char [] name, bool dontBroadcast)
{
	char sVoteDetails[PLATFORM_MAX_PATH];
	GetEventString(event, "details", sVoteDetails, sizeof(sVoteDetails));
	
	if (!strcmp(sVoteDetails, "#L4D_vote_passed_restart_game"))
	{
		Delete_Timers();
		
		g_bNewGame 	= true;
		g_bGamePlay = false;
		
		ServerConsole("OnMapRestart");
		
		Call_StartForward(g_fwOnMapRestart);
		Call_Finish();
	}
	else if (!strcmp(sVoteDetails, "#L4D_vote_passed_mission_change"))
	{
		Delete_Timers();
		
		g_bNewGame 	= true;
		g_bGamePlay = false;
		
		ServerConsole("OnMissionChange");
		
		Call_StartForward(g_fwOnMissionChange);
		Call_Finish();
	}
}

void Event_map_transition(Handle event, const char [] name, bool dontBroadcast)
{
	Delete_Timers();
	
	g_bNewGame 	= false;
	g_bGamePlay = false;
	
	ServerConsole("OnMapTransit");
	
	Call_StartForward(g_fwOnMapTransit);
	Call_Finish();
}

void Event_finale_win(Handle event, const char [] name, bool dontBroadcast)
{
	Delete_Timers();
	
	g_bNewGame 	= false;
	g_bGamePlay = false;
	
	EventDisable(player_spawn);
}

void GameplayStart(Handle timer)
{
	ServerConsole("OnGameplayStart");
	
	g_iStage = 0;
	
	Call_StartForward(g_fwOnGameplayStart);
	Call_PushCell(g_iStage);
	Call_Finish();
	
	RTimerKill(g_tGameplayStage);
	
	g_tGameplayStage = RTimerCreate(1.0, GameplayStage, _, TIMER_REPEAT | TIMER_FLAG_NO_ROUNDCHANGE);
	if (!g_tGameplayStage)
	{
		LogError("\"GameplayStart: Timer not created\"");
	}
	
	GetConVarString(FindConVar("mp_gamemode"), g_sGameMode, sizeof(g_sGameMode));
	
	if (!strcmp(g_sGameMode, "survival") ||
		!strcmp(g_sGameMode, "versus") ||
		!strcmp(g_sGameMode, "scavenge"))
	{
		EventEnable(round_end);
	}
	else
	{
		EventEnable(mission_lost);
	}
		
	EventDisable(player_spawn);
}

Action GameplayStage(Handle timer)
{
	g_iStage ++;
	
	if (g_iStage > MAX_STAGE)
	{
		g_iStage = 0;
		
		return Plugin_Stop;
	}
	
	Call_StartForward(g_fwOnGameplayStart);
	Call_PushCell(g_iStage);
	Call_Finish();
	
	return Plugin_Continue;
}

void Delete_Timers()
{
	RTimerKill(g_tGameplayStart);
	RTimerKill(g_tGameplayStage);
}

void EventEnable(EventName name)
{
	if (g_bEventHook[name])
	{
		return;
	}
	
	g_bEventHook[name] = true;
	
	switch(name)
	{
		case player_spawn:
		{
			HookEvent("player_spawn", Event_player_spawn);
		}
		case mission_lost:
		{
			HookEvent("mission_lost", Event_mission_lost, EventHookMode_Pre);
		}
		case round_end:
		{
			HookEvent("round_end", Event_round_end);
		}
	}
}

void EventDisable(EventName name)
{
	if (!g_bEventHook[name])
	{
		return;
	}
	
	g_bEventHook[name] = false;
	
	switch(name)
	{
		case player_spawn:
		{
			UnhookEvent("player_spawn", Event_player_spawn);
		}
		case mission_lost:
		{
			UnhookEvent("mission_lost", Event_mission_lost, EventHookMode_Pre);
		}
		case round_end:
		{
			UnhookEvent("round_end", Event_round_end);
		}
	}
}

int SetUserConnect(int userid)
{
	if (GetUserSlot(userid))
	{
		return 0;
	}
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!g_iUserId[i])
		{
			g_iUserId[i] = userid;
			
			return i;
		}
	}
	
	return 0;
}

int SetUserDisconnect(int userid)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (g_iUserId[i] == userid)
		{
			g_iUserId[i] = 0;
			
			return i;
		}
	}
	
	return 0;
}

int GetUserSlot(int userid)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (g_iUserId[i] == userid)
		{
			return i;
		}
	}

	return 0;
}

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

void ServerConsole(char [] message)
{
	if (!GetConVarBool(g_cServerConsole))
	{
		return;
	}
	
	LogMessage(message);
}
