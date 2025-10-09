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
	version 	= "1.7",
	url 		= "https://forums.alliedmods.net/showthread.php?p=2829933#post2829933"
}

#define MAX_PLAYERS 				18
#define MAX_STRING_LENGTH			128
#define MAX_CLASSNAME_LENGTH 		64

#define FLOOR_HEIGH_SEARCH			75.0
#define GLOW_NAME 					"rf_rescue_glow"
#define VISIBLE_HEIGH				50.0
#define VISIBLE_HEIGH_INCAP			30.0

char 	gs_model_pills[]			= "models/w_models/weapons/w_eq_painpills.mdl";

bool 	gb_spawn_playerid			[MAX_SURVIVORID + 1];
int 	gi_time_playerid			[MAX_SURVIVORID + 1];

Handle 	gt_CheckClientDead			[MAX_SURVIVORID + 1];
Handle 	gt_CreateRescue				[MAX_SURVIVORID + 1];


#define MAX_TIMERS					MAX_PLAYERS * 4
Handle 	gt_Timer					[MAX_TIMERS + 1];

bool 	gb_finale_start;
bool 	gb_rescue_spawn				[MAX_SURVIVORID + 1];

ConVar 	gc_rescue_min_dead_time_final;
ConVar 	gc_respawn_mode_finale;
ConVar	gc_respawn_outside_time;
ConVar 	gc_rescue_door_opening_distance;
ConVar 	gc_rescue_renderamt;

float 	gf_rescue_min_dead_time_final;
int 	gi_respawn_mode_finale;
float 	gf_respawn_outside_time;

float 	gv_origin_dead_survivor		[MAX_SURVIVORID + 1][3];

#define MAX_RESCUE					64
int 	gi_rescue					[MAX_RESCUE + 1];

float 	gv_rescue_origin			[MAX_RESCUE + 1][3];
float 	gv_rescue_angles			[MAX_RESCUE + 1][3];

#define MAX_FINAL_RESCUES			3
int 	gi_final_rescue_slot		[MAX_FINAL_RESCUES + 1];
int 	gi_final_rescue_survivor	[MAX_FINAL_RESCUES + 1];

char 	gs_chance_rescue_slot[3];

char 	gs_name_clone				[MAX_STRING_LENGTH];

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

// INCAP SOUNDS
char 	gs_sound_Incap[][] =
{
		"help01",
		"help02",
		"help03",
		"help04"
};

char 	gs_random_Incap[sizeof(gs_sound_Incap)];

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
	HookEvent("finale_win", Event_finale_win);
		
	gc_rescue_min_dead_time_final = CreateConVar("rf_rescue_min_dead_time_final", "30", "The duration in seconds that a survivor must be dead before they can be rescued", _, true, 0.0, true, 600.0);
	SetConVarFlags(gc_rescue_min_dead_time_final, GetConVarFlags(gc_rescue_min_dead_time_final) & ~FCVAR_NOTIFY);
	
	HookConVarChange(gc_rescue_min_dead_time_final, OnConVarChanged_rescue_min_dead_time_final);
	
	gc_respawn_mode_finale = CreateConVar("rf_respawn_mode_finale", "2", "Respawn mode: 0 - respawn is disabled, 1 - respawn is active only once, 2 - respawn is active many times", _, true, 0.0, true, 2.0);
	SetConVarFlags(gc_respawn_mode_finale, GetConVarFlags(gc_respawn_mode_finale) & ~FCVAR_NOTIFY);
	
	HookConVarChange(gc_respawn_mode_finale, OnConVarChanged_respawn_mode_finale);
	
	gc_respawn_outside_time = CreateConVar("rf_respawn_outside_time", "60", "Time in seconds for automatic switching of respawn to respawn at the place of death if the respawn is out of reach. 0 - disabled", _, true, 0.0, true, 540.0);
	SetConVarFlags(gc_respawn_outside_time, GetConVarFlags(gc_respawn_outside_time) & ~FCVAR_NOTIFY);
	
	gc_rescue_door_opening_distance = CreateConVar("rf_rescue_door_opening_distance", "400", "Sets the automatic door opening distance. 0 - disabled", _, true, 0.0, true, 800.0);
	SetConVarFlags(gc_rescue_door_opening_distance, GetConVarFlags(gc_rescue_door_opening_distance) & ~FCVAR_NOTIFY);
	
	gc_rescue_renderamt = CreateConVar("rf_rescue_renderamt", "128", "Sets the transparency level: 0 - invisible, 255 - fully visible", _, true, 0.0, true, 255.0);
	SetConVarFlags(gc_rescue_renderamt, GetConVarFlags(gc_rescue_renderamt) & ~FCVAR_NOTIFY);
	
	HookConVarChange(gc_respawn_outside_time, OnConVarChanged_respawn_outside_time);
	
	AutoExecConfig(true, "respawn_final");
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
		for (int i = 1; i <= MAX_SURVIVORID; i++)
		{
			gb_spawn_playerid[i] = false;
		}
	}
	
	if (gi_respawn_mode_finale)
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
	FormatEx(gs_name_clone, sizeof(gs_name_clone), "empty");
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
	if (!strcmp(classname, "trigger_finale")) //  || !strcmp(classname, "trigger_finale_dlc3")
	{
		HookSingleEntityOutput(entity, "UseStart", UseStart, true);
		//HookSingleEntityOutput(entity, "FinaleStart", FinaleStart, true);
	}
}

