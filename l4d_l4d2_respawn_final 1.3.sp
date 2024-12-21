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


public Plugin:myinfo = 
{
	name 		= "[L4D/L4D2] Respawn Final",
	author 		= "Skv",
	description = "The plugin allows survivors to respawn in the finale",
	version 	= "1.3",
	url 		= "https://forums.alliedmods.net/showthread.php?p=2829933#post2829933"
}

bool DEBUG = false;

#define MAX_PLAYERS 			18
#define MAX_STRING_LENGTH		128

#define GLOW_NAME 				"rf_rescue_glow"
#define VISIBLE_HEIGH			80.0

char 	gs_model_pills[]		= "models/w_models/weapons/w_eq_painpills.mdl";


#define MAX_TIMERSLOTS			64
Handle 	gt_Timers				[MAX_TIMERSLOTS + 1];

Handle 	gt_UserTimers			[MAX_PLAYERS + 1];

int 	gi_users				[MAX_PLAYERS + 1];
int 	gi_users_respawn		[MAX_PLAYERS + 1];
int 	gi_users_calls			[MAX_PLAYERS + 1];

float 	gv_origin_rescue[3];
float 	gv_angles_rescue[3];

bool 	gb_finale_start;
bool 	gb_rescue_spawn;

ConVar 	gc_rescue_min_dead_time_final;
ConVar 	gc_respawn_mode_finale;
ConVar	gc_respawn_outside_rescue;
ConVar	gc_respawn_outside_time;

float 	gf_rescue_min_dead_time_final;
int 	gi_respawn_mode_finale;
bool 	gb_respawn_outside_rescue;

float 	gf_origin_dead_survivor[MAX_PLAYERS + 1][3];

#define MAX_RESCUE				64
int 	gi_rescue_vectors		[MAX_RESCUE + 1][7]; 

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
		strcopy(error, err_max, "Plugin only supports Left 4 Dead (2)");
		return APLRes_SilentFailure;
	}
			
	return APLRes_Success;
}

public OnPluginStart()
{
	HookEvent("player_team", Event_player_team);
	HookEvent("player_death", Event_player_death);
	
	HookEvent("player_spawn", Event_player_spawn);
	//HookEvent("survivor_rescued", Event_survivor_rescued);
	
	HookEvent("mission_lost", Event_mission_lost);
	HookEvent("entity_visible", Event_entity_visible);
	
	HookEvent("finale_start", Event_finale_start);
	HookEvent("finale_escape_start", Event_finale_escape_start);
	
	gc_rescue_min_dead_time_final = CreateConVar("rf_rescue_min_dead_time_final", "30", "The duration in seconds that a survivor must be dead before they can be rescued", _, true, 0.0, true, 600.0);
	SetConVarFlags(gc_rescue_min_dead_time_final, GetConVarFlags(gc_rescue_min_dead_time_final) & ~FCVAR_NOTIFY);
	
	gc_respawn_mode_finale = CreateConVar("rf_respawn_mode_finale", "2", "Respawn mode: 0 - respawn is disabled, 1 - respawn is active only once, 2 - respawn is active many times", _, true, 0.0, true, 2.0);
	SetConVarFlags(gc_respawn_mode_finale, GetConVarFlags(gc_respawn_mode_finale) & ~FCVAR_NOTIFY);
	
	HookConVarChange(gc_respawn_mode_finale, OnConVarChanged_respawn_mode_finale);
	
	gc_respawn_outside_rescue = CreateConVar("rf_respawn_outside_rescue", "1", "Possibility of respawning at the place of death if rescue rooms are not found", _, true, 0.0, true, 1.0);
	SetConVarFlags(gc_respawn_outside_rescue, GetConVarFlags(gc_respawn_outside_rescue) & ~FCVAR_NOTIFY);
	
	HookConVarChange(gc_respawn_outside_rescue, OnConVarChanged_respawn_outside_rescue);
	
	gc_respawn_outside_time = CreateConVar("rf_respawn_outside_time", "120", "Time in seconds for automatic switching of respawn to respawn at the place of death if the respawn is out of reach. 0 - disabled", _, true, 0.0, true, 540.0);
	SetConVarFlags(gc_respawn_outside_time, GetConVarFlags(gc_respawn_outside_time) & ~FCVAR_NOTIFY);
	
	AutoExecConfig(true, "respawn_final");
	
	RegAdminCmd("sm_char", Cmd_char, ADMFLAG_CONFIG, "");
}

