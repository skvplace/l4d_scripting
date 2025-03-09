/**
 * Срабатывает, когда начинается gameplay в режиме coop
 * stage 	- очередность загрузки (секунды)
 
 forward void OnGameplayStart(int stage);

 **
 * Срабатывает, когда сервер покидает последний игрок
 
 forward void OnServerEmpty();

 **
 * Срабатывает, когда меняется карта
 
 forward void OnMapTransit();

 **
 * Срабатывает, когда карта перезапускается
 
 forward void OnMapRestart();

 **
 * Срабатывает, когда запускается спасательный транспорт с выжившими на борту
 
 forward void OnEscapeVehicleLeaving();

 * маркировка глобальных переменных:
 gi_ 	integer
 gf_	float
 gb_	bool
 gs_	string
 gv_ 	vector
 gc_	convar
 gt_	timer
 gk_	key value
 gF_	forvard

**/

#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#include <skvtools>

public Plugin:myinfo =
{
	name 		= "[skvtools] l4d_l4d2_gamestartcoop",
	author 		= "Skv",
	description = "Сreates a global forwards in coop mode",
	version 	= "3.7.1",
	url 		= ""
}

bool DEBUG = false;

#define 		MAX_PLAYERS 	18

int 			gi_stage;
bool 			gb_new_game;
bool 			gb_event_hook;
bool 			gb_change_level;

Handle 			gt_GameplayStart;
Handle 			gt_GameplayStart_Stage;

GlobalForward 	gF_OnGameplayStart;
GlobalForward 	gF_OnMapTransit;
GlobalForward 	gF_OnMapRestart;
GlobalForward 	gF_OnChangeLevel;
GlobalForward 	gF_OnServerEmpty;
GlobalForward 	gF_OnEscapeVehicleLeaving;

ConVar 			gc_server_console;

#define 		MAX_TIMERS					32
Handle 			gt_Timers					[MAX_TIMERS + 1];

public APLRes AskPluginLoad2(Handle plugin, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_Left4Dead && GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left4Dead and Left4Dead2");
		return APLRes_SilentFailure;
	}
	
	RegPluginLibrary("[skvtools] l4d_l4d2_gamestartcoop");
	
	CreateNative("FireChangeLevel", native_FireChangeLevel);
	return APLRes_Success;
}

int native_FireChangeLevel(Handle plugin, int numParams)
{
	int len;
	GetNativeStringLength(1, len);
 
	if (len <= 0)
	{
		return 0;
	}
	
	char[] map = new char[len + 1];
	GetNativeString(1, map, len + 1);
	
	if (!IsMapValid(map))
	{
		return 0;
	}
	
	GetNativeStringLength(2, len);
 
	char[] reason = new char[len + 1];
	GetNativeString(2, reason, len + 1);
	
	Call_StartForward(gF_OnChangeLevel);
	Call_PushString(map);
	Call_PushString(reason);
	Call_Finish();
	
	Delete_Timers();
	gb_change_level = true;
	
	PrintToChatSkv(DEBUG, "ForceChangeLevel");
	ForceChangeLevel(map, reason);
	
	return 1;
}

public OnNeedChangeLevel(char [] map, char [] reason)
{
	Call_StartForward(gF_OnChangeLevel);
	Call_PushString(map);
	Call_PushString(reason);
	Call_Finish();
	
	Delete_Timers();
	gb_change_level = true;	
	
	ForceChangeLevel(map, reason);
}

public OnPluginStart()
{
	HookEvent("mission_lost", Event_mission_lost);
	
	gF_OnGameplayStart = new GlobalForward("OnGameplayStart", ET_Ignore, Param_Cell);
	
	HookEvent("player_disconnect", Event_player_disconnect, EventHookMode_Pre);
	
	gF_OnMapRestart = new GlobalForward("OnMapRestart", ET_Ignore);
	HookEvent("vote_passed", Event_vote_passed);
		
	gF_OnMapTransit = new GlobalForward("OnMapTransit", ET_Ignore);
	HookEvent("map_transition", Event_map_transition, EventHookMode_Pre);
	HookEvent("finale_win", Event_map_transition, EventHookMode_Pre);
	
	gF_OnChangeLevel = new GlobalForward("OnChangeLevel", ET_Ignore, Param_String, Param_String);
	
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

void HookEvent_Enable()
{
	if (!gb_event_hook)
	{
		gb_event_hook = true;
		HookEvent("player_spawn", Event_player_spawn);
	}
}

void HookEvent_Disable()
{
	if (gb_event_hook)
	{
		gb_event_hook = false;
		UnhookEvent("player_spawn", Event_player_spawn);
	}
}

public OnClientPutInServer(int client)
{
	if (IsFakeClient(client))
	{
		return;
	}
	
	bool first_round = true;
			
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		if (i != client && IsValidClient(i) && !IsFakeClient(i))
		{
			first_round = false;
		}
	}
		
	if (first_round)
	{
		PrintToServerPlugin("OnClientPutInServer");
		
		Delete_Timers();
		HookEvent_Enable();
	}
}

