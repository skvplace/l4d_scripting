/**
 * ========================================================================
 * Plugin [L4D/L4D2] Respawn Final
 * Respawning survivors during the finale
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
	name 		= "[L4D/L4D2] Respawn Final",
	author 		= "Skv",
	description = "The plugin allows survivors to respawn in the finale",
	version 	= "1.5.4 (P)",
	url 		= "https://forums.alliedmods.net/showthread.php?p=2829933#post2829933"
}

#define MAX_PLAYERS 				18
#define MAX_STRING_LENGTH			128

#define GLOW_NAME 					"rf_rescue_glow"
#define VISIBLE_HEIGH				80.0
#define VISIBLE_HEIGH_INCAP			30.0

char 	gs_model_pills[]			= "models/w_models/weapons/w_eq_painpills.mdl";

bool 	gb_spawn_playerid			[MAX_PLAYERS + 1];
int 	gi_time_playerid			[MAX_PLAYERS + 1];

Handle 	gt_CheckClientDead			[MAX_PLAYERS + 1];
Handle 	gt_CreateRescue				[MAX_PLAYERS + 1];


#define MAX_TIMERS					MAX_PLAYERS * 4
Handle 	gt_Timer					[MAX_TIMERS + 1];

bool 	gb_finale_start;
bool 	gb_rescue_spawn;

ConVar 	gc_rescue_min_dead_time_final;
ConVar 	gc_respawn_mode_finale;
ConVar	gc_respawn_outside_rescue;
ConVar	gc_respawn_outside_time;

float 	gf_rescue_min_dead_time_final;
int 	gi_respawn_mode_finale;
bool 	gb_respawn_outside_rescue;
float 	gf_respawn_outside_time;

float 	gv_origin_dead_survivor		[MAX_PLAYERS + 1][3];

#define MAX_RESCUE					64
int 	gi_rescue					[MAX_RESCUE + 1];

float 	gv_rescue_origin			[MAX_RESCUE + 1][3];
float 	gv_rescue_angles			[MAX_RESCUE + 1][3];

#define MAX_FINAL_RESCUES			3
int 	gi_final_rescue_slot		[MAX_FINAL_RESCUES + 1];
int 	gi_final_rescue_slot_client	[MAX_FINAL_RESCUES + 1];

char 	gs_chance_rescue_slot[3];

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
	HookEvent("player_bot_replace", Event_replace); // бот заменил игрока
	HookEvent("bot_player_replace", Event_replace); // игрок заменил бота
	
	HookEvent("player_death", Event_player_death);
	HookEvent("survivor_rescued", Event_survivor_rescued);
		
	HookEvent("mission_lost", Event_mission_lost);
	HookEvent("entity_visible", Event_entity_visible);
	
	HookEvent("finale_start", Event_finale_start);
	HookEvent("finale_win", Event_finale_win);
		
	gc_rescue_min_dead_time_final = CreateConVar("rf_rescue_min_dead_time_final", "30", "The duration in seconds that a survivor must be dead before they can be rescued", _, true, 0.0, true, 600.0);
	SetConVarFlags(gc_rescue_min_dead_time_final, GetConVarFlags(gc_rescue_min_dead_time_final) & ~FCVAR_NOTIFY);
	
	HookConVarChange(gc_rescue_min_dead_time_final, OnConVarChanged_rescue_min_dead_time_final);
	
	gc_respawn_mode_finale = CreateConVar("rf_respawn_mode_finale", "2", "Respawn mode: 0 - respawn is disabled, 1 - respawn is active only once, 2 - respawn is active many times", _, true, 0.0, true, 2.0);
	SetConVarFlags(gc_respawn_mode_finale, GetConVarFlags(gc_respawn_mode_finale) & ~FCVAR_NOTIFY);
	
	HookConVarChange(gc_respawn_mode_finale, OnConVarChanged_respawn_mode_finale);
	
	gc_respawn_outside_rescue = CreateConVar("rf_respawn_outside_rescue", "1", "Possibility of respawning at the place of death if rescue rooms are not found", _, true, 0.0, true, 1.0);
	SetConVarFlags(gc_respawn_outside_rescue, GetConVarFlags(gc_respawn_outside_rescue) & ~FCVAR_NOTIFY);
	
	HookConVarChange(gc_respawn_outside_rescue, OnConVarChanged_respawn_outside_rescue);
	
	gc_respawn_outside_time = CreateConVar("rf_respawn_outside_time", "120", "Time in seconds for automatic switching of respawn to respawn at the place of death if the respawn is out of reach. 0 - disabled", _, true, 0.0, true, 540.0);
	SetConVarFlags(gc_respawn_outside_time, GetConVarFlags(gc_respawn_outside_time) & ~FCVAR_NOTIFY);
	
	HookConVarChange(gc_respawn_outside_time, OnConVarChanged_respawn_outside_time);
	
	AutoExecConfig(true, "respawn_final");
}

void OnConVarChanged_rescue_min_dead_time_final(ConVar convar, const char[] oldValue, const char[] newValue)
{
	gf_rescue_min_dead_time_final = StringToFloat(newValue);
}

void OnConVarChanged_respawn_mode_finale(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (!gb_finale_start)
	{
		return;
	}
	
	gi_respawn_mode_finale = StringToInt(newValue);
	
	if (gi_respawn_mode_finale != 1)
	{
		for (int i = 1; i <= MAX_PLAYERS; i++)
		{
			gb_spawn_playerid[i] = false;
		}
	}
	
	if (gi_respawn_mode_finale)
	{
		SearchDeadSurvivor();
	}
}

void OnConVarChanged_respawn_outside_rescue(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (!gb_finale_start)
	{
		return;
	}
	
	gb_respawn_outside_rescue = view_as<bool>(StringToInt(newValue));
	
	if (gi_respawn_mode_finale && gb_respawn_outside_rescue)
	{
		SearchDeadSurvivor();
	}
}

void OnConVarChanged_respawn_outside_time(ConVar convar, const char[] oldValue, const char[] newValue)
{
	gf_respawn_outside_time = StringToFloat(newValue);
}

public OnMapStart()
{
	PrecacheModel(gs_model_pills);
}

public OnGameplayStart(int stage)
{
	if (stage)
	{
		return;
	}
	
	Delete_Timers();
	
	gf_rescue_min_dead_time_final 	= GetConVarFloat	(gc_rescue_min_dead_time_final);
	gi_respawn_mode_finale 			= GetConVarInt		(gc_respawn_mode_finale);
	gb_respawn_outside_rescue 		= GetConVarBool		(gc_respawn_outside_rescue);
	gf_respawn_outside_time			= GetConVarFloat	(gc_respawn_outside_time);
	
	int i = -1;
	while ((i = FindEntityByClassname(i, "info_survivor_rescue")) != -1)
	{
		SetRescueVectors(i);
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

public OnEntityCreated(entity, const String:classname[])
{
	if (!strcmp(classname, "trigger_finale") || !strcmp(classname, "trigger_finale_dlc3"))
	{
		HookSingleEntityOutput(entity, "UseStart", UseStart, true);
		HookSingleEntityOutput(entity, "FinaleStart", FinaleStart, true);
	}
}

void UseStart(char [] output, int entity, int activator, float delay)
{
	if (gb_finale_start)
	{
		return;
	}
	
	if (SetNearRescueVectors(activator))
	{
		gb_rescue_spawn = true;
	}
}

void Event_finale_start(Handle:event, const String:name[], bool:dontBroadcast)
{
	int timer_slot = GetFreeTimerSlot();
	if (timer_slot)
	{
		gt_Timer[timer_slot] = CreateTimer(5.0, Check_FinaleStart);
	}
}

void Event_finale_win(Handle:event, const String:name[], bool:dontBroadcast)
{
	Delete_Timers();
}

Action:Check_FinaleStart(Handle timer)
{
	SearchDeadSurvivor();
	
	if (gb_finale_start)
	{
		return;
	}
	
	int client = GetSpawnClient();
	if (!client)
	{
		return;
	}
	
	if (SetNearRescueVectors(client))
	{
		gb_rescue_spawn = true;
	}
	
	gb_finale_start = true;
}

void FinaleStart(char [] output, int entity, int activator, float delay)
{
	if (gb_finale_start)
	{
		return;
	}
	
	gb_finale_start = true;
	
	int slot = gi_final_rescue_slot[1];
		
	if (gv_rescue_origin[slot][0] != 0.0 && gv_rescue_origin[slot][1] != 0.0 && gv_rescue_origin[slot][2] != 0.0)
	{
		return;
	}
	
	if (SetNearRescueVectors(activator))
	{
		gb_rescue_spawn = true;
	}
}

void Event_replace(Handle:event, const String:name[], bool:dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "player"));
	if (!IsValidClient(client)) {return;}
	
	int bot = GetClientOfUserId(GetEventInt(event, "bot"));
	if (!IsValidClient(client)) {return;}
	
	if (!strcmp(name, "player_bot_replace"))
	{
		// бот заменил игрока
		ReplaceRescue(client, bot);
		
	}
	else
	{
		// игрок заменил бота
		ReplaceRescue(bot, client);
	}
}

void Event_survivor_rescued(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!gb_finale_start)
	{
		return;
	}
	
	int client = GetClientOfUserId(GetEventInt(event, "victim"));
	if (!IsValidClientTeam2(client)) {return;}
	
	RemoveGlowRescue(client, 0.1);
}

void Event_player_death(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (gf_rescue_min_dead_time_final <= 0.0)
	{
		return;
	}
	
	if (!gb_finale_start)
	{
		return;
	}
	
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsValidClientTeam2(client)) 
	{
		return;
	}
	
	SetOriginDeadSurvivors(client);
		
	int survivorid = GetClientSurvivorId(client);
	if (survivorid)
	{
		if (IsValidHandle(gt_CheckClientDead[survivorid]))
		{
			delete gt_CheckClientDead[survivorid];
		}
		
		gt_CheckClientDead[survivorid] = CreateTimer(gf_rescue_min_dead_time_final, CheckClientDead, survivorid, TIMER_REPEAT);
			
	}
}
	
Action:CheckClientDead(Handle timer, int survivorid)
{
	if (!gi_respawn_mode_finale)
	{
		return Plugin_Stop;
	}
	
	int userid = GetSurvivorUserId(survivorid);
	if (!userid)
	{
		//LogError("CheckClientDead: userid is NULL, survivorid %d", userid, survivorid);
		return Plugin_Continue;
	}
	
	int client = GetClientOfUserId(userid);
	if (!IsValidClient(client))
	{
		return Plugin_Continue;
	}
	
	if (IsPlayerAlive(client))
	{
		return Plugin_Stop;
	}
	
	CreateRescue(null, survivorid);
	
	return Plugin_Stop;
}

void Event_entity_visible(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!gb_finale_start)
	{
		return;
	}
	
	char targetname[MAX_NAME_LENGTH];
	GetEventString(event, "entityname", targetname, sizeof(targetname));
		
	if (StrContains(targetname, GLOW_NAME) > -1)
	{
		int survivor = GetClientOfUserId(GetEventInt(event, "userid"));
		
		int visible_prop = GetEventInt(event, "subject");
		
		float pos_spawn[3];
		GetEntPropVector(visible_prop, Prop_Send, "m_vecOrigin", pos_spawn);
			
		float ang_spawn[3];
		GetEntPropVector(visible_prop, Prop_Data, "m_angRotation", ang_spawn);
		
		int client = GetEntPropEnt(visible_prop, Prop_Data, "m_hOwnerEntity");
		
		if (IsValidClient(client))
		{
			int entity = GetClientActiveProp(client);
			if (entity)
			{
				char default_anim[MAX_NAME_LENGTH];
				GetEntPropString(entity, Prop_Data, "m_iszDefaultAnim", default_anim, sizeof(default_anim));
				
				if (StrContains(default_anim, "Rescue", false) > -1)
				{
					pos_spawn[2] -= VISIBLE_HEIGH;
					Respawn(client, survivor, pos_spawn, ang_spawn, false);
				}
				else
				{
					pos_spawn[2] -= VISIBLE_HEIGH_INCAP;
					Respawn(client, survivor, pos_spawn, ang_spawn, true);
				}
			}
		}
		else
		{
			InputTarget(targetname, "Kill");
		}
	}
}

void Respawn(int client, int rescuer, float pos_spawn[3], float ang_spawn[3], bool incap = false)
{
	if (!IsValidClient(client))
	{
		return;
	}
	
	int entity = CreateEntityByName("info_survivor_rescue");
	if (entity == -1)
	{
		return;
	}
	
	char targetname[MAX_TARGET_LENGTH];
	FormatEx(targetname, sizeof(targetname), "%s_%d", GLOW_NAME, GetClientUserId(client));
	
	DispatchKeyValue(entity, "targetname", targetname);
	
	SetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity", client);
	
	char client_model[PLATFORM_MAX_PATH];
	GetClientModel(client, client_model, sizeof(client_model));
	
	DispatchKeyValue(entity, "model", client_model);
	
	DispatchKeyValueVector(entity, "origin", pos_spawn);
	DispatchKeyValueVector(entity, "angles", ang_spawn);
	
	DispatchSpawn(entity);
	ActivateEntity(entity);
	
	// обязательно обе строки рядом!
	SetEntPropEnt(entity, Prop_Send, "m_survivor", client);
	AcceptEntityInput(entity, "Rescue", rescuer);
	
	if (incap)
	{
		//SDKHooks_TakeDamage(client, 0, 0, 110.0, DMG_BULLET, -1, NULL_VECTOR, NULL_VECTOR);
		SetEntProp(client, Prop_Send, "m_isIncapacitated", 1);
	}
		
	SetUserRespawn(client);
}

Action:CreateRescue(Handle timer, int survivorid)
{
	if (!gb_finale_start)
	{
		return;
	}	
	
	int userid = GetSurvivorUserId(survivorid);
	if (!userid)
	{
		return;
	}
	
	int client = GetClientOfUserId(userid);
	if (!IsValidClientTeam2(client))
	{
		return;
	}
	
	if (IsPlayerAlive(client))
	{
		return;
	}
	
	if (!gb_rescue_spawn && !gb_respawn_outside_rescue)
	{
		gb_rescue_spawn = true;
	}
	
	if (gi_respawn_mode_finale == 1 && IsClientRespawned(client))
	{
		return;
	}
	
	if (IsActiveClientRescue(client))
	{
		return;
	}
	
	if (IsActiveRescueLimit())
	{
		float yell_interval = GetConVarFloat(FindConVar("rescue_yell_interval"));
		if (yell_interval <= 0.0)
		{
			yell_interval = 6.0;
		}
			
		if (IsValidHandle(gt_CreateRescue[survivorid]))
		{
			delete gt_CreateRescue[survivorid];
		}
			
		gt_CreateRescue[survivorid] = CreateTimer(yell_interval, CreateRescue, survivorid);
				
		return;
	}
	
	float pos_spawn[3]; float ang_spawn[3];
	
	if (!gb_rescue_spawn && !GetOriginDeadSurvivors(pos_spawn))
	{
		for (int i = 1; i <= MAX_PLAYERS; i++)
		{
			if (IsValidClientTeam2Alive(i))
			{
				GetClientAbsOrigin(i, gv_origin_dead_survivor[1]);
					
				break;
			}
		}
		
		if (!gv_origin_dead_survivor[1][0] && !gv_origin_dead_survivor[1][1] && !gv_origin_dead_survivor[1][2])
		{
			return;
		}
		
		float yell_interval = GetConVarFloat(FindConVar("rescue_yell_interval"));
		if (yell_interval <= 0.0)
		{
			yell_interval = 6.0;
		}
			
		if (IsValidHandle(gt_CreateRescue[survivorid]))
		{
			delete gt_CreateRescue[survivorid];
		}
		
		gt_CreateRescue[survivorid] = CreateTimer(yell_interval, CreateRescue, survivorid);
			
		return;
	}
	
	char temp[PLATFORM_MAX_PATH];
	GetClientModel(client, temp, sizeof(temp));
	
	int entity;
	
	if (GetEngineVersion() == Engine_Left4Dead)
	{
		entity = CreateEntityByName("prop_glowing_object");
		if (entity == -1)
		{
			//LogError("Error create prop_glowing_object");
			return;
		}
		
		DispatchKeyValue(entity, "StartGlowing", "1");
		DispatchKeyValue(entity, "GlowForTeam", "2");
	}
	else
	{
		entity = CreateEntityByName("prop_dynamic");
		if (entity == -1)
		{
			return;
		}
		
		DispatchKeyValue(entity, "StartGlowing", "0");
		DispatchKeyValue(entity, "GlowForTeam", "-1");
		
		DispatchKeyValue(entity, "glowstate", "0");
		DispatchKeyValue(entity, "glowrangemin", "150");
		DispatchKeyValue(entity, "glowrange", "0");
		DispatchKeyValue(entity, "glowcolor", "0 0 0");
		
		InputEntity(entity, "StartGlowing", _, 0.1);
	}
	
	if (gb_rescue_spawn)
	{
		if (!GetVectorsFinalRescue(client, pos_spawn, ang_spawn))
		{
			InputKill(entity);
			return;
		}
	}
	
	char targetname[MAX_TARGET_LENGTH];
	FormatEx(targetname, sizeof(targetname), "%s_%d", GLOW_NAME, GetClientUserId(client));
	
	DispatchKeyValue(entity, "targetname", targetname);
	
	DispatchKeyValue(entity, "model", temp);
	DispatchKeyValue(entity, "solid", "0");
	
	if (gb_rescue_spawn)
	{
		DispatchKeyValue(entity, "DefaultAnim", "Idle_Rescue_01c");
	}
	else
	{
		DispatchKeyValue(entity, "DefaultAnim", "Idle_Incap_Pistol");
	}
	
	DispatchKeyValue(entity, "rendermode", "1");
	DispatchKeyValue(entity, "renderamt", "0");
	//DispatchKeyValue(entity, "rendercolor", "255 0 0");
	
	DispatchKeyValueVector(entity, "origin", pos_spawn);
	DispatchKeyValueVector(entity, "angles", ang_spawn);
		
	DispatchSpawn(entity);
	
	CloseNearDoors(entity);
	
	int visible_prop = CreateEntityByName("prop_door_rotating");
	if (visible_prop == -1)
	{
		return;
	}
	
	SetEntPropEnt(visible_prop, Prop_Data, "m_hOwnerEntity", client);
	
	DispatchKeyValue(visible_prop, "targetname", targetname);
	
	if (gb_rescue_spawn)
	{
		pos_spawn[2] += VISIBLE_HEIGH;
	}
	else
	{
		pos_spawn[2] += VISIBLE_HEIGH_INCAP;
	}
	
	DispatchKeyValueVector(visible_prop, "origin", pos_spawn);
		
	DispatchKeyValue(visible_prop, "model", gs_model_pills);
	
	DispatchKeyValue(visible_prop, "rendermode", "10");
	DispatchKeyValue(visible_prop, "renderamt", "0");
	DispatchKeyValue(visible_prop, "renderfx", "0");
	DispatchKeyValue(visible_prop, "rendercolor", "0 0 0");
	DispatchKeyValue(visible_prop, "disableshadows", "1");
	
	DispatchSpawn(visible_prop);
	
	Rescue_Playsound(client, entity);
	
	gi_time_playerid[survivorid] = RoundFloat(GetGameTime());
		
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
}

void CloseNearDoors(int entity)
{
	if (!IsValidEntity(entity))
	{
		return;
	}
	
	float pos_entity[3];
	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", pos_entity);
	
	int door = FindNearEntityByClassname(entity, "prop_door_rotating", true, 300.0);
	if (!door)
	{
		return;
	}
	
	InputEntity(door, "Close");
	
	char name[MAX_STRING_LENGTH];
	GetEntPropString(door, Prop_Data, "m_iName", name, sizeof(name));
	if (strlen(name))
	{
		InputTarget(name, "Close");
	}
	
	GetEntPropString(door, Prop_Data, "m_SlaveName", name, sizeof(name));
	if (strlen(name))
	{
		InputTarget(name, "Close");
	}
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
			
	int userid = GetSurvivorUserId(survivorid);
	if (!userid)
	{
		//LogError("Rescue_Playsound_Timer: userid is NULL, survivorid %d", userid, survivorid);
		return Plugin_Stop;
	}
	
	int client = GetClientOfUserId(userid);
	
	int entity = EntRefToEntIndex(ReadPackCell(data_sound));
	if (!IsValidEntity(entity))
	{
		return Plugin_Stop;
	}
	
	if (!IsValidClient(client))
	{
		char name[MAX_STRING_LENGTH];
		GetEntPropString(entity, Prop_Data, "m_iName", name, sizeof(name));
			
		InputTarget(name, "Kill");
		return Plugin_Stop;
	}
	
	Rescue_Playsound(client, entity);
	
	int respawn_outside_time = RoundFloat(gf_respawn_outside_time);
		
	if (respawn_outside_time) //  && gb_rescue_spawn
	{
		if (RoundFloat(GetGameTime()) - gi_time_playerid[survivorid] >= respawn_outside_time)
		{
			gb_rescue_spawn = false;
			gi_time_playerid[survivorid] = 0;
			
			if (IsValidEntity(entity))
			{
				char name[MAX_STRING_LENGTH];
				GetEntPropString(entity, Prop_Data, "m_iName", name, sizeof(name));
			
				InputTarget(name, "Kill");
			}
			
			if (IsValidHandle(gt_CheckClientDead[survivorid]))
			{
				delete gt_CheckClientDead[survivorid];
			}
			
			float yell_interval = GetConVarFloat(FindConVar("rescue_yell_interval"));
			if (yell_interval <= 0.0)
			{
				yell_interval = 6.0;
			}
		
			gt_CheckClientDead[survivorid] = CreateTimer(yell_interval, CheckClientDead, survivorid, TIMER_REPEAT);
			
			return Plugin_Stop;
		}
	}
	
	return Plugin_Continue;
}

void Rescue_Playsound(client, entity)
{
	if (!IsValidClient(client))
	{
		return;
	}
	
	if (!IsValidEntity(entity))
	{
		return;
	}
	
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

bool IsActiveRescueLimit()
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
	
	int act_rescue_count;
	
	char name[MAX_STRING_LENGTH];
	
	int i = -1;
	while ((i = FindEntityByClassname(i, classname)) != -1)
	{
		GetEntPropString(i, Prop_Data, "m_iName", name, sizeof(name));
		if (StrContains(name, GLOW_NAME) > -1)
		{
			act_rescue_count ++;
		}
	}
	
	int dead_players_count;
	
	for (i = 1; i <= MAX_PLAYERS; i ++)
	{
		if (IsValidClientTeam2(i) && !IsPlayerAlive(i)) 
		{
			dead_players_count ++;
		}
	}
	
	if (act_rescue_count < dead_players_count)
	{
		return false;
	}
	
	return true;
}

int IsActiveClientRescue(int client)
{
	if (!IsValidClient(client)) {return 0;}
	
	char classname[MAX_STRING_LENGTH];
	
	if (GetEngineVersion() == Engine_Left4Dead)
	{
		FormatEx(classname, sizeof(classname), "prop_glowing_object");
	}
	else
	{
		FormatEx(classname, sizeof(classname), "prop_dynamic");
	}
	
	char client_model[PLATFORM_MAX_PATH];
	GetClientModel(client, client_model, sizeof(client_model));
	
	char glow_model[PLATFORM_MAX_PATH];
	
	char targetname[MAX_TARGET_LENGTH];
	FormatEx(targetname, sizeof(targetname), "%s_%d", GLOW_NAME, GetClientUserId(client));
	
	char glow_name[MAX_STRING_LENGTH];
	
	int i = -1;
	while ((i = FindEntityByClassname(i, classname)) != -1)
	{
		GetEntPropString(i, Prop_Data, "m_iName", glow_name, sizeof(glow_name));
		GetEntPropString(i, Prop_Data, "m_ModelName", glow_model, sizeof(glow_model));
		
		if (!strcmp(glow_name, targetname))
		{
			return i;
		}
		else if (StrContains(glow_name, GLOW_NAME) > -1 && !strcmp(client_model, glow_model))
		{
			return i;
		}
	}
	
	return 0;
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
	for (int i = 1; i <= MAX_TIMERS; i++)
	{
		if (IsValidHandle(gt_Timer[i]))
		{
			CloseHandle(gt_Timer[i]);
		}
	}
	
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		gv_origin_dead_survivor[i][0] = 0.0;
		gv_origin_dead_survivor[i][1] = 0.0;
		gv_origin_dead_survivor[i][2] = 0.0;
	}
	
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		gb_spawn_playerid[i] = false;
		gi_time_playerid[i] = 0;
		
		if (IsValidHandle(gt_CheckClientDead[i]))
		{
			delete gt_CheckClientDead[i];
		}
		
		if (IsValidHandle(gt_CreateRescue[i]))
		{
			delete gt_CreateRescue[i];
		}
	}
	
	gb_finale_start = false;
	gb_rescue_spawn = false;
	
	for (int i = 1; i <= MAX_RESCUE; i++)
	{
		gi_rescue[i] = 0;
		
		gv_rescue_origin[i][0] = 0.0;
		gv_rescue_origin[i][1] = 0.0;
		gv_rescue_origin[i][2] = 0.0;
		
		gv_rescue_angles[i][0] = 0.0;
		gv_rescue_angles[i][1] = 0.0;
		gv_rescue_angles[i][2] = 0.0;
	}
	
	for (int i = 1; i <= MAX_FINAL_RESCUES; i++)
	{
		gi_final_rescue_slot[i] = 0;
		gi_final_rescue_slot_client[i] = 0;
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
	
	char classname[MAX_STRING_LENGTH];
	
	if (GetEngineVersion() == Engine_Left4Dead)
	{
		FormatEx(classname, sizeof(classname), "prop_glowing_object");
	}
	else
	{
		FormatEx(classname, sizeof(classname), "prop_dynamic");
	}
	
	int userid = GetClientUserId(client);
	
	char temp[MAX_STRING_LENGTH];
	FormatEx(temp, sizeof(temp), "%s_%d", GLOW_NAME, userid);
	
	char name[MAX_STRING_LENGTH];
		
	int i = -1;
	while ((i = FindEntityByClassname(i, classname)) != -1)
	{
		GetEntPropString(i, Prop_Data, "m_iName", name, sizeof(name));
		if (!strcmp(name, temp))
		{
			InputTarget(name, "Kill", _, time);
		}
	}
	
	//PrintToChatSkv(DEBUG_SLOT, "RemoveGlowRescue: userid %d", userid);
		
	for (i = 1; i <= MAX_FINAL_RESCUES; i++)
	{
		if (gi_final_rescue_slot_client[i] == userid)
		{
			gi_final_rescue_slot_client[i] = 0; // активная респа
		}
	}
}

int GetClientActiveProp(int client)
{
	if (!IsValidClient(client)) {return 0;}
	
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
	FormatEx(targetname, sizeof(targetname), "%s_%d", GLOW_NAME, GetClientUserId(client));
	
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

void SetOriginDeadSurvivors(int client)
{
	if (!IsValidClientTeam2(client)) {return;}
	
	float pos_spawn[3];
	GetEntPropVector(client, Prop_Data, "m_vecOrigin", pos_spawn);
	
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		if (!gv_origin_dead_survivor[i][0] && !gv_origin_dead_survivor[i][1] && !gv_origin_dead_survivor[i][2])
		{
			gv_origin_dead_survivor[i] = pos_spawn;
			
			break;
		}
	}
}

bool GetOriginDeadSurvivors(float pos_spawn[3])
{
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		if (gv_origin_dead_survivor[i][0] && gv_origin_dead_survivor[i][1] && gv_origin_dead_survivor[i][2])
		{
			pos_spawn = gv_origin_dead_survivor[i];
			
			gv_origin_dead_survivor[i][0] = 0.0;
			gv_origin_dead_survivor[i][1] = 0.0;
			gv_origin_dead_survivor[i][2] = 0.0;
			
			return true;
		}
	}
	
	return false;
}

void SearchDeadSurvivor()
{
	if (!gi_respawn_mode_finale)
	{
		return;
	}
	
	float death_time;
	float time_respawn;
	
	int survivorid;
	
	for (int i = 1; i <= MAX_PLAYERS; i ++)
	{
		if (IsValidClientTeam2(i) && !IsPlayerAlive(i))
		{
			survivorid = GetClientSurvivorId(i);
			if (survivorid)
			{
				death_time = GetGameTime() - GetEntPropFloat(i, Prop_Send, "m_flDeathTime");
				
				time_respawn = gf_rescue_min_dead_time_final - death_time;
				
				if (time_respawn <= 0.0)
				{
					time_respawn = 0.1;
				}
				
				if (IsValidHandle(gt_CreateRescue[survivorid]))
				{
					delete gt_CreateRescue[survivorid];
				}
				
				gt_CreateRescue[survivorid] = CreateTimer(time_respawn, CreateRescue, survivorid);
			}		
		}
	}
}

bool SetUserRespawn(int client)
{
	if (IsClientRespawned(client))
	{
		return true;
	}
	
	int survivorid = GetClientSurvivorId(client);
	if (!survivorid)
	{
		return false;
	}
	
	gb_spawn_playerid[survivorid] = true;
	
	return true;
}

bool IsClientRespawned(int client)
{
	int survivorid = GetClientSurvivorId(client);
	if (!survivorid)
	{
		return false;
	}
	
	return gb_spawn_playerid[survivorid];
}

void ReplaceRescue(int client, int new_client)
{
	if (!gb_finale_start)
	{
		return;
	}
	
	if (!IsValidClient(client)) {return;}
	if (!IsValidClient(new_client)) {return;}
	
	char classname[MAX_STRING_LENGTH];
	
	if (GetEngineVersion() == Engine_Left4Dead)
	{
		FormatEx(classname, sizeof(classname), "prop_glowing_object");
	}
	else
	{
		FormatEx(classname, sizeof(classname), "prop_dynamic");
	}
	
	int userid = GetClientUserId(client);
	
	char temp[MAX_STRING_LENGTH];
	FormatEx(temp, sizeof(temp), "%s_%d", GLOW_NAME, userid);
	
	int new_userid = GetClientUserId(new_client);
	
	char new_temp[MAX_STRING_LENGTH];
	FormatEx(new_temp, sizeof(new_temp), "targetname %s_%d", GLOW_NAME, new_userid);
	
	char name[MAX_STRING_LENGTH];
	
	int i = -1;
	while ((i = FindEntityByClassname(i, "prop_door_rotating")) != -1)
	{
		GetEntPropString(i, Prop_Data, "m_iName", name, sizeof(name));
		if (!strcmp(name, temp) && client == GetEntPropEnt(i, Prop_Data, "m_hOwnerEntity"))
		{
			SetEntPropEnt(i, Prop_Data, "m_hOwnerEntity", new_client);
			break;
		}
	}
	
	i = -1;
	while ((i = FindEntityByClassname(i, classname)) != -1)
	{
		GetEntPropString(i, Prop_Data, "m_iName", name, sizeof(name));
		if (!strcmp(name, temp))
		{
			InputTarget(name, "AddOutput", new_temp);
			
			break;
		}
	}
	
	//PrintToChatSkv(DEBUG_SLOT, "RemoveGlowRescue: userid %d", userid);
		
	for (i = 1; i <= MAX_FINAL_RESCUES; i++)
	{
		if (gi_final_rescue_slot_client[i] == userid)
		{
			gi_final_rescue_slot_client[i] = new_userid; // активная респа
		}
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
 * Проверяет клиента команды 2
 *
 * client 		- Client index.
 * return 		- true если client valid и false если нет
 */
