/**
 * ========================================================================
 * Plugin [L4D/L4D2] Teleport survivors
 * Teleportation of belated survivors.
 * ========================================================================
 *
 * This program is free software; you can redistribute it and/or modify it.
 *
**/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#include <skvtools>

public Plugin myinfo = 
{
	name 		= "[L4D] Teleport survivors",
	author 		= "Skv",
	description = "Teleports belated survivors to elevators, shelters, and rescue vehicles",
	version 	= "3.4 (d)",
	url 		= "https://forums.alliedmods.net/showthread.php?p=2841063#post2841063"
}

bool DEBUG 			= false;
bool DEBUG_HELP 	= false;
bool DEBUG_SPRITE 	= false;
bool DEBUG_LOG 		= false;
char debugfile		[MAX_STRING_LENGTH];

char gs_glow_model[] = "sprites/glow01.vmt";

#define TRIGGER_SAFEROOM_NAME 				"ts_trigger_saferoom"
#define TRIGGER_ELEVATOR_NAME 				"ts_trigger_elevator"
#define TRIGGER_ESCAPE_NAME 				"ts_trigger_escape"
#define TRIGGER_DOORWAY_NAME				"ts_trigger_doorway"

char 	gs_model_trigger[] 					= "models/props_street/garbage_can.mdl";

float 	gv_pos_teleport[3];

bool 	gb_mission_lost;

Handle 	gt_OnTrigger;
Handle 	gt_Teleport;
Handle 	gt_SearchFarBots;
Handle 	gt_TimerThreat						[MAX_SURVIVORID + 1];
Handle 	gt_BotHelps							[MAX_SURVIVORID + 1];

ConVar 	gc_teleport_countdown_elevator;
ConVar 	gc_teleport_countdown_escape;
ConVar 	gc_teleport_countdown_saferoom;
ConVar 	gc_teleport_percent;
ConVar 	gc_teleport_percent_bot;
ConVar 	gc_teleport_bot_countdown;
ConVar 	gc_teleport_bot_distance;
ConVar 	gc_teleport_bot_interval;
ConVar 	gc_teleport_bot_threat;
ConVar 	gc_teleport_bot_help;
ConVar 	gc_teleport_bot_threat_distance;
ConVar 	gc_teleport_plugin_enabled;
ConVar 	gc_teleport_gamemode_supported;

bool 	gb_plugin_enabled;
bool 	gb_eventhook;

float 	gf_teleport_bot_interval;
float 	gf_teleport_bot_threat_distance;

int 	gi_teleport_countdown;

Handle 	gk_button_triggers;

#define MAX_ESCAPE_DATA 					8 
int 	gi_escape_trigger_hammerid			[MAX_ESCAPE_DATA + 1];

int 	gi_survivor_teleport;
int 	gi_gather_percent;

int 	gi_help_owner						[MAX_SURVIVORID + 1]; // bot
int 	gi_help_target						[MAX_SURVIVORID + 1]; // client

float 	gv_pos_opener[3];

public APLRes AskPluginLoad2(Handle plugin, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_Left4Dead && GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left4Dead & Left4dead2");
		return APLRes_SilentFailure;
	}
			
	return APLRes_Success;
}

public void OnPluginStart()
{
	char plugin_name[PLATFORM_MAX_PATH];
	GetPluginFilename(INVALID_HANDLE, plugin_name, sizeof(plugin_name));
	
	BuildPath(Path_SM, debugfile, sizeof(debugfile), "data/%s.log", plugin_name);
	
	gc_teleport_countdown_elevator 	= CreateConVar("ts_teleport_countdown_elevator", "20", "Countdown to teleportation to the elevators. 0 - is disabled", _, true, 0.0, true, 240.0);
	gc_teleport_countdown_escape 	= CreateConVar("ts_teleport_countdown_escape", "20", "Countdown to teleportation to escape. 0 - is disabled", _, true, 0.0, true, 240.0);
	gc_teleport_countdown_saferoom 	= CreateConVar("ts_teleport_countdown_saferoom", "20", "Countdown to teleportation to saferoom. 0 - is disabled", _, true, 0.0, true, 240.0);
	gc_teleport_percent 			= CreateConVar("ts_teleport_percent", "51", "Percentage of survivors required for activation", _, true, 1.0, true, 100.0);
	gc_teleport_percent_bot 		= CreateConVar("ts_teleport_percent_bot", "1", "The percentage of teleportation should take into account bots.", _, true, 0.0, true, 1.0);
	gc_teleport_bot_interval = CreateConVar("ts_teleport_bot_interval", "30", "What interval in seconds should I scan for lagging bots?. If less than 1, then disabled", _, true, 0.0, true, 240.0); 
	gc_teleport_bot_distance		= CreateConVar("ts_teleport_bot_distance", "1500", "If the bots are further than this distance, they will be moved", _, true, 500.0, true, 3000.0); 
	gc_teleport_bot_threat			= CreateConVar("ts_teleport_bot_threat", "2.0", "Bot movement time when threatened. 0 - is disabled", _, true, 0.0, true, 15.0);
	gc_teleport_bot_help			= CreateConVar("ts_teleport_bot_help", "2.0", "Bot movement time when need help. 0 - is disabled", _, true, 0.0, true, 15.0);
	gc_teleport_bot_threat_distance	= CreateConVar("ts_teleport_bot_threat_distance", "300", "If the bots are further than this distance, they will be moved", _, true, 300.0, true, 2000.0); 
	gc_teleport_bot_countdown		= CreateConVar("ts_teleport_bot_countdown", "1", "Enables the teleportation countdown for bots. If 0, bots are teleported without a countdown.", _, true, 0.0, true, 1.0); 
	gc_teleport_plugin_enabled		= CreateConVar("ts_teleport_plugin_enabled", "1", "Enables plugin", _, true, 0.0, true, 1.0); 
	gc_teleport_gamemode_supported = CreateConVar("ts_teleport_gamemode_supported", "coop, realism, mutation, survival", "Set supported game modes");
	
	SetConVarFlags(gc_teleport_countdown_elevator, GetConVarFlags(gc_teleport_countdown_elevator) & ~FCVAR_NOTIFY);
	SetConVarFlags(gc_teleport_countdown_escape, GetConVarFlags(gc_teleport_countdown_escape) & ~FCVAR_NOTIFY);
	SetConVarFlags(gc_teleport_countdown_saferoom, GetConVarFlags(gc_teleport_countdown_saferoom) & ~FCVAR_NOTIFY);
	SetConVarFlags(gc_teleport_percent, GetConVarFlags(gc_teleport_percent) & ~FCVAR_NOTIFY);
	SetConVarFlags(gc_teleport_percent_bot, GetConVarFlags(gc_teleport_percent_bot) & ~FCVAR_NOTIFY);
	SetConVarFlags(gc_teleport_bot_interval, GetConVarFlags(gc_teleport_bot_interval) & ~FCVAR_NOTIFY);
	SetConVarFlags(gc_teleport_bot_distance, GetConVarFlags(gc_teleport_bot_distance) & ~FCVAR_NOTIFY);
	SetConVarFlags(gc_teleport_bot_threat, GetConVarFlags(gc_teleport_bot_threat) & ~FCVAR_NOTIFY);
	SetConVarFlags(gc_teleport_bot_threat, GetConVarFlags(gc_teleport_bot_threat) & ~FCVAR_NOTIFY);
	SetConVarFlags(gc_teleport_bot_help, GetConVarFlags(gc_teleport_bot_help) & ~FCVAR_NOTIFY);
	SetConVarFlags(gc_teleport_bot_threat_distance, GetConVarFlags(gc_teleport_bot_threat_distance) & ~FCVAR_NOTIFY);
	SetConVarFlags(gc_teleport_bot_countdown, GetConVarFlags(gc_teleport_bot_countdown) & ~FCVAR_NOTIFY);
	SetConVarFlags(gc_teleport_plugin_enabled, GetConVarFlags(gc_teleport_plugin_enabled) & ~FCVAR_NOTIFY);
	SetConVarFlags(gc_teleport_gamemode_supported, GetConVarFlags(gc_teleport_gamemode_supported) & ~FCVAR_NOTIFY);
	
	AutoExecConfig(true, "teleport_survivors");
	LoadTranslations("teleport_survivors.phrases");
	
	gb_plugin_enabled = GetConVarBool(gc_teleport_plugin_enabled);
	
	if (gb_plugin_enabled)
	{
		char gamemode_supported[PLATFORM_MAX_PATH];
		GetConVarString(gc_teleport_gamemode_supported, gamemode_supported, sizeof(gamemode_supported));
		
		char gamemode[MAX_STRING_LENGTH];
		GetConVarString(FindConVar("mp_gamemode"), gamemode, sizeof(gamemode));
		if (StrContains(gamemode_supported, gamemode) == -1)
		{
			gb_plugin_enabled = false;
		}
	}
}

public void OnAllPluginsLoaded()
{
	if (!LibraryExists("[skvtools] l4d_gamestart"))
	{
		SetFailState("The library [skvtools] l4d_gamestart was not found!");
	}
}

public void OnMapInit(const char[] mapName)
{
	gb_plugin_enabled = GetConVarBool(gc_teleport_plugin_enabled);
	
	if (gb_plugin_enabled)
	{
		char gamemode_supported[MAX_STRING_LENGTH];
		GetConVarString(gc_teleport_gamemode_supported, gamemode_supported, sizeof(gamemode_supported));
		
		char gamemode[MAX_STRING_LENGTH];
		GetConVarString(FindConVar("mp_gamemode"), gamemode, sizeof(gamemode));
			
		if (StrContains(gamemode_supported, gamemode) == -1)
		{
			gb_plugin_enabled = false;
			LogMessage("The plugin is disabled because mp_gamemode is not supported!");
		}
	}
	else
	{
		LogMessage("The plugin is disabled because ts_teleport_plugin_enabled is 0");
	}
	
	if (!gb_plugin_enabled)
	{
		Events_RemoveHooks();
		return;
	}
	
	Events_SetHooks();
	
	LogToDebug(DEBUG_LOG, debugfile, "OnMapInit: \"%s\"", mapName);
	
	if (gk_button_triggers != null)
	{
		delete gk_button_triggers;
	}
	
	gk_button_triggers = CreateKeyValues("button_triggers");
	
	Search_Trigger();
}

