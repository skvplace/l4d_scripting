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
	description 	= "The plugin allows survivors to respawn in the finale",
	version 	= "1.5.2",
	url 		= "https://forums.alliedmods.net/showthread.php?p=2829933#post2829933"
}

bool DEBUG 		= false;
bool DEBUG_SLOT 	= false;
bool DEBUG_LOG;

char gs_debugfile[256];

#define MAX_PLAYERS 				18
#define MAX_STRING_LENGTH			128

#define GLOW_NAME 				"rf_rescue_glow"
#define VISIBLE_HEIGH				80.0
#define VISIBLE_HEIGH_INCAP			30.0

char 	gs_model_pills[]			= "models/w_models/weapons/w_eq_painpills.mdl";

int 	gi_user_playerid			[MAX_PLAYERS + 1];
bool 	gb_spawn_playerid			[MAX_PLAYERS + 1];
int 	gi_time_playerid			[MAX_PLAYERS + 1];

Handle 	gt_CreateRescue				[MAX_PLAYERS + 1];

#define MAX_TIMERS				MAX_PLAYERS * 4
Handle 	gi_Timer				[MAX_TIMERS + 1];

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

float 	gv_origin_dead_survivor			[MAX_PLAYERS + 1][3];

#define MAX_RESCUE				64
int 	gi_rescue				[MAX_RESCUE + 1];

float 	gv_rescue_origin			[MAX_RESCUE + 1][3];
float 	gv_rescue_angles			[MAX_RESCUE + 1][3];

#define MAX_FINAL_RESCUES			3
int 	gi_final_rescue_slot			[MAX_FINAL_RESCUES + 1];
int 	gi_final_rescue_slot_client		[MAX_FINAL_RESCUES + 1];

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
		strcopy(error, err_max, "Plugin only supports Left 4 Dead (2)");
		return APLRes_SilentFailure;
	}
			
	return APLRes_Success;
}

public OnPluginStart()
{
	BuildPath(Path_SM, gs_debugfile, sizeof(gs_debugfile), "data/z_respawn_final.log");
		
	HookEvent("player_team", Event_player_team);
	
	HookEvent("player_bot_replace", Event_replace); // бот заменил игрока
	HookEvent("bot_player_replace", Event_replace); // игрок заменил бота
	
	HookEvent("player_death", Event_player_death);
	HookEvent("player_spawn", Event_player_spawn);
		
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
	
	RegAdminCmd("sm_final", Cmd_final, ADMFLAG_CONFIG, "");
}

public Action:Cmd_final(client, args)
{
	if (!DEBUG && !DEBUG_SLOT)
	{
		PrintToChat(client, "DEBUG mode disabled - cancel command");
		return;
	}
	
	ConVar lr_rescue_mode = FindConVar("lr_rescue_mode");
	
	if (!IsValidHandle(lr_rescue_mode))
	{
		PrintToChatSkv(true, "Cmd_final: lr_rescue_mode IS NOT VALID");
	}
	
	SetConVarInt(lr_rescue_mode, 3);
	
	int slot = gi_final_rescue_slot[1];
	PrintToChatSkv(DEBUG_SLOT, "Cmd_final: slot %d", slot);
		
	if (gv_rescue_origin[slot][0] != 0.0 && gv_rescue_origin[slot][1] != 0.0 && gv_rescue_origin[slot][2] != 0.0)
	{
		PrintToChatSkv(DEBUG_SLOT, "Cmd_final: ERROR - slot is not cleared!");
		return;
	}
	
	if (SetNearRescueVectors(client))
	{
		gb_rescue_spawn = true;
	}
	
	gb_finale_start = true;
	
	DEBUG_LOG = true;
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
	DEBUG_LOG = false;
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
	
	if (DEBUG || DEBUG_SLOT)
	{
		gf_rescue_min_dead_time_final = 10.0;
		//gf_respawn_outside_time = 10.0;
	}
	
	DEBUG_LOG = false;
	
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
	
	PrintToChatSkv(DEBUG, "UseStart: activator %d", activator);
	
	if (SetNearRescueVectors(activator))
	{
		gb_rescue_spawn = true;
	}
}

