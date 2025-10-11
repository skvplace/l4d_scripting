/**
 * ========================================================================
 * Plugin [L4D/L4D2] Rescue Control
 * Manage the respawn of players.
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
	name 		= "[L4D/L4D2] Rescue Control",
	author 		= "Skv",
	description = "The plugin manage the respawn of survivors",
	version 	= "1.4",
	url 		= "https://forums.alliedmods.net/showthread.php?p=2836579#post2836579"
}

#define MAX_PLAYERS 				18
#define MAX_STRING_LENGTH			128
#define MAX_CLASSNAME_LENGTH 		64

#define FLOOR_HEIGH_SEARCH			75.0
#define RESCUE_SEARCH_DISTANCE 		200.0
#define ROOM_SCAN_MAX_DISTANCE 		1000.0
#define ROOM_NAME 					"rc_rescue_room"

Handle 	gk_rooms;

#define GLOW_NAME 					"rc_rescue_glow"
#define VISIBLE_HEIGH				80.0
#define VISIBLE_HEIGH_INCAP			30.0

char 	gs_model_pills[]			= "models/w_models/weapons/w_eq_painpills.mdl";

Handle 	gt_CheckNearRescue			[MAX_PLAYERS + 1];
Handle 	gt_CreateRescue				[MAX_PLAYERS + 1];

#define MAX_TIMERS					MAX_PLAYERS * 4
Handle 	gt_Timer					[MAX_TIMERS + 1];

bool 	gb_finale_start;

ConVar 	gc_rescue_min_dead_time;
ConVar 	gc_rescue_mode;
ConVar 	gc_rescue_door_opening_distance;

float 	gf_rescue_min_dead_time;
int 	gi_rescue_mode;

#define MAX_ROOM_RESCUES			3
char 	gs_chance_rescue_slot		[MAX_ROOM_RESCUES];

// TEENGIRL SOUNDS
char 	gs_sound_TeenGirl[][] =
{
		"callforrescue01",
		"callforrescue02",
		"callforrescue06",
		"callforrescue07",
		"callforrescue14",
		"callforrescue16"
};

char 	gs_random_TeenGirl[sizeof(gs_sound_TeenGirl)];

// BIKER SOUNDS
char 	gs_sound_Biker[][] =
{
		"callforrescue01",
		"callforrescue02",
		"callforrescue03",
		"callforrescue04",
		"callforrescue06",
		"callforrescue07",
		"callforrescue08",
		"callforrescue09",
		"callforrescue10",
		"callforrescue11",
		"callforrescue12",
		"callforrescue13"
};

char 	gs_random_Biker[sizeof(gs_sound_Biker)];

// LOUIS SOUNDS
char 	gs_sound_Manager[][] =
{
		"callforrescue01",
		"callforrescue02",
		"callforrescue03"
};

char 	gs_random_Manager[sizeof(gs_sound_Manager)];

// BILL SOUNDS
char 	gs_sound_NamVet[][] =
{
		"callforrescue01",
		"callforrescue02",
		"callforrescue05",
		"callforrescue06",
		"callforrescue07",
		"callforrescue08",
		"callforrescue10",
		"callforrescue11",
		"callforrescue12"
};

char 	gs_random_NamVet[sizeof(gs_sound_NamVet)];

// Gambler SOUNDS
char 	gs_sound_Gambler[][] =
{
		"callforrescue01",
		"callforrescue02",
		"callforrescue03",
		"callforrescue04",
		"callforrescue05",
		"callforrescue06",
		"callforrescue07",
		"callforrescue08",
		"callforrescue09",
		"callforrescue10",
		"callforrescue11",
		"callforrescue12"
};

char 	gs_random_Gambler[sizeof(gs_sound_Gambler)];

// Producer SOUNDS
char 	gs_sound_Producer[][] =
{
		"callforrescue01",
		"callforrescue02",
		"callforrescue03",
		"callforrescue04",
		"callforrescue05",
		"callforrescue06",
		"callforrescue07",
		"callforrescue08",
		"callforrescue09",
		"callforrescue10",
		"callforrescue11",
		"callforrescue12"
};

char 	gs_random_Producer[sizeof(gs_sound_Producer)];

// Coach SOUNDS
char 	gs_sound_Coach[][] =
{
		"callforrescue01",
		"callforrescue02",
		"callforrescue03",
		"callforrescue04",
		"callforrescue05",
		"callforrescue06",
		"callforrescue07",
		"callforrescue08",
		"callforrescue09",
		"callforrescue10",
		"callforrescue11",
		"callforrescue12",
		"callforrescue13",
		"callforrescue14",
		"callforrescue15",
		"callforrescue16"
};

char 	gs_random_Coach[sizeof(gs_sound_Coach)];

// Mechanic SOUNDS
char 	gs_sound_Mechanic[][] =
{
		"callforrescue01",
		"callforrescue02",
		"callforrescue03",
		"callforrescue04",
		"callforrescue05",
		"callforrescue06",
		"callforrescue07",
		"callforrescue08",
		"callforrescue09",
		"callforrescue10",
		"callforrescue11",
		"callforrescue12",
		"callforrescue13",
		"callforrescue14",
		"callforrescue15",
		"callforrescue16",
		"callforrescue17",
		"callforrescue18",
		"callforrescue19"
};

char 	gs_random_Mechanic[sizeof(gs_sound_Mechanic)];

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
	HookEvent("player_death", Event_player_death);
	HookEvent("survivor_rescued", Event_survivor_rescued);
		
	HookEvent("mission_lost", Event_mission_lost);
	
	HookEvent("player_use",  Event_player_use);
	HookEvent("entity_visible", Event_entity_visible);
	
	HookEvent("finale_start", Event_finale_start);
			
	gc_rescue_min_dead_time = FindConVar("rescue_min_dead_time");
	HookConVarChange(gc_rescue_min_dead_time, OnConVarChanged_rescue_min_dead_time);
	
	gc_rescue_mode = CreateConVar("rescue_mode", "2", "Rescue mode: 0 - rescue is disabled, 1 - rescue room is active only once, 2 - rescue is active many times", _, true, 0.0, true, 2.0);
	SetConVarFlags(gc_rescue_mode, GetConVarFlags(gc_rescue_mode) & ~FCVAR_NOTIFY);
	HookConVarChange(gc_rescue_mode, OnConVarChanged_rescue_mode);
	
	gc_rescue_door_opening_distance = CreateConVar("rescue_door_opening_distance", "400", "Sets the automatic door opening distance", _, true, 0.0, true, 800.0);
	SetConVarFlags(gc_rescue_door_opening_distance, GetConVarFlags(gc_rescue_door_opening_distance) & ~FCVAR_NOTIFY);
	
	AutoExecConfig(true, "rescue_control");
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

void OnConVarChanged_rescue_min_dead_time(ConVar convar, const char[] oldValue, const char[] newValue)
{
	gf_rescue_min_dead_time = StringToFloat(newValue);
	if (gf_rescue_min_dead_time < 1.0)
	{
		gf_rescue_min_dead_time = 1.0;
	}
}

void OnConVarChanged_rescue_mode(ConVar convar, const char[] oldValue, const char[] newValue)
{
	gi_rescue_mode = StringToInt(newValue);
	
	if (gb_finale_start)
	{
		return;
	}
	
	if (gi_rescue_mode == 0)
	{
		int rescue;
		
		char name[MAX_STRING_LENGTH];
		int survivorid;
		
		for (int i = 1; i <= MAX_PLAYERS; i++)
		{
			survivorid = GetClientSurvivorId(i);
			if (survivorid)
			{
				if (IsValidHandle(gt_CheckNearRescue[survivorid]))
				{
					delete gt_CheckNearRescue[survivorid];
				}
				
				if (IsValidHandle(gt_CreateRescue[survivorid]))
				{
					delete gt_CreateRescue[survivorid];
				}
				
				rescue = GetActiveRescue(survivorid);
				if (rescue)
				{
					GetEntPropString(rescue, Prop_Data, "m_iName", name, sizeof(name));
					InputTarget(name, "Kill");
				}
			}
		}
		
		Room_Disable_All();
	}
	else
	{
		Rescue_Restore_All();
		
		if (StringToInt(oldValue) == 0)
		{
			SearchDeadSurvivor();
		}
	}
}

public OnMapStart()
{
	PrecacheModel(gs_model_pills);
}

public OnGameplayStart(int stage)
{
	if (stage != 4)
	{
		return;
	}
	
	Delete_Timers();
	
	gf_rescue_min_dead_time 	= GetConVarFloat	(gc_rescue_min_dead_time);
	gi_rescue_mode 				= GetConVarInt		(gc_rescue_mode);
	
	if (IsValidHandle(gk_rooms))
	{
		CloseHandle(gk_rooms);
	}
	
	gk_rooms = CreateKeyValues("rooms");
	
	int i = -1;
	while ((i = FindEntityByClassname(i, "info_survivor_rescue")) != -1)
	{
		if (!Search_Recue_Rooms(i))
		{
			Create_Recue_Rooms(i);
		}
	}
	
	char name[MAX_CLASSNAME_LENGTH];
	
	i = -1; int door;
	while ((i = FindEntityByClassname(i, "info_target")) != -1)
	{
		GetEntPropString(i, Prop_Data, "m_iName", name, sizeof(name));
		if (!strcmp(name, ROOM_NAME))
		{
			RoomData_Create(i);
			
			door = -1;
			while ((door = FindEntityByClassname(door, "prop_door_rotating")) != -1)
			{
				if (i == GetEntPropEnt(door, Prop_Data, "m_hOwnerEntity"))
				{
					HookSingleEntityOutput(door, "OnOpen", OnOpen_Door);
					InputEntity(door, "Unlock");
				}
			}
		}
	}
	
	i = -1;
	while ((i = FindEntityByClassname(i, "info_survivor_rescue")) != -1)
	{
		InputKill(i);
	}
	
	if (gi_rescue_mode == 0)
	{
		Room_Disable_All();
	}
}

void Event_mission_lost(Handle:event, const String:name[], bool:dontBroadcast)
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

public OnServerEmpty()
{
	Delete_Timers();
}

public OnEscapeVehicleLeaving()
{
	Delete_Timers();
}

void Event_finale_start(Handle:event, const String:name[], bool:dontBroadcast)
{
	SetConVarInt(gc_rescue_mode, 0);
	gb_finale_start = true;
}

void Event_survivor_rescued(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (gb_finale_start)
	{
		return;
	}
	
	int client = GetClientOfUserId(GetEventInt(event, "victim"));
	if (!IsValidClientTeam2(client)) {return;}
	
	RemoveGlowRescue(client, 0.1);
}

void SearchDeadSurvivor()
{
	if (gf_rescue_min_dead_time < 1.0)
	{
		gf_rescue_min_dead_time = 1.0;
	}
	
	int survivorid;
	
	for (int i = 1; i <= MAX_PLAYERS; i ++)
	{
		if (IsValidClientTeam2(i) && !IsPlayerAlive(i))
		{
			survivorid = GetClientSurvivorId(i);
			if (survivorid)
			{
				if (!IsValidHandle(gt_CheckNearRescue[survivorid]))
				{
					gt_CheckNearRescue[survivorid] = CreateTimer((gf_rescue_min_dead_time * 0.25) + (i * 0.5), CheckNearRescue, survivorid);
				}
			}		
		}
	}
}

void Event_player_death(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (gf_rescue_min_dead_time < 1.0)
	{
		gf_rescue_min_dead_time = 1.0;
	}
	
	if (gb_finale_start)
	{
		return;
	}
	
	if (gi_rescue_mode == 0)
	{
		return;
	}
	
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsValidClientTeam2(client)) 
	{
		return;
	}
	
	int survivorid = GetClientSurvivorId(client);
	if (survivorid)
	{
		if (!IsValidHandle(gt_CheckNearRescue[survivorid]))
		{
			gt_CheckNearRescue[survivorid] = CreateTimer(gf_rescue_min_dead_time, CheckNearRescue, survivorid);
		}
	}
}
	
Action:CheckNearRescue(Handle timer, int survivorid)
{
	if (gb_finale_start)
	{
		return;
	}
	
	int client = GetClientOfSurvivorId(survivorid);
	if (IsValidClientTeam2Alive(client))
	{
		return;
	}
	
	if (!IsValidHandle(gt_CreateRescue[survivorid]))
	{
		gt_CreateRescue[survivorid] = CreateTimer(3.0, CreateRescue, survivorid, TIMER_REPEAT);
	}
}

Action:CreateRescue(Handle timer, int survivorid)
{
	if (gb_finale_start)
	{
		return Plugin_Stop;
	}	
	
	int client = GetClientOfSurvivorId(survivorid);
	if (!IsValidClientTeam2(client))
	{
		return Plugin_Continue;
	}
	
	if (IsPlayerAlive(client))
	{
		int rescue = GetActiveRescue(survivorid);
		if (rescue)
		{
			float pos_rescue[3];
			GetEntPropVector(rescue, Prop_Data, "m_vecOrigin", pos_rescue);
			
			char name[MAX_STRING_LENGTH];
			GetEntPropString(rescue, Prop_Data, "m_iName", name, sizeof(name));
				
			InputTarget(name, "Kill");
			
			if (gi_rescue_mode == 2)
			{
				Rescue_Restore(pos_rescue);
			}
		}
		
		return Plugin_Stop;
	}
	
	if (GetActiveRescue(survivorid))
	{
		return Plugin_Continue;
	}
		
	float pos_spawn[3]; float ang_spawn[3];
	
	int room = GetVectorsRescue(-1, pos_spawn, ang_spawn);
	if (!room)
	{
		return Plugin_Continue;
	}
	
	if (IsAnySurvivorNear_DontWatch(room, 200.0))
	{
		Rescue_Restore(pos_spawn);
		return Plugin_Continue;
	}
	
	if (NeedCloseRoomDoors(room))
	{
		return Plugin_Continue;
	}

	char temp[PLATFORM_MAX_PATH];
	GetClientModel(client, temp, sizeof(temp));
	
	int entity;
	
	if (GetEngineVersion() == Engine_Left4Dead)
	{
		entity = CreateEntityByName("prop_glowing_object");
		if (entity == -1)
		{
			return Plugin_Stop;
		}
		
		DispatchKeyValue(entity, "StartGlowing", "1");
		DispatchKeyValue(entity, "GlowForTeam", "2");
	}
	else
	{
		entity = CreateEntityByName("prop_dynamic");
		if (entity == -1)
		{
			return Plugin_Stop;
		}
		
		DispatchKeyValue(entity, "StartGlowing", "0");
		DispatchKeyValue(entity, "GlowForTeam", "-1");
		
		DispatchKeyValue(entity, "glowstate", "0");
		DispatchKeyValue(entity, "glowrangemin", "150");
		DispatchKeyValue(entity, "glowrange", "0");
		DispatchKeyValue(entity, "glowcolor", "0 0 0");
		
		InputEntity(entity, "StartGlowing", _, 0.1);
	}
	
	SetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity", room);
	
	char targetname[MAX_TARGET_LENGTH];
	FormatEx(targetname, sizeof(targetname), "%s_%d", GLOW_NAME, survivorid);
	
	DispatchKeyValue(entity, "targetname", targetname);
	
	DispatchKeyValue(entity, "model", temp);
	DispatchKeyValue(entity, "solid", "0");
	DispatchKeyValue(entity, "DefaultAnim", "Idle_Rescue_01c");
			
	DispatchKeyValue(entity, "rendermode", "1");
	DispatchKeyValue(entity, "renderamt", "0");
	//DispatchKeyValue(entity, "rendercolor", "255 0 0");
	
	DispatchKeyValueVector(entity, "origin", pos_spawn);
	DispatchKeyValueVector(entity, "angles", ang_spawn);
		
	DispatchSpawn(entity);
	
	int visible_prop = CreateEntityByName("prop_door_rotating");
	if (visible_prop == -1)
	{
		return Plugin_Stop;
	}
	
	SetEntPropEnt(visible_prop, Prop_Data, "m_hOwnerEntity", room);
	
	DispatchKeyValue(visible_prop, "targetname", targetname);
	
	pos_spawn[2] += VISIBLE_HEIGH;
	DispatchKeyValueVector(visible_prop, "origin", pos_spawn);
		
	DispatchKeyValue(visible_prop, "model", gs_model_pills);
	
	DispatchKeyValue(visible_prop, "rendermode", "10");
	DispatchKeyValue(visible_prop, "renderamt", "0");
	DispatchKeyValue(visible_prop, "renderfx", "0");
	DispatchKeyValue(visible_prop, "rendercolor", "0 0 0");
	DispatchKeyValue(visible_prop, "disableshadows", "1");
	
	int enteffects = GetEntProp(visible_prop, Prop_Send, "m_fEffects");
	enteffects |= 32;
	SetEntProp(visible_prop, Prop_Send, "m_fEffects", enteffects);
	
	DispatchSpawn(visible_prop);
	
	Rescue_Playsound(client, entity);
	
	int timer_slot = GetFreeTimerSlot();
	if (timer_slot)
	{
		float yell_interval = GetConVarFloat(FindConVar("rescue_yell_interval"));
		if (yell_interval <= 0.0)
		{
			yell_interval = 6.0;
		}

		DataPack data_sound;
		gt_Timer[timer_slot] = CreateDataTimer(yell_interval, Rescue_Playsound_Timer, data_sound, TIMER_REPEAT);
		
		WritePackCell(data_sound, survivorid);
		WritePackCell(data_sound, EntIndexToEntRef(entity));
	}
	
	if (GetEngineVersion() == Engine_Left4Dead)
	{
		int pills = FindDistEntityByClassname(entity, "weapon_pain_pills_spawn", 100.0);
		if (!pills)
		{
			float pos_entity[3];
			GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos_entity);
			
			pills = CreateEntityByName("weapon_pain_pills_spawn");
			if (IsValidEntity(pills))
			{
				SetEntPropEnt(pills, Prop_Data, "m_hOwnerEntity", room);
				
				DispatchKeyValue(pills, "targetname", targetname);
				DispatchKeyValue(pills, "spawnflags", "3");
				DispatchKeyValue(pills, "count", "1");
				
				DispatchKeyValue(pills, "rendermode", "10");
				DispatchKeyValue(pills, "renderamt", "0");
				DispatchKeyValue(pills, "renderfx", "0");
				DispatchKeyValue(pills, "rendercolor", "0 0 0");
				DispatchKeyValue(pills, "disableshadows", "1");
				
				enteffects = GetEntProp(pills, Prop_Send, "m_fEffects");
				enteffects |= 32;
				SetEntProp(pills, Prop_Send, "m_fEffects", enteffects);
				
				TeleportEntity(pills, pos_entity);
				
				DispatchSpawn(pills);
				ActivateEntity(pills);
			}
		}
		else
		{
			DispatchKeyValue(pills, "targetname", targetname);
			SetEntPropEnt(pills, Prop_Data, "m_hOwnerEntity", room);
		}
	}
	
	return Plugin_Continue;
}

bool NeedCloseRoomDoors(int room)
{
	if (!IsValidEntity(room))
	{
		return false;
	}
	
	char name[MAX_STRING_LENGTH];
	
	bool need_close;
	
	int door = -1;
	while ((door = FindEntityByClassname(door, "prop_door_rotating")) != -1)
	{
		if (room == GetEntPropEnt(door, Prop_Data, "m_hOwnerEntity"))
		{
			GetEntPropString(door, Prop_Data, "m_iName", name, sizeof(name));
			if (strlen(name))
			{
				InputTarget(name, "Close");
			}
			else
			{
				InputEntity(door, "Close");
			}
			
			GetEntPropString(door, Prop_Data, "m_SlaveName", name, sizeof(name));
			if (strlen(name))
			{
				InputTarget(name, "Close");
			}
			
			// 0 - закрыта, 1 - открывается, 2 - открыта, 3 - закрывается
			if (GetEntProp(door, Prop_Send, "m_eDoorState"))
			{
				need_close = true;
			}
		}
	}
	
	return need_close;
}

Action:Rescue_Playsound_Timer(Handle timer, Handle h_data)
{
	if (!IsValidHandle(h_data))
	{
		return Plugin_Stop;
	}
	
	DataPack data_sound = view_as<DataPack>(h_data);
	
	ResetPack(data_sound);
	
	int survivorid = ReadPackCell(data_sound);
			
	int client = GetClientOfSurvivorId(survivorid);
	if (!client)
	{
		return Plugin_Stop;
	}
	
	int entity = EntRefToEntIndex(ReadPackCell(data_sound));
	if (!IsValidEntity(entity))
	{
		return Plugin_Stop;
	}
	
	float pos_entity[3];
	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", pos_entity);
	
	if (!IsValidClient(client) || IsAllSurvivorFar(entity))
	{
		char name[MAX_STRING_LENGTH];
		GetEntPropString(entity, Prop_Data, "m_iName", name, sizeof(name));
			
		InputTarget(name, "Kill");
		
		if (gi_rescue_mode != 0)
		{
			Rescue_Restore(pos_entity);
		}
		
		return Plugin_Stop;
	}
	
	if (IsPlayerAlive(client))
	{
		char name[MAX_STRING_LENGTH];
		GetEntPropString(entity, Prop_Data, "m_iName", name, sizeof(name));
			
		InputTarget(name, "Kill");
			
		if (gi_rescue_mode != 0)
		{
			Rescue_Restore(pos_entity);
		}
		
		return Plugin_Stop;
	}
	
	int room = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");
	
	float pos_spawn[3]; float ang_spawn[3];
	
	int new_room = GetVectorsRescue(room, pos_spawn, ang_spawn);
	if (new_room)
	{
		char name[MAX_STRING_LENGTH];
		GetEntPropString(entity, Prop_Data, "m_iName", name, sizeof(name));
			
		InputTarget(name, "Kill");
		
		if (gi_rescue_mode != 0)
		{
			Rescue_Restore(pos_entity);
			Rescue_Restore(pos_spawn);
		}
		
		NeedCloseRoomDoors(new_room);
		
		return Plugin_Stop;
	}
	
	float rescue_door_opening_distance = GetConVarFloat(gc_rescue_door_opening_distance);
	if (rescue_door_opening_distance)
	{
		if (rescue_door_opening_distance < 200.0)
		{
			rescue_door_opening_distance = 200.0;
		}
		
		int rescuer = IsAnySurvivorNear_Watch(room, rescue_door_opening_distance);
		if (OpenRoom(room, rescuer))
		{
			return Plugin_Stop;
		}
	}
	
	Rescue_Playsound(client, entity);
		
	return Plugin_Continue;
}

void Rescue_Playsound(int client, int entity)
{
	if (!IsValidClient(client))
	{
		return;
	}
	
	if (!IsValidEntity(entity))
	{
		return;
	}
	
	LureNearBot(entity);
	
	char temp[PLATFORM_MAX_PATH];
	GetClientModel(client, temp, sizeof(temp));
	
	if (StrContains(temp, "survivor_teenangst") > -1)
	{
		int vocalize_track = GetRandomSelect(gs_random_TeenGirl, sizeof(gs_random_TeenGirl));
		FormatEx(temp, sizeof(temp), "player/survivor/voice/TeenGirl/%s.wav", gs_sound_TeenGirl[vocalize_track]);
	}
	else if (StrContains(temp, "survivor_biker") > -1)
	{
		int vocalize_track = GetRandomSelect(gs_random_Biker, sizeof(gs_random_Biker));
		FormatEx(temp, sizeof(temp), "player/survivor/voice/Biker/%s.wav", gs_sound_Biker[vocalize_track]);
	}
	else if (StrContains(temp, "survivor_manager") > -1)
	{
		int vocalize_track = GetRandomSelect(gs_random_Manager, sizeof(gs_random_Manager));
		FormatEx(temp, sizeof(temp), "player/survivor/voice/Manager/%s.wav", gs_sound_Manager[vocalize_track]);
	}
	else if (StrContains(temp, "survivor_namvet") > -1)
	{
		int vocalize_track = GetRandomSelect(gs_random_NamVet, sizeof(gs_random_NamVet));
		FormatEx(temp, sizeof(temp), "player/survivor/voice/NamVet/%s.wav", gs_sound_NamVet[vocalize_track]);
	}
	else if (StrContains(temp, "survivor_gambler") > -1)
	{
		int vocalize_track = GetRandomSelect(gs_random_Gambler, sizeof(gs_random_Gambler));
		FormatEx(temp, sizeof(temp), "player/survivor/voice/gambler/%s.wav", gs_random_Gambler[vocalize_track]);
	}
	else if (StrContains(temp, "survivor_producer") > -1)
	{
		int vocalize_track = GetRandomSelect(gs_random_Producer, sizeof(gs_random_Producer));
		FormatEx(temp, sizeof(temp), "player/survivor/voice/producer/%s.wav", gs_sound_Producer[vocalize_track]);
	}
	else if (StrContains(temp, "survivor_coach") > -1)
	{
		int vocalize_track = GetRandomSelect(gs_random_Coach, sizeof(gs_random_Coach));
		FormatEx(temp, sizeof(temp), "player/survivor/voice/coach/%s.wav", gs_sound_Coach[vocalize_track]);
	}
	else if (StrContains(temp, "survivor_mechanic") > -1)
	{
		int vocalize_track = GetRandomSelect(gs_random_Mechanic, sizeof(gs_random_Mechanic));
		FormatEx(temp, sizeof(temp), "player/survivor/voice/mechanic/%s.wav", gs_sound_Mechanic[vocalize_track]);
	}
	else
	{
		return;
	}
	
	float pos_spawn[3];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", pos_spawn);
	
	pos_spawn[2] += VISIBLE_HEIGH + 5.0;
	
	EmitAmbientSound(temp, pos_spawn, entity);
}

int GetActiveRescue(int survivorid)
{
	char classname[MAX_STRING_LENGTH];
	
	if (GetEngineVersion() == Engine_Left4Dead)
	{
		FormatEx(classname, sizeof(classname), "prop_glowing_object");
	}
	else
	{
		FormatEx(classname, sizeof(classname), "prop_dynamic");
	}
	
	char targetname[MAX_TARGET_LENGTH];
	FormatEx(targetname, sizeof(targetname), "%s_%d", GLOW_NAME, survivorid);
	
	char glow_name[MAX_STRING_LENGTH];
	
	int i = -1;
	while ((i = FindEntityByClassname(i, classname)) != -1)
	{
		GetEntPropString(i, Prop_Data, "m_iName", glow_name, sizeof(glow_name));
		if (!strcmp(glow_name, targetname))
		{
			return i;
		}
	}
	
	return 0;
}

int GetActiveRescueRoom(int survivorid, int room)
{
	if (!IsValidEntity(room))
	{
		return 0;
	}
	
	char classname[MAX_STRING_LENGTH];
	
	if (GetEngineVersion() == Engine_Left4Dead)
	{
		FormatEx(classname, sizeof(classname), "prop_glowing_object");
	}
	else
	{
		FormatEx(classname, sizeof(classname), "prop_dynamic");
	}
	
	char targetname[MAX_TARGET_LENGTH];
	FormatEx(targetname, sizeof(targetname), "%s_%d", GLOW_NAME, survivorid);
	
	char glow_name[MAX_STRING_LENGTH];
	
	int i = -1;
	while ((i = FindEntityByClassname(i, classname)) != -1)
	{
		GetEntPropString(i, Prop_Data, "m_iName", glow_name, sizeof(glow_name));
		if (!strcmp(glow_name, targetname))
		{
			if (room == GetEntPropEnt(i, Prop_Data, "m_hOwnerEntity"))
			{
				return i;
			}
		}
	}
	
	return 0;
}

int GetActiveRescueCount(int room)
{
	if (!IsValidEntity(room))
	{
		return 0;
	}
	
	char classname[MAX_STRING_LENGTH];
	
	if (GetEngineVersion() == Engine_Left4Dead)
	{
		FormatEx(classname, sizeof(classname), "prop_glowing_object");
	}
	else
	{
		FormatEx(classname, sizeof(classname), "prop_dynamic");
	}
	
	char glow_name[MAX_STRING_LENGTH];
	
	int count;
	
	int i = -1;
	while ((i = FindEntityByClassname(i, classname)) != -1)
	{
		GetEntPropString(i, Prop_Data, "m_iName", glow_name, sizeof(glow_name));
		if (StrContains(glow_name, GLOW_NAME) > -1)
		{
			if (room == GetEntPropEnt(i, Prop_Data, "m_hOwnerEntity"))
			{
				count ++;
			}
		}
	}
	
	return count;
}

int GetFreeTimerSlot()
{
	for (int i = 1; i <= MAX_TIMERS; i++)
	{
		if (!IsValidHandle(gt_Timer[i]))
		{
			return i;
		}
	}
	
	return 0;
}

void Delete_Timers()
{
	if (IsValidHandle(gk_rooms))
	{
		delete gk_rooms;
	}
	
	for (int i = 1; i <= MAX_TIMERS; i++)
	{
		if (IsValidHandle(gt_Timer[i]))
		{
			CloseHandle(gt_Timer[i]);
		}
	}
	
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		if (IsValidHandle(gt_CheckNearRescue[i]))
		{
			delete gt_CheckNearRescue[i];
		}
		
		if (IsValidHandle(gt_CreateRescue[i]))
		{
			delete gt_CreateRescue[i];
		}
	}
	
	gb_finale_start = false;
		
	char classname[MAX_STRING_LENGTH];
	
	if (GetEngineVersion() == Engine_Left4Dead)
	{
		FormatEx(classname, sizeof(classname), "prop_glowing_object");
	}
	else
	{
		FormatEx(classname, sizeof(classname), "prop_dynamic");
	}
	
	char name[MAX_STRING_LENGTH];
	
	int i = -1;
	while ((i = FindEntityByClassname(i, classname)) != -1)
	{
		GetEntPropString(i, Prop_Data, "m_iName", name, sizeof(name));
		if (StrContains(name, GLOW_NAME) > -1)
		{
			InputTarget(name, "Kill");
		}
	}
}

void RemoveGlowRescue(int client, float time = 0.0)
{
	if (!IsValidClient(client)) {return;}
	
	int survivorid = GetClientSurvivorId(client);
	if (!survivorid)
	{
		LogError("RemoveGlowRescue: survivorid is NULL");
		return;
	}
	
	char classname[MAX_STRING_LENGTH];
	
	if (GetEngineVersion() == Engine_Left4Dead)
	{
		FormatEx(classname, sizeof(classname), "prop_glowing_object");
	}
	else
	{
		FormatEx(classname, sizeof(classname), "prop_dynamic");
	}
	
	char temp[MAX_STRING_LENGTH];
	FormatEx(temp, sizeof(temp), "%s_%d", GLOW_NAME, survivorid);
	
	char name[MAX_STRING_LENGTH];
	
	float pos_spawn[3];
	
	int i = -1;
	while ((i = FindEntityByClassname(i, classname)) != -1)
	{
		GetEntPropString(i, Prop_Data, "m_iName", name, sizeof(name));
		if (!strcmp(name, temp))
		{
			if (gi_rescue_mode == 2)
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", pos_spawn);
				Rescue_Restore(pos_spawn);
			}
			else
			{
				CreateTimer(0.5, Room_Disable, GetEntPropEnt(i, Prop_Data, "m_hOwnerEntity"), TIMER_FLAG_NO_MAPCHANGE);
			}
			
			InputTarget(name, "Kill", _, time);
		}
	}
}

int GetClientActiveProp(int client)
{
	if (!IsValidClient(client)) {return 0;}
	
	int survivorid = GetClientSurvivorId(client);
	if (!survivorid)
	{
		LogError("GetClientActiveProp: survivorid is NULL");
		return 0;
	}
	
	char classname[MAX_STRING_LENGTH];
	
	if (GetEngineVersion() == Engine_Left4Dead)
	{
		FormatEx(classname, sizeof(classname), "prop_glowing_object");
	}
	else
	{
		FormatEx(classname, sizeof(classname), "prop_dynamic");
	}
	
	char targetname[MAX_TARGET_LENGTH];
	FormatEx(targetname, sizeof(targetname), "%s_%d", GLOW_NAME, survivorid);
	
	char name[MAX_STRING_LENGTH];
	
	int i = -1;
	while ((i = FindEntityByClassname(i, classname)) != -1)
	{
		GetEntPropString(i, Prop_Data, "m_iName", name, sizeof(name));
		if (!strcmp(name, targetname))
		{
			return i;
		}
	}
	
	return 0;
}

void Event_entity_visible(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (gb_finale_start)
	{
		return;
	}
	
	char targetname[MAX_NAME_LENGTH];
	GetEventString(event, "entityname", targetname, sizeof(targetname));
		
	if (StrContains(targetname, GLOW_NAME) > -1)
	{
		int survivor 		= GetClientOfUserId(GetEventInt(event, "userid"));
		int visible_prop 	= GetEventInt(event, "subject");
		
		int client = GetClientOfNameEntity(visible_prop);
		if (IsValidClient(client))
		{
			int entity = GetClientActiveProp(client);
			if (entity)
			{
				float pos_spawn[3];
				GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos_spawn);
					
				float ang_spawn[3];
				GetEntPropVector(entity, Prop_Data, "m_angRotation", ang_spawn);
				
				Respawn(client, survivor, pos_spawn, ang_spawn);
			}
		}
		else
		{
			InputTarget(targetname, "Kill");
		}
	}
}

int GetClientOfNameEntity(int entity)
{
	if (!IsValidEntity(entity))
	{
		return 0;
	}
	
	char name[MAX_STRING_LENGTH];
	GetEntPropString(entity, Prop_Data, "m_iName", name, sizeof(name));
	
	int match = StrContains(name, GLOW_NAME);
		
	if (match > -1)
	{
		int len = strlen(GLOW_NAME) + 1;
		strcopy(name, sizeof(name), name[len]);
		
		int survivorid = StringToInt(name);
		
		if (survivorid)
		{
			return GetClientOfSurvivorId(survivorid);
		}
	}
	
	return 0;
}

bool OpenRoom(int room, int rescuer)
{
	if (!IsValidEntity(room))
	{
		return false;
	}
	
	if (!IsValidClientTeam2Alive(rescuer))
	{
		return false;
	}
	
	if (!gi_rescue_mode)
	{
		return false;
	}
	
	if (!GetConVarInt(gc_rescue_door_opening_distance))
	{
		return false;
	}
	
	int active_rescues;
	
	for (int i = 1; i <= MAX_SURVIVORID; i++)
	{
		if (GetActiveRescue(i))
		{
			active_rescues ++;
		}
	}
	
	if (!active_rescues)
	{
		return false;
	}
	
	if (active_rescues < GetDeathSurvivors())
	{
		int active_rescue_room;
	
		for (int i = 1; i <= MAX_SURVIVORID; i++)
		{
			if (GetActiveRescueRoom(i, room))
			{
				active_rescue_room ++;
			}
		}
		
		int rescue_room = GetCountRescueRoom(room);
		if (active_rescue_room < rescue_room)
		{
			return false;
		}
	}
	
	int door = -1;
	while ((door = FindEntityByClassname(door, "prop_door_rotating")) != -1)
	{
		if (room == GetEntPropEnt(door, Prop_Data, "m_hOwnerEntity"))
		{
			SetVariantString("!activator");
			AcceptEntityInput(door, "Open", rescuer);
		}
	}
	
	return true;
}

int GetCountRescueRoom(int room)
{
	if (!IsValidHandle(gk_rooms))
	{
		return 0;
	}
	
	if (!IsValidEntity(room))
	{
		return 0;
	}
	
	char temp[MAX_STRING_LENGTH];
	FormatEx(temp, sizeof(temp), "%d", room);
	
	KvRewind(gk_rooms);
	
	if (!KvJumpToKey(gk_rooms, temp, false))
	{
		return 0;
	}
	
	int rescue = 1;
	FormatEx(temp, sizeof(temp), "%d", rescue);
	
	while (KvJumpToKey(gk_rooms, temp, false))
	{
		rescue ++;
		FormatEx(temp, sizeof(temp), "%d", rescue);
		
		KvGoBack(gk_rooms);
	}
	
	KvRewind(gk_rooms);
	
	rescue --;
	return rescue;
}

int GetDeathSurvivors()
{
	int death_survivors;
	
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		if (IsClientInGame(i))
		{
			if (GetClientTeam(i) == 2 && !IsPlayerAlive(i))
			{
				death_survivors ++;
			}
		}
	}
	
	return death_survivors;
}

void Event_player_use(Handle:event, const String:name[], bool:dontBroadcast)
{
	int rescuer = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsValidClientTeam2Alive(rescuer)) {return;}
	
	int entity = GetEventInt(event, "targetid");
	if (!IsValidEntity(entity)) {return;}
	
	char classname[MAX_CLASSNAME_LENGTH];
	GetEntityClassname(entity, classname, sizeof(classname));
	/*
	if (!strcmp(classname, "prop_door_rotating"))
	{
		int room = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");
		if (IsValidEntity(room))
		{
			OnOpen_Room(room, rescuer);
		}
	}
	else*/
	if (!strcmp(classname, "weapon_pain_pills_spawn")) 
	{
		int room = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");
		if (IsValidEntity(room))
		{
			OnOpen_Room(room, rescuer);
			CreateTimer(0.5, PillsSlotRemove,  GetClientUserId(rescuer), TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

void OnOpen_Door(char [] output, int door, int rescuer, float delay)
{
	int room = GetEntPropEnt(door, Prop_Data, "m_hOwnerEntity"); 
	if (!IsValidEntity(room))
	{
		return;
	}
	
	if (!IsValidClientTeam2Alive(rescuer))
	{
		float pos_door[3];
		GetEntPropVector(door, Prop_Data, "m_vecOrigin", pos_door);
			
		float ang_door[3];
		GetEntPropVector(door, Prop_Data, "m_angRotation", ang_door);
			
		ang_door[0] = 0.0;
		ang_door[1] += 90.0;
		ang_door[2] = 0.0;
			
		float vMaxs[3], vMins[3];
				
		GetEntPropVector(door, Prop_Send, "m_vecMaxs", vMaxs);
		GetEntPropVector(door, Prop_Send, "m_vecMins", vMins);
			
		float distance = (vMins[1] * (-1) + vMaxs[1]) * 0.92;
			
		MovePos_Forward(pos_door, ang_door, distance);
		
		pos_door[2] += vMins[2];
		pos_door[2] += (vMins[2] * (-1) + vMaxs[2]) * 0.36;
		
		rescuer = FindNearRescuer(pos_door);
	}
	
	OnOpen_Room(room, rescuer);
}

Action:PillsSlotRemove(Handle timer, int userid)
{
	int rescuer = GetClientOfUserId(userid);
	if (!IsValidClientTeam2Alive(rescuer))
	{
		return;
	}
	
	int pills = GetPlayerWeaponSlot(rescuer, 4);
	if (IsValidEntity(pills))
	{
		char targetname[MAX_STRING_LENGTH];
		GetEntPropString(pills, Prop_Data, "m_iName", targetname, sizeof(targetname));
		
		RemovePlayerItem(rescuer, pills);
		InputKill(pills);
	}
}

void OnOpen_Room(int room, int rescuer)
{
	if (!IsValidEntity(room))
	{
		return;
	}
	
	char classname[MAX_STRING_LENGTH];
	GetEntityClassname(room, classname, sizeof(classname));
	
	if (strcmp(classname, "info_target"))
	{
		return;
	}
	/*
	if (!IsValidClient(rescuer)) 
	{
		return;
	}
	*/
	if (GetEngineVersion() == Engine_Left4Dead)
	{
		FormatEx(classname, sizeof(classname), "prop_glowing_object");
	}
	else
	{
		FormatEx(classname, sizeof(classname), "prop_dynamic");
	}
	
	char name[MAX_STRING_LENGTH];
	
	float pos_spawn[3]; float ang_spawn[3];
	
	int i = -1;
	while ((i = FindEntityByClassname(i, classname)) != -1)
	{
		GetEntPropString(i, Prop_Data, "m_iName", name, sizeof(name));
		if (!StrContains(name, GLOW_NAME))
		{
			if (room == GetEntPropEnt(i, Prop_Data, "m_hOwnerEntity"))
			{
				GetEntPropVector(i, Prop_Data, "m_vecOrigin", pos_spawn);
				GetEntPropVector(i, Prop_Data, "m_angRotation", ang_spawn);
				
				if (GetEngineVersion() == Engine_Left4Dead2)
				{
					FreeBotOrder(rescuer);
				}
				
				Respawn(GetClientOfNameEntity(i), rescuer, pos_spawn, ang_spawn);
			}
		}
	}
}

void Respawn(int client, int rescuer, float pos_spawn[3], float ang_spawn[3])
{
	if (!IsValidClient(client))
	{
		return;
	}
	
	if (IsPlayerAlive(client))
	{
		return;
	}
	
	int survivorid = GetClientSurvivorId(client);
	if (!survivorid)
	{
		LogError("Respawn: survivorid is NULL");
		return;
	}
	
	ang_spawn[0] = 0.0;
	ang_spawn[2] = 0.0;
	
	if (!IsValidClientTeam2Alive(rescuer)) 
	{
		rescuer = client;
	}
	
	int entity = CreateEntityByName("info_survivor_rescue");
	if (entity == -1)
	{
		return;
	}
	
	char targetname[MAX_TARGET_LENGTH];
	FormatEx(targetname, sizeof(targetname), "%s_%d", GLOW_NAME, survivorid);
	
	DispatchKeyValue(entity, "targetname", targetname);
	
	SetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity", client);
	
	char client_model[PLATFORM_MAX_PATH];
	GetClientModel(client, client_model, sizeof(client_model));
	
	DispatchKeyValue(entity, "model", client_model);
	
	pos_spawn[2] += 80.0;
	DispatchKeyValueVector(entity, "rescueEyePos", pos_spawn);
	pos_spawn[2] -= 80.0;
	
	DispatchKeyValueVector(entity, "origin", pos_spawn);
	DispatchKeyValueVector(entity, "angles", ang_spawn);
	
	DispatchSpawn(entity);
	ActivateEntity(entity);
	
	if (IsValidClientTeam2Alive(rescuer)) 
	{
		// обязательно обе строки рядом!
		SetEntPropEnt(entity, Prop_Send, "m_survivor", client);
		AcceptEntityInput(entity, "Rescue", rescuer);
	}
	else
	{
		// обязательно обе строки рядом!
		SetEntPropEnt(entity, Prop_Send, "m_survivor", client);
		AcceptEntityInput(entity, "Rescue");
	}
	
	if (IsValidHandle(gt_CheckNearRescue[survivorid]))
	{
		delete gt_CheckNearRescue[survivorid];
	}
}

bool Search_Recue_Rooms(int rescue)
{	
	if (!IsValidEntity(rescue))
	{
		return false;
	}
	
	float pos_rescue[3];
	GetEntPropVector(rescue, Prop_Data, "m_vecOrigin", pos_rescue);
	
	pos_rescue[2] += 70.0;
	
	float vec_buffer[3];
	vec_buffer = pos_rescue;
	
	if (IsSkyCheck(vec_buffer))
	{
		return false;
	}
	
	bool scan = ScanDoorAround(rescue, pos_rescue);
	
	#define STEP_SEARCH 70.0
	#define FLOOR_HEIGH 100.0
	
	float heigh = FLOOR_HEIGH;
		
	float buffer_pos[3];
	TR_TraceRayFilter(pos_rescue, view_as<float>({-90.0, 0.0, 0.0}), MASK_SOLID, RayType_Infinite, TraceFilter_TraceYaw);
	if (TR_DidHit(INVALID_HANDLE))
	{
		TR_GetEndPosition(buffer_pos, INVALID_HANDLE);
		heigh = GetVectorDistance(buffer_pos, pos_rescue);
	}
	
	int i_amount = 1;
	
	if (heigh > FLOOR_HEIGH)
	{
		if (heigh / FLOOR_HEIGH > 1.00)
		{
			i_amount = RoundFloat(heigh / FLOOR_HEIGH);
		}
	}
		
	float ang_scan[3]; 
	ang_scan[1] = -90.0;
	
	float long; float distance; 
	
	for (int i = 1; i <= i_amount; i++)
	{
		ang_scan[1] = -90.0;
		while (ang_scan[1] <= 180.0)
		{
			vec_buffer = pos_rescue;
			distance = TraceYawDistance(vec_buffer, ang_scan);
			
			if (distance > STEP_SEARCH)
			{
				distance -= STEP_SEARCH * 0.5;
				long = STEP_SEARCH * 0.5;
				
				while (distance > long)
				{
					vec_buffer = pos_rescue;
				
					MovePos_Forward(vec_buffer, ang_scan, long);
					if (ScanDoorAround(rescue, vec_buffer))
					{
						scan = true;
					}
					
					long += STEP_SEARCH * 0.5;
				}
			}
					
			ang_scan[1] += 45.0; // 45 - шаг углов
		}
		
		pos_rescue[2] += FLOOR_HEIGH;
	}
	
	return scan;
}

// ang_min - начинаем с угла
// ang_max - заканчиваем углом
bool ScanDoorAround(int rescue, float pos_rescue[3])
{
	float ang_min = -180.0;
	float ang_max = 180.0;
	
	float ang_start[3];
	ang_start[1] = ang_min;
	
	char classname[MAX_CLASSNAME_LENGTH];
	
	int door;
	
	bool search;
	
	while (ang_start[1] < ang_max)
	{
		door = TraceYawEntity(pos_rescue, ang_start);
			
		if (door)
		{
			GetEntityClassname(door, classname, sizeof(classname));
			
			if (!strcmp(classname, "prop_door_rotating") || !strcmp(classname, "func_door"))
			{
				search = true;
				
				if (SetRoomData(rescue, door))
				{
					//search = true;
				}
			}
		}
		
		ang_start[1] += 5.0; // 2.5 шаг углов
	}
	
	return search;
}

bool SetRoomData(int rescue, int door)
{
	if (!IsValidEntity(rescue))
	{
		return false;
	}
	
	int owner_rescue = GetEntPropEnt(rescue, Prop_Data, "m_hOwnerEntity");
	int owner_door = -1;
	
	if (IsValidEntity(door))
	{
		owner_door = GetEntPropEnt(door, Prop_Data, "m_hOwnerEntity");
	}
	
	int room;
	
	if (IsValidEntity(owner_rescue))
	{
		char classname[MAX_CLASSNAME_LENGTH];
		GetEntityClassname(owner_rescue, classname, sizeof(classname));
	
		if (!strcmp(classname, "info_target"))
		{
			room = owner_rescue;
		}
	}
	else if (IsValidEntity(owner_door))
	{
		char classname[MAX_CLASSNAME_LENGTH];
		GetEntityClassname(owner_door, classname, sizeof(classname));
	
		if (!strcmp(classname, "info_target"))
		{
			room = owner_door;
		}
	}
	
	if (room)
	{
		if (IsValidEntity(door))
		{
			SetEntPropEnt(door, Prop_Data, "m_hOwnerEntity", room);
		}
		
		SetEntPropEnt(rescue, Prop_Data, "m_hOwnerEntity", room);
				
		return true;
	}
	
	if (SpawnRoomEntity(rescue, door))
	{
		return true;
	}
	
	return false;
}

int SpawnRoomEntity(int rescue, int door)
{
	if (!IsValidEntity(rescue))
	{
		return 0;
	}
	
	int room = CreateEntityByName("info_target");
	if (room == -1)
	{
		return 0;
	}
		
	DispatchKeyValue(room, "targetname", ROOM_NAME);
	DispatchKeyValue(room, "spawnflags", "0");
	
	float pos_spawn[3];
	GetEntPropVector(rescue, Prop_Data, "m_vecOrigin", pos_spawn);
	
	pos_spawn[2] += 50.0;
	DispatchKeyValueVector(room, "origin", pos_spawn);
	DispatchKeyValueInt(room, "max_health", MAX_PLAYERS);
	
	DispatchSpawn(room);
	
	SetEntPropEnt(rescue, Prop_Data, "m_hOwnerEntity", room);
	
	if (IsValidEntity(door))
	{
		char classname[MAX_CLASSNAME_LENGTH];
		GetEntityClassname(door, classname, sizeof(classname));
		
		if (!strcmp(classname, "prop_door_rotating") || !strcmp(classname, "func_door"))
		{
			SetEntPropEnt(door, Prop_Data, "m_hOwnerEntity", room);
		}
	}
	
	return room;
}

int TraceYawEntity(float map_pos[3], float buffer_ang[3])
{			
	float pos_start[3];
	pos_start = map_pos;
	
	float pos_end[3];
	pos_end = pos_start;
	
	MovePos_Forward(pos_end, buffer_ang, ROOM_SCAN_MAX_DISTANCE);
	
	Handle trace = TR_TraceHullFilterEx(pos_start, pos_end, view_as<float>({-2.5, -2.5, -2.5}), view_as<float>({2.5, 2.5, 2.5}), MASK_SOLID, TraceFilter_TraceYaw);
	if (TR_DidHit(trace))
	{
		int entity = TR_GetEntityIndex(trace);
		if (entity && IsValidEntity(entity))
		{
			CloseHandle(trace);
			return entity;
		}
	}
	
	CloseHandle(trace);
	return 0;
}

bool TraceFilter_TraceYaw(int entity, int contentsMask)
{
	char classname[MAX_CLASSNAME_LENGTH];
	GetEntityClassname(entity, classname, sizeof(classname));
	
	if (!strcmp(classname, "func_playerinfected_clip"))
	{
		return false;
	}
	
	return true;
}

float TraceYawDistance(float map_pos[3], float buffer_ang[3])
{
	float pos_start[3];
	pos_start = map_pos;
	
	buffer_ang[0] = 0.0;
	buffer_ang[2] = 0.0;
	
	float pos_end[3];
	pos_end = pos_start;
	
	MovePos_Forward(pos_end, buffer_ang, ROOM_SCAN_MAX_DISTANCE);
	
	Handle trace = TR_TraceHullFilterEx(pos_start, pos_end, view_as<float>({-2.5, -2.5, -2.5}), view_as<float>({2.5, 2.5, 2.5}), MASK_SOLID, TraceFilter_TraceYaw);
	if (TR_DidHit(trace))
	{
		TR_GetEndPosition(pos_end, trace);
		
		float distance = GetVectorDistance(pos_start, pos_end);
		
		CloseHandle(trace);
		return distance;
	}
	
	CloseHandle(trace);
	return 0.0;
}


// проверяет небо, если есть то вернет true
bool IsSkyCheck(float origin[3], float step = 5.0)
{
	float vec_origin[3];
	vec_origin = origin;
	
	if (!IsSkyAbove(vec_origin)) // 5
	{
		vec_origin[0] += step; // 6
		
		if (!IsSkyAbove(vec_origin))
		{
			vec_origin[1] += step; // 3
			
			if (!IsSkyAbove(vec_origin))
			{
				vec_origin[0] -= step; // 2
								
				if (!IsSkyAbove(vec_origin))
				{
					vec_origin[0] -= step; // 1
					
					if (!IsSkyAbove(vec_origin))
					{
						vec_origin[1] -= step; // 4
					
						if (!IsSkyAbove(vec_origin))
						{
							vec_origin[1] -= step; // 7		
							
							if (!IsSkyAbove(vec_origin))
							{
								vec_origin[0] += step; // 8
								
								if (!IsSkyAbove(vec_origin))
								{
									vec_origin[0] += step; // 9
									
									if (!IsSkyAbove(vec_origin))
									{
										return false;
									}
								}
							}
						}
					}
				}
			}
		}
	}
			
	return true;
}

stock bool IsSkyAbove(float origin[3])
{
	float vec_mins[3];
	vec_mins[0] = -5.0;
	vec_mins[1] = vec_mins[0];
	vec_mins[2] = 0.0;
	
	float vec_maxs[3];
	vec_maxs[0] = 5.0;
	vec_maxs[1] = vec_maxs[0];
	vec_maxs[2] = 10.0;
	
	float pos_start[3];
	pos_start = origin;
	
	float pos_end[3];
	pos_end = pos_start;
	
	float ang_sky[3];
	ang_sky[0] = -90.0;
	MovePos_Forward(pos_end, ang_sky, 10000.0);
	
	Handle trace = TR_TraceHullFilterEx(pos_start, pos_end, vec_mins, vec_maxs, MASK_SOLID, TraceFilter_SkyCheck);
	
	char surface[64];
	
	if (TR_DidHit(trace))
	{
		TR_GetSurfaceName(trace, surface, sizeof(surface));
	}
	
	CloseHandle(trace);
	
	if (!strcmp(surface, "TOOLS/TOOLSSKYBOX"))
	{
		return true;
	}
	
	return false;
}

stock bool TraceFilter_SkyCheck(entity, contentsMask, any:client)
{
	if (entity > 0 && entity <= MAX_PLAYERS)
	{
		return false;
	}
	
	char classname[MAX_CLASSNAME_LENGTH];
	GetEntityClassname(entity, classname, sizeof(classname));
	
	if (!strcmp(classname, "infected") || !strcmp(classname, "witch"))
	{
		return false;
	}
	
	if (!strcmp(classname, "func_playerinfected_clip"))
	{
		return false;
	}
	
	return true;
}

void RoomData_Create(int room)
{
	if (!IsValidHandle(gk_rooms))
	{
		return;
	}
	
	if (!IsValidEntity(room))
	{
		return;
	}
	
	char temp[MAX_STRING_LENGTH];
	FormatEx(temp, sizeof(temp), "%d", room);
	
	KvRewind(gk_rooms);
	
	if (!KvJumpToKey(gk_rooms, temp, true))
	{
		return;
	}
	
	int amount = 0;
	
	float vec_temp[3];
	
	int rescue = -1;
	while ((rescue = FindEntityByClassname(rescue, "info_survivor_rescue")) != -1)
	{
		if (room == GetEntPropEnt(rescue, Prop_Data, "m_hOwnerEntity"))
		{
			amount ++;
			if (amount <= MAX_ROOM_RESCUES)
			{
				FormatEx(temp, sizeof(temp), "%d", amount);
				
				if (KvJumpToKey(gk_rooms, temp, true))
				{
					GetEntPropVector(rescue, Prop_Data, "m_vecOrigin", vec_temp);
					
					FormatEx(temp, sizeof(temp), "%d %d %d", RoundFloat(vec_temp[0]), RoundFloat(vec_temp[1]), RoundFloat(vec_temp[2]));
					KvSetString(gk_rooms, "origin", temp);
					
					GetEntPropVector(rescue, Prop_Data, "m_angRotation", vec_temp);
					
					FormatEx(temp, sizeof(temp), "%d %d %d", RoundFloat(vec_temp[0]), RoundFloat(vec_temp[1]), RoundFloat(vec_temp[2]));
					KvSetString(gk_rooms, "angles", temp);
					
					KvSetNum(gk_rooms, "active", 0);
					
					KvGoBack(gk_rooms);
				}
			}
		}
	}
	
	SetEntProp(room, Prop_Data, "m_iHealth", amount);
	KvSetNum(gk_rooms, "rescue_count", amount);
	
	KvRewind(gk_rooms);
}

int GetVectorsRescue(int old_room, float pos_spawn[3], float ang_spawn[3])
{
	float distance = GetConVarFloat(FindConVar("rescue_range"));
	
	int room = GetNearRoom(distance);
	if (!room)
	{
		return 0;
	}
	
	if (room == old_room)
	{
		return 0;
	}
		
	int rescue_count = GetEntProp(room, Prop_Data, "m_iHealth");
	
	if (!rescue_count)
	{
		return 0;
	}
	
	int random;
	
	for (int i = 1; i <= rescue_count; i++)
	{
		random = GetRandomSelect(gs_chance_rescue_slot, sizeof(gs_chance_rescue_slot));
		random ++;
		
		if (random <= MAX_ROOM_RESCUES)
		{
			if (IsRescueFree(room, random, pos_spawn, ang_spawn))
			{
				return room;
			}
		}
	}
	
	return 0;
}

int GetNearRoom(float distance)
{
	int result;
	
	float pos_client[3];
		
	float pos_i[3]; 
	float distance_old; 
	float distance_client_i;
	
	int i;
	
	char name[MAX_CLASSNAME_LENGTH];
	
	int count_max, count_active;
		
	for (int client = 1; client <= MAX_PLAYERS; client ++)
	{
		if (IsValidClientTeam2Alive(client) && !IsSurvivorIncapacitated(client))
		{
			GetClientAbsOrigin(client, pos_client);
			
			i = -1;
			while ((i = FindEntityByClassname(i, "info_target")) != -1)
			{
				GetEntPropString(i, Prop_Data, "m_iName", name, sizeof(name));
				if (!strcmp(name, ROOM_NAME))
				{
					count_max = GetCountRescueRoom(i);
					count_active = GetActiveRescueCount(i);
					
					if (count_max > count_active)
					{
						GetEntPropVector(i, Prop_Data, "m_vecOrigin", pos_i);
							
						distance_client_i = GetVectorDistance(pos_client, pos_i);
								
						if (distance >= distance_client_i)
						{
							if (!IsVisible(client, i))
							{
								if (IsSameFloor(pos_client[2], pos_i[2]))
								{
									if (!distance_old || distance_client_i < distance_old)
									{
										distance_old = distance_client_i;
										result = i;
									}
								}
							}
						}
					}
				}
			}
		}
	}
	
	if (result)
	{
		return result;
	}
	
	distance_old = 0.0;
	
	for (int client = 1; client <= MAX_PLAYERS; client ++)
	{
		if (IsValidClientTeam2Alive(client) && !IsSurvivorIncapacitated(client))
		{
			GetClientEyePosition(client, pos_client);
			
			i = -1;
			while ((i = FindEntityByClassname(i, "info_target")) != -1)
			{
				GetEntPropString(i, Prop_Data, "m_iName", name, sizeof(name));
				if (!strcmp(name, ROOM_NAME))
				{
					if (GetEntProp(i, Prop_Data, "m_iHealth"))
					{
						GetEntPropVector(i, Prop_Data, "m_vecOrigin", pos_i);
						
						distance_client_i = GetVectorDistance(pos_client, pos_i);
						
						if (distance >= distance_client_i)
						{
							if (!IsVisible(client, i))
							{
								if (!distance_old || distance_client_i < distance_old)
								{
									distance_old = distance_client_i;
									result = i;
								}
							}
						}
					}
				}
			}
		}
	}
	
	return result;
}

bool IsRescueFree(int room, int rescue_slot, float origin[3], float angles[3])
{
	if (!IsValidHandle(gk_rooms))
	{
		return false;
	}
	
	if (!IsValidEntity(room))
	{
		return false;
	}
	
	char temp[MAX_STRING_LENGTH];
	FormatEx(temp, sizeof(temp), "%d", room);
	
	KvRewind(gk_rooms);
	
	if (!KvJumpToKey(gk_rooms, temp, false))
	{
		return false;
	}
	
	FormatEx(temp, sizeof(temp), "%d", rescue_slot);
	
	char value[MAX_STRING_LENGTH];
	int len;
	
	bool result;
	
	if (KvJumpToKey(gk_rooms, temp, false))
	{
		if (!KvGetNum(gk_rooms, "active"))
		{
			KvGetString(gk_rooms, "origin", value, sizeof(value), "none");
			if (strcmp(value, "none"))
			{
				SplitString(value, " ", temp, sizeof(temp));
				len = strlen(temp) + 1;
				origin[0] = StringToFloat(temp);
				
				strcopy(value, sizeof(value), value[len]);
				SplitString(value, " ", temp, sizeof(temp));
				len = strlen(temp) + 1;
				origin[1] = StringToFloat(temp);
							
				strcopy(value, sizeof(value), value[len]);
				origin[2] = StringToFloat(value);
				
				KvGetString(gk_rooms, "angles", value, sizeof(value), "none");
				if (strcmp(value, "none"))
				{
					SplitString(value, " ", temp, sizeof(temp));
					len = strlen(temp) + 1;
					angles[0] = StringToFloat(temp);
								
					strcopy(value, sizeof(value), value[len]);
					SplitString(value, " ", temp, sizeof(temp));
					len = strlen(temp) + 1;
					angles[1] = StringToFloat(temp);
								
					strcopy(value, sizeof(value), value[len]);
					angles[2] = StringToFloat(value);
				}
			}
			
			KvSetNum(gk_rooms, "active", 1);
			result = true;
		}
						
		KvGoBack(gk_rooms);
	}
	
	if (result)
	{
		int rescue_count = KvGetNum(gk_rooms, "rescue_count");
		
		rescue_count --;
		if (rescue_count < 0)
		{
			rescue_count = 0;
		}
		
		SetEntProp(room, Prop_Data, "m_iHealth", rescue_count);
		KvSetNum(gk_rooms, "rescue_count", rescue_count);
	}
	
	KvRewind(gk_rooms);
	
	return result;
}

bool Rescue_Restore(float origin[3])
{
	if (!IsValidHandle(gk_rooms))
	{
		return false;
	}
	
	char pos_spawn[MAX_CLASSNAME_LENGTH];
	FormatEx(pos_spawn, sizeof(pos_spawn), "%d %d %d", 	RoundFloat(origin[0]), 
														RoundFloat(origin[1]), 
														RoundFloat(origin[2]));
	
	KvRewind(gk_rooms);
	
	char name[MAX_CLASSNAME_LENGTH];
	char room[MAX_CLASSNAME_LENGTH];
	char temp[MAX_CLASSNAME_LENGTH];
	
	int rescue_slot;
	
	char value[MAX_CLASSNAME_LENGTH];
		
	bool result;
	
	int i = -1;
	while ((i = FindEntityByClassname(i, "info_target")) != -1)
	{
		GetEntPropString(i, Prop_Data, "m_iName", name, sizeof(name));
		if (!strcmp(name, ROOM_NAME))
		{
			FormatEx(room, sizeof(room), "%d", i);
			
			if (KvJumpToKey(gk_rooms, room, false))
			{
				rescue_slot = 1;
				FormatEx(temp, sizeof(temp), "%d", rescue_slot);
				
				while (KvJumpToKey(gk_rooms, temp, false))
				{
					KvGetString(gk_rooms, "origin", value, sizeof(value), "none");
					
					if (!strcmp(value, pos_spawn))
					{
						KvSetNum(gk_rooms, "active", 0);
						
						result = true;
					}
					
					rescue_slot ++;
					FormatEx(temp, sizeof(temp), "%d", rescue_slot);
					
					KvGoBack(gk_rooms);
				}
				
				if (result)
				{
					int rescue_count = KvGetNum(gk_rooms, "rescue_count");
					
					rescue_count ++;
							
					SetEntProp(i, Prop_Data, "m_iHealth", rescue_count);
					KvSetNum(gk_rooms, "rescue_count", rescue_count);
					
					break;
				}
				
				KvGoBack(gk_rooms);
			}
		}
	}
		
	KvRewind(gk_rooms);
	
	return result;
}

void Rescue_Restore_All()
{
	if (!IsValidHandle(gk_rooms))
	{
		return;
	}
	
	KvRewind(gk_rooms);
	
	char name[MAX_CLASSNAME_LENGTH];
	char room[MAX_CLASSNAME_LENGTH];
	char temp[MAX_CLASSNAME_LENGTH];
	
	int rescue_slot;
	
	int i = -1;
	while ((i = FindEntityByClassname(i, "info_target")) != -1)
	{
		GetEntPropString(i, Prop_Data, "m_iName", name, sizeof(name));
		if (!strcmp(name, ROOM_NAME))
		{
			FormatEx(room, sizeof(room), "%d", i);
			
			if (KvJumpToKey(gk_rooms, room, false))
			{
				rescue_slot = 1;
				FormatEx(temp, sizeof(temp), "%d", rescue_slot);
				
				while (KvJumpToKey(gk_rooms, temp, false))
				{
					KvSetNum(gk_rooms, "active", 0);
						
					rescue_slot ++;
					FormatEx(temp, sizeof(temp), "%d", rescue_slot);
					
					KvGoBack(gk_rooms);
				}
				
				rescue_slot --;
				
				SetEntProp(i, Prop_Data, "m_iHealth", rescue_slot);
				KvSetNum(gk_rooms, "rescue_count", rescue_slot);
				
				KvGoBack(gk_rooms);
			}
		}
	}
		
	KvRewind(gk_rooms);
}

void Room_Disable_All()
{
	char name[MAX_CLASSNAME_LENGTH];
	
	int i = -1;
	while ((i = FindEntityByClassname(i, "info_target")) != -1)
	{
		GetEntPropString(i, Prop_Data, "m_iName", name, sizeof(name));
		if (!strcmp(name, ROOM_NAME))
		{
			Room_Disable(null, i);
		}
	}
}

Action:Room_Disable(Handle timer, int room)
{
	if (!IsValidHandle(gk_rooms))
	{
		return;
	}
	
	KvRewind(gk_rooms);
	
	int rescue_slot;
	
	char temp[MAX_CLASSNAME_LENGTH];
	FormatEx(temp, sizeof(temp), "%d", room);
			
	if (KvJumpToKey(gk_rooms, temp, false))
	{
		KvSetNum(gk_rooms, "rescue_count", 0);
		if (IsValidEntity(room))
		{
			SetEntProp(room, Prop_Data, "m_iHealth", 0);
		}
		
		rescue_slot = 1;
		FormatEx(temp, sizeof(temp), "%d", rescue_slot);
				
		while (KvJumpToKey(gk_rooms, temp, false))
		{
			KvSetNum(gk_rooms, "active", 1);
								
			rescue_slot ++;
			FormatEx(temp, sizeof(temp), "%d", rescue_slot);
					
			KvGoBack(gk_rooms);
		}
	}
		
	KvRewind(gk_rooms);
}

void Create_Recue_Rooms(int entity)
{
	if (!IsValidEntity(entity))
	{
		return;
	}
	
	float pos_entity[3];
	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", pos_entity);
		
	float pos_i[3];
	
	int i = -1;
	while ((i = FindEntityByClassname(i, "info_survivor_rescue")) != -1)
	{
		GetEntPropVector(i, Prop_Data, "m_vecOrigin", pos_i);
		if (GetVectorDistance(pos_entity, pos_i) <= RESCUE_SEARCH_DISTANCE)
		{
			SetRoomData(i, -1);
		}
	}
}

bool IsAllSurvivorFar(int entity)
{
	float distance = GetConVarFloat(FindConVar("rescue_range")); //  * 0.5
	
	float pos_entity[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos_entity);
	
	float pos_survivor[3];
	
	int near;
	
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		if (IsValidClientTeam2Alive(i))
		{
			GetClientEyePosition(i, pos_survivor);
				
			if (GetVectorDistance(pos_entity, pos_survivor) <= distance)
			{
				near ++;
			}
		}
	}
	
	if (!near)
	{
		return true;
	}
	
	return false;
}

int IsAnySurvivorNear_DontWatch(int room, float distance)
{
	float pos_room[3];
	GetEntPropVector(room, Prop_Send, "m_vecOrigin", pos_room);
	
	float pos_survivor[3];
	
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		if (IsValidClientTeam2Alive(i)) //  && !IsFakeClient(i)
		{
			GetClientEyePosition(i, pos_survivor);
			
			if (IsVisible(i, room) && IsInSight(i, pos_room, 110.0))
			{
				return i;
			}
			
			GetClientEyePosition(i, pos_survivor);
			
			if (GetVectorDistance(pos_room, pos_survivor) <= distance)
			{
				if (IsSameFloor(pos_room[2], pos_survivor[2]))
				{
					if (IsVisible(i, room))
					{
						return i;
					}
				}
			}
		}
	}
	
	return 0;
}

int IsAnySurvivorNear_Watch(int room, float distance)
{
	float pos_room[3];
	GetEntPropVector(room, Prop_Send, "m_vecOrigin", pos_room);
	
	float pos_survivor[3];
	
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		if (IsValidClientTeam2Alive(i)) //  && !IsFakeClient(i)
		{
			GetClientEyePosition(i, pos_survivor);
			
			if (GetVectorDistance(pos_room, pos_survivor) <= distance)
			{
				if (IsSameFloor(pos_room[2], pos_survivor[2]))
				{
					if (IsVisible(i, room) || IsVisibleDoorRoom(i, room))
					{
						return i;
					}
				}
			}
		}
	}
	
	return 0;
}