void UseStart(char [] output, int entity, int activator, float delay)
{
	//PrintToChatAll("UseStart");
	
	if (gb_finale_start)
	{
		return;
	}
	
	gb_finale_start = true;
	
	bool result;
	
	if (SetNearRescueVectors(activator))
	{
		result = true;
	}
	
	for (int i = 1; i <= MAX_SURVIVORID; i++)
	{
		gb_rescue_spawn[i] = result;
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
	//PrintToChatAll("Check_FinaleStart");
	
	SearchDeadSurvivor();
	
	if (gb_finale_start)
	{
		return;
	}
	
	gb_finale_start = true;
	
	int client = GetSpawnClient();
	if (!client)
	{
		return;
	}
	
	bool result;
	
	if (SetNearRescueVectors(client))
	{
		result = true;
	}
	
	for (int i = 1; i <= MAX_SURVIVORID; i++)
	{
		gb_rescue_spawn[i] = result;
	}
}
/*
void FinaleStart(char [] output, int entity, int activator, float delay)
{
	//PrintToChatAll("FinaleStart");
		
	if (gb_finale_start)
	{
		return;
	}
	
	gb_finale_start = true;
	
	if (!gi_rescue[1])
	{
		return;
	}
	
	bool result;
	
	if (SetNearRescueVectors(activator))
	{
		result = true;
	}
	
	for (int i = 1; i <= MAX_SURVIVORID; i++)
	{
		gb_rescue_spawn[i] = result;
	}
}
*/
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
	int survivorid = GetClientSurvivorId(client);
	if (survivorid)
	{
		SetOriginDeadSurvivors(survivorid);
		
		if (IsValidHandle(gt_CheckClientDead[survivorid]))
		{
			delete gt_CheckClientDead[survivorid];
		}
		
		gt_CheckClientDead[survivorid] = CreateTimer(gf_rescue_min_dead_time_final, CheckClientDead, survivorid, TIMER_REPEAT);
		
		for (int i = 1; i <= MAX_FINAL_RESCUES; i++)
		{
			if (gi_final_rescue_survivor[i] == survivorid)
			{
				gi_final_rescue_survivor[i] = 0;
				break;
			}
		}
	}
}