void Event_finale_start(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (DEBUG || DEBUG_SLOT)
	{
		DEBUG_LOG = true;
	}
	
	int timer_slot = GetFreeTimerSlot();
	if (timer_slot)
	{
		gi_Timer[timer_slot] = CreateTimer(5.0, Check_FinaleStart);
	}
}

void Event_finale_win(Handle:event, const String:name[], bool:dontBroadcast)
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
	PrintToChatSkv(DEBUG_SLOT, "FinaleStart: slot %d", slot);
		
	if (gv_rescue_origin[slot][0] != 0.0 && gv_rescue_origin[slot][1] != 0.0 && gv_rescue_origin[slot][2] != 0.0)
	{
		return;
	}
	
	PrintToChatSkv(DEBUG, "FinaleStart: activator %d", activator);
	
	if (SetNearRescueVectors(activator))
	{
		gb_rescue_spawn = true;
	}
}

void Event_player_team(Handle:event, const String:name[], bool:dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsValidClient(client)) {return;}
	
	int oldteam = GetEventInt(event, "oldteam");
	int team = GetEventInt(event, "team");
	
	if (team == 2 && oldteam == 0)
	{
		LogToDebug(DEBUG_LOG, gs_debugfile, "--------------------------------");
		LogToDebug(DEBUG_LOG, gs_debugfile, "%s: client %d <userid %d>", name, client, GetEventInt(event, "userid"));
		
		int playerid = SetPlayerID(client);
		
		if (playerid && gb_finale_start)
		{
			if (!IsValidHandle(gt_CreateRescue[playerid]))
			{
				gt_CreateRescue[playerid] = CreateTimer(1.0, Check_Client_Dead, playerid);
			}
		}
	}
}

void Event_replace(Handle:event, const String:name[], bool:dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "player"));
	if (!IsValidClient(client)) {return;}
	
	int bot = GetClientOfUserId(GetEventInt(event, "bot"));
	if (!IsValidClient(client)) {return;}
	
	LogToDebug(DEBUG_LOG, gs_debugfile, "--------------------------------");
	LogToDebug(DEBUG_LOG, gs_debugfile, "%s: player %d <userid %d>, bot %d <userid %d>", name, client, GetEventInt(event, "player"), bot, GetEventInt(event, "bot"));
	
	if (!strcmp(name, "player_bot_replace"))
	{
		// бот заменил игрока
		LogToDebug(DEBUG_LOG, gs_debugfile, "бот заменил игрока");
		
		if (!ReplacePlayerID(client, bot))
		{
			SetPlayerID(bot);
		}
	}
	else
	{
		// игрок заменил бота
		LogToDebug(DEBUG_LOG, gs_debugfile, "игрок заменил бота");
		
		if (!ReplacePlayerID(bot, client))
		{
			SetPlayerID(bot);
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
	
	LogToDebug(DEBUG_LOG, gs_debugfile, "--------------------------------");
	LogToDebug(DEBUG_LOG, gs_debugfile, "%s: %N %s, client %d <userid %d>", name, client, IsFakeClient(client) ? "<BOT>":"<PLAYER>", client, GetEventInt(event, "userid"));
	
	RemoveGlowRescue(client, 0.1);
}

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
		//SearchDeadSurvivor();
		return;
	}
	
	LogToDebug(DEBUG_LOG, gs_debugfile, "--------------------------------");
	LogToDebug(DEBUG_LOG, gs_debugfile, "%s: %N %s, client %d <userid %d>", name, client, IsFakeClient(client) ? "<BOT>":"<PLAYER>", client, GetEventInt(event, "userid"));
	
	SetOriginDeadSurvivors(client);
		
	int playerid = GetPlayerID(client);
	if (playerid)
	{
		if (!IsValidHandle(gt_CreateRescue[playerid]))
		{
			gt_CreateRescue[playerid] = CreateTimer(gf_rescue_min_dead_time_final, Check_Client_Dead, playerid);
			
			PrintToChatSkv(DEBUG, "Event_player_death: client %d, create timer %f", client, gf_rescue_min_dead_time_final);
			LogToDebug(DEBUG_LOG, gs_debugfile, "%s: CreateTimer %f, client %d <userid %d> playerid %d", name, gf_rescue_min_dead_time_final, client, GetClientUserId(client), playerid);
		}
	}
}
	