int IsVisibleDoorRoom(int client, int room)
{
	int door = -1;
	while ((door = FindEntityByClassname(door, "prop_door_rotating")) != -1)
	{
		if (room == GetEntPropEnt(door, Prop_Data, "m_hOwnerEntity"))
		{
			if (IsVisible(client, door))
			{
				return true;
			}
		}
	}
	
	return false;
}

void LureNearBot(int entity)
{
	float distance = GetConVarFloat(FindConVar("rescue_range")) * 0.5;
	
	float pos_entity[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos_entity);
	
	float pos_survivor[3];
	
	int pills;
	
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		if (IsValidClientTeam2Alive(i) && IsFakeClient(i))
		{
			GetClientAbsOrigin(i, pos_survivor);
				
			if (GetVectorDistance(pos_entity, pos_survivor) <= distance)
			{
				if (IsSameFloor(pos_entity[2], pos_survivor[2]))
				{
					if (GetEngineVersion() == Engine_Left4Dead)
					{
						pills = GetPlayerWeaponSlot(i, 4);
						if (IsValidEntity(pills))
						{
							RemovePlayerItem(i, pills);
							InputKill(pills);
						}
					
						break;
					}
					else
					{
						 SendBotToPos(i, pos_entity);
					}
				}
			}
		}
	}
}