Action:CheckClientDead(Handle timer, int survivorid)
{
	if (!gi_respawn_mode_finale)
	{
		return Plugin_Stop;
	}
	
	int client = GetClientOfSurvivorId(survivorid);
	if (!IsValidClient(client))
	{
		return Plugin_Continue;
	}
	
	if (IsPlayerAlive(client))
	{
		return Plugin_Stop;
	}
	
	if (IsValidHandle(gt_CreateRescue[survivorid]))
	{
		delete gt_CreateRescue[survivorid];
	}
	
	gt_CreateRescue[survivorid] = CreateTimer(3.0, CreateRescue, survivorid, TIMER_REPEAT);
	
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
	
	//PrintToChatAll("%s: targetname %s", name, targetname);
	
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
				
				char default_anim[MAX_CLASSNAME_LENGTH];
				GetEntPropString(entity, Prop_Data, "m_iszDefaultAnim", default_anim, sizeof(default_anim));
				
				if (StrContains(default_anim, "Rescue", false) > -1)
				{
					Respawn(client, survivor, pos_spawn, ang_spawn, false);
				}
				else
				{
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

void Respawn(int client, int rescuer, float pos_spawn[3], float ang_spawn[3], bool incap = false)
{
	if (!IsValidClient(client))
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
	
	pos_spawn[2] += 10.0;
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
				
		Event event = CreateEvent("player_incapacitated");
		event.SetInt("userid", GetClientUserId(client));
		event.SetInt("attacker", GetClientUserId(client));
		event.Fire();
		
		//PrintToChatAll("Respawn: set incap");
	}
		
	SetUserRespawn(client);
}

Action:CreateRescue(Handle timer, int survivorid)
{
	if (!gb_finale_start)
	{
		return Plugin_Stop;
	}	
	
	if (!gi_respawn_mode_finale)
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
		return Plugin_Stop;
	}
	
	if (!gf_respawn_outside_time)
	{
		gb_rescue_spawn[survivorid] = true;
	}
	
	if (gi_respawn_mode_finale == 1 && IsClientRespawned(client))
	{
		return Plugin_Stop;
	}
	
	if (IsActiveClientRescue(client))
	{
		//PrintToChatAll("CreateRescue: IsActiveClientRescue");
		return Plugin_Continue;
	}
	
	float pos_spawn[3]; float ang_spawn[3];
	
	//PrintToChatAll("CreateRescue: gb_rescue_spawn %s", gb_rescue_spawn[survivorid] ? "true":"false");
	
	if (!gb_rescue_spawn[survivorid])
	{
		if (!GetOriginDeadSurvivors(survivorid, pos_spawn))
		{
			return Plugin_Stop;
		}
		
		//PrintToChatAll("CreateRescue: GetOriginDeadSurvivors");
	}
	else 
	{
		int rescue_slot = GetVectorsFinalRescue(survivorid, pos_spawn, ang_spawn);
		
		if (!rescue_slot)
		{
			//PrintToChatAll("CreateRescue: !GetVectorsFinalRescue ");
			return Plugin_Continue;
		}
		
		if (IsAnySurvivorNearOrigin(pos_spawn))
		{
			gi_final_rescue_survivor[rescue_slot] = 0; 
			
			//PrintToChatAll("CreateRescue: IsAnySurvivorNearOrigin");
			return Plugin_Continue;
		}
	}	
		
	//PrintToChatAll("CreateRescue: create at %d %d %d", RoundFloat(pos_spawn[0]), RoundFloat(pos_spawn[1]), RoundFloat(pos_spawn[2]));
	
	char temp[PLATFORM_MAX_PATH];
	GetClientModel(client, temp, sizeof(temp));
	
	int entity;
	
	if (GetEngineVersion() == Engine_Left4Dead)
	{
		entity = CreateEntityByName("prop_glowing_object");
		if (entity == -1)
		{
			return Plugin_Continue;
		}
		
		DispatchKeyValue(entity, "StartGlowing", "1");
		DispatchKeyValue(entity, "GlowForTeam", "2");
	}
	else
	{
		entity = CreateEntityByName("prop_dynamic");
		if (entity == -1)
		{
			return Plugin_Continue;
		}
		
		DispatchKeyValue(entity, "StartGlowing", "0");
		DispatchKeyValue(entity, "GlowForTeam", "-1");
		
		DispatchKeyValue(entity, "glowstate", "0");
		DispatchKeyValue(entity, "glowrangemin", "150");
		DispatchKeyValue(entity, "glowrange", "0");
		DispatchKeyValue(entity, "glowcolor", "0 0 0");
		
		InputEntity(entity, "StartGlowing", _, 0.1);
	}
	
	char targetname[MAX_TARGET_LENGTH];
	FormatEx(targetname, sizeof(targetname), "%s_%d", GLOW_NAME, survivorid);
	
	DispatchKeyValue(entity, "targetname", targetname);
	DispatchKeyValue(entity, "model", temp);
	DispatchKeyValue(entity, "solid", "0");
	
	if (gb_rescue_spawn[survivorid])
	{
		DispatchKeyValue(entity, "DefaultAnim", "Idle_Rescue_01c");
	}
	else
	{
		DispatchKeyValue(entity, "DefaultAnim", "Idle_Incap_Pistol");
	}
	
	DispatchKeyValue(entity, "rendermode", "1");
	DispatchKeyValueInt(entity, "renderamt", GetConVarInt(gc_rescue_renderamt)); // 0
	//DispatchKeyValue(entity, "rendercolor", "255 0 0");
	
	DispatchKeyValueVector(entity, "origin", pos_spawn);
	DispatchKeyValueVector(entity, "angles", ang_spawn);
		
	DispatchSpawn(entity);
	
	CloseNearDoors(entity);
	
	int visible_prop = CreateEntityByName("prop_door_rotating");
	if (visible_prop == -1)
	{
		return Plugin_Continue;
	}
	
	SetEntPropEnt(visible_prop, Prop_Data, "m_hOwnerEntity", entity);
	
	DispatchKeyValue(visible_prop, "targetname", targetname);
	
	if (gb_rescue_spawn[survivorid])
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
	
	int enteffects = GetEntProp(visible_prop, Prop_Send, "m_fEffects");
	enteffects |= 32;
	SetEntProp(visible_prop, Prop_Send, "m_fEffects", enteffects);
	
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
	
	if (GetEngineVersion() == Engine_Left4Dead)
	{
		int pills = FindDistEntityByClassname(entity, "weapon_pain_pills_spawn", 50.0);
		if (!pills)
		{
			float pos_entity[3];
			GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos_entity);
			
			pills = CreateEntityByName("weapon_pain_pills_spawn");
			if (IsValidEntity(pills))
			{
				SetEntPropEnt(pills, Prop_Data, "m_hOwnerEntity", entity);
				
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
				
				//PrintToChatSkv(true, "CreateRescue: spawn pills %d, targetname %s", pills, targetname);
			}
		}
		else
		{
			DispatchKeyValue(pills, "targetname", targetname);
			SetEntPropEnt(pills, Prop_Data, "m_hOwnerEntity", entity);
		}
	}
	
	if (gi_rescue[1])
	{
		gb_rescue_spawn[survivorid] = true;
	}
		
	return Plugin_Stop;
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
	
	SetEntPropEnt(door, Prop_Data, "m_hOwnerEntity", entity);
	//PrintToChatAll("CloseNearDoors: set hook for door %d", door);
	
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