Action:Check_Client_Dead(Handle timer, int playerid)
{
	if (!gi_respawn_mode_finale)
	{
		return;
	}
	
	int userid = GetPlayerUserId(playerid);
	if (!userid)
	{
		SearchDeadSurvivor();
		
		//LogError("Check_Client_Dead: userid is NULL, playerid %d", userid, playerid);
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
		SearchDeadSurvivor();
		return;
	}
	
	PrintToChatSkv(DEBUG, "client is dead");
	
	CreateRescue(null, playerid);
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

Action:CreateRescue(Handle timer, int playerid)
{
	PrintToChatSkv(DEBUG, "CreateRescue: 1");
	LogToDebug(DEBUG_LOG, gs_debugfile, "CreateRescue: playerid %d", playerid);
	
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
	
	int userid = GetPlayerUserId(playerid);
	if (!userid)
	{
		//LogError("CreateRescue: userid is NULL, playerid %d", userid, playerid);
		return;
	}
	
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
		gb_rescue_spawn = true;
	}
	
	PrintToChatSkv(DEBUG, "CreateRescue: gi_respawn_mode_finale %d", gi_respawn_mode_finale);
		
	if (gi_respawn_mode_finale == 1 && IsClientRespawned(client))
	{
		return;
	}
	
	PrintToChatSkv(DEBUG, "CreateRescue: 5");
	
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
			
		if (IsValidHandle(gt_CreateRescue[playerid]))
		{
			delete gt_CreateRescue[playerid];
		}
			
		gt_CreateRescue[playerid] = CreateTimer(yell_interval, CreateRescue, playerid);
		LogToDebug(DEBUG_LOG, gs_debugfile, "CreateRescue: IsActiveRescueLimit: CreateTimer %f, client %d <userid %d> playerid %d", yell_interval, client, GetClientUserId(client), playerid);
				
		return;
	}
	
	PrintToChatSkv(DEBUG, "CreateRescue: 6");
	
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
		
		PrintToChatSkv(DEBUG, "CreateRescue: create origin");
		
		float yell_interval = GetConVarFloat(FindConVar("rescue_yell_interval"));
		if (yell_interval <= 0.0)
		{
			yell_interval = 6.0;
		}
			
		if (IsValidHandle(gt_CreateRescue[playerid]))
		{
			delete gt_CreateRescue[playerid];
		}
			
		gt_CreateRescue[playerid] = CreateTimer(yell_interval, CreateRescue, playerid);
		LogToDebug(DEBUG_LOG, gs_debugfile, "CreateRescue: !GetOriginDeadSurvivors: CreateTimer %f, client %d <userid %d> playerid %d", yell_interval, client, GetClientUserId(client), playerid);
			
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
			PrintToChatSkv(DEBUG, "CreateRescue: error GetVectorsFinalRescue");
			
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
	
	PrintToChatSkv(DEBUG, "CreateRescue: spawn glowing object");
	
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
	
	gi_time_playerid[playerid] = RoundFloat(GetGameTime());
		
	int timer_slot = GetFreeTimerSlot();
	if (timer_slot)
	{
		float yell_interval = GetConVarFloat(FindConVar("rescue_yell_interval"));
		if (yell_interval <= 0.0)
		{
			yell_interval = 6.0;
		}

		DataPack data_sound;
		gi_Timer[timer_slot] = CreateDataTimer(yell_interval, Rescue_Playsound_Timer, data_sound, TIMER_REPEAT);
		
		WritePackCell(data_sound, playerid);
		WritePackCell(data_sound, EntIndexToEntRef(entity));
	}
	
	PrintToChatSkv(DEBUG, "spawn rescue %d", entity);
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
	
	PrintToChatSkv(DEBUG, "CloseNearDoors: entity %d, door %d", entity, door);
}