public void OnMapStart()
{
	PrecacheModel(gs_glow_model);
	PrecacheModel(gs_model_trigger);
}

void Events_SetHooks()
{
	if (gb_eventhook)
	{
		return;
	}
	
	gb_eventhook = true;
	
	HookEvent("finale_win",  Event_finale_win);
	
	HookEvent("player_hurt",  Event_player_hurt);
	HookEvent("player_incapacitated", Event_player_need_help);
	HookEvent("player_ledge_grab", Event_player_need_help);
	HookEvent("revive_success", Event_revive_success);
		
	HookEvent("lunge_pounce", Event_player_attacked);
	HookEvent("tongue_grab", Event_player_attacked);
		
	HookEvent("pounce_end", Event_player_released);
	HookEvent("pounce_stopped", Event_player_released);
	HookEvent("tongue_release", Event_player_released);
	HookEvent("tongue_pull_stopped", Event_player_released);
		
	if (GetEngineVersion() == Engine_Left4Dead2)
	{
		HookEvent("charger_pummel_start", Event_player_attacked);
		HookEvent("jockey_ride", Event_player_attacked);
			
		HookEvent("charger_pummel_end", Event_player_released);
		HookEvent("jockey_ride_end", Event_player_released);
	}
}

void Events_RemoveHooks()
{
	if (!gb_eventhook)
	{
		return;
	}
	
	gb_eventhook = false;
	
	UnhookEvent("finale_win",  Event_finale_win);
	
	UnhookEvent("player_hurt",  Event_player_hurt);
	UnhookEvent("player_incapacitated", Event_player_need_help);
	UnhookEvent("player_ledge_grab", Event_player_need_help);
	UnhookEvent("revive_success", Event_revive_success);
		
	UnhookEvent("lunge_pounce", Event_player_attacked);
	UnhookEvent("tongue_grab", Event_player_attacked);
		
	UnhookEvent("pounce_end", Event_player_released);
	UnhookEvent("pounce_stopped", Event_player_released);
	UnhookEvent("tongue_release", Event_player_released);
	UnhookEvent("tongue_pull_stopped", Event_player_released);
		
	if (GetEngineVersion() == Engine_Left4Dead2)
	{
		UnhookEvent("charger_pummel_start", Event_player_attacked);
		UnhookEvent("jockey_ride", Event_player_attacked);
			
		UnhookEvent("charger_pummel_end", Event_player_released);
		UnhookEvent("jockey_ride_end", Event_player_released);
	}
}

public void OnGameplayStart(int stage)
{
	if (stage != 5)
	{
		return;
	}
	
	gb_plugin_enabled = GetConVarBool(gc_teleport_plugin_enabled);
	
	if (gb_plugin_enabled)
	{
		char gamemode_supported[PLATFORM_MAX_PATH];
		GetConVarString(gc_teleport_gamemode_supported, gamemode_supported, sizeof(gamemode_supported));
		
		char gamemode[MAX_STRING_LENGTH];
		GetConVarString(FindConVar("mp_gamemode"), gamemode, sizeof(gamemode));
		if (StrContains(gamemode_supported, gamemode) == -1)
		{
			gb_plugin_enabled = false;
		}
	}
	
	if (!gb_plugin_enabled)
	{
		return;
	}
	
	gb_mission_lost = false;
	
	Delete_Timers();
	
	if (DEBUG)
	{
		SetConVarInt(gc_teleport_countdown_elevator, 10);
		SetConVarInt(gc_teleport_countdown_saferoom, 10);
		SetConVarInt(gc_teleport_countdown_escape, 10);
		SetConVarInt(gc_teleport_percent, 51);
		SetConVarInt(gc_teleport_percent_bot, 1);
		SetConVarInt(gc_teleport_bot_countdown, 1);
		
		//SetConVarFloat(gc_teleport_bot_interval, 240.0);
		//SetConVarFloat(gc_teleport_bot_distance, 2000.0);
		//SetConVarFloat(gc_teleport_bot_threat_distance, 10.0);
		
		PrintToChatSkv(DEBUG, "OnGameplayStart: set convars");
		LogToDebug(DEBUG_LOG, debugfile, "OnGameplayStart: set convars");
	}
	
	gf_teleport_bot_interval = GetConVarFloat(gc_teleport_bot_interval);
	if (gf_teleport_bot_interval >= 1.0)
	{
		gt_SearchFarBots = RTimerCreate(gf_teleport_bot_interval, SearchFarBots, _, TIMER_REPEAT | TIMER_FLAG_NO_ROUNDCHANGE);
	}
	
	gf_teleport_bot_threat_distance = GetConVarFloat(gc_teleport_bot_threat_distance);
	
	int entity;
	
	if (GetConVarInt(gc_teleport_countdown_elevator))
	{	
		int i = -1;
		while ((i = FindEntityByClassname(i, "func_button")) != -1)
		{
			Search_ButtonTriggers(i);
		}
	}
	
	if (GetConVarInt(gc_teleport_countdown_saferoom))
	{
		Search_SafeDoor();
	}
	
	if (GetConVarInt(gc_teleport_countdown_escape))
	{
		if (FindEntityByClassname(-1, "info_changelevel") != -1)
		{
			PrintToChatSkv(DEBUG, "OnGameplayStart: its not finale map");
			LogToDebug(DEBUG_LOG, debugfile, "OnGameplayStart: its not finale map");
			return;
		}
		
		PrintToChatSkv(DEBUG, "OnGameplayStart: finale map");
		
		for (int i = 1; i <= MAX_ESCAPE_DATA; i++)
		{
			if (gi_escape_trigger_hammerid[i])
			{
				entity = FindEntityByHammerid(gi_escape_trigger_hammerid[i]);
				if (IsEntityValid(entity))
				{
					HookSingleEntityOutput(entity, "OnTrigger", OnStartTouch_Escape);
																			
					PrintToChatSkv(DEBUG, "OnGameplayStart: find trigger %d, hammerid %d", entity, gi_escape_trigger_hammerid[i]);
					LogToDebug(DEBUG_LOG, debugfile, "OnGameplayStart: find trigger %d, hammerid %d", entity, gi_escape_trigger_hammerid[i]);
					
					SetDebugSpritesTrigger(entity, "255 255 255");
				}
			}
		}
	}
}

void OnPressed(const char[] output, int button, int activator, float delay)
{
	PrintToChatSkv(DEBUG, "OnPressed: entity %d", button);
	
	Teleport_Cancel();
	
	RTimerKill(gt_OnTrigger);
	
	UnhookSingleEntityOutput(button, "OnPressed", OnPressed);
}

void OnUseLocked(const char[] output, int button, int client, float delay)
{
	if (!IsValidClientTeam2Alive(client))
	{
		return;
	}
	
	PrintToChatSkv(DEBUG, "%s: button %d", output, button);
	
	int countdown = GetConVarInt(gc_teleport_countdown_elevator);
	if (countdown <= 0)
	{
		return;
	}
	
	int trigger = GetTriggerOfButton(button);
	if (!trigger)
	{
		char targetname_button[MAX_STRING_LENGTH]; 
		GetEntPropString(button, Prop_Data, "m_iName", targetname_button, sizeof(targetname_button));
		
		LogError("OnUseLocked: trigger is no found, button name %s", targetname_button);
		return;
	}
	
	int disabled = GetEntProp(trigger, Prop_Data, "m_bDisabled");
	if (disabled)
	{
		PrintToChatSkv(DEBUG, "%s: trigger %d is disabled", output, trigger);
		return;
	}
	
	UnhookSingleEntityOutput(button, output, OnUseLocked);
	
	GetClientAbsOrigin(client, gv_pos_teleport);
	gv_pos_teleport[2] += 10.0;
	
	RTimerKill(gt_OnTrigger);
	
	DataPack pack;
	
	gt_OnTrigger = RTimerDataCreate(1.0, OnTrigger, pack, TIMER_REPEAT | TIMER_FLAG_NO_ROUNDCHANGE);
	
	if (gt_OnTrigger != null)
	{	
		WritePackCell(pack, EntIndexToEntRef(trigger));
		WritePackCell(pack, countdown);
	}
}

void OnStartTouch_SafeRoom(const char[] output, int trigger, int client, float delay)
{
	if (!IsValidClientTeam2Alive(client))
	{
		return;
	}
	
	char targetname[MAX_STRING_LENGTH]; 
	GetEntPropString(trigger, Prop_Data, "m_iName", targetname, sizeof(targetname));
	
	PrintToChatSkv(DEBUG, "OnStartTouch_SafeRoom: %s", targetname);
	
	int countdown = GetConVarInt(gc_teleport_countdown_saferoom);
	if (countdown <= 0)
	{
		return;
	}
	
	UnhookSingleEntityOutput(trigger, output, OnStartTouch_SafeRoom);
	
	float pos_entity[3];
	GetEntPropVector(trigger, Prop_Data, "m_vecOrigin", pos_entity);
	
	GetClientAbsOrigin(client, gv_pos_teleport);
	gv_pos_teleport[2] += 10.0;
	
	float ang[3];
	
	ang[0] = 0.0;
	ang[1] = GetAngleOrigin(gv_pos_teleport, pos_entity);
	ang[2] = 0.0;
	
	MovePos_Forward(gv_pos_teleport, ang, 50.0);
		
	RTimerKill(gt_OnTrigger);
	
	DataPack pack;
	
	gt_OnTrigger = RTimerDataCreate(2.0, OnTrigger, pack, TIMER_REPEAT | TIMER_FLAG_NO_ROUNDCHANGE);
	
	if (gt_OnTrigger != null)
	{	
		WritePackCell(pack, EntIndexToEntRef(trigger));
		WritePackCell(pack, countdown);
	}
}