void Event_player_use(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!gb_finale_start)
	{
		return;
	}	
	
	int rescuer = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsValidClientTeam2Alive(rescuer)) {return;}
	
	int entity = GetEventInt(event, "targetid");
	//PrintToChatAll("%s: entity %d, rescuer %d", name, entity, rescuer);
	
	if (!IsValidEntity(entity)) {return;}
	
	char classname[PLATFORM_MAX_PATH];
	GetEntityClassname(entity, classname, sizeof(classname));
	
	//PrintToChatAll("%s: classname %s", name, classname);
	
	if (!strcmp(classname, "prop_door_rotating"))
	{
		int rescue = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");
		if (IsValidEntity(rescue))
		{
			//PrintToChatAll("%s: door %d, rescuer %d", name, entity, rescuer);
			OpenDoor(rescue, rescuer);
		}
	}
	else if (!strcmp(classname, "weapon_pain_pills_spawn") || !strcmp(classname, "weapon_pain_pills")) 
	{
		//PrintToChatAll("%s: %N use classname %s %d", name, rescuer, classname, entity);
		
		char targetname[MAX_STRING_LENGTH];
		GetEntPropString(entity, Prop_Data, "m_iName", targetname, sizeof(targetname));
		
		if (StrContains(targetname, GLOW_NAME) > -1)
		{
			int client = GetClientOfNameEntity(entity);
			if (IsValidClient(client))
			{
				int rescue = GetClientActiveProp(client);
				if (rescue)
				{
					if (IsValidEntity(rescue))
					{
						//PrintToChatAll("%s: door %d, rescuer %d", name, entity, rescuer);
						OpenDoor(rescue, rescuer);
					}
				}
			}
		}
	}
}