public Action:Cmd_char(client, args)
{
	int client_character;
	char temp[PLATFORM_MAX_PATH];
	
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		if (IsValidClientTeam2(i))
		{
			client_character = GetEntProp(i, Prop_Send, "m_survivorCharacter");
			GetClientModel(i, temp, sizeof(temp));
			
			PrintToChat(client, "%N character %d, model %s", i, client_character, temp);
		}
	}
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
		for (int i = 0; i <= MAX_PLAYERS; i++)
		{
			gi_users_respawn[i] = 0;
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
	
	gf_rescue_min_dead_time_final = GetConVarFloat(gc_rescue_min_dead_time_final);
	if (DEBUG)
	{
		gf_rescue_min_dead_time_final = 5.0;
	}
	
	gi_respawn_mode_finale = GetConVarInt(gc_respawn_mode_finale);
	gb_respawn_outside_rescue = GetConVarBool(gc_respawn_outside_rescue);
	
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

public OnServerEmpty()
{
	Delete_Timers();
}
/*
public OnEscapeVehicleLeaving()
{
	Delete_Timers();
}
*/
public OnEntityCreated(entity, const String:classname[])
{
	if (!strcmp(classname, "finale_trigger") || !strcmp(classname, "trigger_finale") || !strcmp(classname, "trigger_finale_dlc3"))
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
	
	if (SetNearRescueOrigin(activator))
	{
		gb_rescue_spawn = true;
	}
}

void Event_finale_start(Handle:event, const String:name[], bool:dontBroadcast)
{
	int timer_slot = GetFreeTimerSlot();
	if (timer_slot)
	{
		gt_Timers[timer_slot] = CreateTimer(5.0, Check_FinaleStart);
	}
}

void Event_finale_escape_start(Handle:event, const String:name[], bool:dontBroadcast)
{
	Delete_Timers();
}

Action:Check_FinaleStart(Handle timer)
{
	PrintToChatSkv(DEBUG, "Check_FinaleStart");
	
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
	
	if (SetNearRescueOrigin(client))
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
	
	if (gv_origin_rescue[0] != 0.0 && gv_origin_rescue[1] != 0.0 && gv_origin_rescue[2] != 0.0)
	{
		return;
	}
	
	if (SetNearRescueOrigin(activator))
	{
		gb_rescue_spawn = true;
	}
}

void Event_player_team(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!gb_finale_start)
	{
		return;
	}
	
	int userid = GetEventInt(event, "userid");
	int client = GetClientOfUserId(userid);
	
	if (IsFakeClient(client)) {return;}
	
	int team = GetEventInt(event, "team");
	int oldteam = GetEventInt(event, "oldteam");
	
	if (team && oldteam)
	{
		return;
	}
	
	if (!oldteam) // подключился
	{
		int timer_slot = GetFreeTimerSlot();
		if (timer_slot)
		{
			gt_Timers[timer_slot] = CreateTimer(1.0, Check_Client_Dead, userid);
		}
	}
}

void Event_player_spawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!gb_finale_start)
	{
		return;
	}
	
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsValidClientTeam2(client)) {return;}
	
	RemoveGlowRescue(client);
}