bool IsValidClientAlive(int client)
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

/**
 * Проверяет клиента команды 2
 *
 * client 		- Client index.
 * return 		- true если client valid и false если нет
 */
bool IsValidClientTeam2Alive(int client)
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

int GetSpawnClient()
{
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		if (IsValidClientTeam2Alive(i) && !IsFakeClient(i))
		{
			return i;
		}
	}
	
	return 0;
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
int GetRandomSelect(char [] random_data, int value)
{
	#define MAX_RANDOM_SELECT 128
	
	value --;
	
	if (value < 1 || value > MAX_RANDOM_SELECT)
	{
		//LogError("GetRandomSelect: ERROR: INVALID value = %d", value + 1);
		return -1;
	}
	
	int massive_free[MAX_RANDOM_SELECT + 1];
	int a;

	for (int i = 1; i <= value; i++)
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
 * Посылает действие на все сущности с одинаковым targetname 
 *
 * targetname 	- имя сущностей на которых хотим подействовать
 * input 		- название действия
 * value 		- значение действия (например 1, если на свет передается brightness 1)
 * delay 		- кол-во секунд, через которое запускается действие
*/
void InputTarget(char [] targetname, char [] input, char [] value = "", float delay = 0.0)
{
	int entity = CreateEntityByName("logic_relay");
	
	if (entity == -1)
	{
		return;
	}

	DispatchKeyValue(entity, "targetname", "inputtarget_relay");
	DispatchKeyValue(entity, "spawnflags", "2");
	DispatchKeyValue(entity, "StartDisabled", "0");

	DispatchSpawn(entity);
	
	static char temp[MAX_STRING_LENGTH];
	FormatEx(temp, sizeof(temp), "%s,%s,%s,%f,-1", targetname, input, value, delay);
	DispatchKeyValue(entity, "OnTrigger", temp);
	
	AcceptEntityInput(entity, "Trigger");
	AcceptEntityInput(entity, "Kill");
}

bool SetNearRescueVectors(int entity)
{
	bool result;
	
	if (!IsValidEntity(entity))
	{
		return result;
	}
	
	float pos_entity[3];
	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", pos_entity);
	
	ClearSlotFinalNearOrigin();
	
	float pos_i[3]; 
	float distance_old; 
	float distance_entity_i;
	
	int slot; int near_rescue_slot;
	
	for (int j = 1; j <= MAX_FINAL_RESCUES; j ++)
	{
		distance_old = 0.0;
		
		pos_i[0] = 0.0;
		pos_i[1] = 0.0;
		pos_i[2] = 0.0;
		
		near_rescue_slot = 0;
		
		for (int i = 1; i <= MAX_RESCUE; i++)
		{
			if (gi_rescue[i] && !IsSavedSlotFinalNearOrigin(i))
			{
				//PrintToChatSkv(DEBUG_SLOT, "SetNearRescueVectors: i = %d, origin %d %d %d", i, RoundFloat(gv_rescue_origin[i][0]), RoundFloat(gv_rescue_origin[i][1]), RoundFloat(gv_rescue_origin[i][2]));
				
				distance_entity_i = GetVectorDistance(pos_entity, gv_rescue_origin[i]);
				//PrintToChatSkv(DEBUG_SLOT, "SetNearRescueVectors: distance_entity_i %d", RoundFloat(distance_entity_i));
				
				if (distance_old == 0 || distance_entity_i < distance_old)
				{
					distance_old = distance_entity_i;
					//PrintToChatSkv(DEBUG_SLOT, "SetNearRescueVectors: distance_old %d", RoundFloat(distance_old));
					
					pos_i = gv_rescue_origin[i];
					near_rescue_slot = i;
				}	
			}
		}
		
		if (pos_i[0] != 0.0 && pos_i[1] != 0.0 && pos_i[2] != 0.0)
		{
			slot = SaveSlotFinalNearOrigin(near_rescue_slot);
			if (slot)
			{
				gi_final_rescue_slot_client[slot] = 0;
				result = true;
			}
		}
	}
	
	return result;
}

bool GetVectorsFinalRescue(int client, float pos_spawn[3], float ang_spawn[3])
{
	int random;
	
	for (int i = 1; i <= MAX_FINAL_RESCUES; i++)
	{
		random = GetRandomSelect(gs_chance_rescue_slot, sizeof(gs_chance_rescue_slot));
		random ++;
		
		if (random <= MAX_FINAL_RESCUES)
		{
			if (gi_final_rescue_slot[random] && !gi_final_rescue_slot_client[random])
			{
				gi_final_rescue_slot_client[random] = GetClientUserId(client); // активная респа
					
				pos_spawn = gv_rescue_origin[gi_final_rescue_slot[random]];
				ang_spawn = gv_rescue_angles[gi_final_rescue_slot[random]];
					
				//PrintToChatSkv(true, "GetVectorsFinalRescue: set active random slot %d, userid %d", random, GetClientUserId(client));
				
				return true;
			}
		}
	}
	
	for (int i = 1; i <= MAX_FINAL_RESCUES; i++)
	{
		if (gi_final_rescue_slot[i] && !gi_final_rescue_slot_client[i])
		{
			gi_final_rescue_slot_client[i] = GetClientUserId(client); // активная респа
			
			pos_spawn = gv_rescue_origin[gi_final_rescue_slot[i]];
			ang_spawn = gv_rescue_angles[gi_final_rescue_slot[i]];
			
			return true;
		}
	}
	
	return false;
}

void ClearSlotFinalNearOrigin()
{
	for (int i = 1; i <= MAX_FINAL_RESCUES; i++)
	{
		gi_final_rescue_slot[i] = 0;
	}
}

int SaveSlotFinalNearOrigin(int slot)
{
	for (int i = 1; i <= MAX_FINAL_RESCUES; i++)
	{
		if (!gi_final_rescue_slot[i])
		{
			gi_final_rescue_slot[i] = slot;
			return i;
		}
	}
	
	return 0;
}

bool IsSavedSlotFinalNearOrigin(int slot)
{
	for (int i = 1; i <= MAX_FINAL_RESCUES; i++)
	{
		if (gi_final_rescue_slot[i] == slot)
		{
			return true;
		}
	}
	
	return false;
}

void SetRescueVectors(int rescue)
{
	if (!IsValidEntity(rescue))
	{
		return;
	}
	
	float pos_spawn[3];
	GetEntPropVector(rescue, Prop_Data, "m_vecOrigin", pos_spawn);
	
	float ang_spawn[3];
	GetEntPropVector(rescue, Prop_Data, "m_angRotation", ang_spawn);
	
	for (int i = 1; i <= MAX_RESCUE; i++)
	{
		if (!gi_rescue[i])
		{
			gi_rescue[i] = rescue; // сохраненная 
			
			gv_rescue_origin[i] = pos_spawn;
			gv_rescue_angles[i] = ang_spawn;
			
			break;
		}
	}
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
void InputEntity(int entity, char[] input, char[] value = "", float time_start = 0.0, float time_life = 0.0)
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
			FormatEx(temp, sizeof(temp), "OnUser1 !self:%s:%s:%f:-1", input, value, time_start);
				
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
 * entity 		- сущность, которая удаляется
 * time 		- кол-во секунд, через которое удаляется
*/
void InputKill(int entity, float time = 0.0)
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
	}
	else if (time > 0.0)
	{
		static char temp[MAX_STRING_LENGTH];
		
		if (HasEntProp(entity, Prop_Data, "m_iParent"))
		{
			if (IsValidEntity(GetEntPropEnt(entity, Prop_Data, "m_pParent")))
			{
				FormatEx(temp, sizeof(temp), "OnUser4 !self:ClearParent::%f:-1", time);
				SetVariantString(temp);
				AcceptEntityInput(entity, "AddOutput");
			}
		}
		
		FormatEx(temp, sizeof(temp), "OnUser4 !self:Kill::%f:-1", time);
		SetVariantString(temp);
		AcceptEntityInput(entity, "AddOutput");
	
		AcceptEntityInput(entity, "FireUser4");
	}
}

