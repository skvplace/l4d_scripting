/**
 * ========================================================================
 * Plugin [L4D/L4D2] Teleport survivors
 * Teleports lagging survivors.
 * ========================================================================
 *
 * This program is free software; you can redistribute it and/or modify it.
 *
**/

#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#include <skvtools_survivorid>

public Plugin:myinfo = 
{
	name 		= "[L4D/L4D2] Teleport survivors",
	author 		= "Skv",
	description = "Teleports lagging survivors",
	version 	= "2.7.1",
	url 		= "https://forums.alliedmods.net/showthread.php?p=2841063#post2841063"
}

#define MAX_PLAYERS 						18
#define MAX_ENTITIES						4096

#define MAX_CLASSNAME_LENGTH				64
#define MAX_STRING_LENGTH					128

#define TRIGGER_SAFEROOM_NANE 				"ts_trigger_saferoom"
#define TRIGGER_ELEVATOR_NAME 				"ts_trigger_elevator"
#define TRIGGER_ESCAPE_NAME 				"ts_trigger_escape"

char 	gs_model_trigger[] 					= "models/props_street/garbage_can.mdl";

float 	gv_pos_teleport[3];

bool 	gb_mission_lost;

Handle 	gt_Teleport;
Handle 	gt_SearchFarBots;

ConVar 	gc_teleport_countdown_elevator;
ConVar 	gc_teleport_countdown_escape;
ConVar 	gc_teleport_countdown_saferoom;
ConVar 	gc_teleport_percent;
ConVar 	gc_teleport_percent_bot;
ConVar 	gc_teleport_bot_distance;
ConVar 	gc_teleport_bot_interval;

float 	gf_teleport_bot_interval;

int 	gi_teleport_countdown;

Handle 	gk_button_triggers;

#define MAX_ESCAPE_DATA 					8 
int 	gi_escape_trigger_hammerid			[MAX_ESCAPE_DATA + 1];

float 	gv_safedor_pos[3];

int 	gi_survivor_teleport;
int 	gi_gather_percent;

int 	gi_survivor_trigger					[MAX_SURVIVORID + 1];

public APLRes AskPluginLoad2(Handle plugin, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_Left4Dead && GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left4Dead & Left4dead2");
		return APLRes_SilentFailure;
	}
			
	return APLRes_Success;
}

public OnPluginStart()
{
	gc_teleport_countdown_elevator 	= CreateConVar("ts_teleport_countdown_elevator", "20", "Countdown to teleportation to the elevators. 0 - is disabled", _, true, 0.0, true, 240.0);
	SetConVarFlags(gc_teleport_countdown_elevator, GetConVarFlags(gc_teleport_countdown_elevator) & ~FCVAR_NOTIFY);
	
	gc_teleport_countdown_escape 	= CreateConVar("ts_teleport_countdown_escape", "20", "Countdown to teleportation to escape. 0 - is disabled", _, true, 0.0, true, 240.0);
	SetConVarFlags(gc_teleport_countdown_escape, GetConVarFlags(gc_teleport_countdown_escape) & ~FCVAR_NOTIFY);
	
	gc_teleport_countdown_saferoom 	= CreateConVar("ts_teleport_countdown_saferoom", "20", "Countdown to teleportation to saferoom. 0 - is disabled", _, true, 0.0, true, 240.0);
	SetConVarFlags(gc_teleport_countdown_saferoom, GetConVarFlags(gc_teleport_countdown_saferoom) & ~FCVAR_NOTIFY);
	
	gc_teleport_percent 			= CreateConVar("ts_teleport_percent", "51", "Percentage of survivors required for activation", _, true, 1.0, true, 100.0);
	SetConVarFlags(gc_teleport_percent, GetConVarFlags(gc_teleport_percent) & ~FCVAR_NOTIFY);
	
	gc_teleport_percent_bot 		= CreateConVar("ts_teleport_percent_bot", "1", "The percentage of teleportation should take into account bots.", _, true, 0.0, true, 1.0);
	SetConVarFlags(gc_teleport_percent_bot, GetConVarFlags(gc_teleport_percent_bot) & ~FCVAR_NOTIFY);
	
	gc_teleport_bot_interval = CreateConVar("ts_teleport_bot_interval", "30", "What interval in seconds should I scan for lagging bots?. If less than 1, then disabled", _, true, 0.0, true, 240.0); 
	SetConVarFlags(gc_teleport_bot_interval, GetConVarFlags(gc_teleport_bot_interval) & ~FCVAR_NOTIFY);
	
	gc_teleport_bot_distance	= CreateConVar("ts_teleport_bot_distance", "750", "If the bots are further than this distance, they will be moved", _, true, 500.0, true, 2000.0); 
	SetConVarFlags(gc_teleport_bot_distance, GetConVarFlags(gc_teleport_bot_distance) & ~FCVAR_NOTIFY);
	
	AutoExecConfig(true, "teleport_survivors");
	LoadTranslations("teleport_survivors.phrases");
	
	HookEvent("mission_lost", Event_mission_lost);
	HookEvent("finale_win",  Event_finale_win);
}

public OnAllPluginsLoaded()
{
	if (!LibraryExists("[skvtools] l4d_l4d2_gamestartcoop"))
	{
		SetFailState("The library [skvtools] l4d_l4d2_gamestartcoop was not found!");
	}
	else if (!LibraryExists("[skvtools] l4d_survivorid"))
	{
		SetFailState("The library [skvtools] l4d_survivorid was not found!");
	}
}