// tx Earendil
// https://forums.alliedmods.net/showthread.php?t=340022
/**
 *    Sends Bot to the desired vector
 *    If the vector is on air bot will go just under that vector
 *    Sometimes bots would get stuck attempting to go to that place
 *    Works for both Special Infected and Survivor Bot
 */
stock void SendBotToPos(int bot, float vPos[3])
{
	char sBuffer[256];
	Format(sBuffer, sizeof(sBuffer), "CommandABot( { cmd = 1, bot = GetPlayerFromUserID(%i) pos = Vector(%f,%f,%f) } )", GetClientUserId(bot), vPos[0], vPos[1], vPos[2]);
	SetVariantString(sBuffer);
	AcceptEntityInput(bot, "RunScriptCode");
}

/*
 *    Bot will be free from last order so he will regain "conciousness"
 *    and start working as a normal bot again
 *    Works for both Special Infected and Survivor Bot
 */
stock void FreeBotOrder(int bot)
{
	char sBuffer[256];
	Format (sBuffer, sizeof(sBuffer), "CommandABot( { cmd = 3, bot = GetPlayerFromUserID(%i) } )", GetClientUserId(bot));
	SetVariantString(sBuffer);
	AcceptEntityInput(bot, "RunScriptCode");
} 

bool IsSameFloor(float z1, float z2)
{
	float z_floor;
	
	z_floor = z1 - z2;
	if (z_floor < 0) {z_floor *= -1;}
						
	if (z_floor <= FLOOR_HEIGH_SEARCH)
	{
		return true;
	}
	
	return false;
}