Action:Rescue_Playsound_Timer(Handle timer, Handle h_data)
{
	if (!IsValidHandle(h_data))
	{
		return Plugin_Stop;
	}
	
	DataPack data_sound = view_as<DataPack>(h_data);
	
	ResetPack(data_sound);
	
	int playerid = ReadPackCell(data_sound);
			
	int userid = GetPlayerUserId(playerid);
	if (!userid)
	{
		//LogError("Rescue_Playsound_Timer: userid is NULL, playerid %d", userid, playerid);
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
		if (RoundFloat(GetGameTime()) - gi_time_playerid[playerid] >= respawn_outside_time)
		{
			gb_rescue_spawn = false;
			gi_time_playerid[playerid] = 0;
			
			if (IsValidEntity(entity))
			{
				char name[MAX_STRING_LENGTH];
				GetEntPropString(entity, Prop_Data, "m_iName", name, sizeof(name));
			
				InputTarget(name, "Kill");
			}
			
			CreateTimer(1.0, Check_Client_Dead, playerid);
			
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
	PrintToChatSkv(DEBUG, "Rescue_Playsound: play %s", temp);
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
		if (!IsValidHandle(gi_Timer[i]))
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
		if (IsValidHandle(gi_Timer[i]))
		{
			CloseHandle(gi_Timer[i]);
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
				
		if (IsValidHandle(gt_CreateRescue[i]))
		{
			CloseHandle(gt_CreateRescue[i]);
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
			PrintToChatSkv(DEBUG_SLOT, "RemoveGlowRescue: clear slot %d, userid %d", gi_final_rescue_slot[i], userid);
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
	
	PrintToChatSkv(DEBUG, "SearchDeadSurvivor");
	LogToDebug(DEBUG_LOG, gs_debugfile, "SearchDeadSurvivor");
	
	float death_time;
	float time_respawn;
	
	int playerid;
	
	for (int i = 1; i <= MAX_PLAYERS; i ++)
	{
		if (IsValidClientTeam2(i) && !IsPlayerAlive(i))
		{
			PrintToChatSkv(DEBUG, "SearchDeadSurvivor: find %N", i);
			
			playerid = GetPlayerID(i);
			if (playerid)
			{
				death_time = GetGameTime() - GetEntPropFloat(i, Prop_Send, "m_flDeathTime");
				PrintToChatSkv(DEBUG, "SearchDeadSurvivor: death_time %f", death_time);
				
				time_respawn = gf_rescue_min_dead_time_final - death_time;
				PrintToChatSkv(DEBUG, "SearchDeadSurvivor: time_respawn %f", time_respawn);
				
				if (time_respawn <= 0.0)
				{
					time_respawn = 0.1;
				}
				
				if (!IsValidHandle(gt_CreateRescue[playerid]))
				{
					gt_CreateRescue[playerid] = CreateTimer(time_respawn, CreateRescue, playerid);
					
					PrintToChatSkv(DEBUG, "SearchDeadSurvivor: CreateTimer %f", time_respawn);
					LogToDebug(DEBUG_LOG, gs_debugfile, "SearchDeadSurvivor: CreateTimer %f, client %d <userid %d> playerid %d", time_respawn, i, GetClientUserId(i), playerid);
				}
			}		
		}
	}
	
	LogToDebug(DEBUG_LOG, gs_debugfile, "SearchDeadSurvivor: все игроки живы");
}

bool SetUserRespawn(int client)
{
	if (IsClientRespawned(client))
	{
		return true;
	}
	
	int playerid = GetPlayerID(client);
	if (!playerid)
	{
		return false;
	}
	
	gb_spawn_playerid[playerid] = true;
	
	return true;
}

bool IsClientRespawned(int client)
{
	int playerid = GetPlayerID(client);
	if (!playerid)
	{
		return false;
	}
	
	return gb_spawn_playerid[playerid];
}

public OnClientDisconnect(int client)
{
	LogToDebug(DEBUG_LOG, gs_debugfile, "--------------------------------");
	LogToDebug(DEBUG_LOG, gs_debugfile, "OnClientDisconnect: userid %d", GetClientUserId(client));
	
	if (RemovePlayerID(client) && gb_finale_start)
	{
		RemoveGlowRescue(client);
	}
}

int SetPlayerID(int client)
{
	int playerid = GetPlayerID(client, true);
	if (playerid)
	{
		return playerid;
	}
	
	if (!IsValidClient(client))
	{
		return 0;
	}
	
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		if (!gi_user_playerid[i])
		{
			gi_user_playerid[i] = GetClientUserId(client);
			
			LogToDebug(DEBUG_LOG, gs_debugfile, "SetPlayerIDs: set new client %d <userid %d> to slot %d", client, GetClientUserId(client), i);
			
			StatusPlayerID();
			
			return i;
		}
	}
	
	//LogToDebug(DEBUG_LOG, gs_debugfile, "SetPlayerIDs: ERROR no free slots client %d <userid %d>", client, GetClientUserId(client));
	
	return 0;
}

int GetPlayerID(int client, bool from_SetPlayerID = false)
{
	if (!IsValidClient(client))
	{
		return 0;
	}
	
	int userid = GetClientUserId(client);
	
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		if (gi_user_playerid[i] == userid)
		{
			LogToDebug(DEBUG_LOG, gs_debugfile, "GetPlayerID: find client %d <userid %d>, slot %d", client, userid, i);
			return i;
		}
	}
	
	if (!from_SetPlayerID)
	{
		LogToDebug(DEBUG_LOG, gs_debugfile, "GetPlayerID: ERROR no find client %d <userid %d>", client, GetClientUserId(client));
	}
	
	return 0;
}

int GetPlayerUserId(int playerid)
{
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		if (i == playerid)
		{
			return gi_user_playerid[i];
		}
	}
	
	return 0;
}

int RemovePlayerID(int client)
{
	if (!IsValidClient(client))
	{
		return 0;
	}
	
	int userid = GetClientUserId(client);
	
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		if (gi_user_playerid[i] == userid)
		{
			gi_user_playerid[i] = 0;
			gb_spawn_playerid[i] = false;
			
			LogToDebug(DEBUG_LOG, gs_debugfile, "RemovePlayerID: find client %d <userid %d>, slot %d", client, userid, i);
			
			StatusPlayerID();
			
			return i;
		}
	}
	
	//LogToDebug(DEBUG_LOG, gs_debugfile, "RemovePlayerID: no find client %d <userid %d>", client, GetClientUserId(client));
	return 0;
}