/**
 * ищет наиболее близкую или отдаленную сущность по классу
 *
 * entity 		- сущность, относительно которой происходит поиск (заданная сущность)
 * classname 	- класс искомой сущности
 * near 		- если true, то ищет самую близкую, иначе самую отдаленную
 * distance 	- дистанция поиска
 * return 		- сущность или 0, если не найдено
 */
int FindNearEntityByClassname(int entity, char[] classname, bool near = true, float distance = 0.0)
{
	int result;
	
	if (!IsValidEntity(entity))
	{
		return result;
	}
	
	float pos_entity[3];
	
	int parent = GetEntPropEnt(entity, Prop_Data, "m_pParent");
	
	if (IsValidEntity(parent))
	{
		GetEntPropVector(parent, Prop_Data, "m_vecOrigin", pos_entity);
	}
	else
	{
		GetEntPropVector(entity, Prop_Data, "m_vecOrigin", pos_entity);
	}
	
	float pos_i[3]; 
	float distance_old; 
	float distance_entity_i;
	
	int i = -1;
	while ((i = FindEntityByClassname(i, classname)) != -1)
	{
		if (i != entity)
		{  
			parent = GetEntPropEnt(i, Prop_Data, "m_pParent");
			
			if (IsValidEntity(parent))
			{
				GetEntPropVector(parent, Prop_Data, "m_vecOrigin", pos_i);
			}
			else
			{
				GetEntPropVector(i, Prop_Data, "m_vecOrigin", pos_i);
			}
			
			distance_entity_i = GetVectorDistance(pos_entity, pos_i);
			
			if (distance == 0.0)
			{
				if (distance_old == 0)
				{
					distance_old = distance_entity_i;
					result = i;
				}
				
				if (near)
				{
					if (distance_entity_i < distance_old)
					{
						distance_old = distance_entity_i;
						result = i;
					}
				}
				else
				{
					if (distance_entity_i > distance_old)
					{
						distance_old = distance_entity_i;
						result = i;
					}
				}
			}
			else if (distance >= distance_entity_i)
			{
				if (distance_old == 0)
				{
					distance_old = distance_entity_i;
					result = i;
				}
				
				if (near)
				{
					if (distance_entity_i < distance_old)
					{
						distance_old = distance_entity_i;
						result = i;
					}
				}
				else
				{
					if (distance_entity_i > distance_old)
					{
						distance_old = distance_entity_i;
						result = i;
					}
				}
			}			
		}
	}
	
	return result;
}