bool IsInSight(int client, float vec_origin[3], float fov)
{
	if (!IsValidClientTeam2Alive(client))
	{
		return false;
	}
	
	float client_pos[3];
	GetClientEyePosition(client, client_pos);
	
	client_pos[2] = 0.0;
	
	float client_ang[3];
	GetClientEyeAngles(client, client_ang);
	
	client_ang[0] = 0.0;
	client_ang[2] = 0.0;
	
	float ang_min = client_ang[1] - fov * 0.5;
	float ang_max = client_ang[1] + fov * 0.5;
	
	float ang_temp[3];
	ang_temp = client_ang;
	
	float pos_entity[3];
	
	pos_entity[0] = vec_origin[0];
	pos_entity[1] = vec_origin[1];
	pos_entity[2] = 0.0;
	
	float distance = GetVectorDistance(pos_entity, client_pos);
	
	float pos_temp[3];
	
	while (ang_min < ang_max)
	{
		pos_temp = client_pos;
		ang_temp[1] = ang_min;
			
		MovePos_Forward(pos_temp, ang_temp, distance);
		
		if (GetVectorDistance(pos_entity, pos_temp) <= distance * 0.1)
		{
			return true;
		}
		
		ang_min += 5.0;
	}
	
	return false;
}

bool IsVisible(int client, int entity)
{
	if (!IsValidClientTeam2Alive(client))
	{
		return false;
	}
	
	if (!IsValidEntity(entity))
	{
		return false;
	}
		
	float pos_start[3];
	GetClientEyePosition(client, pos_start);
	
	float pos_end[3];
	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", pos_end);
	
	char classname[MAX_CLASSNAME_LENGTH];
	GetEntityClassname(entity, classname, sizeof(classname));
	
	if (!strcmp(classname, "prop_door_rotating") || !strcmp(classname, "func_door"))
	{
		int door = entity;
		
		float pos_door[3];
		GetEntPropVector(door, Prop_Data, "m_vecOrigin", pos_door);
			
		float ang_door[3];
		GetEntPropVector(door, Prop_Data, "m_angRotation", ang_door);
			
		ang_door[0] = 0.0;
		ang_door[1] += 90.0;
		ang_door[2] = 0.0;
			
		float vMaxs[3], vMins[3];
				
		GetEntPropVector(door, Prop_Send, "m_vecMaxs", vMaxs);
		GetEntPropVector(door, Prop_Send, "m_vecMins", vMins);
			
		float distance = (vMins[1] * (-1) + vMaxs[1]) * 0.5;
			
		MovePos_Forward(pos_door, ang_door, distance);
		
		pos_door[2] += vMins[2];
		pos_door[2] += (vMins[2] * (-1) + vMaxs[2]) * 0.36;
		
		pos_end = pos_door;
	}
	
	float ang_client[3];
	GetClientEyeAngles(client, ang_client);
	
	ang_client[0] = 0.0;
	ang_client[2] = 0.0;
	
	MovePos_Forward(pos_end, ang_client, 10.0);
	
	Handle trace = TR_TraceRayFilterEx(pos_start, pos_end, MASK_SOLID, RayType_EndPoint, TraceFilter_Visible);
	if (TR_DidHit(trace))
	{
		int index = TR_GetEntityIndex(trace);
		CloseHandle(trace);
		
		if (index == entity)
		{
			return true;
		}
		
		return false;
	}
	
	CloseHandle(trace);
	return true;
}