bool OpenDoor(int rescue, int rescuer)
{
	if (!IsValidEntity(rescue))
	{
		return false;
	}
	
	char classname[MAX_CLASSNAME_LENGTH];
	GetEntityClassname(rescue, classname, sizeof(classname));
	
	char classname_rescue[MAX_CLASSNAME_LENGTH];
	
	if (GetEngineVersion() == Engine_Left4Dead)
	{
		FormatEx(classname_rescue, sizeof(classname_rescue), "prop_glowing_object");
	}
	else
	{
		FormatEx(classname_rescue, sizeof(classname_rescue), "prop_dynamic");
	}
	
	if (strcmp(classname, classname_rescue))
	{
		return false;
	}
	
	if (!rescuer || !IsValidEntity(rescuer)) 
	{
		return false;
	}
	
	//PrintToChatAll("OpenDoor: rescue %d, rescuer %d", rescue, rescuer);
	
	float pos_spawn[3];
	GetEntPropVector(rescue, Prop_Data, "m_vecOrigin", pos_spawn);
	
	float ang_spawn[3];
	GetEntPropVector(rescue, Prop_Data, "m_angRotation", ang_spawn);
				
	if (GetEngineVersion() == Engine_Left4Dead2)
	{
		FreeBotOrder(rescuer);
	}
	
	//PrintToChatAll("OpenDoor: respawn force");
	
	char default_anim[MAX_CLASSNAME_LENGTH];
	GetEntPropString(rescue, Prop_Data, "m_iszDefaultAnim", default_anim, sizeof(default_anim));
	
	bool incap;
	
	if (StrContains(default_anim, "Incap", false) > -1)
	{
		incap = true;
	}
		
	Respawn(GetClientOfNameEntity(rescue), rescuer, pos_spawn, ang_spawn, incap);
		
	return true;
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
	
	if (IsPlayerAlive(client) || !IsValidClient(client))
	{
		char name[MAX_STRING_LENGTH];
		GetEntPropString(entity, Prop_Data, "m_iName", name, sizeof(name));
			
		InputTarget(name, "Kill");
		return Plugin_Stop;
	}
	
	int respawn_outside_time = RoundFloat(gf_respawn_outside_time);
	if (respawn_outside_time)
	{
		if (RoundFloat(GetGameTime()) - gi_time_playerid[survivorid] >= respawn_outside_time)
		{
			gb_rescue_spawn[survivorid] = false;
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
	
	float rescue_door_opening_distance = GetConVarFloat(gc_rescue_door_opening_distance);
	if (rescue_door_opening_distance)
	{
		if (rescue_door_opening_distance < 200.0)
		{
			rescue_door_opening_distance = 200.0;
		}
		
		int rescuer = IsAnySurvivorNearEntity(entity, rescue_door_opening_distance);
		if (OpenDoor(entity, rescuer))
		{
			return Plugin_Stop;
		}
	}
		
	Rescue_Playsound(client, entity);
	
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
	
	char default_anim[MAX_CLASSNAME_LENGTH];
	GetEntPropString(entity, Prop_Data, "m_iszDefaultAnim", default_anim, sizeof(default_anim));
				
	if (StrContains(default_anim, "Incap", false) > -1)
	{
		int vocalize_track = GetRandomSelect(gs_random_Incap, sizeof(gs_random_Incap));
		FormatEx(temp, sizeof(temp), "player/survivor/voice/TeenGirl/%s.wav", gs_sound_Incap[vocalize_track]);
	}
	
	float pos_spawn[3];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", pos_spawn);
	
	pos_spawn[2] += VISIBLE_HEIGH + 5.0;
	
	EmitAmbientSound(temp, pos_spawn, entity);
}

int IsActiveClientRescue(int client)
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
	
	char client_model[PLATFORM_MAX_PATH];
	GetClientModel(client, client_model, sizeof(client_model));
	
	char glow_model[PLATFORM_MAX_PATH];
	
	char targetname[MAX_TARGET_LENGTH];
	FormatEx(targetname, sizeof(targetname), "%s_%d", GLOW_NAME, survivorid);
	
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
	
	LogError("GetFreeTimerSlot: no free slots");
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
	
	for (int i = 1; i <= MAX_SURVIVORID; i++)
	{
		gv_origin_dead_survivor[i][0] = 0.0;
		gv_origin_dead_survivor[i][1] = 0.0;
		gv_origin_dead_survivor[i][2] = 0.0;
		
		gb_rescue_spawn[i] = false;
		
		gb_spawn_playerid[i] = false;
		gi_time_playerid[i] = 0;
	}
	
	for (int i = 1; i <= MAX_SURVIVORID; i++)
	{
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
		gi_final_rescue_survivor[i] = 0;
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
		
	int i = -1;
	while ((i = FindEntityByClassname(i, classname)) != -1)
	{
		GetEntPropString(i, Prop_Data, "m_iName", name, sizeof(name));
		if (!strcmp(name, temp))
		{
			InputTarget(name, "Kill", _, time);
		}
	}
	
	for (i = 1; i <= MAX_FINAL_RESCUES; i++)
	{
		if (gi_final_rescue_survivor[i] == survivorid)
		{
			gi_final_rescue_survivor[i] = 0;
			
			//PrintToChatAll("RemoveGlowRescue: clear gi_final_rescue_survivor %d ", i);
			break;
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

void SetOriginDeadSurvivors(int survivorid)
{
	int client = GetClientOfSurvivorId(survivorid);
	if (!IsValidClientTeam2(client)) {return;}
		
	float pos_spawn[3];
	GetEntPropVector(client, Prop_Data, "m_vecOrigin", pos_spawn);
	
	gv_origin_dead_survivor[survivorid] = pos_spawn;
	
	//PrintToChatAll("SetOriginDeadSurvivors: client origin %d %d %d", RoundFloat(pos_spawn[0]), RoundFloat(pos_spawn[1]), RoundFloat(pos_spawn[2]));
	
	if (strcmp(gs_name_clone, "empty"))
	{
		float time = gf_rescue_min_dead_time_final;
		
		time -= 1.0;
		if (time > 0.0)
		{
			CreateTimer(time, SetOriginCloneSurvivor, survivorid, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

Action:SetOriginCloneSurvivor(Handle timer, int survivorid)
{
	if (!survivorid)
	{
		return;
	}
	
	int clone = GetSurvivorClone(survivorid);
	if (!clone)
	{
		return;
	}
	
	float pos_spawn[3];
	GetEntPropVector(clone, Prop_Data, "m_vecOrigin", pos_spawn);
	
	gv_origin_dead_survivor[survivorid] = pos_spawn;
	
	//PrintToChatAll("SetOriginCloneSurvivor: clone origin %d %d %d", RoundFloat(pos_spawn[0]), RoundFloat(pos_spawn[1]), RoundFloat(pos_spawn[2]));
}

bool GetOriginDeadSurvivors(int survivorid, float pos_spawn[3])
{
	for (int i = 1; i <= MAX_SURVIVORID; i++)
	{
		if (i == survivorid)
		{
			if (!gv_origin_dead_survivor[i][0] && !gv_origin_dead_survivor[i][1] && !gv_origin_dead_survivor[i][2])
			{
				if (GetOriginAliveSurvivors(pos_spawn))
				{
					return true;
				}
				else
				{
					//PrintToChatAll("GetOriginDeadSurvivors: ERROR GetOriginAliveSurvivors false");
					return false;
				}
			}
			else
			{
				pos_spawn = gv_origin_dead_survivor[i];
			
				gv_origin_dead_survivor[i][0] = 0.0;
				gv_origin_dead_survivor[i][1] = 0.0;
				gv_origin_dead_survivor[i][2] = 0.0;
			
				return true;
			}
		}
	}
	
	return false;
}

bool GetOriginAliveSurvivors(float pos_spawn[3])
{
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		if (IsValidClientTeam2Alive(i))
		{
			GetClientAbsOrigin(i, pos_spawn);
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
				
				if (!IsValidHandle(gt_CheckClientDead[survivorid]))
				{
					gt_CheckClientDead[survivorid] = CreateTimer(time_respawn, CheckClientDead, survivorid, TIMER_REPEAT);
				}
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
	
	float distance_old; 
	float distance_entity_i;
	
	int near_rescue_slot;
	
	for (int j = 1; j <= MAX_FINAL_RESCUES; j ++)
	{
		distance_old = 0.0;
		
		near_rescue_slot = 0;
		
		for (int i = 1; i <= MAX_RESCUE; i++)
		{
			if (gi_rescue[i] && !IsSavedSlotFinalNearOrigin(i))
			{
				//PrintToChatAll("SetNearRescueVectors: i = %d, origin %d %d %d", i, RoundFloat(gv_rescue_origin[i][0]), RoundFloat(gv_rescue_origin[i][1]), RoundFloat(gv_rescue_origin[i][2]));
				
				distance_entity_i = GetVectorDistance(pos_entity, gv_rescue_origin[i]);
				//PrintToChatAll("SetNearRescueVectors: distance_entity_i %d", RoundFloat(distance_entity_i));
				
				if (distance_old == 0 || distance_entity_i < distance_old)
				{
					distance_old = distance_entity_i;
					//PrintToChatAll("SetNearRescueVectors: distance_old %d", RoundFloat(distance_old));
					
					near_rescue_slot = i;
				}
			}
		}
		
		if (near_rescue_slot)
		{
			//PrintToChatAll("SetNearRescueVectors: near_rescue_slot %d", near_rescue_slot);
			
			if (j == 1)
			{
				gi_final_rescue_slot[j] = near_rescue_slot;
				//PrintToChatAll("SetNearRescueVectors: near_rescue_slot %d ", near_rescue_slot);
			}
			else
			{
				float dist = GetVectorDistance(gv_rescue_origin[gi_final_rescue_slot[1]], gv_rescue_origin[near_rescue_slot]);
				//PrintToChatAll("SetNearRescueVectors: dist %f", dist);
				
				if (dist < 750.0)
				{
					gi_final_rescue_slot[j] = near_rescue_slot;
					//PrintToChatAll("SetNearRescueVectors: near_rescue_slot %d ", near_rescue_slot);
				}
			}
			
			gi_final_rescue_survivor[j] = 0;
			
			result = true;
			
			
		}
		else
		{
			break;
		}
	}
	
	return result;
}

void ClearSlotFinalNearOrigin()
{
	for (int i = 1; i <= MAX_FINAL_RESCUES; i++)
	{
		gi_final_rescue_slot[i] = 0;
		gi_final_rescue_survivor[i] = 0;
	}
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

int GetVectorsFinalRescue(int survivorid, float pos_spawn[3], float ang_spawn[3])
{
	//PrintToChatAll("GetVectorsFinalRescue: survivorid %d, pos_spawn %d %d %d", survivorid, RoundFloat(pos_spawn[0]), RoundFloat(pos_spawn[1]), RoundFloat(pos_spawn[2]));
	
	if (!survivorid)
	{
		//PrintToChatAll("GetVectorsFinalRescue: ERROR survivorid is NULL");
		return 0;
	}
		
	int size;
	
	for (int i = 1; i <= MAX_FINAL_RESCUES; i++)
	{
		if (gi_final_rescue_slot[i])
		{
			size ++;
		}
	}
	
	//PrintToChatAll("GetVectorsFinalRescue: size %d ", size);
	
	if (!size)
	{
		return 0;
	}
	
	int free_slots;
	
	for (int i = 1; i <= size; i++)
	{
		//PrintToChatAll("GetVectorsFinalRescue: gi_final_rescue_survivor[%d] %d", i, gi_final_rescue_survivor[i]);
		
		if (!gi_final_rescue_survivor[i])
		{
			free_slots ++;
		}
	}
	
	//PrintToChatAll("GetVectorsFinalRescue: free_slots %d ", free_slots);
	
	if (!free_slots)
	{
		return 0;
	}
	
	int slot;
	
	while ((slot = GetRandomSlot(survivorid, pos_spawn, ang_spawn)) == 0)
	{
		//PrintToChatAll("GetVectorsFinalRescue: GetRandomSlot false");
	}
	
	return slot;
}

int GetRandomSlot(int survivorid, float pos_spawn[3], float ang_spawn[3])
{
	int random = GetRandomSelect(gs_chance_rescue_slot, sizeof(gs_chance_rescue_slot));
	random ++;
	
	//PrintToChatAll("GetRandomSlot: random %d ", random);
	
	if (gi_final_rescue_survivor[random])
	{
		return 0;
	}
	
	if (!gi_final_rescue_slot[random])
	{
		return 0;
	}
	
	gi_final_rescue_survivor[random] = survivorid; // активная респа
					
	pos_spawn = gv_rescue_origin[gi_final_rescue_slot[random]];
	ang_spawn = gv_rescue_angles[gi_final_rescue_slot[random]];
	
	return random;
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
	
	ang_spawn[0] = 0.0;
	ang_spawn[2] = 0.0;
	
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

int IsAnySurvivorNearOrigin(float pos_spawn[3])
{
	float pos_survivor[3];
	
	float pos_spawn_up[3];
	
	pos_spawn_up = pos_spawn;
	pos_spawn_up[2] += 70.0;
			
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		if (IsValidClientTeam2Alive(i)) //  && !IsFakeClient(i)
		{
			GetClientEyePosition(i, pos_survivor);
			
			if (IsVisibleOrigin(pos_survivor, pos_spawn))
			{
				//PrintToChatSkv(DEBUG_VISIBLE, "IsAnySurvivorNear: visible, return %d", i);
				return i;				
			}
			
			if (IsVisibleOrigin(pos_survivor, pos_spawn_up))
			{
				//PrintToChatSkv(DEBUG_VISIBLE, "IsAnySurvivorNear: visible, return %d", i);
				return i;				
			}
			/*
			if (GetVectorDistance(pos_spawn, pos_survivor) <= distance)
			{
				if (IsSameFloor(pos_spawn[2], pos_survivor[2]))
				{
					if (IsVisibleOrigin(pos_survivor, pos_spawn))
					{
						return i;
					}
				}
			}
			
			if (GetVectorDistance(pos_spawn_up, pos_survivor) <= distance)
			{
				if (IsSameFloor(pos_spawn_up[2], pos_survivor[2]))
				{
					if (IsVisibleOrigin(pos_survivor, pos_spawn_up))
					{
						return i;
					}
				}
			}
			
			GetClientEyePosition(i, pos_survivor);
				
			if (GetVectorDistance(pos_spawn, pos_survivor) <= distance)
			{
				if (IsSameFloor(pos_spawn[2], pos_survivor[2]))
				{
					GetClientEyePosition(i, client_pos);
					if (IsVisibleOrigin(client_pos, pos_spawn))
					{
						//PrintToChatSkv(DEBUG_VISIBLE, "IsAnySurvivorNear: visible, return %d", i);
						return i;				
					}
				}
			}
			*/
		}
	}
	
	//PrintToChatSkv(DEBUG_VISIBLE, "IsAnySurvivorNear: return 0");
	return 0;
}

int IsAnySurvivorNearEntity(int entity, float distance)
{
	float pos_entity[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos_entity);
	
	float pos_entity_up[3];
	
	pos_entity_up = pos_entity;
	pos_entity_up[2] += 70.0;
	
	float pos_survivor[3];
	
	int door = -1;
	float pos_door[3];
	
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		if (IsValidClientTeam2Alive(i)) //  && !IsFakeClient(i)
		{
			GetClientEyePosition(i, pos_survivor);
				
			if (GetVectorDistance(pos_entity, pos_survivor) <= distance)
			{
				return i;
			}
			
			if (IsVisible(i, entity))
			{
				return i;
			}
				
			if (IsVisibleOrigin(pos_survivor, pos_entity) || IsVisibleOrigin(pos_survivor, pos_entity_up))
			{
				return i;
			}
				
			door = GetDoorRescue(entity);
			GetEntPropVector(door, Prop_Send, "m_vecOrigin", pos_door);
			pos_door[2] += 50.0;
					
			if (IsVisibleOrigin(pos_survivor, pos_door))
			{
				//PrintToChatSkv(DEBUG_VISIBLE, "IsAnySurvivorNear: return %d", i);
				return i;
			}
		}
	}
	
	//PrintToChatSkv(DEBUG_VISIBLE, "IsAnySurvivorNear: return 0");
	return 0;
}

int GetDoorRescue(int rescue)
{
	int door = -1;
	while ((door = FindEntityByClassname(door, "prop_door_rotating")) != -1)
	{
		if (rescue == GetEntPropEnt(door, Prop_Data, "m_hOwnerEntity"))
		{
			return door;
		}
	}
	
	return 0;
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
	char sBuffer[128];
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
	char sBuffer[96];
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

stock bool IsInSight(int client, float vec_origin[3], float fov)
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

bool IsVisibleOrigin(float pos1[3], float pos2[3])
{
	float pos_start[3];
	pos_start = pos1;
	
	float pos_end[3];
	pos_end = pos2;
	
	Handle trace = TR_TraceRayFilterEx(pos_start, pos_end, MASK_SOLID, RayType_EndPoint, TraceFilter_Visible);
	if (TR_DidHit(trace))
	{
		//PrintToChatSkv(true, "IsVisible: return false");
		
		CloseHandle(trace);
		return false;
	}
	
	//PrintToChatSkv(true, "IsVisible: return true");
	
	CloseHandle(trace);
	return true;
}

bool IsVisible(int client, int entity)
{
	if (!IsValidEntity(entity))
	{
		return false;
	}
	
	if (!IsValidClientTeam2Alive(client))
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
		//PrintToChatSkv(true, "IsVisible: TR_DidHit, index %d", index);
		
		if (index == entity)
		{
			CloseHandle(trace);
			return true;
		}
		
		CloseHandle(trace);
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

/**
 * перемещает координаты вперед-назад согласно углам
 *
 * vec_origin 		- начальные координаты
 * vec_angles 		- углы
 * distance			- расстояние, если +, то вперед, если минус назад
 */
void MovePos_Forward(float vec_origin[3], float vec_angles[3], float distance)
{
	float direction[3];
		
	GetAngleVectors(vec_angles, direction, NULL_VECTOR, NULL_VECTOR);
	
	vec_origin[0] = vec_origin[0] + direction[0] * distance;
	vec_origin[1] = vec_origin[1] + direction[1] * distance;
	vec_origin[2] = vec_origin[2] + direction[2] * distance;
}

public OnPluginReviveSurvivor(char[] clone_name)
{
	FormatEx(gs_name_clone, sizeof(gs_name_clone), clone_name);
	//PrintToChatAll("OnPluginReviveSurvivor: %s", clone_name);
}

int GetSurvivorClone(int survivorid)
{
	if (!strcmp(gs_name_clone, "empty"))
	{
		return false;
	}
	
	char targetname[MAX_TARGET_LENGTH];
	FormatEx(targetname, sizeof(targetname), "%s_%d", gs_name_clone, survivorid);
	
	char buffer[MAX_STRING_LENGTH];
	
	int i = -1;
	while ((i = FindEntityByClassname(i, "commentary_dummy")) != -1)
	{
		GetEntPropString(i, Prop_Data, "m_iName", buffer, sizeof(buffer));
			
		if (!strcmp(buffer, targetname))
		{
			return i;
		}
	}

	return 0;
}
