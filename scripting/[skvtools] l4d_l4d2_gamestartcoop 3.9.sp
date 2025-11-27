/**
 * ========================================================================
 * Plugin l4d_l4d2_gamestartcoop
 * Generates game forwards and natives, see skvtools_gamestartcoop.inc
 * ========================================================================
 *
 * This program is free software; you can redistribute it and/or modify it.
 *
**/

#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#include <skvtools_gamestartcoop>

public Plugin:myinfo =
{
	name 		= "[skvtools] l4d_l4d2_gamestartcoop",
	author 		= "Skv",
	description = "Сreates a global forwards in coop mode",
	version 	= "3.9",
	url 		= ""
}

#define 		MAX_PLAYERS 				18

int 			gi_stage;
bool 			gb_new_game;

Handle 			gt_GameplayStart;
Handle 			gt_GameplayStart_Stage;

GlobalForward 	gF_OnGameplayStart;
GlobalForward 	gF_OnMapTransit;
GlobalForward 	gF_OnMissionChange;
GlobalForward 	gF_OnMapRestart;
GlobalForward 	gF_OnServerEmpty;
GlobalForward 	gF_OnEscapeVehicleLeaving;

ConVar 			gc_server_console;

enum 			Events
{
				PLAYER_SPAWN = 0,
				PLAYER_TEAM
};

bool 			gb_eventhook[2];

public APLRes AskPluginLoad2(Handle plugin, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_Left4Dead && GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left4Dead and Left4Dead2");
		return APLRes_SilentFailure;
	}
	
	RegPluginLibrary("[skvtools] l4d_l4d2_gamestartcoop");
	
	return APLRes_Success;
}

public OnPluginStart()
{
	HookEvent("mission_lost", Event_mission_lost);
	
	gF_OnGameplayStart = new GlobalForward("OnGameplayStart", ET_Ignore, Param_Cell);
	
	gF_OnMapRestart = new GlobalForward("OnMapRestart", ET_Ignore);
	HookEvent("vote_passed", Event_vote_passed);
		
	gF_OnMapTransit = new GlobalForward("OnMapTransit", ET_Ignore);
	HookEvent("map_transition", Event_map_transition, EventHookMode_Pre);
	HookEvent("finale_win", Event_map_transition, EventHookMode_Pre);
	
	gF_OnMissionChange = new GlobalForward("OnMissionChange", ET_Ignore);
	
	gF_OnServerEmpty = new GlobalForward("OnServerEmpty", ET_Ignore);
	gF_OnEscapeVehicleLeaving = new GlobalForward("OnEscapeVehicleLeaving", ET_Ignore);
	
	gc_server_console = CreateConVar("gamestartcoop_server_console", "1", "Output messages to server console?", _, true, 0.0, true, 1.0);
	SetConVarFlags(gc_server_console, GetConVarFlags(gc_server_console) & ~FCVAR_NOTIFY);
	
	AutoExecConfig(true, "l4d_l4d2_gamestartcoop");
}

public OnMapStart()
{
	gb_new_game = false;
	
	Delete_Timers();
}

void EventEnable_PLAYER_SPAWN()
{
	if (!gb_eventhook[PLAYER_SPAWN])
	{
		gb_eventhook[PLAYER_SPAWN] = true;
		HookEvent("player_spawn", Event_player_spawn);
	}
}

void EventDisable_PLAYER_SPAWN()
{
	if (gb_eventhook[PLAYER_SPAWN])
	{
		gb_eventhook[PLAYER_SPAWN] = false;
		UnhookEvent("player_spawn", Event_player_spawn);
	}
}

public OnClientPutInServer(int client)
{
	if (IsFakeClient(client))
	{
		return;
	}
	
	bool first = true;
			
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		if (i != client && IsValidClient(i) && !IsFakeClient(i))
		{
			first = false;
		}
	}
		
	if (first)
	{
		PrintToServerPlugin("OnClientPutInServer");
		
		Delete_Timers();
		EventEnable_PLAYER_SPAWN();
		EventEnable_PLAYER_TEAM();
	}
}

void Event_player_spawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsValidClient(client)) {return;}
	
	if (!IsFakeClient(client) && GetClientTeam(client) == 2)
	{
		gb_new_game = false;
		
		EventDisable_PLAYER_SPAWN();
		Delete_Timers();
		
		gt_GameplayStart = CreateTimer(0.1, GameplayStart);
	}
}

void Event_mission_lost(Handle:event, const String:name[], bool:dontBroadcast)
{
	gb_new_game = true;
	
	Delete_Timers();
	
	PrintToServerPlugin("Event mission_lost");
}

public OnEntityCreated(entity, const String:classname[])
{
	if (!strcmp(classname, "logic_auto"))
	{
		HookSingleEntityOutput(entity, "OnNewGame", OnHook_logic_auto, true);
	}
	else if (!strcmp(classname, "trigger_finale") || !strcmp(classname, "trigger_finale_dlc3"))
	{
		HookSingleEntityOutput(entity, "EscapeVehicleLeaving", EscapeVehicleLeaving, true);
	}
}