void OnFullyClosed(char [] output, int safedoor, int client, float delay)
{
	if (!IsValidClientTeam2Alive(client))
	{
		return;
	}
	
	int countdown = GetConVarInt(gc_teleport_countdown_saferoom);
	if (countdown <= 0)
	{
		return;
	}
	
	int trigger;
	
	char targetname[MAX_STRING_LENGTH];
	
	int i = -1;
	while ((i = FindEntityByClassname(i, "trigger_multiple")) != -1)
	{
		GetEntPropString(i, Prop_Data, "m_iName", targetname, sizeof(targetname));
		if (!strcmp(targetname, TRIGGER_SAFEROOM_NAME))
		{
			trigger = i;
			break;
		}
	}
	
	if (!trigger)
	{
		LogError("%s: trigger is no found", output);
		return;
	}
	
	if (!gv_pos_opener[0] && !gv_pos_opener[1] && !gv_pos_opener[2])
	{
		return;
	}
	
	UnhookSingleEntityOutput(safedoor, output, OnFullyClosed);
	
	PrintToChatSkv(DEBUG, "OnFullyClosed: client %N, safedoor %d", client, safedoor);
	
	float pos_door[3];
	GetEntPropVector(safedoor, Prop_Data, "m_vecAbsOrigin", pos_door);
	
	PrintToChatSkv(DEBUG, "OnFullyClosed: pos_door %d, %d, %d", RoundFloat(pos_door[0]), RoundFloat(pos_door[1]), RoundFloat(pos_door[2]));
	
	float ang_door[3];
	GetEntPropVector(safedoor, Prop_Data, "m_angRotation", ang_door);
	
	ang_door[0] = 0.0;
	ang_door[1] += 90.0;
	ang_door[2] = 0.0;
		
	float vMaxs[3], vMins[3];
			
	GetEntPropVector(safedoor, Prop_Send, "m_vecMaxs", vMaxs);
	GetEntPropVector(safedoor, Prop_Send, "m_vecMins", vMins);
		
	float distance = (vMins[1] * (-1) + vMaxs[1]) * 0.5;
		
	MovePos_Forward(pos_door, ang_door, distance);
	
	pos_door[2] += vMins[2];
	pos_door[2] += (vMins[2] * (-1) + vMaxs[2]) * 0.1; // 0.36
	
	PrintToChatSkv(DEBUG, "OnFullyClosed: pos_safedoor %d, %d, %d", RoundFloat(pos_door[0]), RoundFloat(pos_door[1]), RoundFloat(pos_door[2]));
	
	SetDebugSprites(pos_door, "255 255 0");
	
	float ang_entity[3];
						
	ang_entity[0] = 0.0;
	ang_entity[1] = GetAngleOrigin(gv_pos_opener, pos_door);
	ang_entity[2] = 0.0;
		
	PrintToChatSkv(DEBUG, "OnTrigger_SafeRoom: ang_entity[1] %f", ang_entity[1]);
			
	MovePos_Forward(pos_door, ang_entity, 90.0);
			
	gv_pos_teleport = pos_door;		
		
	SetDebugSprites(gv_pos_teleport, "0 255 0");
	
	RTimerKill(gt_OnTrigger);
	
	DataPack pack;
	
	gt_OnTrigger = RTimerDataCreate(2.0, OnTrigger, pack, TIMER_REPEAT | TIMER_FLAG_NO_ROUNDCHANGE);
	
	if (gt_OnTrigger != null)
	{	
		WritePackCell(pack, EntIndexToEntRef(trigger));
		WritePackCell(pack, countdown);
	}
}

void OnStartTouch_Escape(const char[] output, int trigger, int client, float delay)
{
	if (!IsValidClientTeam2Alive(client))
	{
		return;
	}
	
	char targetname[MAX_STRING_LENGTH]; 
	GetEntPropString(trigger, Prop_Data, "m_iName", targetname, sizeof(targetname));
	
	PrintToChatSkv(DEBUG, "OnTrigger_Escape: %s", targetname);
	
	int countdown = GetConVarInt(gc_teleport_countdown_escape);
	if (countdown <= 0)
	{
		return;
	}
	
	UnhookSingleEntityOutput(trigger, output, OnStartTouch_Escape);
	
	float pos_entity[3];
	GetEntPropVector(trigger, Prop_Data, "m_vecOrigin", pos_entity);
	
	GetClientAbsOrigin(client, gv_pos_teleport);
	gv_pos_teleport[2] += 10.0;
	
	float ang[3];
	
	ang[0] = 0.0;
	ang[1] = GetAngleOrigin(gv_pos_teleport, pos_entity);
	ang[2] = 0.0;
	
	MovePos_Forward(gv_pos_teleport, ang, 50.0);
	
	RTimerKill(gt_OnTrigger);
	
	DataPack pack;
	
	gt_OnTrigger = RTimerDataCreate(2.0, OnTrigger, pack, TIMER_REPEAT | TIMER_FLAG_NO_ROUNDCHANGE);
	
	if (gt_OnTrigger != null)
	{	
		WritePackCell(pack, EntIndexToEntRef(trigger));
		WritePackCell(pack, countdown);
	}
}

int SafeRoomTrigger_Spawn(int safedoor)
{
	LogToDebug(DEBUG_LOG, debugfile, "SafeRoomTrigger_Spawn: safedoor %d", safedoor);
	
	int info_changelevel = FindEntityByClassname(-1, "info_changelevel");
	if (!IsEntityValid(info_changelevel))
	{
		return 0;
	}
	
	char targetname[MAX_STRING_LENGTH];
	
	int i = -1;
	while ((i = FindEntityByClassname(i, "trigger_multiple")) != -1)
	{
		GetEntPropString(i, Prop_Data, "m_iName", targetname, sizeof(targetname));
		if (!strcmp(targetname, TRIGGER_SAFEROOM_NAME))
		{
			InputKill(i);
		}
	}
	
	float vMins[3];
	GetEntPropVector(info_changelevel, Prop_Data, "m_vecMins", vMins);
	
	//PrintToChatSkv(DEBUG, "SafeRoomTrigger_Spawn: vMins %d, %d, %d", RoundFloat(vMins[0]), RoundFloat(vMins[1]), RoundFloat(vMins[2]));
	
	float vMaxs[3];
	GetEntPropVector(info_changelevel, Prop_Data, "m_vecMaxs", vMaxs);
	
	float pos_spawn[3];
	GetEntPropVector(info_changelevel, Prop_Data, "m_vecMaxs", pos_spawn);
	
	//PrintToChatSkv(DEBUG, "SafeRoomTrigger_Spawn: vMaxs %d, %d, %d", RoundFloat(vMaxs[0]), RoundFloat(vMaxs[1]), RoundFloat(vMaxs[2]));
	
	vMaxs[0] = (vMaxs[0] - vMins[0]) * 0.5;
	vMaxs[1] = (vMaxs[1] - vMins[1]) * 0.5;
	vMaxs[2] = (vMaxs[2] - vMins[2]) * 0.5;
	
	//PrintToChatSkv(DEBUG, "SafeRoomTrigger_Spawn: vMaxs trigger %d, %d, %d", RoundFloat(vMaxs[0]), RoundFloat(vMaxs[1]), RoundFloat(vMaxs[2]));
	
	vMins[0] = vMaxs[0] * (-1.0);
	vMins[1] = vMaxs[1] * (-1.0);
	vMins[2] = vMaxs[2] * (-1.0);
	
	//PrintToChatSkv(DEBUG, "SafeRoomTrigger_Spawn: vMins trigger %d, %d, %d", RoundFloat(vMins[0]), RoundFloat(vMins[1]), RoundFloat(vMins[2]));
	
	pos_spawn[0] -= vMaxs[0];
	pos_spawn[1] -= vMaxs[1];
	pos_spawn[2] -= vMaxs[2];
	
	PrintToChatSkv(DEBUG, "SafeRoomTrigger_Spawn: pos_spawn %d, %d, %d", RoundFloat(pos_spawn[0]), RoundFloat(pos_spawn[1]), RoundFloat(pos_spawn[2]));
	
	float scale = 1.05;
	
	vMins[0] *= scale;
	vMins[1] *= scale;
	vMins[2] *= 1.10;
	
	vMaxs[0] *= scale;
	vMaxs[1] *= scale;
	
	int entity = CreateEntityByName("trigger_multiple");
	if (entity == -1)
	{
		return 0;
	}
	
	if (IsEntityValid(safedoor))
	{
		SetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity", safedoor);
		
		PrintToChatSkv(DEBUG, "SafeRoomTrigger_Spawn: set owner %d", safedoor);
		LogToDebug(DEBUG_LOG, debugfile, "SafeRoomTrigger_Spawn: set owner %d", safedoor);
	}
	else
	{
		HookSingleEntityOutput(entity, "OnStartTouch", OnStartTouch_SafeRoom);
		
		PrintToChatSkv(DEBUG, "SafeRoomTrigger_Spawn: set hook OnStartTouch");
		LogToDebug(DEBUG_LOG, debugfile, "SafeRoomTrigger_Spawn: set hook OnStartTouch");
	}
	
	DispatchKeyValue(entity, "targetname", TRIGGER_SAFEROOM_NAME);
	DispatchKeyValue(entity, "spawnflags", "1");
	DispatchKeyValue(entity, "entireteam", "2");
	DispatchKeyValue(entity, "allowincap", "1");
	DispatchKeyValue(entity, "wait", "1.0");
	
	DispatchSpawn(entity);
	ActivateEntity(entity);
	
	//pos_spawn[2] += 2.0;
	TeleportEntity(entity, pos_spawn);
	
	SetEntityModel(entity, gs_model_trigger);
	
	SetEntPropVector(entity, Prop_Send, "m_vecMins", vMins);
	SetEntPropVector(entity, Prop_Send, "m_vecMaxs", vMaxs);
	SetEntProp(entity, Prop_Send, "m_nSolidType", 2);
	
	int enteffects = GetEntProp(entity, Prop_Send, "m_fEffects");
	enteffects |= 32;
	SetEntProp(entity, Prop_Send, "m_fEffects", enteffects); 
	
	PrintToChatSkv(DEBUG, "SafeRoomTrigger_Spawn: spawn trigger %d", entity);
	LogToDebug(DEBUG_LOG, debugfile, "SafeRoomTrigger_Spawn: spawn trigger %d", entity);
	
	SetDebugSpritesTrigger(entity, "255 255 255");
	
	return entity;
}

