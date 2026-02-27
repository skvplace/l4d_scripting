/**
 * ========================================================================
 * Plugin l4d_l4d2_gamestart
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

public Plugin myinfo =
{
	name 		= "[skvtools] l4d_gamestart",
	author 		= "Skv",
	description = "Сreates a global forwards",
	version 	= "3.2 (d)",
	url 		= ""
}

#define FILE_PATH_LOG						"data/S15_L%s.log"
char 	gs_logpath							[PLATFORM_MAX_PATH];

#define 		MAX_STAGE 					18
#define 		MAX_PLAYERS 				18

int 			gi_stage;

bool 			gb_new_game;
bool 			gb_gameplay;
bool 			gb_server_empty;

char 			gs_gamemode					[MAX_NAME_LENGTH];

Handle 			gt_GameplayStart;
Handle 			gt_GameplayStart_Stage;

GlobalForward 	gF_OnGameplayStart;
GlobalForward 	gF_OnMapRestart;
GlobalForward 	gF_OnMapTransit;
GlobalForward 	gF_OnMissionChange;
GlobalForward 	gF_OnMissionLost;
GlobalForward 	gF_OnRoundEnd;
GlobalForward 	gF_OnServerEmpty;
GlobalForward 	gF_OnEscapeVehicleLeaving;

ConVar 			gc_server_console;

enum 			EventName
{
				player_spawn = 0,
				mission_lost,
				round_end
};

bool 			gb_eventhook[3];
int 			gi_users					[MAX_PLAYERS + 1];

public APLRes AskPluginLoad2(Handle plugin, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_Left4Dead && GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left4Dead and Left4Dead2");
		return APLRes_SilentFailure;
	}
	
	RegPluginLibrary("[skvtools] l4d_gamestart");
	
	CreateNative("IsGameplayActive", native_IsGameplayActive);
	
	return APLRes_Success;
}

any native_IsGameplayActive(Handle plugin, int numParams)
{
	return gb_gameplay;
}

public void OnPluginStart()
{
	char data[64];
	FormatTime(data, sizeof(data), "20%y%m%d", GetTime());
	
	char buffer[64];
	FormatEx(buffer, sizeof(buffer), FILE_PATH_LOG, data);
	BuildPath(Path_SM, gs_logpath, sizeof(gs_logpath), buffer);
	
	HookEvent("player_connect", 	Event_player_connect, EventHookMode_Pre);
	HookEvent("player_disconnect", 	Event_player_disconnect, EventHookMode_Pre);
	HookEvent("player_team", 		Event_player_team, EventHookMode_Pre);
	
	HookEvent("vote_passed", 	Event_vote_passed);
	HookEvent("map_transition", Event_map_transition);
	HookEvent("finale_win", 	Event_finale_win);
	
	GetConVarString(FindConVar("mp_gamemode"), gs_gamemode, sizeof(gs_gamemode));
	
	gF_OnGameplayStart 			= CreateGlobalForward("OnGameplayStart", 		ET_Ignore, Param_Cell);
	gF_OnMapRestart 			= CreateGlobalForward("OnMapRestart", 			ET_Ignore);
	gF_OnMapTransit 			= CreateGlobalForward("OnMapTransit", 			ET_Ignore);
	gF_OnMissionChange 			= CreateGlobalForward("OnMissionChange", 		ET_Ignore);
	gF_OnMissionLost 			= CreateGlobalForward("OnMissionLost", 			ET_Ignore);
	gF_OnRoundEnd 				= CreateGlobalForward("OnRoundEnd", 			ET_Ignore);
	gF_OnServerEmpty 			= CreateGlobalForward("OnServerEmpty", 			ET_Ignore);
	gF_OnEscapeVehicleLeaving 	= CreateGlobalForward("OnEscapeVehicleLeaving", ET_Ignore);
	
	gc_server_console = CreateConVar("gamestart_server_console", "1", "Output messages to server console?", _, true, 0.0, true, 1.0);
	
	SetConVarFlags(gc_server_console, GetConVarFlags(gc_server_console) & ~FCVAR_NOTIFY);
	
	AutoExecConfig(true, "l4d_gamestart");
}

public void OnMapStart()
{
	gb_new_game = false;
	gb_gameplay = false;
	
	char data[64];
	FormatTime(data, sizeof(data), "20%y%m%d", GetTime());
	
	char buffer[64];
	FormatEx(buffer, sizeof(buffer), FILE_PATH_LOG, data);
	BuildPath(Path_SM, gs_logpath, sizeof(gs_logpath), buffer);
	
	if (!gb_server_empty)
	{
		EventEnable(player_spawn);
	}
}

public void OnMapEnd()
{
	LogToFileEx(gs_logpath, "OnMapEnd");
	
	gb_new_game = false;
	gb_gameplay = false;
}

void Event_player_connect(Handle event, const char [] name, bool dontBroadcast)
{
	int bot = GetEventInt(event, "bot");
	if (bot)
	{
		return;
	}
	
	gb_server_empty = false;
	
	bool first = true;
	
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		if (gi_users[i])
		{
			first = false;
		}
	}
	
	if (!SetUserConnect(GetEventInt(event, "userid")))
	{
		return;
	}
	
	LogToFileEx(gs_logpath, "Event_player_connect: userid %d", GetEventInt(event, "userid"));
	
	if (!first)
	{
		return;
	}
	
	PrintToServerPlugin("FirstClientConnected");
		
	LogToFileEx(gs_logpath, "FirstClientConnected");
	//PrintToChatAll("FirstClientPutInGame");
		
	Delete_Timers();
	
	EventEnable(player_spawn);
}

void Event_player_disconnect(Handle event, const char [] name, bool dontBroadcast)
{
	if (!SetUserDisconnect(GetEventInt(event, "userid")))
	{
		return;
	}
	
	LogToFileEx(gs_logpath, "Event_player_disconnect: userid %d", GetEventInt(event, "userid"));
	
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		if (gi_users[i])
		{
			return;
		}
	}
	
	if (gb_server_empty)
	{
		return;
	}
	
	SetServerEmpty();
}

void Event_player_team(Handle event, const char [] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsFakeClient(client)) {return;}
	
	if (GetEventInt(event, "team") != 0)
	{
		return;
	}
	
	if (!SetUserDisconnect(GetEventInt(event, "userid")))
	{
		return;
	}
	
	LogToFileEx(gs_logpath, "Event_player_team: disconnect userid %d", GetEventInt(event, "userid"));
		
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		if (gi_users[i])
		{
			return;
		}
	}
	
	if (gb_server_empty)
	{
		return;
	}
	
	SetServerEmpty();
}

void SetServerEmpty()
{	
	gb_new_game 	= false;
	gb_gameplay 	= false;
	gb_server_empty = true;
	
	EventDisable(player_spawn);
	EventDisable(mission_lost);
	EventDisable(round_end);
	
	Delete_Timers();
	
	PrintToServerPlugin("OnServerEmpty");
	LogToFileEx(gs_logpath, "OnServerEmpty");
	
	Call_StartForward(gF_OnServerEmpty);
	Call_Finish();
}

void Event_player_spawn(Handle event, const char [] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsValidClient(client)) {return;}
	if (GetClientTeam(client) != 2) {return;}
	
	LogToFileEx(gs_logpath, "%s", name);
	//PrintToChatAll("%s", name);
	
	gb_new_game = false;
	gb_gameplay = true;
	
	GetConVarString(FindConVar("mp_gamemode"), gs_gamemode, sizeof(gs_gamemode));
	LogToFileEx(gs_logpath, "gs_gamemode: %s", gs_gamemode);
	
	if (!strcmp(gs_gamemode, "survival") ||
		!strcmp(gs_gamemode, "versus") ||
		!strcmp(gs_gamemode, "scavenge"))
	{
		EventEnable(round_end);
	}
	else
	{
		EventEnable(mission_lost);
	}
		
	EventDisable(player_spawn);
	Delete_Timers();
		
	gt_GameplayStart = CreateTimer(0.1, GameplayStart);
}

void Event_mission_lost(Handle event, const char [] name, bool dontBroadcast)
{
	gb_new_game = true;
	gb_gameplay = false;
	
	Delete_Timers();
	
	EventEnable(player_spawn);
	EventDisable(mission_lost);
	
	PrintToServerPlugin("OnMissionLost");
	
	LogToFileEx(gs_logpath, "OnMissionLost");
	//PrintToChatAll("OnMissionLost");
	
	Call_StartForward(gF_OnMissionLost);
	Call_Finish();
}

void Event_round_end(Handle event, const char [] name, bool dontBroadcast)
{
	gb_new_game = true;
	gb_gameplay = false;
	
	Delete_Timers();
	
	EventEnable(player_spawn);
	EventDisable(round_end);
	
	PrintToServerPlugin("OnRoundEnd");
	
	LogToFileEx(gs_logpath, "OnRoundEnd");
	//PrintToChatAll("OnRoundEnd");
	
	Call_StartForward(gF_OnRoundEnd);
	Call_Finish();
}

public void OnEntityCreated(int entity,char [] classname)
{
	if (!strcmp(classname, "logic_auto"))
	{
		HookSingleEntityOutput(entity, "OnMapSpawn", OnHook_logic_auto);
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
	gb_gameplay = true;
	
	EventEnable(player_spawn);
	
	LogToFileEx(gs_logpath, "%s", output);
	//PrintToChatAll("%s", output);
	
	Delete_Timers();
		
	gt_GameplayStart = CreateTimer(0.1, GameplayStart);
}

void Event_vote_passed(Handle event, const char [] name, bool dontBroadcast)
{
	char vote_details[PLATFORM_MAX_PATH];
	GetEventString(event, "details", vote_details, sizeof(vote_details));
	
	if (!strcmp(vote_details, "#L4D_vote_passed_restart_game"))
	{
		Delete_Timers();
		
		gb_new_game = true;
		gb_gameplay = false;
		
		PrintToServerPlugin("OnMapRestart");
		
		LogToFileEx(gs_logpath, "OnMapRestart");
		//PrintToChatAll("OnMapRestart");
		
		Call_StartForward(gF_OnMapRestart);
		Call_Finish();
	}
	else if (!strcmp("#L4D_vote_passed_mission_change", vote_details)) 
	{
		Delete_Timers();
		
		gb_new_game = true;
		gb_gameplay = false;
		
		PrintToServerPlugin("OnMissionChange");
		
		LogToFileEx(gs_logpath, "OnMissionChange");
		//PrintToChatAll("OnMissionChange");
		
		Call_StartForward(gF_OnMissionChange);
		Call_Finish();
	}
}

void Event_map_transition(Handle event, const char [] name, bool dontBroadcast)
{
	Delete_Timers();
	
	gb_new_game = false;
	gb_gameplay = false;
	
	//EventEnable(player_spawn);
	
	PrintToServerPlugin("OnMapTransit");
	
	LogToFileEx(gs_logpath, "OnMapTransit");
	//PrintToChatAll("OnMapTransit");
	
	Call_StartForward(gF_OnMapTransit);
	Call_Finish();
}

void Event_finale_win(Handle event, const char [] name, bool dontBroadcast)
{
	Delete_Timers();
	
	gb_new_game = false;
	gb_gameplay = false;
	
	EventDisable(player_spawn);
}

void GameplayStart(Handle timer)
{
	PrintToServerPlugin("OnGameplayStart");
	
	LogToFileEx(gs_logpath, "OnGameplayStart");
	//PrintToChatAll("OnGameplayStart");
	
	gi_stage = 0;
	
	Call_StartForward(gF_OnGameplayStart);
	Call_PushCell(gi_stage);
	Call_Finish();
	
	if (IsValidHandle(gt_GameplayStart_Stage))
	{
		delete gt_GameplayStart_Stage;
	}
	
	gt_GameplayStart_Stage = CreateTimer(1.0, GameplayStart_Stage, _, TIMER_REPEAT);
	
	GetConVarString(FindConVar("mp_gamemode"), gs_gamemode, sizeof(gs_gamemode));
	LogToFileEx(gs_logpath, "gs_gamemode: %s", gs_gamemode);
	
	if (!strcmp(gs_gamemode, "survival") ||
		!strcmp(gs_gamemode, "versus") ||
		!strcmp(gs_gamemode, "scavenge"))
	{
		EventEnable(round_end);
	}
	else
	{
		EventEnable(mission_lost);
	}
		
	EventDisable(player_spawn);
}

Action GameplayStart_Stage(Handle timer)
{
	gi_stage ++;
	
	if (gi_stage > MAX_STAGE)
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

void EventEnable(EventName name)
{
	if (gb_eventhook[name])
	{
		return;
	}
	
	gb_eventhook[name] = true;
	
	switch(name)
	{
		case player_spawn:
		{
			HookEvent("player_spawn", Event_player_spawn);
			
			LogToFileEx(gs_logpath, "EventEnable: player_spawn");
		}
		case mission_lost:
		{
			HookEvent("mission_lost", Event_mission_lost, EventHookMode_Pre);
			
			LogToFileEx(gs_logpath, "EventEnable: mission_lost");
		}
		case round_end:
		{
			HookEvent("round_end", Event_round_end);
			
			LogToFileEx(gs_logpath, "EventEnable: round_end");
		}
	}
}

void EventDisable(EventName name)
{
	if (!gb_eventhook[name])
	{
		return;
	}
	
	gb_eventhook[name] = false;
	
	switch(name)
	{
		case player_spawn:
		{
			UnhookEvent("player_spawn", Event_player_spawn);
			
			LogToFileEx(gs_logpath, "EventDisable: player_spawn");
		}
		case mission_lost:
		{
			UnhookEvent("mission_lost", Event_mission_lost, EventHookMode_Pre);
			
			LogToFileEx(gs_logpath, "EventDisable: mission_lost");
		}
		case round_end:
		{
			UnhookEvent("round_end", Event_round_end);
			
			LogToFileEx(gs_logpath, "EventDisable: round_end");
		}
	}
}

int SetUserConnect(int userid)
{
	if (GetUserSlot(userid))
	{
		return 0;
	}
	
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		if (!gi_users[i])
		{
			gi_users[i] = userid;
			LogToFileEx(gs_logpath, "\"SetUserConnect:\" slot %d", i);
			
			return i;
		}
	}
	
	return 0;
}

int SetUserDisconnect(int userid)
{
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		if (gi_users[i] == userid)
		{
			gi_users[i] = 0;
			LogToFileEx(gs_logpath, "\"SetUserDisconnect:\" slot %d", i);
			
			return i;
		}
	}
	
	return 0;
}

int GetUserSlot(int userid)
{
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		if (gi_users[i] == userid)
		{
			return i;
		}
	}

	return 0;
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