bool TraceFilter_Visible(int entity, int contentsMask)
{
	char classname[MAX_CLASSNAME_LENGTH];
	GetEntityClassname(entity, classname, sizeof(classname));
	
	if (!strcmp(classname, "prop_door_rotating") || !strcmp(classname, "func_door"))
	{
		return true;
	}
		
	if (entity > 0 && IsValidEntity(entity)) return false;
	
	return true;
}

/**
 * Проверяет клиента команды 2
 *
 * client 		- Client index.
 * return 		- true если client valid и false если нет
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
 * client 		- Client index.
 * return 		- true если client valid и false если нет
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
 * client 		- Client index.
 * return 		- true если client valid и false если нет
 */
stock bool IsValidClientTeam2(int client)
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


/**
 * Проверяет клиента команды 2
 *
 * client 		- Client index.
 * return 		- true если client valid и false если нет
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
 * Удаляет сущность через интервал НЕ УДАЛЯЮТСЯ СУЩНОСТИ МЕНЬШЕ ЧЕМ MAX_PLAYERS
 *
 * entity 		- сущность, которая удаляется
 * time 		- кол-во секунд, через которое удаляется
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
 * Посылает действие на все сущности с одинаковым targetname 
 *
 * targetname 	- имя сущностей на которых хотим подействовать
 * input 		- название действия
 * value 		- значение действия (например 1, если на свет передается brightness 1)
 * delay 		- кол-во секунд, через которое запускается действие
*/
stock void InputTarget(char [] targetname, char [] input, char [] value = "", float delay = 0.0)
{
	int entity = CreateEntityByName("logic_relay");
	if (entity == -1)
	{
		return;
	}

	char name[MAX_STRING_LENGTH];
	FormatEx(name, sizeof(name), "inputtarget_relay_%d", entity);

	DispatchKeyValue(entity, "targetname", name);
	DispatchKeyValue(entity, "spawnflags", "1"); // 2
	DispatchKeyValue(entity, "StartDisabled", "0");

	DispatchSpawn(entity);
	
	static char temp[MAX_STRING_LENGTH];
	Format(temp, sizeof(temp), "%s,%s,%s,%f,0", targetname, input, value, delay); // -1
	DispatchKeyValue(entity, "OnTrigger", temp);
	
	AcceptEntityInput(entity, "Trigger");
	AcceptEntityInput(entity, "Kill");
}