void DoorwayTrigger_Spawn(int safedoor)
{
	if (!IsEntityValid(safedoor))
	{
		return;
	}
	
	float pos_spawn[3];
	GetEntPropVector(safedoor, Prop_Data, "m_vecAbsOrigin", pos_spawn);
	
	float vMins[3];
	GetEntPropVector(safedoor, Prop_Data, "m_vecMins", vMins);
	
	vMins[1] = -27.0;
	vMins[0] = -27.0;
		
	float vMaxs[3];
	GetEntPropVector(safedoor, Prop_Data, "m_vecMaxs", vMaxs);
	
	vMaxs[1] = 27.0;
	vMaxs[0] = 27.0;
		
	int entity = CreateEntityByName("trigger_multiple");
	if (entity == -1)
	{
		return;
	}
	
	SetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity", safedoor);
			
	DispatchKeyValue(entity, "targetname", TRIGGER_DOORWAY_NAME);
	DispatchKeyValue(entity, "spawnflags", "1");
	DispatchKeyValue(entity, "allowincap", "0");
	DispatchKeyValue(entity, "entireteam", "2");
	DispatchKeyValue(entity, "wait", "1.0");
		
	DispatchSpawn(entity);
	ActivateEntity(entity);
	
	TeleportEntity(entity, pos_spawn);
	
	SetEntityModel(entity, gs_model_trigger);
	
	SetEntPropVector(entity, Prop_Send, "m_vecMins", vMins);
	SetEntPropVector(entity, Prop_Send, "m_vecMaxs", vMaxs);
	SetEntProp(entity, Prop_Send, "m_nSolidType", 2);
	
	int enteffects = GetEntProp(entity, Prop_Send, "m_fEffects");
	enteffects |= 32;
	SetEntProp(entity, Prop_Send, "m_fEffects", enteffects); 
	
	HookSingleEntityOutput(entity, "OnStartTouch", OnStartTouch_doorway);
	
	PrintToChatSkv(DEBUG, "DoorwayTrigger_Spawn: spawn trigger %d", entity);
	LogToDebug(DEBUG_LOG, debugfile, "DoorwayTrigger_Spawn: spawn trigger %d", entity);
	
	SetDebugSpritesTrigger(entity, "255 0 255");
}

void OnStartTouch_doorway(const char[] output, int trigger, int client, float delay)
{
	if (!IsVisible(client, GetEntPropEnt(trigger, Prop_Data, "m_hOwnerEntity")))
	{
		return;
	}
	
	UnhookSingleEntityOutput(trigger, output, OnStartTouch_doorway);
	
	GetClientAbsOrigin(client, gv_pos_opener);
	SetDebugSprites(gv_pos_opener, "0 0 255"); 
		
	InputKill(trigger);
}

bool IsVisible(int client, int entity)
{
	if (!IsValidClientTeam2Alive(client))
	{
		return false;
	}
	
	if (!IsEntityValid(entity))
	{
		return false;
	}
		
	float pos_start[3];
	GetClientEyePosition(client, pos_start);
	
	float pos_end[3];
	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", pos_end);
	
	char classname[MAX_CLASSNAME_LENGTH];
	GetEntityClassname(entity, classname, sizeof(classname));
	
	float ang_client[3];
	GetClientEyeAngles(client, ang_client);
	
	ang_client[0] = 0.0;
	ang_client[2] = 0.0;
	
	MovePos_Forward(pos_end, ang_client, 5.0); // 10.0
	
	Handle trace = TR_TraceRayFilterEx(pos_start, pos_end, MASK_SOLID, RayType_EndPoint, TraceFilter_Visible);
	if (TR_DidHit(trace))
	{
		int index = TR_GetEntityIndex(trace);
		delete trace;
		
		if (index == entity)
		{
			return true;
		}
		
		return false;
	}
	
	delete trace;
	return true;
}

bool TraceFilter_Visible(int entity, int contentsMask)
{
	char classname[MAX_CLASSNAME_LENGTH];
	GetEntityClassname(entity, classname, sizeof(classname));
	
	if (!strcmp(classname, "prop_door_rotating_checkpoint"))
	{
		return true;
	}
		
	if (entity > 0 && IsEntityValid(entity)) return false;
	
	return true;
}

Action OnTrigger(Handle timer, Handle h_data)
{
	if (!IsValidHandle(h_data))
	{
		gt_OnTrigger = null;
		return Plugin_Stop;
	}
	
	RTimerSetInterval(timer, 1.0);
	
	DataPack pack = view_as<DataPack>(h_data);
	ResetPack(pack);
	
	int trigger 	= EntRefToEntIndex(ReadPackCell(pack));
	int countdown 	= ReadPackCell(pack);
	
	if (!IsSurvivorsGathered(trigger))
	{
		PrintToChatSkv(DEBUG, "OnTrigger: gathered false");
		Teleport_Cancel();
		
		return Plugin_Continue;
	}
	
	PrintToChatSkv(DEBUG, "OnTrigger: gathered true");
	
	if (!GetConVarBool(gc_teleport_bot_countdown) && IsAllHumansInside(trigger))
	{
		Teleport(null,  EntIndexToEntRef(trigger));
		
		gt_OnTrigger = null;
		return Plugin_Stop;
	}
	
	if (OnEntireTeam(trigger))
	{
		Teleport_Cancel();
		return Plugin_Continue;
	}
	
	if (gt_Teleport != null)
	{
		return Plugin_Continue;
	}
	
	gi_teleport_countdown = countdown + 1;
	
	gt_Teleport = RTimerCreate(1.0, Teleport, EntIndexToEntRef(trigger), TIMER_REPEAT | TIMER_FLAG_NO_ROUNDCHANGE);
	
	return Plugin_Continue;
}

bool OnEntireTeam(int trigger)
{
	if (!IsEntityValid(trigger))
	{
		return false;
	}
	
	int people;
	int people_inside;
			
	for (int client = 1; client <= MAX_PLAYERS; client ++)
	{
		if (IsValidClientTeam2Alive(client))
		{
			people ++;
				
			if (IsClientInTrigger(client, trigger))
			{
				people_inside ++;
			}
		}
	}
	
	if (people == people_inside)
	{
		return true;
	}
	
	return false;
}

int IsSurvivorsGathered(int trigger)
{
	if (!IsEntityValid(trigger))
	{
		return 0;
	}
	
	bool bot = GetConVarBool(gc_teleport_percent_bot);
	
	int people;
	int people_inside;
			
	for (int client = 1; client <= MAX_PLAYERS; client ++)
	{
		if (IsValidClientTeleport(client))
		{
			if (bot && IsFakeClient(client) || !IsFakeClient(client))
			{
				people ++;
				
				if (IsClientInTrigger(client, trigger))
				{
					people_inside ++;
				}
			}
		}
	}
	
	gi_gather_percent = 0;
	gi_survivor_teleport = people;
	
	if (!people)
	{
		return 0;
	}
	
	int percent = RoundFloat(float(people_inside) / float(people) * 100.0);
	PrintToChatSkv(DEBUG, "IsSurvivorsGathered: people %d, inside %d (%d)", people, people_inside, percent);
	
	gi_gather_percent 	= percent;
		
	if (percent < GetConVarInt(gc_teleport_percent))
	{
		IsSurvivorsEntireTeam(trigger);
		return 0;
	}
	
	return percent;
}

bool IsSurvivorsEntireTeam(int trigger)
{
	int teleport_percent = GetConVarInt(gc_teleport_percent);
	PrintToChatSkv(DEBUG, "IsSurvivorsEntireTeam: gi_gather_percent %d, teleport_percent %d", gi_gather_percent, teleport_percent);
	
	if (gi_gather_percent >= teleport_percent)
	{
		return true;
	}
	
	int gathered_survivors 	= RoundFloat(float(gi_gather_percent) * 0.01 * float(gi_survivor_teleport));
	float min_convar_survivors 	= float(teleport_percent) * 0.01 * float(gi_survivor_teleport);
	
	int min_survivors = RoundFloat(min_convar_survivors);
	
	if (min_convar_survivors > min_survivors)
	{
		min_survivors ++; 
	}
	
	PrintToChatSkv(DEBUG, "IsSurvivorsEntireTeam: gathered_survivors %d, min_survivors %f", gathered_survivors, min_survivors);
	
	if (gathered_survivors < min_survivors && gi_gather_percent)
	{
		for (int i = 1; i <= MAX_PLAYERS; i++)
		{
			if (IsValidClientTeam2Alive(i) && IsClientInTrigger(i, trigger))
			{
				PrintHintText(i, "%t", "Not enough survivors", min_survivors);
			}
		}
		
		return false;
	}
	
	return true;
}


public void OnMissionLost()
{
	gb_mission_lost = true;
}

void Event_finale_win(Handle event, const char[] name, bool dontBroadcast)
{
	Delete_Timers();
}