/*
void Event_survivor_rescued(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!gb_finale_start)
	{
		return;
	}
	
	int client = GetClientOfUserId(GetEventInt(event, "victim"));
	if (!IsValidClientTeam2(client)) {return;}
	
	LogToDebug(DEBUG_LOG, gs_logfile, "%s, client %d", name, client);
	
	RemoveGlowRescue(client);
}
*/
void Event_player_death(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!DEBUG && gf_rescue_min_dead_time_final <= 0.0)
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
		if (IsValidClient(client)) 
		{
			SearchDeadSurvivor();
		}
		
		return;
	}
	
	SetOriginDeadSurvivors(client);
		
	int user_slot = GetUserSlot(client);
	if (user_slot)
	{
		if (!IsValidHandle(gt_UserTimers[user_slot]))
		{
			gt_UserTimers[user_slot] = CreateTimer(gf_rescue_min_dead_time_final, Check_Client_Dead, GetClientUserId(client));
			
			PrintToChatSkv(DEBUG, "Event_player_death: client %d, create timer %f", client, gf_rescue_min_dead_time_final);
		}
	}
}
	
Action:Check_Client_Dead(Handle timer, int userid)
{
	if (!gi_respawn_mode_finale)
	{
		return;
	}
	
	int client = GetClientOfUserId(userid);
	
	if (!IsValidClientTeam2(client))
	{
		SearchDeadSurvivor();
		return;
	}
	
	PrintToChatSkv(DEBUG, "Check_Client_Dead: %d", client);
	
	if (IsPlayerAlive(client))
	{
		return;
	}
	
	PrintToChatSkv(DEBUG, "client is dead");
	
	CreateRescue(null, userid);
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
		
		//InputTarget(targetname, "Kill");
		
		if (IsValidClient(client))
		{
			pos_spawn[2] -= VISIBLE_HEIGH;
			Respawn(client, survivor, pos_spawn, ang_spawn);
		}
	}
}

void Respawn(int client, int rescuer, float pos_spawn[3], float ang_spawn[3])
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
	
	SetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity", client);
	
	DispatchKeyValue(entity, "model", "models/editor/playerstart.mdl");
	DispatchKeyValueVector(entity, "origin", pos_spawn);
	DispatchKeyValueVector(entity, "angles", ang_spawn);
	
	DispatchSpawn(entity);
	ActivateEntity(entity);
	
	SetEntPropEnt(entity, Prop_Send, "m_survivor", client);
	AcceptEntityInput(entity, "Rescue", rescuer);
	
	if (!gb_rescue_spawn)
	{
		//SDKHooks_TakeDamage(client, 0, 0, 110.0, DMG_BULLET, -1, NULL_VECTOR, NULL_VECTOR);
		SetEntProp(client, Prop_Send, "m_isIncapacitated", 1);
	}
		
	SetUserRespawn(client);
}