public OnMapInit(const char[] mapName)
{
	if (IsValidHandle(gk_button_triggers))
	{
		delete gk_button_triggers;
	}
	
	gk_button_triggers = CreateKeyValues("button_triggers");
	
	Search_Trigger();
}

public OnMapStart()
{
	PrecacheModel(gs_model_trigger);
}

public OnGameplayStart(int stage)
{
	if (stage != 5)
	{
		return;
	}
	
	gb_mission_lost = false;
	
	Delete_Timers();
	
	gf_teleport_bot_interval = GetConVarFloat(gc_teleport_bot_interval);
	if (gf_teleport_bot_interval >= 1.0)
	{
		gt_SearchFarBots = CreateTimer(gf_teleport_bot_interval, SearchFarBots, _, TIMER_REPEAT);
	}
	
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
			return;
		}
		
		for (int i = 1; i <= MAX_ESCAPE_DATA; i++)
		{
			if (gi_escape_trigger_hammerid[i])
			{
				entity = FindEntityByHammerid(gi_escape_trigger_hammerid[i]);
				if (IsValidEntity(entity))
				{
					HookSingleEntityOutput(entity, "OnEntireTeamStartTouch", OnEntireTeamStartTouch);
					
					HookSingleEntityOutput(entity, "OnStartTouch", OnStartTouch_Escape);
					HookSingleEntityOutput(entity, "OnEndTouch", OnEndTouch_Escape);
				}
			}
		}
	}
}

void OnEntireTeamStartTouch(const char[] output, int trigger, int activator, float delay)
{
	if (IsValidHandle(gt_Teleport))
	{
		CreateTimer(0.5, Teleport_Cancel);
	}
}

void OnPressed(const char[] output, int button, int activator, float delay)
{
	CreateTimer(0.5, Teleport_Cancel);
	
	UnhookSingleEntityOutput(button, "OnPressed", OnPressed);
	
	int trigger = GetEntityTrigger(button);
	if (trigger)
	{
		UnhookSingleEntityOutput(trigger, "OnEntireTeamStartTouch", OnEntireTeamStartTouch);
			
		UnhookSingleEntityOutput(trigger, "OnStartTouch", OnStartTouch_Elevator);
		UnhookSingleEntityOutput(trigger, "OnEndTouch", OnEndTouch_Elevator);
	}
}

void OnUseLocked(const char[] output, int button, int client, float delay)
{
	if (!IsValidClientTeam2Alive(client))
	{
		return;
	}
	
	int countdown = GetConVarInt(gc_teleport_countdown_elevator);
	if (countdown <= 0)
	{
		return;
	}
	
	int trigger = GetEntityTrigger(button);
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
		return;
	}
	
	UnhookSingleEntityOutput(button, output, OnUseLocked);
	
	GetClientAbsOrigin(client, gv_pos_teleport);
	gv_pos_teleport[2] += 10.0;
	
	HookSingleEntityOutput(trigger, "OnEntireTeamStartTouch", OnEntireTeamStartTouch);
		
	HookSingleEntityOutput(trigger, "OnStartTouch", OnStartTouch_Elevator);
	HookSingleEntityOutput(trigger, "OnEndTouch", OnEndTouch_Elevator);
		
	if (!IsSurvivorsGathered(trigger))
	{
		IsSurvivorsEntireTeam(client, trigger);
	}
	else
	{
		Teleport_Start(button, countdown);
	}
}