int ReplacePlayerID(int client, int new_client)
{
	if (!IsValidClient(client))
	{
		return 0;
	}
	
	if (!IsValidClient(new_client))
	{
		return 0;
	}
	
	int userid = GetClientUserId(client);
	
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		if (gi_user_playerid[i] == userid)
		{
			gi_user_playerid[i] = GetClientUserId(new_client);
			
			LogToDebug(DEBUG_LOG, gs_debugfile, "ReplacePlayerID: replace client %d <userid %d>, slot %d, at new client %d <userid %d>", client, userid, i, new_client, GetClientUserId(new_client));
			
			StatusPlayerID();
			ReplaceRescue(client, new_client);
			
			return i;
		}
	}
	
	//LogToDebug(DEBUG_LOG, gs_debugfile, "ReplacePlayerID: ERROR no find client %d <userid %d>", client, GetClientUserId(client));
	
	//StatusPlayerID();
	
	return 0;
}

void ReplaceRescue(int client, int new_client)
{
	if (!gb_finale_start)
	{
		return;
	}
	
	if (!IsValidClient(client)) {return;}
	if (!IsValidClient(new_client)) {return;}
	
	LogToDebug(DEBUG_LOG, gs_debugfile, "ReplacePlayerID: replace client %d <userid %d>, at new client %d <userid %d>", client, GetClientUserId(client), new_client, GetClientUserId(new_client));
	
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
			
			LogToDebug(DEBUG_LOG, gs_debugfile, "ReplacePlayerID: replace targetname");
			break;
		}
	}
	
	//PrintToChatSkv(DEBUG_SLOT, "RemoveGlowRescue: userid %d", userid);
		
	for (i = 1; i <= MAX_FINAL_RESCUES; i++)
	{
		if (gi_final_rescue_slot_client[i] == userid)
		{
			gi_final_rescue_slot_client[i] = new_userid; // активная респа
			PrintToChatSkv(DEBUG_SLOT, "ReplaceRescue: replace slot %d, new_userid %d", gi_final_rescue_slot[i], new_userid);
		}
	}
}