public void OnMapEnd()
{
	Delete_Timers();
}

public void OnMapTransit()
{
	Delete_Timers();
}

public void OnMapRestart()
{
	Delete_Timers();
}

public void OnMissionChange()
{
	Delete_Timers();
}

public void OnServerEmpty()
{
	Delete_Timers();
	
	char plugin_name[PLATFORM_MAX_PATH];
	GetPluginFilename(INVALID_HANDLE, plugin_name, sizeof(plugin_name));
	
	ServerCommand("sm plugins reload \"%s\"", plugin_name);
}

void Delete_Timers()
{
	RTimerKill(gt_OnTrigger);
	RTimerKill(gt_Teleport);
	RTimerKill(gt_SearchFarBots);
	
	for (int i = 1; i <= MAX_SURVIVORID; i++)
	{
		RTimerKill(gt_TimerThreat[i]);
		RTimerKill(gt_BotHelps[i]);
		
		gi_help_owner	[i] = 0;
		gi_help_target	[i] = 0;
	}
}

void Search_ButtonTriggers(int button)
{
	//PrintToChatSkv(DEBUG, "Search_ButtonTriggers: button %d", button);
	
	if (gk_button_triggers == null)
	{
		return;
	}
	
	KvRewind(gk_button_triggers);
	
	if (!IsEntityValid(button))
	{
		return;
	}
		
	char targetname_button[MAX_STRING_LENGTH]; 
	GetEntPropString(button, Prop_Data, "m_iName", targetname_button, sizeof(targetname_button));
	
	if (!strlen(targetname_button))
	{
		//PrintToChatSkv(DEBUG, "Search_ButtonTriggers: button is no name");
		return;
	}
		
	if (!KvJumpToKey(gk_button_triggers, targetname_button, false))
	{
		//PrintToChatSkv(DEBUG, "Search_ButtonTriggers: button is no found");
		return;
	}
	
	PrintToChatSkv(DEBUG, "Search_ButtonTriggers: find button %s", targetname_button);
	
	char key_value	[PLATFORM_MAX_PATH];
	KvGetString(gk_button_triggers, "hammerid", key_value, sizeof(key_value));
	//PrintToChatSkv(DEBUG, "Search_ButtonTriggers: kv get hammerid %s", key_value);	
	
	int hammerid = StringToInt(key_value);
	if (!hammerid)
	{
		KvRewind(gk_button_triggers);
		return;
	}
	
	int entity = FindEntityByHammerid(hammerid);
	//PrintToChatSkv(DEBUG, "Search_ButtonTriggers: find entity %d", entity);	
	if (entity == -1)
	{
		KvRewind(gk_button_triggers);
		return;
	}
	
	SetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity", button);
	
	HookSingleEntityOutput(button, "OnUseLocked", OnUseLocked);
	HookSingleEntityOutput(button, "OnPressed", OnPressed);
	
	PrintToChatSkv(DEBUG, "Search_ButtonTriggers: set hook to trigger %d, hammerid %d", entity, hammerid);
	
	KvRewind(gk_button_triggers);
}

int FindEntityByHammerid(int hammerid)
{
	for (int i = MAX_PLAYERS; i <= MAX_ENTITIES; i++)
	{
		if (IsEntityValid(i))
		{
			if (GetEntProp(i, Prop_Data, "m_iHammerID") == hammerid)
			{
				return i;
			}
		}
	}
	
	return -1;
}

// pos_1 смотрит на pos_2
float GetAngleOrigin(float pos_1[3], float pos_2[3])
{
	float prepare1 = pos_1[1] - pos_2[1];
	float prepare2 = pos_1[0] - pos_2[0];
		
	float angle = ArcTangent(prepare1 / prepare2) / 0.0174533;
	
	if (pos_2[0] < pos_1[0])
	{
		if (angle < 0.0)
		{
			angle += 180.0;
		}
		else
		{
			angle -= 180.0;
		}
	}
	
	return angle;
}

int GetTriggerOfButton(int entity)
{
	if (!IsEntityValid(entity))
	{
		return 0;
	}
	
	int i = -1;
	while ((i = FindEntityByClassname(i, "trigger_multiple")) != -1)
	{
		if (GetEntPropEnt(i, Prop_Data, "m_hOwnerEntity") == entity)
		{
			return i;
		}
	}
	
	return 0;
}

Action Teleport(Handle timer, int ref)
{
	//PrintToChatSkv(DEBUG, "Teleport");
	
	if (gb_mission_lost)
	{
		gt_Teleport = null;
		return Plugin_Stop;
	}
	
	//PrintToChatSkv(DEBUG, "Teleport: gi_teleport_countdown %d", gi_teleport_countdown);
	
	if (IsValidHandle(timer))
	{
		gi_teleport_countdown --;
		if (gi_teleport_countdown > 0)
		{
			PrintHintTextToAll("%t: %d", "Countdown", gi_teleport_countdown);
			return Plugin_Continue;
		}
	}
		
	RTimerKill(gt_OnTrigger);
	
	int trigger = EntRefToEntIndex(ref);
	if (!IsEntityValid(trigger))
	{
		gt_Teleport = null;
		return Plugin_Stop;
	}
	
	char classname[MAX_CLASSNAME_LENGTH];
	GetEntityClassname(trigger, classname, sizeof(classname));
	
	if (strcmp(classname, "trigger_finale"))
	{
		char name[MAX_NAME_LENGTH];
		
		for (int i = 1; i <= MAX_PLAYERS; i++)
		{
			if (IsValidClientTeam3Alive(i) && IsClientInTrigger(i, trigger) && IsAnySurvivorNear_Watch(i, 400.0))
			{
				GetClientName(i, name, sizeof(name));
				
				gi_teleport_countdown = 0;
				PrintHintTextToAll("%t", "Infected", name);
				
				if (!timer)
				{
					gt_Teleport = RTimerCreate(1.0, Teleport, ref, TIMER_REPEAT | TIMER_FLAG_NO_ROUNDCHANGE);
				}
				
				return Plugin_Continue;
			}
		}
	}
	
	char targetname[MAX_CLASSNAME_LENGTH];
	GetEntPropString(trigger, Prop_Data, "m_iName", targetname, sizeof(targetname));
	
	if (!strcmp(targetname, TRIGGER_SAFEROOM_NAME))
	{
		int safedoor = GetEntPropEnt(trigger, Prop_Data, "m_hOwnerEntity");
		if (IsEntityValid(safedoor))
		{
			if (GetEntProp(safedoor, Prop_Data, "m_spawnflags") == 32768)
			{
				gi_teleport_countdown = 0;
				PrintHintTextToAll("%t", "Safedoor");
				
				if (!timer)
				{
					gt_Teleport = RTimerCreate(1.0, Teleport, ref, TIMER_REPEAT | TIMER_FLAG_NO_ROUNDCHANGE);
				}
				
				return Plugin_Continue;
			}
				
			InputEntity(safedoor, "Close"); // , _, 0.5
		}
		else
		{
			UnhookSingleEntityOutput(trigger, "OnStartTouch", OnStartTouch_SafeRoom);
		}
	}
	else
	{
		int button = GetEntPropEnt(trigger, Prop_Data, "m_hOwnerEntity");
		if (IsEntityValid(button))
		{
			GetEntityClassname(button, classname, sizeof(classname));
		
			if (!strcmp(classname, "func_button"))
			{
				UnhookSingleEntityOutput(button, "OnPressed", OnPressed);
				
				InputEntity(button, "Unlock");
				InputEntity(button, "Press"); // , _, 0.5
			}
		}
	}
	
	PrintHintTextToAll("%t", "Teleport");
	
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		if (!IsValidClientTeleport(i))
		{
			if (IsValidClientTeam2Alive(i))
			{
				ForcePlayerSuicide(i);
			}
		}
		else
		{
			TeleportEntity(i, gv_pos_teleport);
		}
	}
	
	LogToDebug(DEBUG_LOG, debugfile, "Teleport");
	
	gt_Teleport = null;
	return Plugin_Stop;
}

int IsAnySurvivorNear_Watch(int client, float distance)
{
	float pos_client[3];
	GetClientEyePosition(client, pos_client);
	
	float pos_survivor[3];
	
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		if (IsValidClientTeam2Alive(i)) //  && !IsFakeClient(i)
		{
			GetClientEyePosition(i, pos_survivor);
			
			if (GetVectorDistance(pos_client, pos_survivor) <= distance)
			{
				if (IsVisibleClient(i, client))
				{
					return i;
				}
			}
		}
	}
	
	return 0;
}

bool IsVisibleClient(int survivor, int client)
{
	float pos_start[3];
	GetClientEyePosition(survivor, pos_start);
	
	float pos_end[3];
	GetClientEyePosition(client, pos_end);
	
	float ang_client[3];
	GetClientEyeAngles(survivor, ang_client);
	
	ang_client[0] = 0.0;
	ang_client[2] = 0.0;
	
	MovePos_Forward(pos_end, ang_client, 10.0);
	
	Handle trace = TR_TraceRayFilterEx(pos_start, pos_end, MASK_VISIBLE, RayType_EndPoint, TraceFilter_VisibleClient);
	if (TR_DidHit(trace))
	{
		int index = TR_GetEntityIndex(trace);
		delete trace;
		
		if (index == client)
		{
			return true;
		}
		
		return false;
	}
	
	delete trace;
	return true;
}

bool TraceFilter_VisibleClient(int entity, int contentsMask)
{
	if (entity > 0 && IsEntityValid(entity)) return false;
	
	return true;
}

void Teleport_Cancel()
{
	if (gt_Teleport != null)
	{
		PrintHintTextToAll("%t", "Teleport Canceled");
		RTimerKill(gt_Teleport);
	}
	
	PrintToChatSkv(DEBUG, "Teleport_Cancel");
}