/**
 * Посылает на сущность действие с регулируемым интервалом
 *
 * entity 		- сущность для передачи последовательности действий
 * input 		- название действия
 * value 		- значение действия (например 1, если на свет передается brightness 1)
 * time_start 	- кол-во секунд, через которое запускается действие
 * time_life 	- кол-во секунд, через которое удаляется сущность, если 0 - то не удаляется
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

stock bool IsSurvivorIncapacitated(int client)
{
	return bool:GetEntProp(client, Prop_Send, "m_isIncapacitated");
}

/**
 * возвращает случайное число из интервала размера массива без повтора, пока не 
 * переберутся все значения
 *
 * MAX_RANDOM_SELECT 	- макс размер массива
 * random_data			- массив хранения значений в текстовом формате
 * value				- величина требуемого интервала, отправляется в функцию в виде sizeof(random_data)
 * return				- значение от 0 по sizeof(random_data) - 1, или -1, если превышение массива
 */
stock int GetRandomSelect(char [] random_data, int value)
{
	#define MAX_RANDOM_SELECT 128
	
	value --;
	
	if (value < 1 || value > MAX_RANDOM_SELECT)
	{
		//LogError("GetRandomSelect: ERROR: INVALID value = %d", value + 1);
		return 0;
	}
	
	int massive_free[MAX_RANDOM_SELECT + 1];
	int a;

	for (int i = 0; i <= value; i++)
	{
		if (random_data[i] == 0)
		{
			massive_free[a] = i;
						
			a ++;
			
		}
	}
	
	a --;
	if (a < 0)
	{
		for (int j = 0; j <= value; j++)
		{
			random_data[j] = 0;
		}
	}
	
	int chance = GetRandomInt(0, a);
	
	int j;
	for (j = 0; j <= value; j++)
	{	
		if (massive_free[chance] == j)
		{
			random_data[j] = 1;
						
			break;
		}
	}
	
	return j;
}