void StatusPlayerID()
{
	LogToDebug(DEBUG_LOG, gs_debugfile, "--------------------------------");
	LogToDebug(DEBUG_LOG, gs_debugfile, "StatusPlayerID:");
		
	int userid; int client;
	
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		if (gi_user_playerid[i])
		{
			userid = gi_user_playerid[i];
			client = GetClientOfUserId(userid);
			
			if (IsValidClient(client))
			{
				LogToDebug(DEBUG_LOG, gs_debugfile, "%i client %d <userid %d> %N %s", i, client, userid, client, IsFakeClient(client) ? "<BOT>":"<PLAYER>");
			}
			else
			{
				gi_user_playerid[i] = 0;
				gb_spawn_playerid[i] = false;
			}
		}
		else
		{
			LogToDebug(DEBUG_LOG, gs_debugfile, "%i 0", i);
		}
	}
	
	LogToDebug(DEBUG_LOG, gs_debugfile, "--------------------------------");
	LogToDebug(DEBUG_LOG, gs_debugfile, " ");
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
	
	PrintToChatSkv(DEBUG_SLOT, "SetNearRescueVectors: pos_entity %d %d %d", RoundFloat(pos_entity[0]), RoundFloat(pos_entity[1]), RoundFloat(pos_entity[2]));
	
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
						
				PrintToChatSkv(DEBUG_SLOT, "SetNearRescueVectors: save slot %d, origin %d %d %d", near_rescue_slot, RoundFloat(gv_rescue_origin[near_rescue_slot][0]), RoundFloat(gv_rescue_origin[near_rescue_slot][1]), RoundFloat(gv_rescue_origin[near_rescue_slot][2]));
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
			
			PrintToChatSkv(true, "GetVectorsFinalRescue: set active slot %d, userid %d", i, GetClientUserId(client));
			
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
			
			PrintToChatSkv(DEBUG_SLOT, "SetRescueVectors: rescue %d save to slot %d, origin %d %d %d", rescue, i, RoundFloat(gv_rescue_origin[i][0]), RoundFloat(gv_rescue_origin[i][1]), RoundFloat(gv_rescue_origin[i][2]));
			
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
		
	FormatEx(game_time, sizeof(game_time), "%s.%s", temp1, fraction);
		
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
stock int FindNearEntityByClassname(int entity, char[] classname, bool near = true, float distance = 0.0)
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
 * логирует в зависимости от DEBUG
 *
 * DEBUG 		- правда - логирует, ложь - нет
 * logfile 		- путь лог файла с именем и расширением
 * message 		- сообщение
 * any ... 		- параметры функции
 */
stock void LogToDebug(bool debug_status = false, char [] logfile, char [] message, any ...)
{
	if (!debug_status)
	{
		return;
	}

	Handle h_file = OpenFile(logfile, "a+");
	
	if (h_file == null)
	{
		char plugin_name[PLATFORM_MAX_PATH];
		GetPluginFilename(INVALID_HANDLE, plugin_name, sizeof(plugin_name));
		
		LogError("[%s]: LogToDebug: error open file %s", plugin_name, logfile);
		return;
	}
	
	float time = GetGameTime();
		
	char fraction[5]; // кол-во разрядов после запятой, если 5, то 2, если 6, то 3 и т.д.
	FloatToString(FloatFraction(time), fraction, sizeof(fraction));
		
	char game_time[PLATFORM_MAX_PATH];
	FloatToString(time, game_time, sizeof(game_time));
	
	char temp1[PLATFORM_MAX_PATH];
	SplitString(game_time, ".", temp1, sizeof(temp1));
	
	if (strlen(temp1) == 1)
	{
		Format(temp1, sizeof(temp1), "00%s", temp1);
	}
	else if (strlen(temp1) == 2)
	{
		Format(temp1, sizeof(temp1), "0%s", temp1);
	}
		
	char temp2[PLATFORM_MAX_PATH];
	SplitString(fraction, ".", temp2, sizeof(temp2));
	int len = strlen(temp2) + 1;
	
	strcopy(fraction, sizeof(fraction), fraction[len]);
	Format(game_time, sizeof(game_time), "%s.%s", temp1, fraction);
		
	SetGlobalTransTarget(LANG_SERVER);
	
	len = strlen(message) + PLATFORM_MAX_PATH;
	char [] buffer = new char[len];
	
	VFormat(buffer, len, message, 4); // 4 - это номер параметра any
	
	char data[64];
	FormatTime(data, sizeof(data), "%T", GetTime());
	
	Format(buffer, len + 16, "%s:%s %s", data, game_time, buffer);
	WriteFileLine(h_file, buffer);
	
	CloseHandle(h_file);
}