bool IsValidClientTeleport(int client)
{
	if (!IsValidClientTeam2Alive(client))
	{
		return false;
	}
	
	if (IsSurvivorHanging(client) ||
		IsSurvivorIncapacitated(client) ||
		IsSurvivorPounced(client) ||
		IsSurvivorGrabbed(client) ||
		IsSurvivorPummel(client) ||
		IsSurvivorCarry(client) ||
		IsSurvivorJockey(client))
	{
		return false;
	}
	
	return true;
}

void Search_Trigger()
{
	LogToDebug(DEBUG_LOG, debugfile, "Search_EscapeTrigger");
	
	EscapeTriggers_Remove();
	
	char classname			[PLATFORM_MAX_PATH];
	char key				[PLATFORM_MAX_PATH];
	char keyvalue			[PLATFORM_MAX_PATH];
	char button_targetname	[PLATFORM_MAX_PATH];
	char trigger_targetname	[PLATFORM_MAX_PATH];
	char trigger_output		[PLATFORM_MAX_PATH];
		
	int hammerid; int start_disabled; int unlock;
	
	EntityLumpEntry entry;
	
	for (int i, n = EntityLump.Length(); i < n; i++)
	{
		entry = EntityLump.Get(i);
		
		if (entry.GetNextKey("classname", classname, sizeof(classname)) != -1)
		{
			if (!strcmp(classname, "trigger_multiple"))
			{
				LogToDebug(DEBUG_LOG, debugfile, "scan \"%s\"", classname);
				
				entry.GetNextKey("targetname", trigger_targetname, sizeof(trigger_targetname));
				LogToDebug(DEBUG_LOG, debugfile, "targetname \"%s\"", trigger_targetname);
					
				hammerid = 0;
					
				if (entry.GetNextKey("hammerid", keyvalue, sizeof(keyvalue)) != -1)
				{
					hammerid = StringToInt(keyvalue);
					LogToDebug(DEBUG_LOG, debugfile, "hammerid %d", hammerid);
				}
				
				if (entry.GetNextKey("OnEntireTeamStartTouch", keyvalue, sizeof(keyvalue)) != -1)
				{
					LogToDebug(DEBUG_LOG, debugfile, "OnEntireTeamStartTouch find");
				
					unlock = 0; start_disabled = 0;
											
					for (int j = 0; j < entry.Length; j++)
					{
						entry.Get(j, key, sizeof(key), keyvalue, sizeof(keyvalue));
						
						if (!strcmp(key, "StartDisabled"))
						{
							start_disabled = StringToInt(keyvalue);
							LogToDebug(DEBUG_LOG, debugfile, "start_disabled %d", start_disabled);
						}
						else if (!strcmp(key, "OnEntireTeamStartTouch") &&
								StrContains(keyvalue, "UnLock", false) > -1)
						{
							unlock = 1;
							FormatEx(trigger_output, sizeof(trigger_output), keyvalue);
							
							LogToDebug(DEBUG_LOG, debugfile, "find unlock %d", unlock);
						}
					}
					
					if (unlock)
					{
						if (GetEngineVersion() == Engine_Left4Dead)
						{
							SplitString(trigger_output, ",", button_targetname, sizeof(button_targetname));
							LogToDebug(DEBUG_LOG, debugfile, "button_targetname \"%s\"", button_targetname);
						}
						else
						{
							SplitString(trigger_output, "", button_targetname, sizeof(button_targetname));
							LogToDebug(DEBUG_LOG, debugfile, "button_targetname \"%s\"", button_targetname);
						}
						
						Search_ButtonTrigger(hammerid, button_targetname);
					}
					else if (strlen(trigger_targetname)) 
					{
						if (start_disabled == 1 || 
							StrContains(trigger_targetname, "escape", false) > -1 ||
							!strcmp(trigger_targetname, "trigger_heli") ||
							!strcmp(trigger_targetname, "trigger_escape"))
						{
							LogToDebug(DEBUG_LOG, debugfile, "save escape trigger %d", hammerid);
							EscapeTrigger_Set(hammerid);
						}
					}
				}
			}
		}
						
		delete entry;
	}
}

void Search_ButtonTrigger(int trigger_hammerid, char button_targetname[PLATFORM_MAX_PATH])
{
	LogToDebug(DEBUG_LOG, debugfile, "Search_ButtonTrigger:");
	
	char classname	[PLATFORM_MAX_PATH];
	char keyvalue	[PLATFORM_MAX_PATH];
	char targetname	[PLATFORM_MAX_PATH];
	
	int hammerid;
	
	EntityLumpEntry entry;
	
	for (int i, n = EntityLump.Length(); i < n; i++)
	{
		entry = EntityLump.Get(i);
		
		if (entry.GetNextKey("classname", classname, sizeof(classname)) != -1)
		{
			if (!strcmp(classname, "func_button"))
			{
				entry.GetNextKey("targetname", targetname, sizeof(targetname));
				if (!strcmp(button_targetname, targetname))
				{
					hammerid = 0;
					
					if (entry.GetNextKey("hammerid", keyvalue, sizeof(keyvalue)) != -1)
					{
						hammerid = StringToInt(keyvalue);
						LogToDebug(DEBUG_LOG, debugfile, "find button hammerid %d", hammerid);
						
						if (IsValidHandle(gk_button_triggers))
						{
							KvRewind(gk_button_triggers);
		
							if (KvJumpToKey(gk_button_triggers, targetname, true))
							{
								KvSetNum(gk_button_triggers, "hammerid", trigger_hammerid);
								LogToDebug(DEBUG_LOG, debugfile, "kv set hammerid %d", trigger_hammerid);
																	
								KvRewind(gk_button_triggers);
							}
						}
						
						delete entry;
						return;
					}
				}
			}
		}
						
		delete entry;
	}
}

void EscapeTrigger_Set(int hammerid)
{
	if (EscapeTrigger_Is(hammerid))
	{
		return;
	}
	
	for (int i = 1; i <= MAX_ESCAPE_DATA; i++)
	{
		if (!gi_escape_trigger_hammerid[i])
		{
			gi_escape_trigger_hammerid[i] = hammerid;
					
			break;
		}
	}
}

bool EscapeTrigger_Is(int hammerid)
{
	for (int i = 1; i <= MAX_ESCAPE_DATA; i++)
	{
		if (gi_escape_trigger_hammerid[i] && gi_escape_trigger_hammerid[i] == hammerid)
		{
			return true;
		}
	}
	
	return false;
}

void EscapeTriggers_Remove()
{
	for (int i = 1; i <= MAX_ESCAPE_DATA; i++)
	{
		gi_escape_trigger_hammerid[i] = 0;
	}
}

void Search_SafeDoor()
{
	LogToDebug(DEBUG_LOG, debugfile, "Search_SafeDoor");
	
	gv_pos_teleport[0] = 0.0;
	gv_pos_teleport[1] = 0.0;
	gv_pos_teleport[2] = 0.0;
		
	int safedoor = -1;
		
	int i = -1;
	while ((i = FindEntityByClassname(i, "prop_door_rotating_checkpoint")) != -1)
	{
		//PrintToChatSkv(DEBUG, "Search_SafeDoor: check safedoor %d", safedoor);
		
		if (GetEntProp(i, Prop_Data, "m_spawnflags") & 8192)
		{
			//PrintToChatSkv(DEBUG, "Search_SafeDoor: find safedoor %d", safedoor);
			
			if (!IsAnySurvivorNearEntity(i, 500.0))
			{
				safedoor = i;
				
				HookSingleEntityOutput(safedoor, "OnFullyClosed", OnFullyClosed);
				
				DoorwayTrigger_Spawn(safedoor);
							
				PrintToChatSkv(DEBUG, "Search_SafeDoor: set hook to %d", safedoor);
				LogToDebug(DEBUG_LOG, debugfile, "Search_SafeDoor: set hook to %d", safedoor);
				
				break;
			}
		}
	}
	
	SafeRoomTrigger_Spawn(safedoor);
}

int IsAnySurvivorNearEntity(int entity, float distance)
{
	float pos_entity[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos_entity);
	
	float pos_survivor[3];
	
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		if (IsValidClientTeam2Alive(i))
		{
			GetClientEyePosition(i, pos_survivor);
				
			if (GetVectorDistance(pos_entity, pos_survivor) <= distance)
			{
				return i;
			}
		}
	}
	
	return 0;
}

stock void SetDebugSpritesTrigger(int entity, char [] light_color)
{
	if (!DEBUG_SPRITE)
	{
		return;
	}
	
	if (!IsEntityValid(entity))
	{
		return;
	}
	
	float pos_spawn[3];
	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", pos_spawn);
	
	PrintToChatSkv(DEBUG_SPRITE, "SetDebugSpritesTrigger: pos_spawn %d, %d, %d", RoundFloat(pos_spawn[0]), RoundFloat(pos_spawn[1]), RoundFloat(pos_spawn[2]));
	
	float vMins[3];
	GetEntPropVector(entity, Prop_Data, "m_vecMins", vMins);
		
	float vMaxs[3];
	GetEntPropVector(entity, Prop_Data, "m_vecMaxs", vMaxs);
	
	pos_spawn[2] += vMaxs[2];
	
	float pos_temp[3];
	pos_temp = pos_spawn;
	
	pos_temp[0] += vMaxs[0];
	pos_temp[1] += vMaxs[1];
	SetDebugSprites(pos_temp, light_color, false);
	
	pos_temp = pos_spawn;
	
	pos_temp[0] += vMaxs[0];
	pos_temp[1] += vMins[1];
	SetDebugSprites(pos_temp, light_color, false);
	
	pos_temp = pos_spawn;
	
	pos_temp[0] += vMins[0];
	pos_temp[1] += vMaxs[1];
	SetDebugSprites(pos_temp, light_color, false);
	
	pos_temp = pos_spawn;
	
	pos_temp[0] += vMins[0];
	pos_temp[1] += vMins[1];
	SetDebugSprites(pos_temp, light_color, false);
	
	pos_spawn[2] -= vMaxs[2];
	pos_spawn[2] += vMins[2];
	
	pos_temp = pos_spawn;
	
	pos_temp[0] += vMaxs[0];
	pos_temp[1] += vMaxs[1];
	SetDebugSprites(pos_temp, light_color, false);
	
	pos_temp = pos_spawn;
	
	pos_temp[0] += vMaxs[0];
	pos_temp[1] += vMins[1];
	SetDebugSprites(pos_temp, light_color, false);
	
	pos_temp = pos_spawn;
	
	pos_temp[0] += vMins[0];
	pos_temp[1] += vMaxs[1];
	SetDebugSprites(pos_temp, light_color, false);
	
	pos_temp = pos_spawn;
	
	pos_temp[0] += vMins[0];
	pos_temp[1] += vMins[1];
	SetDebugSprites(pos_temp, light_color, false);
}