/**
 * ищет совпадение по классу вокруг заданной сущности
 *
 * entity 		- сущность, относительно которой происходит поиск (заданная сущность)
 * distance 	- расстояние поиска 
 * classname 	- класс искомой сущности
 * return 		- сущность или 0, если не найдено
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

/**
 * перемещает координаты вперед-назад согласно углам
 *
 * vec_origin 	- начальные координаты
 * vec_angles 	- углы
 * distance		- расстояние, если +, то вперед, если минус назад
 */
stock void MovePos_Forward(float vec_origin[3], float vec_angles[3], float distance)
{
	float direction[3];
		
	GetAngleVectors(vec_angles, direction, NULL_VECTOR, NULL_VECTOR);
	
	vec_origin[0] = vec_origin[0] + direction[0] * distance;
	vec_origin[1] = vec_origin[1] + direction[1] * distance;
	vec_origin[2] = vec_origin[2] + direction[2] * distance;
}

int FindNearRescuer(float pos[3])
{
	int rescuer;
	
	float distance_old; float distance;
	
	float pos_i[3];
	
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		if (IsValidClientTeam2Alive(i))
		{
			GetEntPropVector(i, Prop_Data, "m_vecOrigin", pos_i);
			pos_i[2] += 35.0;
			
			distance = GetVectorDistance(pos, pos_i);
			
			if (!distance_old || distance < distance_old)
			{
				distance_old = distance; 
				rescuer = i;
			}
		}
	}
	
	return rescuer;
}