void EscapeVehicleLeaving(char [] output, int caller, int client, float delay)
{
	PrintToServerPlugin("OnEscapeVehicleLeaving");
	
	Call_StartForward(gF_OnEscapeVehicleLeaving);
	Call_Finish();
}

void OnHook_logic_auto(char [] output, int caller, int activator, float delay)
{
	if (!gb_new_game)
	{
		return;
	}
	
	gb_new_game = false;
		
	Delete_Timers();
		
	gt_GameplayStart = CreateTimer(0.1, GameplayStart);
}

void Event_vote_passed(Handle:event, const String:name[], bool:dontBroadcast)
{
	char vote_details[PLATFORM_MAX_PATH];
	GetEventString(event, "details", vote_details, sizeof(vote_details));
	
	if (!strcmp(vote_details, "#L4D_vote_passed_restart_game"))
	{
		Delete_Timers();
		
		PrintToServerPlugin("OnMapRestart");
		
		gb_new_game = true;
				
		Call_StartForward(gF_OnMapRestart);
		Call_Finish();
	}
	else if (!strcmp("#L4D_vote_passed_mission_change", vote_details)) 
	{
		Delete_Timers();
		
		PrintToServerPlugin("OnMissionChange");
				
		gb_new_game = false;
				
		Call_StartForward(gF_OnMissionChange);
		Call_Finish();
	}
}

void Event_map_transition(Handle:event, const String:name[], bool:dontBroadcast)
{
	Delete_Timers();
	
	PrintToServerPlugin("OnMapTransit");
		
	gb_new_game = false;
	
	Call_StartForward(gF_OnMapTransit);
	Call_Finish();
}

void Event_player_team(Handle:event, const String:name[], bool:dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsFakeClient(client)) {return;}
	
	if (GetEventInt(event, "team") != 0)
	{
		return;
	}
	
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		if (i != client && IsValidClient(i) && GetClientTeam(i) == 2 && !IsFakeClient(i))
		{
			return;
		}
	}
	
	EventDisable_PLAYER_TEAM();
	
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			KickClient(i);
		}
	}
	
	Delete_Timers();
	
	gb_new_game = false;
	
	PrintToServerPlugin("OnServerEmpty");
	
	Call_StartForward(gF_OnServerEmpty);
	Call_Finish();
}

void EventEnable_PLAYER_TEAM()
{
	if (!gb_eventhook[PLAYER_TEAM])
	{
		gb_eventhook[PLAYER_TEAM] = true;
		HookEvent("player_team", Event_player_team);
	}
}

void EventDisable_PLAYER_TEAM()
{
	if (gb_eventhook[PLAYER_TEAM])
	{
		gb_eventhook[PLAYER_TEAM] = false;
		UnhookEvent("player_team", Event_player_team);
	}
}

Action:GameplayStart(Handle timer)
{
	PrintToServerPlugin("OnGameplayStart");
		
	gi_stage = 0;
	
	Call_StartForward(gF_OnGameplayStart);
	Call_PushCell(gi_stage);
	Call_Finish();
	
	if (IsValidHandle(gt_GameplayStart_Stage))
	{
		delete gt_GameplayStart_Stage;
	}
	
	gt_GameplayStart_Stage = CreateTimer(1.0, GameplayStart_Stage, 18, TIMER_REPEAT);
}

Action:GameplayStart_Stage(Handle timer, int max_time)
{
	gi_stage ++;
	
	if (gi_stage > max_time)
	{
		gi_stage = 0;
		return Plugin_Stop;
	}
	
	Call_StartForward(gF_OnGameplayStart);
	Call_PushCell(gi_stage);
	Call_Finish();
	
	return Plugin_Continue;
}

void Delete_Timers()
{
	if (IsValidHandle(gt_GameplayStart))
	{
		delete gt_GameplayStart;
	}
	
	if (IsValidHandle(gt_GameplayStart_Stage))
	{
		delete gt_GameplayStart_Stage;
	}
}

/**
 * Проверяет клиента команды 2
 *
 * client 		- Client index.
 * return 		- true если client valid и false если нет
 */
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

/**
 * выводит в консоль сервера с названием плагина
 *
 * message 		- сообщение
 * any ... 		- параметры функции
 */
void PrintToServerPlugin(char [] message, any ...)
{
	if (!GetConVarBool(gc_server_console))
	{
		return;
	}
	
	SetGlobalTransTarget(LANG_SERVER);
	
	int len = strlen(message) + PLATFORM_MAX_PATH;
	char [] buffer = new char[len];
	
	char plugin_name[PLATFORM_MAX_PATH];
	GetPluginFilename(INVALID_HANDLE, plugin_name, sizeof(plugin_name));
	
	VFormat(buffer, len, message, 2); // 2 - это номер параметра any
	
	Format(buffer, len, "%s: %s", plugin_name, buffer);
	PrintToServer(buffer);
}