void SetDebugSprites(float pos_spawn[3], char [] light_color, bool print = true)
{	
	if (!DEBUG_SPRITE)
	{
		return;
	}
	
	int entity = CreateEntityByName("env_sprite");
	if (entity == -1)
	{
		return;
	}
	
	DispatchKeyValue(entity, "spawnflags", "1");
	DispatchKeyValue(entity, "scale", "0.4"); // 0.4
	DispatchKeyValue(entity, "rendermode", "9");
	DispatchKeyValue(entity, "renderfx", "0");
	DispatchKeyValue(entity, "rendercolor", light_color);
	
	DispatchKeyValueInt(entity, "renderamt", 200);
	DispatchKeyValue(entity, "model", gs_glow_model);
	DispatchKeyValue(entity, "HDRColorScale", "1.0");
	DispatchKeyValue(entity, "GlowProxySize", "2");
	
	DispatchSpawn(entity);
	ActivateEntity(entity);
	
	TeleportEntity(entity, pos_spawn);
	PrintToChatSkv(print, "SetDebugSprites: pos_spawn %d, %d, %d", RoundFloat(pos_spawn[0]), RoundFloat(pos_spawn[1]), RoundFloat(pos_spawn[2]));
}

bool IsClientInTrigger(int client, int trigger)
{
	if (!IsEntityValid(trigger))
	{
		return false;
	}
	
	float vOrigin[3];
	GetClientAbsOrigin(client, vOrigin);
	//PrintToChatSkv(DEBUG, "IsClientInTrigger: vOrigin %d, %d, %d", RoundFloat(vOrigin[0]), RoundFloat(vOrigin[1]), RoundFloat(vOrigin[2]));
	
	float pos_spawn[3];
	int parent = GetEntPropEnt(trigger, Prop_Data, "m_pParent");
	
	if (IsEntityValid(parent))
	{
		GetEntPropVector(parent, Prop_Data, "m_vecOrigin", pos_spawn);
	}
	else
	{
		GetEntPropVector(trigger, Prop_Data, "m_vecOrigin", pos_spawn);
	}
	
	float vMins[3];
	GetEntPropVector(trigger, Prop_Send, "m_vecMins", vMins);
	
	float scale = 1.20;
	
	vMins[0] *= scale;
	vMins[1] *= scale;
	vMins[2] *= scale;
	
	vMins[0] += pos_spawn[0];
	vMins[1] += pos_spawn[1];
	vMins[2] += pos_spawn[2];
	
	float vMaxs[3];
	GetEntPropVector(trigger, Prop_Send, "m_vecMaxs", vMaxs);
	
	vMaxs[0] *= scale;
	vMaxs[1] *= scale;
	vMaxs[2] *= scale;
	
	vMaxs[0] += pos_spawn[0];
	vMaxs[1] += pos_spawn[1];
	vMaxs[2] += pos_spawn[2];
	
	//PrintToChatSkv(DEBUG, "IsClientInTrigger: vMins %d, %d, %d", RoundFloat(vMins[0]), RoundFloat(vMins[1]), RoundFloat(vMins[2]));
	
	//PrintToChatSkv(DEBUG, "IsClientInTrigger: vMaxs %d, %d, %d", RoundFloat(vMaxs[0]), RoundFloat(vMaxs[1]), RoundFloat(vMaxs[2]));
	
	if (vOrigin[0] >= vMins[0] &&
		vOrigin[0] <= vMaxs[0] &&
		vOrigin[1] >= vMins[1] &&
		vOrigin[1] <= vMaxs[1] &&
		vOrigin[2] >= vMins[2] &&
		vOrigin[2] <= vMaxs[2])
	{
		return true;
	}
	
	GetClientEyePosition(client, vOrigin);
	
	if (vOrigin[0] >= vMins[0] &&
		vOrigin[0] <= vMaxs[0] &&
		vOrigin[1] >= vMins[1] &&
		vOrigin[1] <= vMaxs[1] &&
		vOrigin[2] >= vMins[2] &&
		vOrigin[2] <= vMaxs[2])
	{
		return true;
	}
	
	return false;
}

Action SearchFarBots(Handle timer)
{
	//PrintToChatSkv(DEBUG, "SearchFarBots");
	
	if (gt_Teleport != null)
	{
		return Plugin_Continue;
	}
	
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		if (!IsAnySurvivorNearBot(i))
		{
			if (!IsValidClientTeleport(i))
			{
				if (IsValidClientTeam2Alive(i) && IsFakeClient(i) && !IsSurvivorReviveOwner(i))
				{
					ForcePlayerSuicide(i);
				}
			}
			else
			{
				if (!IsSurvivorReviveTarget(i))
				{
					//PrintToChatSkv(DEBUG, "SearchFarBots: teleport to %N", i);
					TeleportSurvivorBot(i);
				}
			}
		}
	}
	
	return Plugin_Continue;
}

void TeleportSurvivorBot(int bot)
{
	if (!IsValidClientTeam2Alive(bot) || !IsFakeClient(bot))
	{
		return;
	}
	
	int client = GetNearSurvivor(bot);
	if (!client)
	{
		return;
	}
	
	float pos_client[3];
	GetClientAbsOrigin(client, pos_client);
	
	pos_client[2] += 2.5;
	
	TeleportEntity(bot, pos_client);
	PrintToChatSkv(DEBUG, "TeleportSurvivorBot: teleport %N", bot);
}

int GetNearSurvivor(int client)
{
	if (!IsValidClientTeam2Alive(client))
	{
		return 0;
	}
	
	float pos_client[3];
	GetClientEyePosition(client, pos_client);
	
	float pos_i[3];
	float near_distance; float distance_i_client;	
	
	int near_survivor;
	
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		if (IsValidClientTeam2Alive(i) && !IsFakeClient(i))
		{
			GetClientEyePosition(i, pos_i);
			
			distance_i_client = GetVectorDistance(pos_i, pos_client);
			if (!near_distance ||  near_distance > distance_i_client)
			{
				near_distance = distance_i_client;
				near_survivor = i;
			}
		}
	}
	
	return near_survivor;
}

bool IsAnySurvivorNearBot(int bot)
{
	if (DEBUG_HELP)
	{
		return true;
	}
	
	if (!IsValidClientTeam2Alive(bot) || !IsFakeClient(bot))
	{
		return true;
	}
	
	float distance = GetConVarFloat(gc_teleport_bot_distance);
	
	float pos_bot[3];
	GetClientEyePosition(bot, pos_bot);
	
	float pos_survivor[3];
	
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		if (IsValidClientTeam2Alive(i) && !IsFakeClient(i))
		{
			GetClientEyePosition(i, pos_survivor);
				
			if (GetVectorDistance(pos_bot, pos_survivor) <= distance &&
				IsSameFloor(pos_bot[2], pos_survivor[2], 200.0))
			{
				//PrintToChatSkv(DEBUG, "IsAnySurvivorNear: return true");
				return true;
			}
		}
	}
	
	//PrintToChatSkv(DEBUG, "IsAnySurvivorNear: return false");
	return false;
}

bool IsSameFloor(float z1, float z2, float floor_heigh)
{
	float z_floor;
	
	z_floor = z1 - z2;
	if (z_floor < 0) {z_floor *= -1;}
						
	if (z_floor <= floor_heigh)
	{
		return true;
	}
	
	return false;
}

void Event_player_attacked(Handle event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(event, "victim"));
	if (!IsValidClientTeam2Alive(victim)) {return;}
	
	int survivorid = GetClientSurvivorId(victim);
	if (!survivorid)
	{
		return;
	}
	
	float delay = GetConVarFloat(gc_teleport_bot_threat);
	if (delay <= 0.0)
	{
		RTimerKill(gt_TimerThreat[survivorid]);
				
		return;
	}
	
	if (gt_TimerThreat[survivorid] != null)
	{
		return;
	}
	
	int attacker = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsValidClientTeam3Alive(attacker)) {return;}
	
	//PrintToChatSkv(DEBUG, "%s", name);
	
	gt_TimerThreat[survivorid] = RTimerCreate(delay, TeleportBotToSurvivor, survivorid, TIMER_FLAG_NO_ROUNDCHANGE);
}

void Event_player_released(Handle event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(event, "victim"));
	if (!IsValidClientTeam2Alive(victim)) {return;}
	
	int survivorid = GetClientSurvivorId(victim);
	if (!survivorid)
	{
		return;
	}
	
	RTimerKill(gt_TimerThreat[survivorid]);
}