Action:CreateRescue(Handle timer, int userid)
{
	PrintToChatSkv(DEBUG, "CreateRescue: 1");
	
	if (!gb_finale_start)
	{
		return;
	}	
	
	PrintToChatSkv(DEBUG, "CreateRescue: 2");
	
	// при подключении игрока будет ли он оживать? Если проверка есть, то не будет
	/*if (!gi_respawn_mode_finale)
	{
		return;
	}*/
	
	int client = GetClientOfUserId(userid);
	if (!IsValidClientTeam2(client)) // IsValidClient
	{
		return;
	}
	
	PrintToChatSkv(DEBUG, "CreateRescue: 3");
	
	if (IsPlayerAlive(client))
	{
		return;
	}
		
	PrintToChatSkv(DEBUG, "CreateRescue: 4");
	
	if (!gb_rescue_spawn && !gb_respawn_outside_rescue)
	{
		return;
	}
	
	PrintToChatSkv(DEBUG, "CreateRescue: gi_respawn_mode_finale %d", gi_respawn_mode_finale);
		
	if (gi_respawn_mode_finale == 1 && IsClientRespawned(client))
	{
		return;
	}
	
	PrintToChatSkv(DEBUG, "CreateRescue: 5");
	
	if (!gb_rescue_spawn && !GetOriginDeadSurvivors())
	{
		for (int i = 1; i <= MAX_PLAYERS; i++)
		{
			if (IsValidClientTeam2Alive(i))
			{
				GetClientAbsOrigin(i, gf_origin_dead_survivor[0]);
					
				break;
			}
		}
		
		if (gf_origin_dead_survivor[0][0] == 0.0 && gf_origin_dead_survivor[0][1] == 0.0 && gf_origin_dead_survivor[0][2] == 0.0)
		{
			return;
		}
		
		PrintToChatSkv(DEBUG, "CreateRescue: create origin");
		
		int user_slot = GetUserSlot(client);
		if (user_slot)
		{
			float yell_interval = GetConVarFloat(FindConVar("rescue_yell_interval"));
			if (yell_interval <= 0.0)
			{
				yell_interval = 6.0;
			}
			
			gt_UserTimers[user_slot] = CreateTimer(yell_interval, CreateRescue, userid);
		}
		
		return;
	}
	
	PrintToChatSkv(DEBUG, "CreateRescue: 6");
		
	float pos_spawn[3];
	pos_spawn = gv_origin_rescue;
	
	if (gb_rescue_spawn && IsActiveOtherRescue())
	{
		int user_slot = GetUserSlot(client);
		if (user_slot)
		{
			float yell_interval = GetConVarFloat(FindConVar("rescue_yell_interval"));
			if (yell_interval <= 0.0)
			{
				yell_interval = 6.0;
			}
			
			gt_UserTimers[user_slot] = CreateTimer(yell_interval, CreateRescue, userid);
		}
		
		return;
	}
	
	PrintToChatSkv(DEBUG, "CreateRescue: 7");
	
	char temp[PLATFORM_MAX_PATH];
	GetClientModel(client, temp, sizeof(temp));
	
	int entity;
	
	if (GetEngineVersion() == Engine_Left4Dead)
	{
		entity = CreateEntityByName("prop_glowing_object");
		if (entity == -1)
		{
			LogError("Error create prop_glowing_object");
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
		
	char targetname[MAX_TARGET_LENGTH];
	Format(targetname, sizeof(targetname), "%s%d", GLOW_NAME, GetClientUserId(client));
	
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
	DispatchKeyValueVector(entity, "angles", gv_angles_rescue);
		
	DispatchSpawn(entity);
	
	PrintToChatSkv(DEBUG, "CreateRescue: spawn glowing object");
	
	int visible_prop = CreateEntityByName("prop_door_rotating");
	if (visible_prop == -1)
	{
		return;
	}
	
	SetEntPropEnt(visible_prop, Prop_Data, "m_hOwnerEntity", client);
	
	DispatchKeyValue(visible_prop, "targetname", targetname);
	
	pos_spawn[2] += VISIBLE_HEIGH;
	DispatchKeyValueVector(visible_prop, "origin", pos_spawn);
		
	DispatchKeyValue(visible_prop, "model", gs_model_pills);
	
	DispatchKeyValue(visible_prop, "rendermode", "10");
	DispatchKeyValue(visible_prop, "renderamt", "0");
	DispatchKeyValue(visible_prop, "renderfx", "0");
	DispatchKeyValue(visible_prop, "rendercolor", "0 0 0");
	DispatchKeyValue(visible_prop, "disableshadows", "1");
	
	DispatchSpawn(visible_prop);
	
	Rescue_Playsound(client, entity);
	
	int slot = GetUserSlot(client);
	if (slot)
	{
		gi_users_calls[slot] = RoundFloat(GetGameTime());
	}
	
	int timer_slot = GetFreeTimerSlot();
	if (timer_slot)
	{
		float yell_interval = GetConVarFloat(FindConVar("rescue_yell_interval"));
		if (yell_interval <= 0.0)
		{
			yell_interval = 6.0;
		}

		DataPack data_sound;
		gt_Timers[timer_slot] = CreateDataTimer(yell_interval, Rescue_Playsound_Timer, data_sound, TIMER_REPEAT);
		
		WritePackCell(data_sound, GetClientUserId(client));
		WritePackCell(data_sound, EntIndexToEntRef(entity));
	}
	
	PrintToChatSkv(DEBUG, "spawn rescue %d", entity);
}

Action:Rescue_Playsound_Timer(Handle timer, Handle h_data)
{
	if (!IsValidHandle(h_data))
	{
		return Plugin_Stop;
	}
	
	DataPack data_sound = view_as<DataPack>(h_data);
	
	ResetPack(data_sound);
	
	int client = GetClientOfUserId(ReadPackCell(data_sound));
	
	int entity = EntRefToEntIndex(ReadPackCell(data_sound));
	
	if (!IsValidEntity(entity))
	{
		return Plugin_Stop;
	}
	
	if (!IsValidClient(client))
	{
		if (IsValidEntity(entity))
		{
			char name[MAX_STRING_LENGTH];
			GetEntPropString(entity, Prop_Data, "m_iName", name, sizeof(name));
			
			InputTarget(name, "Kill");
		}
		
		return Plugin_Stop;
	}
		
	Rescue_Playsound(client, entity);
	
	int respawn_outside_time = GetConVarInt(gc_respawn_outside_time);
	
	int slot = GetUserSlot(client);
	if (slot && respawn_outside_time && gb_rescue_spawn)
	{
		if (RoundFloat(GetGameTime()) - gi_users_calls[slot] >= respawn_outside_time)
		{
			gb_rescue_spawn = false;
			gi_users_calls[slot] = 0;
			
			if (IsValidEntity(entity))
			{
				char name[MAX_STRING_LENGTH];
				GetEntPropString(entity, Prop_Data, "m_iName", name, sizeof(name));
			
				InputTarget(name, "Kill");
			}
			
			CreateTimer(1.0, Check_Client_Dead, GetClientUserId(client));
			
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
		Format(temp, sizeof(temp), "player/survivor/voice/TeenGirl/%s.wav", gs_sound_TeenGirl[vocalize_track]);
	}
	else if (StrContains(temp, "survivor_biker") > -1)
	{
		int vocalize_track = GetRandomSelect(gs_random_Biker, sizeof(gs_random_Biker));
		Format(temp, sizeof(temp), "player/survivor/voice/Biker/%s.wav", gs_sound_Biker[vocalize_track]);
	}
	else if (StrContains(temp, "survivor_manager") > -1)
	{
		int vocalize_track = GetRandomSelect(gs_random_Manager, sizeof(gs_random_Manager));
		Format(temp, sizeof(temp), "player/survivor/voice/Manager/%s.wav", gs_sound_Manager[vocalize_track]);
	}
	else if (StrContains(temp, "survivor_namvet") > -1)
	{
		int vocalize_track = GetRandomSelect(gs_random_NamVet, sizeof(gs_random_NamVet));
		Format(temp, sizeof(temp), "player/survivor/voice/NamVet/%s.wav", gs_sound_NamVet[vocalize_track]);
	}
	else if (StrContains(temp, "survivor_gambler") > -1)
	{
		int vocalize_track = GetRandomSelect(gs_random_Gambler, sizeof(gs_random_Gambler));
		Format(temp, sizeof(temp), "player/survivor/voice/gambler/%s.wav", gs_random_Gambler[vocalize_track]);
	}
	else if (StrContains(temp, "survivor_producer") > -1)
	{
		int vocalize_track = GetRandomSelect(gs_random_Producer, sizeof(gs_random_Producer));
		Format(temp, sizeof(temp), "player/survivor/voice/producer/%s.wav", gs_sound_Producer[vocalize_track]);
	}
	else if (StrContains(temp, "survivor_coach") > -1)
	{
		int vocalize_track = GetRandomSelect(gs_random_Coach, sizeof(gs_random_Coach));
		Format(temp, sizeof(temp), "player/survivor/voice/coach/%s.wav", gs_sound_Coach[vocalize_track]);
	}
	else if (StrContains(temp, "survivor_mechanic") > -1)
	{
		int vocalize_track = GetRandomSelect(gs_random_Mechanic, sizeof(gs_random_Mechanic));
		Format(temp, sizeof(temp), "player/survivor/voice/mechanic/%s.wav", gs_sound_Mechanic[vocalize_track]);
	}
	else
	{
		return;
	}
	
	float pos_spawn[3];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", pos_spawn);
	
	pos_spawn[2] += VISIBLE_HEIGH + 5.0;
	
	EmitAmbientSound(temp, pos_spawn, entity);
	PrintToChatSkv(DEBUG, "Rescue_Playsound: play %s", temp);
}

int GetFreeTimerSlot()
{
	for (int i = 1; i <= MAX_TIMERSLOTS; i++)
	{
		if (!IsValidHandle(gt_Timers[i]))
		{
			return i;
		}
	}
	
	return 0;
}

void Delete_Timers()
{
	for (int i = 1; i <= MAX_TIMERSLOTS; i++)
	{
		if (IsValidHandle(gt_Timers[i]))
		{
			CloseHandle(gt_Timers[i]);
		}
	}
	
	for (int i = 0; i <= MAX_PLAYERS; i++)
	{
		gi_users_respawn[i] = 0;
		gi_users_calls[i] = 0;
		
		gf_origin_dead_survivor[i][0] = 0.0;
		gf_origin_dead_survivor[i][1] = 0.0;
		gf_origin_dead_survivor[i][2] = 0.0;
	}
	
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		if (IsValidHandle(gt_UserTimers[i]))
		{
			CloseHandle(gt_UserTimers[i]);
		}
	}
	
	for (int i = 0; i <= MAX_RESCUE; i++)
	{
		gi_rescue_vectors[i][0] = 0;
	}
	
	gb_finale_start = false;
	gb_rescue_spawn = false;
	
	gv_origin_rescue[0] = 0.0;
	gv_origin_rescue[1] = 0.0;
	gv_origin_rescue[2] = 0.0;
	
	char classname[MAX_STRING_LENGTH];
	
	if (GetEngineVersion() == Engine_Left4Dead)
	{
		Format(classname, sizeof(classname), "prop_glowing_object");
	}
	else
	{
		Format(classname, sizeof(classname), "prop_dynamic");
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

void RemoveGlowRescue(int client)
{
	if (!IsValidClient(client)) {return;}
	
	char classname[MAX_STRING_LENGTH];
	
	if (GetEngineVersion() == Engine_Left4Dead)
	{
		Format(classname, sizeof(classname), "prop_glowing_object");
	}
	else
	{
		Format(classname, sizeof(classname), "prop_dynamic");
	}
	
	char temp[MAX_STRING_LENGTH];
	Format(temp, sizeof(temp), "%d", GetClientUserId(client));
	
	char name[MAX_STRING_LENGTH];
		
	int i = -1;
	while ((i = FindEntityByClassname(i, classname)) != -1)
	{
		GetEntPropString(i, Prop_Data, "m_iName", name, sizeof(name));
		if (StrContains(name, temp) > -1)
		{
			InputTarget(name, "Kill");
		}
	}
}

int IsActiveOtherRescue()
{
	char classname[MAX_STRING_LENGTH];
	
	if (GetEngineVersion() == Engine_Left4Dead)
	{
		Format(classname, sizeof(classname), "prop_glowing_object");
	}
	else
	{
		Format(classname, sizeof(classname), "prop_dynamic");
	}
	
	char name[MAX_STRING_LENGTH];
	
	int i = -1;
	while ((i = FindEntityByClassname(i, classname)) != -1)
	{
		GetEntPropString(i, Prop_Data, "m_iName", name, sizeof(name));
		if (StrContains(name, GLOW_NAME) > -1)
		{
			return i;
		}
	}
	
	return 0;
}

void SetOriginDeadSurvivors(int client)
{
	float pos_spawn[3];
	GetEntPropVector(client, Prop_Data, "m_vecOrigin", pos_spawn);
	
	for (int i = 0; i <= MAX_PLAYERS; i++)
	{
		if (gf_origin_dead_survivor[i][0] == 0.0 && gf_origin_dead_survivor[i][1] == 0.0 && gf_origin_dead_survivor[i][2] == 0.0)
		{
			gf_origin_dead_survivor[i] = pos_spawn;
			
			break;
		}
	}
}

bool GetOriginDeadSurvivors()
{
	for (int i = 0; i <= MAX_PLAYERS; i++)
	{
		if (gf_origin_dead_survivor[i][0] != 0.0 && gf_origin_dead_survivor[i][1] != 0.0 && gf_origin_dead_survivor[i][2] != 0.0)
		{
			gv_origin_rescue = gf_origin_dead_survivor[i];
			
			gf_origin_dead_survivor[i][0] = 0.0;
			gf_origin_dead_survivor[i][1] = 0.0;
			gf_origin_dead_survivor[i][2] = 0.0;
			
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
	
	PrintToChatSkv(DEBUG, "SearchDeadSurvivor");
	
	float death_time;
	float time_respawn;
	
	int user_slot;
	
	for (int i = 1; i <= MAX_PLAYERS; i ++)
	{
		if (IsValidClientTeam2(i) && !IsPlayerAlive(i))
		{
			PrintToChatSkv(DEBUG, "SearchDeadSurvivor: find %N", i);
			
			user_slot = GetUserSlot(i);
			if (user_slot)
			{
				death_time = GetGameTime() - GetEntPropFloat(i, Prop_Send, "m_flDeathTime");
				PrintToChatSkv(DEBUG, "SearchDeadSurvivor: death_time %f", death_time);
				
				time_respawn = gf_rescue_min_dead_time_final - death_time;
				PrintToChatSkv(DEBUG, "SearchDeadSurvivor: time_respawn %f", time_respawn);
				
				if (time_respawn <= 0.0)
				{
					time_respawn = 0.1;
				}
				
				if (!IsValidHandle(gt_UserTimers[user_slot]))
				{
					gt_UserTimers[user_slot] = CreateTimer(time_respawn, CreateRescue, GetClientUserId(i));
					PrintToChatSkv(DEBUG, "SearchDeadSurvivor: CreateTimer %f", time_respawn);
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
	
	for (int i = 0; i <= MAX_PLAYERS; i++)
	{
		if (!gi_users_respawn[i])
		{
			gi_users_respawn[i] = GetClientUserId(client);
			
			return true;
		}
	}
	
	LogError("SetUserRespawn: no free slots");
	return false;
}

bool IsClientRespawned(int client)
{
	int userid = GetClientUserId(client);
	
	for (int i = 0; i <= MAX_PLAYERS; i++)
	{
		if (gi_users_respawn[i] == userid)
		{
			return true;
		}
	}
	
	return false;
}

public OnClientPutInServer(int client)
{
	if (!IsValidClient(client))
	{
		return;
	}
	
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		if (!gi_users[i])
		{
			gi_users[i] = GetClientUserId(client);
			return;
		}
	}
	
	LogError("OnClientPutInServer: no free user slots");
}

public OnClientDisconnect(int client)
{
	if (gb_finale_start)
	{
		RemoveGlowRescue(client);
	}
	
	int userid = GetClientUserId(client);
	
	for (int i = 0; i <= MAX_PLAYERS; i++)
	{
		if (gi_users[i] == userid)
		{
			gi_users[i] = 0;
			gi_users_respawn[i] = 0;
			gi_users_calls[i] = 0;
		}
	}
}

int GetUserSlot(int client)
{
	if (!IsValidClient(client))
	{
		return 0;
	}
	
	int userid = GetClientUserId(client);
	
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
		LogError("GetRandomSelect: ERROR: INVALID value = %d", value + 1);
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
	Format(temp, sizeof(temp), "%s,%s,%s,%f,-1", targetname, input, value, delay);
	DispatchKeyValue(entity, "OnTrigger", temp);
	
	AcceptEntityInput(entity, "Trigger");
	AcceptEntityInput(entity, "Kill");
}

bool SetNearRescueOrigin(int entity)
{
	bool result;
	
	if (!IsValidEntity(entity))
	{
		return result;
	}
	
	float pos_entity[3];
	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", pos_entity);
	
	
	float pos_i[3]; 
	float distance_old; 
	float distance_entity_i;
	
	for (int i = 0; i <= MAX_RESCUE; i++)
	{
		if (gi_rescue_vectors[i][0])
		{
			pos_i[0] = gi_rescue_vectors[i][1] * 1.0;
			pos_i[1] = gi_rescue_vectors[i][2] * 1.0;
			pos_i[2] = gi_rescue_vectors[i][3] * 1.0;
						
			distance_entity_i = GetVectorDistance(pos_entity, pos_i);
			
			if (distance_old == 0 || distance_entity_i < distance_old)
			{
				distance_old = distance_entity_i;
				
				gv_origin_rescue[0] = pos_i[0];
				gv_origin_rescue[1] = pos_i[1];
				gv_origin_rescue[2] = pos_i[2];
				
				gv_angles_rescue[0] = gi_rescue_vectors[i][4] * 1.0;
				gv_angles_rescue[1] = gi_rescue_vectors[i][5] * 1.0;
				gv_angles_rescue[2] = gi_rescue_vectors[i][6] * 1.0;
				
				result = true;
			}
		}
	}
	
	return result;
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
	
	for (int i = 0; i <= MAX_RESCUE; i++)
	{
		if (!gi_rescue_vectors[i][0])
		{
			gi_rescue_vectors[i][0] = rescue;
			
			gi_rescue_vectors[i][1] = RoundFloat(pos_spawn[0]);
			gi_rescue_vectors[i][2] = RoundFloat(pos_spawn[1]);
			gi_rescue_vectors[i][3] = RoundFloat(pos_spawn[2]);
			
			gi_rescue_vectors[i][4] = RoundFloat(ang_spawn[0]);
			gi_rescue_vectors[i][5] = RoundFloat(ang_spawn[1]);
			gi_rescue_vectors[i][6] = RoundFloat(ang_spawn[2]);
			
			break;
		}
	}
}

/**
 * посылает сообщение в чат клиенту skv
 *
 * DEBUG 		- правда - выводит на экран, ложь - нет
 * message 		- сообщение
 */
stock void PrintToChatSkv(bool debug_status = false, char[] message, any ...)
{
	if (!debug_status)
	{
		return;
	}
	
	float time = GetGameTime();
		
	char fraction[5];
	FloatToString(FloatFraction(time), fraction, sizeof(fraction));
		
	char game_time[PLATFORM_MAX_PATH];
	FloatToString(time, game_time, sizeof(game_time));
	
	char temp1[PLATFORM_MAX_PATH];
	SplitString(game_time, ".", temp1, sizeof(temp1));
		
	char temp2[PLATFORM_MAX_PATH];
	SplitString(fraction, ".", temp2, sizeof(temp2));
	int len = strlen(temp2) + 1;
	
	strcopy(fraction, sizeof(fraction), fraction[len]);
		
	Format(game_time, sizeof(game_time), "%s.%s", temp1, fraction);
		
	char buffer[254];
	char SteamID[25];
	
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		if (IsValidClientTeam2(i))
		{
			if (GetClientAuthId(i, AuthId_Steam2, SteamID, sizeof(SteamID)))
			{
				if (!strcmp(SteamID, "STEAM_1:1:32618262")) // skv
				{
					SetGlobalTransTarget(i);
					VFormat(buffer, sizeof(buffer), message, 3);
					
					PrintToChat(i, "%s %s", game_time, buffer);
				
					return;
				}
			}
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
 * entity 		- сущность, которая удаляется
 * time 		- кол-во секунд, через которое удаляется
*/
stock void InputKill(int entity, float time = 0.0)
{
	if (!IsValidEntity(entity) || (entity >= 0 && entity <= MAX_PLAYERS)) {return;}
	
	if (time == 0.0)
	{
		if (HasEntProp(entity, Prop_Send, "m_iParent"))
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
		
		if (HasEntProp(entity, Prop_Send, "m_iParent"))
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