void OnStartTouch_Elevator(const char[] output, int entity, int client, float delay)
{
	if (!IsValidClientTeam2Alive(client))
	{
		return;
	}
	
	char targetname[MAX_STRING_LENGTH]; 
	GetEntPropString(entity, Prop_Data, "m_iName", targetname, sizeof(targetname));
	
	ClientTrigger_Set(client, entity);
	
	if (!IsSurvivorsGathered(entity))
	{
		if (IsValidHandle(gt_Teleport))
		{
			Teleport_Cancel(null);
		}
		else
		{
			IsSurvivorsEntireTeam(client, entity);
		}
				
		return;
	}
	
	if (OnTriggetEntireTeam(entity))
	{
		return;
	}
	
	int countdown = GetConVarInt(gc_teleport_countdown_elevator);
	if (countdown <= 0)
	{
		return;
	}
	
	Teleport_Start(GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity"), countdown);
}

void OnStartTouch(const char[] output, int entity, int client, float delay)
{
	if (!IsValidClientTeam2Alive(client))
	{
		return;
	}
	
	ClientTrigger_Set(client, entity);
}

void OnEndTouch(const char[] output, int entity, int client, float delay)
{
	if (!IsValidClientTeam2Alive(client))
	{
		return;
	}
	
	ClientTrigger_Remove(client);
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
	
	int trigger = GetEntityTrigger(safedoor);
	if (!trigger)
	{
		LogError("%s: trigger is no found", output);
		return;
	}
	
	UnhookSingleEntityOutput(safedoor, output, OnFullyClosed);
	
	float pos_door[3];
	GetEntPropVector(safedoor, Prop_Data, "m_vecAbsOrigin", pos_door);
		
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
		
	gv_safedor_pos = pos_door;
		
	HookSingleEntityOutput(trigger, "OnEntireTeamStartTouch", OnEntireTeamStartTouch);
		
	HookSingleEntityOutput(trigger, "OnStartTouch", OnStartTouch_Saferoom);
	HookSingleEntityOutput(trigger, "OnEndTouch", OnEndTouch_Saferoom);
	
	if (!IsSurvivorsGathered(trigger))
	{
		IsSurvivorsEntireTeam(client, trigger);
	}
	else
	{
		float pos_entity[3];
		GetEntPropVector(trigger, Prop_Data, "m_vecOrigin", pos_entity);
		
		float ang_entity[3];
						
		ang_entity[0] = 0.0;
		ang_entity[1] = GetAngleOrigin(gv_safedor_pos, pos_entity);
		ang_entity[2] = 0.0;
		
		MovePos_Forward(gv_safedor_pos, ang_entity, 90.0);
		
		gv_pos_teleport = gv_safedor_pos;
		
		Teleport_Start(trigger, countdown);
	}
}

void OnStartTouch_Saferoom(const char[] output, int entity, int client, float delay)
{
	if (!IsValidClientTeam2Alive(client))
	{
		return;
	}
	
	char targetname[MAX_STRING_LENGTH]; 
	GetEntPropString(entity, Prop_Data, "m_iName", targetname, sizeof(targetname));
	
	ClientTrigger_Set(client, entity);
	
	if (!IsSurvivorsGathered(entity))
	{
		if (IsValidHandle(gt_Teleport))
		{
			Teleport_Cancel(null);
		}
		else
		{
			IsSurvivorsEntireTeam(client, entity);
		}
		
		return;
	}
	
	if (OnTriggetEntireTeam(entity))
	{
		return;
	}
	
	int countdown = GetConVarInt(gc_teleport_countdown_saferoom);
	if (countdown <= 0)
	{
		return;
	}
	
	int near_survivor = GetNearSurvivorGathered(entity);
	if (!near_survivor)
	{
		return;
	}
	
	float pos_client[3];
	GetClientAbsOrigin(near_survivor, pos_client);
	
	pos_client[2] += 5.0;
	
	float pos_entity[3];
	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", pos_entity);
	
	int safedoor = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");
	if (IsValidEntity(safedoor))
	{
		float ang_entity[3];
						
		ang_entity[0] = 0.0;
		ang_entity[1] = GetAngleOrigin(gv_safedor_pos, pos_entity);
		ang_entity[2] = 0.0;
		
		MovePos_Forward(gv_safedor_pos, ang_entity, 90.0);
		
		gv_pos_teleport = gv_safedor_pos;
	}
	else
	{
		gv_pos_teleport[0] = pos_entity[0];
		gv_pos_teleport[1] = pos_entity[1];
		gv_pos_teleport[2] = pos_client[2] + 10.0;
	}
	
	Teleport_Start(entity, countdown);
}

void OnStartTouch_Escape(const char[] output, int entity, int client, float delay)
{
	if (!IsValidClientTeam2Alive(client))
	{
		return;
	}
	
	char targetname[MAX_STRING_LENGTH]; 
	GetEntPropString(entity, Prop_Data, "m_iName", targetname, sizeof(targetname));
	
	ClientTrigger_Set(client, entity);
	
	if (!IsSurvivorsGathered(entity))
	{
		if (IsValidHandle(gt_Teleport))
		{
			Teleport_Cancel(null);
		}
		else
		{
			IsSurvivorsEntireTeam(client, entity);
		}
		
		return;
	}
	
	if (OnTriggetEntireTeam(entity))
	{
		return;
	}
	
	int countdown = GetConVarInt(gc_teleport_countdown_escape);
	if (countdown <= 0)
	{
		return;
	}
	
	float pos_entity[3];
	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", pos_entity);
	
	GetClientAbsOrigin(client, gv_pos_teleport);
	gv_pos_teleport[2] += 10.0;
	
	float ang_client[3];
	
	ang_client[0] = 0.0;
	ang_client[1] = GetAngleOrigin(gv_pos_teleport, pos_entity);
	ang_client[2] = 0.0;
	
	MovePos_Forward(gv_pos_teleport, ang_client, 50.0);
	
	Teleport_Start(entity, countdown);
}

int SafeRoomTrigger_Spawn(int safedoor)
{
	int info_changelevel = FindEntityByClassname(-1, "info_changelevel");
	if (!IsValidEntity(info_changelevel))
	{
		return 0;
	}
	
	char targetname[MAX_STRING_LENGTH];
	
	int i = -1;
	while ((i = FindEntityByClassname(i, "trigger_multiple")) != -1)
	{
		GetEntPropString(i, Prop_Data, "m_iName", targetname, sizeof(targetname));
		if (!strcmp(targetname, TRIGGER_SAFEROOM_NANE))
		{
			InputKill(i);
		}
	}
	
	float vMins[3];
	GetEntPropVector(info_changelevel, Prop_Data, "m_vecMins", vMins);
	
	float vMaxs[3];
	GetEntPropVector(info_changelevel, Prop_Data, "m_vecMaxs", vMaxs);
	
	float pos_spawn[3];
	GetEntPropVector(info_changelevel, Prop_Data, "m_vecMaxs", pos_spawn);
	
	vMaxs[0] = (vMaxs[0] - vMins[0]) * 0.5;
	vMaxs[1] = (vMaxs[1] - vMins[1]) * 0.5;
	vMaxs[2] = (vMaxs[2] - vMins[2]) * 0.5;
	
	vMins[0] = vMaxs[0] * (-1.0);
	vMins[1] = vMaxs[1] * (-1.0);
	vMins[2] = vMaxs[2] * (-1.0);
	
	pos_spawn[0] -= vMaxs[0];
	pos_spawn[1] -= vMaxs[1];
	pos_spawn[2] -= vMaxs[2];
	
	float scale = 0.95;
	
	vMins[0] *= scale;
	vMins[1] *= scale;
	vMins[2] *= 1.15;
	
	vMaxs[0] *= scale;
	vMaxs[1] *= scale;
		
	#define FILTER_SAFEROOM_NANE "ts_filter"
	
	int filter = CreateEntityByName("filter_activator_team");
	if (IsValidEntity(filter))
	{
		DispatchKeyValue(filter, "targetname", FILTER_SAFEROOM_NANE);
		DispatchKeyValue(filter, "filterteam", "2");
		DispatchKeyValueVector(filter, "origin", pos_spawn);
	
		DispatchSpawn(filter);
		ActivateEntity(filter);
	}
	
	int entity = CreateEntityByName("trigger_multiple");
	if (entity == -1)
	{
		return 0;
	}
	
	char output[MAX_CLASSNAME_LENGTH];
	FormatEx(output, sizeof(output), "%s,Kill,,0,-1", FILTER_SAFEROOM_NANE);
	
	DispatchKeyValue(entity, "OnKilled", output);
	
	if (IsValidEntity(safedoor))
	{
		SetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity", safedoor);
	}
		
	DispatchKeyValue(entity, "targetname", TRIGGER_SAFEROOM_NANE);
	DispatchKeyValue(entity, "spawnflags", "1");
	DispatchKeyValue(entity, "entireteam", "2");
	DispatchKeyValue(entity, "filtername", FILTER_SAFEROOM_NANE);
	DispatchKeyValue(entity, "wait", "1.0");
		
	DispatchSpawn(entity);
	ActivateEntity(entity);
	
	pos_spawn[2] += 2.0;
	TeleportEntity(entity, pos_spawn);
	
	SetEntityModel(entity, gs_model_trigger);
	
	SetEntPropVector(entity, Prop_Send, "m_vecMins", vMins);
	SetEntPropVector(entity, Prop_Send, "m_vecMaxs", vMaxs);
	SetEntProp(entity, Prop_Send, "m_nSolidType", 2);
	
	int enteffects = GetEntProp(entity, Prop_Send, "m_fEffects");
	enteffects |= 32;
	SetEntProp(entity, Prop_Send, "m_fEffects", enteffects); 
	
	return entity;
}

bool OnTriggetEntireTeam(int entity)
{
	if (!IsValidEntity(entity))
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
				
			if (IsClientInTrigger(client, entity))
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

int IsSurvivorsGathered(int entity)
{
	if (!IsValidEntity(entity))
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
				
				if (IsClientInTrigger(client, entity))
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
	
	gi_gather_percent 	= percent;
		
	if (percent < GetConVarInt(gc_teleport_percent))
	{
		return 0;
	}
	
	return percent;
}

int GetNearSurvivorGathered(int entity)
{
	if (!IsValidEntity(entity))
	{
		return 0;
	}
	
	float pos_entity[3];
	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", pos_entity);
	
	pos_entity[2] = 0.0;
	
	float pos_client[3];
	
	float distance;
	float distance_old;
	
	int near_client;
	
	for (int client = 1; client <= MAX_PLAYERS; client ++)
	{
		if (IsValidClientTeam2Alive(client) && IsClientInTrigger(client, entity))
		{	
			GetClientAbsOrigin(client, pos_client);
			pos_client[2] = 0.0;
			
			distance = GetVectorDistance(pos_client, pos_entity);
			
			if (!distance_old || distance_old > distance)
			{
				distance_old = distance;
				near_client = client;
			}
		}
	}
	
	return near_client;
}

bool IsSurvivorsEntireTeam(int client, int trigger)
{
	if (!IsValidClientTeam2Alive(client))
	{
		return false;
	}
	
	int teleport_percent = GetConVarInt(gc_teleport_percent);
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
	
	if (gathered_survivors < min_survivors && gi_gather_percent)
	{
		for (int i = 1; i <= MAX_PLAYERS; i++)
		{
			if (IsValidClientTeam2Alive(i) && IsClientInTrigger(i, trigger))
			{
				PrintHintText(client, "%t", "Not enough survivors", min_survivors);
			}
		}
		
		return false;
	}
	
	return true;
}

void OnEndTouch_Elevator(const char[] output, int trigger, int client, float delay)
{
	ClientTrigger_Remove(client);
	
	DataPack pack;
	CreateDataTimer(0.5, OnEndTouch_Elevator_Delay, pack, TIMER_FLAG_NO_MAPCHANGE);
	
	WritePackCell(pack, EntIndexToEntRef(trigger));
	WritePackCell(pack, GetConVarInt(gc_teleport_countdown_elevator));
	
	int button = GetEntPropEnt(trigger, Prop_Data, "m_hOwnerEntity");
	WritePackCell(pack, EntIndexToEntRef(button));
}

Action:OnEndTouch_Elevator_Delay(Handle timer, Handle data)
{
	if (!IsValidHandle(data))
	{
		return;
	}
	
	DataPack pack = view_as<DataPack>(data);
	
	ResetPack(pack);
	
	int trigger 	= EntRefToEntIndex(ReadPackCell(pack));
	int countdown 	= ReadPackCell(pack);
	int button 		= EntRefToEntIndex(ReadPackCell(pack));
	
	if (!IsValidEntity(trigger))
	{
		return;
	}
	
	if (!IsSurvivorsGathered(trigger))
	{
		Teleport_Cancel(null);
	}
	else
	{
		if (!IsValidHandle(gt_Teleport))
		{
			Teleport_Start(button, countdown);
		}
	}
}

void OnEndTouch_Saferoom(const char[] output, int trigger, int client, float delay)
{
	ClientTrigger_Remove(client);
	
	DataPack pack;
	CreateDataTimer(0.5, OnEndTouch_Delay, pack, TIMER_FLAG_NO_MAPCHANGE);
	
	WritePackCell(pack, EntIndexToEntRef(trigger));
	WritePackCell(pack, GetConVarInt(gc_teleport_countdown_saferoom));
}

void OnEndTouch_Escape(const char[] output, int trigger, int client, float delay)
{
	ClientTrigger_Remove(client);
	
	DataPack pack;
	CreateDataTimer(0.5, OnEndTouch_Delay, pack, TIMER_FLAG_NO_MAPCHANGE);
	
	WritePackCell(pack, EntIndexToEntRef(trigger));
	WritePackCell(pack, GetConVarInt(gc_teleport_countdown_escape));
}

Action:OnEndTouch_Delay(Handle timer, Handle data)
{
	if (!IsValidHandle(data))
	{
		return;
	}
	
	DataPack pack = view_as<DataPack>(data);
	
	ResetPack(pack);
	
	int trigger 		= EntRefToEntIndex(ReadPackCell(pack));
	int countdown 	= ReadPackCell(pack);
	
	if (!IsValidEntity(trigger))
	{
		return;
	}
	
	if (!IsSurvivorsGathered(trigger))
	{
		Teleport_Cancel(null);
	}
	else
	{
		if (!IsValidHandle(gt_Teleport))
		{
			Teleport_Start(trigger, countdown);
		}
	}
}

void Event_mission_lost(Handle:event, const String:name[], bool:dontBroadcast)
{
	gb_mission_lost = true;
	
	if (IsValidHandle(gt_Teleport))
	{
		delete gt_Teleport;
	}
}

void Event_finale_win(Handle:event, const String:name[], bool:dontBroadcast)
{
	Delete_Timers();
}

public OnMapTransit()
{
	Delete_Timers();
}

public OnMapRestart()
{
	Delete_Timers();
}

public OnMissionChange()
{
	Delete_Timers();
}

public OnServerEmpty()
{
	Delete_Timers();
	
	if (IsValidHandle(gk_button_triggers))
	{
		delete gk_button_triggers;
	}
	
	char plugin_name[PLATFORM_MAX_PATH];
	GetPluginFilename(INVALID_HANDLE, plugin_name, sizeof(plugin_name));
	
	ServerCommand("sm plugins reload \"%s\"", plugin_name);
}

void Delete_Timers()
{
	if (IsValidHandle(gt_Teleport))
	{
		delete gt_Teleport;
	}
	
	if (IsValidHandle(gt_SearchFarBots))
	{
		delete gt_SearchFarBots;
	}
	
	for (int i = 1; i <= MAX_SURVIVORID; i++)
	{
		gi_survivor_trigger[i] = 0;
	}
}

void Search_ButtonTriggers(int button)
{
	if (!IsValidHandle(gk_button_triggers))
	{
		return;
	}
	
	KvRewind(gk_button_triggers);
	
	if (!IsValidEntity(button))
	{
		return;
	}
		
	char targetname_button[MAX_STRING_LENGTH]; 
	GetEntPropString(button, Prop_Data, "m_iName", targetname_button, sizeof(targetname_button));
	
	if (!strlen(targetname_button))
	{
		return;
	}
		
	if (!KvJumpToKey(gk_button_triggers, targetname_button, false))
	{
		return;
	}
	
	char key_value	[PLATFORM_MAX_PATH];
	KvGetString(gk_button_triggers, "hammerid", key_value, sizeof(key_value));
	
	int hammerid = StringToInt(key_value);
	if (!hammerid)
	{
		KvRewind(gk_button_triggers);
		return;
	}
	
	int entity = FindEntityByHammerid(hammerid);
	if (entity == -1)
	{
		KvRewind(gk_button_triggers);
		return;
	}
	
	SetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity", button);
	
	HookSingleEntityOutput(button, "OnUseLocked", OnUseLocked);
	HookSingleEntityOutput(button, "OnPressed", OnPressed);
	
	HookSingleEntityOutput(entity, "OnStartTouch", OnStartTouch);
	HookSingleEntityOutput(entity, "OnEndTouch", OnEndTouch);
	
	KvRewind(gk_button_triggers);
}

int FindEntityByHammerid(int hammerid)
{
	for (int i = MAX_PLAYERS; i <= MAX_ENTITIES; i++)
	{
		if (IsValidEntity(i))
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

int GetEntityTrigger(int entity)
{
	if (!IsValidEntity(entity))
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

void Teleport_Start(int entity, int countdown)
{
	if (!IsValidEntity(entity))
	{
		return;
	}
	
	if (IsValidHandle(gt_Teleport))
	{
		return;
	}
	
	gi_teleport_countdown = countdown + 1;
	
	gt_Teleport = CreateTimer(1.0, Teleport, EntIndexToEntRef(entity), TIMER_REPEAT);
}

Action:Teleport(Handle timer, int ref)
{
	if (gb_mission_lost)
	{
		return Plugin_Stop;
	}
	
	gi_teleport_countdown --;
	if (gi_teleport_countdown > 0)
	{
		PrintHintTextToAll("%t: %d", "Countdown", gi_teleport_countdown);
		return Plugin_Continue;
	}
			
	int entity = EntRefToEntIndex(ref);
	if (!IsValidEntity(entity))
	{
		return Plugin_Stop;
	}
	
	char classname[MAX_CLASSNAME_LENGTH];
	GetEntityClassname(entity, classname, sizeof(classname));
	
	if (!strcmp(classname, "func_button"))
	{
		UnhookSingleEntityOutput(entity, "OnPressed", OnPressed);
		
		InputEntity(entity, "Unlock");
		InputEntity(entity, "Press");
		
		int trigger = GetEntityTrigger(entity);
		if (trigger)
		{
			UnhookSingleEntityOutput(trigger, "OnEntireTeamStartTouch", OnEntireTeamStartTouch);
			
			UnhookSingleEntityOutput(trigger, "OnStartTouch", OnStartTouch_Elevator);
			UnhookSingleEntityOutput(trigger, "OnEndTouch", OnEndTouch_Elevator);
			
			UnhookSingleEntityOutput(trigger, "OnStartTouch", OnStartTouch);
			UnhookSingleEntityOutput(trigger, "OnEndTouch", OnEndTouch);
		}
	}
	else
	{
		char targetname[MAX_CLASSNAME_LENGTH];
		GetEntPropString(entity, Prop_Data, "m_iName", targetname, sizeof(targetname));
		
		if (!strcmp(targetname, TRIGGER_SAFEROOM_NANE))
		{
			int safedoor = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");
			if (IsValidEntity(safedoor))
			{
				if (GetEntProp(safedoor, Prop_Data, "m_spawnflags") == 32768)
				{
					gi_teleport_countdown = 1;
					return Plugin_Continue;
				}
				
				InputEntity(safedoor, "Close");
			}
			
			UnhookSingleEntityOutput(entity, "OnEntireTeamStartTouch", OnEntireTeamStartTouch);
			
			UnhookSingleEntityOutput(entity, "OnStartTouch", OnStartTouch_Saferoom);
			UnhookSingleEntityOutput(entity, "OnEndTouch", OnEndTouch_Saferoom);
			
			UnhookSingleEntityOutput(entity, "OnStartTouch", OnStartTouch);
			UnhookSingleEntityOutput(entity, "OnEndTouch", OnEndTouch);
		}
		else
		{
			UnhookSingleEntityOutput(entity, "OnEntireTeamStartTouch", OnEntireTeamStartTouch);
			
			UnhookSingleEntityOutput(entity, "OnStartTouch", OnStartTouch_Escape);
			UnhookSingleEntityOutput(entity, "OnEndTouch", OnEndTouch_Escape);
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
	
	return Plugin_Stop;
}

Action:Teleport_Cancel(Handle timer)
{
	if (IsValidHandle(gt_Teleport))
	{
		delete gt_Teleport;
		PrintHintTextToAll("%t", "Teleport Canceled");
	}
}

bool IsValidClientTeleport(int client)
{
	if (!IsValidClientTeam2Alive(client) || 
		IsSurvivorHanging(client) ||
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
	EscapeTriggers_Remove();
	
	char classname			[PLATFORM_MAX_PATH];
	char key				[PLATFORM_MAX_PATH];
	char keyvalue			[PLATFORM_MAX_PATH];
	char button_targetname	[PLATFORM_MAX_PATH];
	char trigger_targetname	[PLATFORM_MAX_PATH];
	char trigger_output		[PLATFORM_MAX_PATH];
		
	int hammerid; int start_disabled; int unlock; int spawnflags;
	
	EntityLumpEntry entry;
	
	for (int i, n = EntityLump.Length(); i < n; i++)
	{
		entry = EntityLump.Get(i);
		
		if (entry.GetNextKey("classname", classname, sizeof(classname)) != -1)
		{
			if (!strcmp(classname, "trigger_multiple"))
			{
				entry.GetNextKey("targetname", trigger_targetname, sizeof(trigger_targetname));
				
				hammerid = 0;
					
				if (entry.GetNextKey("hammerid", keyvalue, sizeof(keyvalue)) != -1)
				{
					hammerid = StringToInt(keyvalue);
				}
				
				if (entry.GetNextKey("OnEntireTeamStartTouch", keyvalue, sizeof(keyvalue)) != -1)
				{
					unlock = 0; start_disabled = 0; spawnflags = 0;
											
					for (int j = 0; j < entry.Length; j++)
					{
						entry.Get(j, key, sizeof(key), keyvalue, sizeof(keyvalue));
						
						if (!strcmp(key, "StartDisabled"))
						{
							start_disabled = StringToInt(keyvalue);
						}
						else if (!strcmp(key, "OnEntireTeamStartTouch") &&
								StrContains(keyvalue, "UnLock", false) > -1)
						{
							unlock = 1;
							FormatEx(trigger_output, sizeof(trigger_output), keyvalue);
						}
						else if (!strcmp(key, "spawnflags"))
						{
							spawnflags = StringToInt(keyvalue);
						}
					}
					
					if (unlock)
					{
						if (GetEngineVersion() == Engine_Left4Dead)
						{
							SplitString(trigger_output, ",", button_targetname, sizeof(button_targetname));
						}
						else
						{
							SplitString(trigger_output, "", button_targetname, sizeof(button_targetname));
						}
						
						Search_ButtonTrigger(hammerid, button_targetname);
					}
					else if (strlen(trigger_targetname)) 
					{
						if (start_disabled == 1 || 
							spawnflags == 3 ||
							(StrContains(trigger_targetname, "escape", false) > -1 && !unlock) ||
							!unlock)
						{
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
	char classname	[PLATFORM_MAX_PATH];
	char keyvalue	[PLATFORM_MAX_PATH];
	char targetname	[PLATFORM_MAX_PATH];
	
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
					if (entry.GetNextKey("hammerid", keyvalue, sizeof(keyvalue)) != -1)
					{
						if (IsValidHandle(gk_button_triggers))
						{
							KvRewind(gk_button_triggers);
		
							if (KvJumpToKey(gk_button_triggers, targetname, true))
							{
								KvSetNum(gk_button_triggers, "hammerid", trigger_hammerid);
																	
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
	int safedoor = -1;
	while ((safedoor = FindEntityByClassname(safedoor, "prop_door_rotating_checkpoint")) != -1)
	{
		if (GetEntProp(safedoor, Prop_Data, "m_spawnflags") & 8192)
		{
			if (!FindDistEntityByClassname(safedoor, "player", 500.0))
			{
				HookSingleEntityOutput(safedoor, "OnFullyClosed", OnFullyClosed);
				
				break;
			}
		}
	}
	
	int trigger = SafeRoomTrigger_Spawn(safedoor); 
	if (trigger)
	{
		if (!IsValidEntity(safedoor))
		{
			HookSingleEntityOutput(trigger, "OnEntireTeamStartTouch", OnEntireTeamStartTouch);
		
			HookSingleEntityOutput(trigger, "OnStartTouch", OnStartTouch_Saferoom);
			HookSingleEntityOutput(trigger, "OnEndTouch", OnEndTouch_Saferoom);
		}
		else
		{
			HookSingleEntityOutput(trigger, "OnStartTouch", OnStartTouch);
			HookSingleEntityOutput(trigger, "OnEndTouch", OnEndTouch);
		}
	}
}

void ClientTrigger_Set(int client, int trigger)
{
	if (IsClientInTrigger(client, trigger))
	{
		return;
	}
	
	int survivorid = GetClientSurvivorId(client);
	if (survivorid)
	{
		gi_survivor_trigger[survivorid] = EntIndexToEntRef(trigger);
	}
}

bool IsClientInTrigger(int client, int trigger)
{
	return gi_survivor_trigger[GetClientSurvivorId(client)] == EntIndexToEntRef(trigger);
}

void ClientTrigger_Remove(int client)
{
	gi_survivor_trigger[GetClientSurvivorId(client)] = 0;
}

Action:SearchFarBots(Handle timer)
{
	if (IsValidHandle(gt_Teleport))
	{
		return Plugin_Continue;
	}
	
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		if (!IsAnySurvivorNearEntity(i))
		{
			if (!IsValidClientTeleport(i))
			{
				if (IsValidClientTeam2Alive(i) && IsFakeClient(i))
				{
					ForcePlayerSuicide(i);
				}
			}
			else
			{
				TeleportSurvivorBot(i);
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

bool IsAnySurvivorNearEntity(int bot)
{
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
				return true;
			}
		}
	}
	
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


/**
 * ищет совпадение по классу вокруг заданной сущности
 *
 * entity 			- сущность, относительно которой происходит поиск (заданная сущность)
 * distance 		- расстояние поиска 
 * classname 		- класс искомой сущности
 * return 			- сущность или 0, если не найдено
 */
stock int FindDistEntityByClassname(int entity, char[] classname, float distance = 50.0)
{
	if (!IsValidEntity(entity))
	{
		return 0;
	}
	
	float pos_entity[3];
	
	int parent = GetEntPropEnt(entity, Prop_Data, "m_pParent");
	
	if (IsValidEntity(parent))
	{
		GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", pos_entity);
	}
	else
	{
		GetEntPropVector(entity, Prop_Data, "m_vecOrigin", pos_entity);
	}
	
	float pos_i[3]; 
	float distance_entity_i;
	
	int i = -1;
	while ((i = FindEntityByClassname(i, classname)) != -1)
	{
		if (i != entity)
		{  
			parent = GetEntPropEnt(i, Prop_Data, "m_pParent");
			
			if (IsValidEntity(parent))
			{
				GetEntPropVector(i, Prop_Data, "m_vecAbsOrigin", pos_i);
			}
			else
			{
				GetEntPropVector(i, Prop_Data, "m_vecOrigin", pos_i);
			}
			
			distance_entity_i = GetVectorDistance(pos_entity, pos_i);
			if (distance_entity_i <= distance)
			{
				return i;
			}
		}
	}
	
	return 0;
}

stock bool IsSurvivorHanging(int client)
{
	return bool:(GetEntProp(client, Prop_Send, "m_isHangingFromLedge") | GetEntProp(client, Prop_Send, "m_isFallingFromLedge"));
}

stock bool IsSurvivorIncapacitated(int client)
{
	return bool:GetEntProp(client, Prop_Send, "m_isIncapacitated");
}

stock int IsSurvivorPounced(int client)
{
	int attacker = GetEntPropEnt(client, Prop_Send, "m_pounceAttacker");
	if (attacker > 0)
	{
		return attacker;
	}
	
	return 0;
}

stock int IsSurvivorGrabbed(int client)
{
	int attacker = GetEntPropEnt(client, Prop_Send, "m_tongueOwner");
	if (attacker > 0)
	{
		return attacker;
	}
	
	return 0;
}

stock int IsSurvivorPummel(int client)
{
	if (GetEngineVersion() != Engine_Left4Dead2)
	{
		return 0;
	}
	
	int attacker = GetEntPropEnt(client, Prop_Send, "m_pummelAttacker");
	if (attacker > 0)
	{
		return attacker;
	}
	
	return 0;
}

stock int IsSurvivorCarry(int client)
{
	if (GetEngineVersion() != Engine_Left4Dead2)
	{
		return 0;
	}
	
	int attacker = GetEntPropEnt(client, Prop_Send, "m_carryAttacker");
	if (attacker > 0)
	{
		return attacker;
	}
	
	return 0;
}

stock int IsSurvivorJockey(int client)
{
	if (GetEngineVersion() != Engine_Left4Dead2)
	{
		return 0;
	}
	
	int attacker = GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker");
	if (attacker > 0)
	{
		return attacker;
	}
	
	return 0;
}

/**
 * Проверяет клиента команды 2
 *
 * client 			- Client index.
 * return 			- true если client valid и false если нет
 */
stock bool IsValidClient(int client)
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
 * Проверяет клиента команды 2
 *
 * client 			- Client index.
 * return 			- true если client valid и false если нет
 */
stock bool IsValidClientAlive(int client)
{
	if (IsValidClient(client))
	{
		if (IsPlayerAlive(client))
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
stock bool IsValidClientTeam2Alive(int client)
{
	if (IsValidClientAlive(client))
	{
		if (GetClientTeam(client) == 2)
		{
			return true;
		}
	}
	return false;
}

/**
 * Посылает на сущность действие с регулируемым интервалом
 *
 * entity 			- сущность для передачи последовательности действий
 * input 			- название действия
 * value 			- значение действия (например 1, если на свет передается brightness 1)
 * time_start 		- кол-во секунд, через которое запускается действие
 * time_life 		- кол-во секунд, через которое удаляется сущность, если 0 - то не удаляется
*/
stock void InputEntity(int entity, char[] input, char[] value = "", float time_start = 0.0, float time_life = 0.0)
{
	if (!IsValidEntity(entity))
	{
		return;
	}
		
	if (!strcmp(input, "Kill") && time_life >= 0)
	{
		InputKill(entity, time_life);
	}
	else
	{
		if (strlen(value) < 1 && time_start == 0.0 && time_life == 0)
		{
			AcceptEntityInput(entity, input);
		}
		else
		{
			char temp[PLATFORM_MAX_PATH];
			Format(temp, sizeof(temp), "OnUser1 !self:%s:%s:%f:-1", input, value, time_start);
				
			SetVariantString(temp);
			AcceptEntityInput(entity, "AddOutput");
			AcceptEntityInput(entity, "FireUser1");
		
			if (time_life > 0)
			{
				InputKill(entity, time_start + time_life);
			}
		}
	}	
}

/**
 * Удаляет сущность через интервал НЕ УДАЛЯЮТСЯ СУЩНОСТИ МЕНЬШЕ ЧЕМ MAX_PLAYERS
 *
 * entity 			- сущность, которая удаляется
 * time 			- кол-во секунд, через которое удаляется
*/
stock void InputKill(int entity, float time = 0.0)
{
	if (!IsValidEntity(entity) || (entity >= 0 && entity <= MAX_PLAYERS)) {return;}
	
	if (time == 0.0)
	{
		if (HasEntProp(entity, Prop_Data, "m_iParent"))
		{
			if (IsValidEntity(GetEntPropEnt(entity, Prop_Data, "m_pParent")))
			{
				AcceptEntityInput(entity, "ClearParent");
			}
		}
		
		AcceptEntityInput(entity, "Kill");
		/*if (IsValidEdict(entity))
		{
			RemoveEdict(entity);
		}*/
	}
	else if (time > 0.0)
	{
		static char temp[MAX_STRING_LENGTH];
		
		if (HasEntProp(entity, Prop_Data, "m_iParent"))
		{
			if (IsValidEntity(GetEntPropEnt(entity, Prop_Data, "m_pParent")))
			{
				Format(temp, sizeof(temp), "OnUser4 !self:ClearParent::%f:-1", time);
				SetVariantString(temp);
				AcceptEntityInput(entity, "AddOutput");
			}
		}
		
		Format(temp, sizeof(temp), "OnUser4 !self:Kill::%f:-1", time);
		SetVariantString(temp);
		AcceptEntityInput(entity, "AddOutput");
	
		AcceptEntityInput(entity, "FireUser4");
	}
}

/**
 * перемещает координаты вперед-назад согласно углам
 *
 * vec_origin 		- начальные координаты
 * vec_angles 		- углы
 * distance			- расстояние, если +, то вперед, если минус назад
 */
stock void MovePos_Forward(float vec_origin[3], float vec_angles[3], float distance)
{
	float direction[3];
		
	GetAngleVectors(vec_angles, direction, NULL_VECTOR, NULL_VECTOR);
	
	vec_origin[0] = vec_origin[0] + direction[0] * distance;
	vec_origin[1] = vec_origin[1] + direction[1] * distance;
	vec_origin[2] = vec_origin[2] + direction[2] * distance;

}