void Event_player_hurt(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsValidClientTeam2Alive(client)) {return;}
	
	int survivorid = GetClientSurvivorId(client);
	if (!survivorid)
	{
		return;
	}
	
	if (IsSurvivorIncapacitated(client) || IsSurvivorHanging(client))
	{
		int bot = gi_help_owner[survivorid];
		if (bot || gt_TimerThreat[survivorid])
		{
			return;
		}
	}
	else
	{
		return;
	}
		
	float delay = GetConVarFloat(gc_teleport_bot_help);
	if (delay <= 0.0)
	{
		RTimerKill(gt_TimerThreat[survivorid]);
				
		return;
	}
	
	//PrintToChatSkv(DEBUG, "%s", name);
		
	gt_TimerThreat[survivorid] = RTimerCreate(delay, TeleportBotToSurvivor, survivorid, TIMER_FLAG_NO_ROUNDCHANGE);
}

void Event_player_need_help(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsValidClientTeam2Alive(client)) {return;}
	
	int survivorid = GetClientSurvivorId(client);
	if (!survivorid)
	{
		return;
	}
	
	float delay = GetConVarFloat(gc_teleport_bot_help);
	if (delay <= 0.0)
	{
		RTimerKill(gt_TimerThreat[survivorid]);
				
		return;
	}
	
	if (gt_TimerThreat[survivorid] != null)
	{
		return;
	}
	
	//PrintToChatSkv(DEBUG, "%s", name);
	
	gt_TimerThreat[survivorid] = RTimerCreate(delay, TeleportBotToSurvivor, survivorid, TIMER_FLAG_NO_ROUNDCHANGE);
}

void Event_revive_success(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsValidClientTeam2Alive(client)) {return;}
	
	int survivorid = GetClientSurvivorId(client);
	if (!survivorid)
	{
		return;
	}
	
	RTimerKill(gt_TimerThreat[survivorid]);
}

void TeleportBotToSurvivor(Handle timer, int survivorid)
{
	if (gt_BotHelps[survivorid] != null)
	{
		gt_TimerThreat[survivorid] = null;
		return;
	}
	
	int client = GetClientOfSurvivorId(survivorid);
	if (!IsValidClientTeam2Alive(client))
	{
		gt_TimerThreat[survivorid] = null;
		return;
	}
	
	if (IsSurvivorReviveOwner(client))
	{
		gt_TimerThreat[survivorid] = null;
		return;
	}
	
	int bot = GetNearBot(client);
	if (!bot)
	{
		gt_TimerThreat[survivorid] = null;
		return;
	}
	
	if (!HelpState_Set(client, bot))
	{
		//PrintToChatSkv(DEBUG, "TeleportBotToSurvivor: HelpState_Set is FALSE");
		
		gt_TimerThreat[survivorid] = null;
		return;
	}
	
	float pos_client[3];
	
	if (IsSurvivorHanging(client))
	{
		float ang_client[3];
		GetClientAbsAngles(client, ang_client);
		
		GetClientEyePosition(client, pos_client);
		pos_client[2] += 5.0;
		
		MovePos_Forward(pos_client, ang_client, 20.0);
	}
	else
	{
		GetClientAbsOrigin(client, pos_client);
		pos_client[2] += 2.5;
	}
	
	if (!GetNearTank(client))
	{
		TeleportEntity(bot, pos_client);
	}
	
	gt_BotHelps[survivorid] = RTimerCreate(1.0, BotHelps, survivorid, TIMER_REPEAT | TIMER_FLAG_NO_ROUNDCHANGE);
	
	//PrintToChatSkv(DEBUG, "TeleportBotToSurvivor: teleport %N", bot);
	gt_TimerThreat[survivorid] = null;
}

Action BotHelps(Handle timer, int survivorid)
{
	int client 	= GetClientOfSurvivorId(survivorid);
	if (!IsValidClientTeam2Alive(client))
	{
		HelpState_RemoveByClient(client);
		
		//PrintToChatSkv(DEBUG, "BotHelps: stop (1), client is not valid");
		
		gt_BotHelps[survivorid] = null;
		return Plugin_Stop;
	}
	
	int bot 	= gi_help_owner[survivorid];
	if (!IsValidClientTeleport(bot) || !IsFakeClient(bot))
	{
		HelpState_Remove(client, bot);
		
		//PrintToChatSkv(DEBUG, "BotHelps: stop (2), bot is not valid or is not bot");
		
		gt_BotHelps[survivorid] = null;
		return Plugin_Stop;
	}
		
	//PrintToChatSkv(DEBUG, "BotHelps: bot %N, client %N", bot, client);
	
	if (IsSurvivorReviveOwner(client) && IsSurvivorReviveOwner(client) != bot)
	{
		//PrintToChatSkv(DEBUG, "BotHelps: stop (3),client have other helper");
		
		gt_BotHelps[survivorid] = null;
		return Plugin_Stop;
	}
	
	if (GetNearTank(client))
	{
		//PrintToChatSkv(DEBUG, "BotHelps: GetNearTank true");
		return Plugin_Continue;
	}
	
	if (IsSurvivorHanging(client) ||
		IsSurvivorIncapacitated(client) ||
		IsSurvivorPounced(client) ||
		IsSurvivorGrabbed(client) ||
		IsSurvivorPummel(client) ||
		IsSurvivorCarry(client) ||
		IsSurvivorJockey(client) ||
		IsSurvivorReviveTarget(bot) == client)
	{
		//PrintToChatSkv(DEBUG, "BotHelps: continue");
		
		float pos_client[3];
		
		if (IsSurvivorHanging(client))
		{
			float ang_client[3];
			GetClientAbsAngles(client, ang_client);
			
			GetClientEyePosition(client, pos_client);
			pos_client[2] += 5.0;
			
			MovePos_Forward(pos_client, ang_client, 20.0);
		}
		else
		{
			GetClientAbsOrigin(client, pos_client);
			pos_client[2] += 2.5;
		}
		
		float pos_bot[3];
		GetClientAbsOrigin(bot, pos_bot);
		
		if (GetVectorDistance(pos_bot, pos_client) > gf_teleport_bot_threat_distance)
		{
			TeleportEntity(bot, pos_client);
		}
		
		return Plugin_Continue;
	}
	
	HelpState_Remove(client, bot);
	
	//PrintToChatSkv(DEBUG, "BotHelps: stop (4), help is not need");
	
	gt_BotHelps[survivorid] = null;
	return Plugin_Stop;
}

int GetNearBot(int client)
{
	if (!IsValidClientTeam2Alive(client))
	{
		return 0;
	}
	
	float pos_client[3];
	GetClientAbsOrigin(client, pos_client);
	
	float pos_i[3];
	float near_distance; float distance_i_client;	
	
	int near_bot;
	
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		if (IsValidClientTeleport(i) && IsFakeClient(i) &&
			!IsSurvivorHealTarget(i) &&
			!IsSurvivorHealOwner(i) &&
			!IsSurvivorReviveTarget(i))
		{
			GetClientAbsOrigin(i, pos_i);
			
			distance_i_client = GetVectorDistance(pos_i, pos_client);
			
			if (distance_i_client <= gf_teleport_bot_threat_distance &&
				IsSameFloor(pos_i[2], pos_client[2], 100.0))
			{
				return 0;
			}
			
			if (!gi_help_target[GetClientSurvivorId(i)])
			{
				if (!near_distance || near_distance > distance_i_client)
				{
					near_distance = distance_i_client;
					near_bot = i;
				}
			}
		}
	}
	
	return near_bot;
}

bool IsAllHumansInside(int entity)
{
	if (!IsEntityValid(entity))
	{
		return false;
	}
	
	char classname[MAX_CLASSNAME_LENGTH];
	GetEntityClassname(entity, classname, sizeof(classname));
	
	if (strcmp(classname, "trigger_multiple"))
	{
		entity = GetTriggerOfButton(entity);
		if (!entity)
		{
			return false;
		}
	}
	
	bool bot;
	
	for (int client = 1; client <= MAX_PLAYERS; client ++)
	{
		if (IsValidClientTeleport(client))
		{
			if (!IsFakeClient(client)) 
			{
				if (!IsClientInTrigger(client, entity))
				{
					return false;
				}
			}
			else
			{
				bot = true;
			}
		}
	}
	
	if (!bot)
	{
		return false;
	}
	
	return true;
}

bool HelpState_Set(int client, int bot)
{
	int survivorid_client = GetClientSurvivorId(client);
	if (!IsValidClientTeam2Alive(client))
	{
		gi_help_owner[survivorid_client] = 0;
		return false;
	}
	
	int survivorid_bot = GetClientSurvivorId(bot);
	if (!IsValidClientTeam2Alive(bot))
	{
		gi_help_target[survivorid_bot] = 0;
		return false;
	}
	
	gi_help_owner	[survivorid_client] = bot;
	gi_help_target	[survivorid_bot] 	= client;
	
	return true;
}

void HelpState_Remove(int client, int bot)
{
	int survivorid_client = GetClientSurvivorId(client);
	if (survivorid_client)
	{
		gi_help_owner[survivorid_client] = 0;
	}
	
	int survivorid_bot = GetClientSurvivorId(bot);
	if (survivorid_bot)
	{
		gi_help_target	[survivorid_bot] = 0;
	}
}

void HelpState_RemoveByClient(int client)
{
	for (int survivorid_bot = 1; survivorid_bot <= MAX_SURVIVORID; survivorid_bot ++)
	{
		if (gi_help_target[survivorid_bot] == client)
		{
			gi_help_target[survivorid_bot] = 0;
		}
	}
	
	int survivorid_client = GetClientSurvivorId(client);
	if (survivorid_client)
	{
		gi_help_owner[survivorid_client] = 0;
	}
}

int GetNearTank(int client)
{
	if (!IsValidClientTeam2Alive(client))
	{
		return 0;
	}
	
	float pos_client[3];
	GetClientAbsOrigin(client, pos_client);
	
	float pos_i[3];
	
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		if (IsPlayerTank(i) && IsPlayerAlive(i))
		{	
			GetClientAbsOrigin(i, pos_i);
			if (GetVectorDistance(pos_client, pos_i) <= 120.0)
			{
				return i;
			}
		}
	}
		
	return 0;
}