void Event_player_spawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsValidClient(client)) {return;}
	
	PrintToChatSkv(DEBUG, "%s", name);
	
	if (!IsFakeClient(client) && GetClientTeam(client) == 2)
	{
		gb_new_game = false;
		
		HookEvent_Disable();
		Delete_Timers();
		
		if (gb_change_level && IsFirstMap())
		{
			PrintToChatSkv(DEBUG, "force restart");
			
			int timer_slot = GetFreeTimerSlot();
			if (timer_slot)
			{
				gt_Timers[timer_slot] = CreateTimer(1.1, Fade_2);
			}
			
			gt_GameplayStart = CreateTimer(3.0, GameplayStart);
			
			DoFadeAll();
			
			ServerCommand("sm_cvar mp_restartgame 1");
		}
		else
		{
			gt_GameplayStart = CreateTimer(0.1, GameplayStart);
		}
		
		gb_change_level = false;
	}
}

Action:Fade_2(Handle timer)
{
	PrintToChatSkv(DEBUG, "Fade_2");
	DoFadeAll(3.0);
}

void DoFadeAll(float time_disable = 0.0)
{
	PrintToChatSkv(DEBUG, "DoFadeAll");
	
	FadeAll(255);
			
	if (time_disable > 0.0)
	{
		int timer_slot = GetFreeTimerSlot();
		if (timer_slot)
		{
			gt_Timers[timer_slot] = CreateTimer(time_disable, DoRestoreSurvivor);
		}
	}
}

Action:DoRestoreSurvivor(Handle timer)
{
	PrintToChatSkv(DEBUG, "DoRestoreSurvivor");
	FadeAll();
}

void FadeAll(int alpha = 0)
{
	if (alpha == 0)
	{
		ScreenFade(0, 0, 0, 0, 0, 1, 500);
	}
	else
	{
		ScreenFade(1, 1, 1, alpha, 200, 0, 5);
	}
}

void ScreenFade(int red, int green, int blue, int alpha, int duration, int type, int speed)
{
	Handle msg = StartMessageAll("Fade");
	BfWriteShort(msg, speed);
	BfWriteShort(msg, duration);
	
	if (type == 0)
	{
		BfWriteShort(msg, (0x0002 | 0x0008));
	}
	else
	{
		BfWriteShort(msg, (0x0001 | 0x0010));
	}
	
	BfWriteByte(msg, red);
	BfWriteByte(msg, green);
	BfWriteByte(msg, blue);
	BfWriteByte(msg, alpha);
	EndMessage();
}

// tx Timocop
bool IsFirstMap()
{
	if (IsFinalMap())
	{
		return false;
	}
	
	new count;
	new i = -1;
	while ((i = FindEntityByClassname(i, "info_landmark")) != -1) 
	{
		count++;
	}
	
	if (count == 1)
	{
		return true;
	}
	
	return false;
} 

bool IsFinalMap()
{
    return (FindEntityByClassname(-1, "info_changelevel") == -1 && FindEntityByClassname(-1, "trigger_changelevel") == -1);
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
	else 
	if (!strcmp(classname, "trigger_finale") || !strcmp(classname, "trigger_finale_dlc3"))
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
		gb_change_level = false;
		
		Call_StartForward(gF_OnMapRestart);
		Call_Finish();
	}
	else if (!strcmp("#L4D_vote_passed_mission_change", vote_details)) 
	{
		Delete_Timers();
		
		PrintToServerPlugin("OnMapTransit");
				
		gb_new_game = false;
		gb_change_level = false;
		
		Call_StartForward(gF_OnMapTransit);
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

void Event_player_disconnect(Handle:event, const String:name[], bool:dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsValidClient(client)) {return;}
	
	if (IsFakeClient(client))
	{
		return;
	}
	
	int people;
		
	for (int i = 1; i <= MaxClients; i++)
	{
		if (i != client && IsClientInGame(i))
		{
			if (!IsFakeClient(i))
			{
				people ++;
			}
		}
	}
	
	if (people)
	{
		return;
	}
	
	Delete_Timers();
	
	PrintToServerPlugin("OnServerEmpty");
		
	gb_new_game = false;
	gb_change_level = false;
	
	Call_StartForward(gF_OnServerEmpty);
	Call_Finish();
}

Action:GameplayStart(Handle timer)
{
	PrintToServerPlugin("OnGameplayStart");
	PrintToChatSkv(DEBUG, "GameplayStart");
	
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
	
	for (int i = 1; i <= MAX_TIMERS; i++)
	{
		if (IsValidHandle(gt_Timers[i]))
		{
			delete gt_Timers[i];
		}
	}
}

int GetFreeTimerSlot()
{
	for (int i = 1; i <= MAX_TIMERS; i++)
	{
		if (!IsValidHandle(gt_Timers[i]))
		{
			return i;
		}
	}
	
	return 0;
}