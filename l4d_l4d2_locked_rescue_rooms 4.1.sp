/**
 * ========================================================================
 * Plugin [L4D/L4D2] Lock rescue
 * Blocks the Respawn Doors until a player appears in the room
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
	name 		= 	"[L4D/L4D2] Locked rescue rooms",
	author 		= 	"Skv",
	description = 	"Player respawn doors are locked until respawn",
	version 	= 	"4.1",
	url 		= 	"https://forums.alliedmods.net/showthread.php?p=2825973#post2825973"
}

bool DEBUG 			= false;
bool DEBUG_SPRITE 	= false;
bool DEBUG_CALL 	= false;
bool DEBUG_MODE		= false;
bool DEBUG_KV		= false;
bool DEBUG_SCAN		= false;
bool DEBUG_OPENDIR	= false;
bool DEBUG_RENAME	= false;

#define MAX_PLAYERS 				18
#define MAX_ENTITIES				4096

#define MAX_CLASSNAME_LENGTH 		64
#define MAX_STRING_LENGTH			128

#define ROOM_SCAN_MAX_DISTANCE 		1000.0
#define ROOM_NAME 					"lr_room_rescue"
#define MAX_TIMERS					128

int 	gi_waiting_rooms			[MAX_TIMERS + 1];
int 	gi_active_rescue			[MAX_TIMERS + 1][2];

char 	gs_glow_model[]				= "sprites/glow01.vmt";

ConVar 	gc_handle_color_locked;
ConVar 	gc_handle_color_unlocked;
ConVar 	gc_handle_color_brightness;
ConVar 	gc_force_doors_open;
ConVar 	gc_force_open_distance;
ConVar 	gc_force_doors_speed;
ConVar 	gc_rescue_mode;

#define DOOR_HANDLE_NAME 			"lr_door_handle_sprite"
char 	gs_handle_color_locked		[16];
char 	gs_handle_color_unlocked	[16];

float 	gf_force_open_distance;

int 	gi_handle_color_brightness;

bool 	gb_finale_start;
bool 	gb_mission_lost;

Handle 	gk_unlocked_doors;
Handle 	gk_rooms;
Handle 	gt_Timers					[MAX_TIMERS + 1];



public APLRes AskPluginLoad2(Handle plugin, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_Left4Dead && GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead and Left 4 Dead 2");
		return APLRes_SilentFailure;
	}
	
	return APLRes_Success;
}
			
public OnPluginStart()
{
	HookEvent("survivor_call_for_help", Event_survivor_call_for_help);
	HookEvent("finale_start", Event_finale_start);
	HookEvent("survivor_rescued", Event_survivor_rescued);
	HookEvent("mission_lost", Event_mission_lost);
	
	gc_handle_color_locked = CreateConVar("lr_handle_color_locked", "255 0 0", "Sets the color of a locked door handle");
	SetConVarFlags(gc_handle_color_locked, GetConVarFlags(gc_handle_color_locked) & ~FCVAR_NOTIFY);
	
	gc_handle_color_unlocked = CreateConVar("lr_handle_color_unlocked", "0 255 0", "Sets the color of the unlocked door handle");
	SetConVarFlags(gc_handle_color_unlocked, GetConVarFlags(gc_handle_color_unlocked) & ~FCVAR_NOTIFY);
	
	gc_handle_color_brightness = CreateConVar("lr_handle_color_brightness", "200", "Sets the brightness of the door handle", _, true, 0.0, true, 255.0);
	SetConVarFlags(gc_handle_color_brightness, GetConVarFlags(gc_handle_color_brightness) & ~FCVAR_NOTIFY);
	
	gc_force_doors_open = CreateConVar("lr_force_doors_open", "1", "Enables automatic door opening when a survivor approaches", _, true, 0.0, true, 1.0);
	SetConVarFlags(gc_force_doors_open, GetConVarFlags(gc_force_doors_open) & ~FCVAR_NOTIFY);
	
	gc_force_open_distance = CreateConVar("lr_force_open_distance", "400", "Sets the automatic door opening distance", _, true, 200.0, true, 800.0);
	SetConVarFlags(gc_force_open_distance, GetConVarFlags(gc_force_open_distance) & ~FCVAR_NOTIFY);
	
	gc_force_doors_speed = CreateConVar("lr_force_doors_speed", "200", "Sets the opening speed of all doors, 0 - disabled", _, true, 0.0, true, 400.0);
	SetConVarFlags(gc_force_doors_speed, GetConVarFlags(gc_force_doors_speed) & ~FCVAR_NOTIFY);
	
	gc_rescue_mode = CreateConVar("lr_rescue_mode", "0", "Respawn mode control: 0 - respawn mode control disabled, 1 - rescue is active only once, 2 - rescue is active many times, 3 - rescue is disabled", _, true, 0.0, true, 3.0);
	SetConVarFlags(gc_rescue_mode, GetConVarFlags(gc_rescue_mode) & ~FCVAR_NOTIFY);
	
	HookConVarChange(gc_rescue_mode, OnConVarChanged);
	
	AutoExecConfig(true, "lock_rescue");
}

void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (gb_mission_lost)
	{
		return;
	}
	
	if (gb_finale_start)
	{
		return;
	}
	
	PrintToChatSkv(DEBUG_MODE, "OnConVarChanged: oldValue %s, newValue %s", oldValue, newValue);
	PrintToChatSkv(true, "OnConVarChanged: rescue_mode %s", newValue);
	
	
	if (StringToInt(newValue) == 3)
	{
		RescueMode3();
	}
	else if (StringToInt(newValue) == 2)
	{
		char name[MAX_CLASSNAME_LENGTH];
		
		int i = -1; int timer_slot;
		while ((i = FindEntityByClassname(i, "info_target")) != -1)
		{
			GetEntPropString(i, Prop_Data, "m_iName", name, sizeof(name));
			if (!strcmp(name, ROOM_NAME))
			{
				timer_slot = GetFreeTimerSlot();
				if (timer_slot)
				{
					gt_Timers[timer_slot] = CreateTimer(1.0, IsAnyClientNear, EntIndexToEntRef(i), TIMER_REPEAT);
				}
			}
		}
	}
	else //if (StringToInt(oldValue) == 3)
	{
		char name[MAX_CLASSNAME_LENGTH];
		
		int i = -1;
		while ((i = FindEntityByClassname(i, "info_target")) != -1)
		{
			GetEntPropString(i, Prop_Data, "m_iName", name, sizeof(name));
			if (!strcmp(name, ROOM_NAME))
			{
				if (!GetEntProp(i, Prop_Data, "m_spawnflags"))
				{
					LockRoom(i);
					ReCreateAllRescuesRoom(i);
				}
			}
		}
	}
}

void RescueMode3()
{
	char name[MAX_CLASSNAME_LENGTH];
		
	int i = -1; int door;
	while ((i = FindEntityByClassname(i, "info_target")) != -1)
	{
		GetEntPropString(i, Prop_Data, "m_iName", name, sizeof(name));
		if (!strcmp(name, ROOM_NAME))
		{
			CloseRoomTimer(i);
			RemoveAllRescuesRoom(i);
			
			door = -1;
			while ((door = FindEntityByClassname(door, "prop_door_rotating")) != -1)
			{
				if (i == GetEntPropEnt(door, Prop_Data, "m_hOwnerEntity"))
				{
					HookSingleEntityOutput(door, "OnOpen", OnOpen_Door_mode3, true);
					InputEntity(door, "Unlock");
				}
			}
		}
	}
	
	InputTarget(DOOR_HANDLE_NAME, "Kill");
}

bool CloseRoomTimer(int room)
{
	for (int i = 1; i <= MAX_TIMERS; i++)
	{
		if (gi_waiting_rooms[i] == room)
		{
			gi_waiting_rooms[i] = 0;
			
			if (IsValidHandle(gt_Timers[i]))
			{
				CloseHandle(gt_Timers[i]);
			}
			
			return true;
		}
	}
	
	return false;
}

void OnOpen_Door_mode3(char [] output, int door, int activator, float delay)
{
	if (GetConVarInt(gc_rescue_mode) != 3)
	{
		return;
	}

	int room = GetEntPropEnt(door, Prop_Data, "m_hOwnerEntity");
	RemoveAllRescuesRoom(room);
	
	DispatchKeyValue(room, "spawnflags", "4");
}

public OnMapStart()
{
	Delete_Timers();
	
	PrecacheModel(gs_glow_model);
}

void Event_mission_lost(Handle:event, const String:name[], bool:dontBroadcast)
{
	gb_mission_lost = true;
	Delete_Timers();
}

public OnGameplayStart(int stage)
{
	if (stage == 0)
	{
		gb_finale_start = false;
		gb_mission_lost = false;
		
		ClearAllActiveRescue();
		Delete_Timers();
		
		return;
	}
	
	if (stage != 5)
	{
		return;
	}
		
	if (DEBUG || DEBUG_SPRITE || DEBUG_CALL || DEBUG_MODE || DEBUG_SCAN || DEBUG_RENAME)
	{
		ServerCommand("sm_cvar rescue_min_dead_time 5");
	}
	
	int rescue_mode = GetConVarInt(gc_rescue_mode);
	PrintToChatSkv(true, "OnGameplayStart: rescue_mode %d", rescue_mode);
	
	if (IsValidHandle(gk_unlocked_doors))
	{
		CloseHandle(gk_unlocked_doors);
	}
	
	gk_unlocked_doors = CreateKeyValues("unlocked_doors");
	
	if (IsValidHandle(gk_unlocked_doors))
	{
		if (!FileToKeyValues(gk_unlocked_doors, "addons/sourcemod/configs/unlocked_doors.txt"))
		{
			char plugin_name[PLATFORM_MAX_PATH];
			GetPluginFilename(INVALID_HANDLE, plugin_name, sizeof(plugin_name));
			
			PrintToServer("%s. error open lock_rescue_data.txt", plugin_name);
				
			CloseHandle(gk_unlocked_doors);
		}
	}
	
	if (IsValidHandle(gk_rooms))
	{
		CloseHandle(gk_rooms);
	}
	
	gk_rooms = CreateKeyValues("rooms");
	
	int speed = GetConVarInt(gc_force_doors_speed);
	if (speed)
	{
		SetAllDoorsSpeed(speed);
	}
	
	GetConVarString(gc_handle_color_locked, gs_handle_color_locked, sizeof(gs_handle_color_locked));
	GetConVarString(gc_handle_color_unlocked, gs_handle_color_unlocked, sizeof(gs_handle_color_unlocked));
	
	gi_handle_color_brightness = GetConVarInt(gc_handle_color_brightness);
	
	gf_force_open_distance 	= GetConVarFloat(gc_force_open_distance);
	//gi_change_model 		= GetConVarInt(gc_change_model);
		
	char map_current[MAX_CLASSNAME_LENGTH];
	GetCurrentMap(map_current, sizeof(map_current));
	
	int i = -1;
	while ((i = FindEntityByClassname(i, "info_survivor_rescue")) != -1)
	{
		Search_Recue_Rooms(i);
	}
	
	char name[MAX_CLASSNAME_LENGTH];
	
	i = -1; int owner;
	while ((i = FindEntityByClassname(i, "prop_door_rotating")) != -1)
	{
		owner = GetEntPropEnt(i, Prop_Data, "m_hOwnerEntity");
		if (IsValidEntity(owner))
		{
			GetEntPropString(owner, Prop_Data, "m_iName", name, sizeof(name));
			if (!strcmp(name, ROOM_NAME))
			{
				RenameRescueDoor(i);
			}
		}
	}
	
	if (GetConVarInt(gc_rescue_mode) == 3)
	{
		RescueMode3();
	}
	else
	{
		i = -1;
		while ((i = FindEntityByClassname(i, "info_target")) != -1)
		{
			GetEntPropString(i, Prop_Data, "m_iName", name, sizeof(name));
			if (!strcmp(name, ROOM_NAME))
			{
				RoomData_Create(i);
				LockRoom(i);
			}
		}
	}
	
	KeyValues_ToFile(gk_rooms, "create");
}

public OnServerEmpty()
{
	Delete_Timers();
	
	char plugin_name[PLATFORM_MAX_PATH];
	GetPluginFilename(INVALID_HANDLE, plugin_name, sizeof(plugin_name));
	
	ServerCommand("sm plugins reload \"%s\"", plugin_name);
}

void SetAllDoorsSpeed(int speed)
{
	int i = -1;
	while ((i = FindEntityByClassname(i, "prop_door_rotating")) != -1)
	{
		if (GetEntProp(i, Prop_Data, "m_spawnflags") & 8192)
		{
			DispatchKeyValueInt(i, "speed", speed);
		}
	}
}

void Event_survivor_call_for_help(Handle:event, const String:name[], bool:dontBroadcast)
{
	int rescue = GetEventInt(event, "subject");
	if (!IsValidEntity(rescue))
	{
		return;
	}
	
	int room = GetEntPropEnt(rescue, Prop_Data, "m_hOwnerEntity");
	PrintToChatSkv(DEBUG_CALL, "Event_survivor_call_for_help: room %d rescue %d", room, rescue);
		
	SetActiveRescue(rescue, GetEventInt(event, "userid"));
	
	if (UnLockRoom(room))
	{
		return;
	}
	
	PrintToChatSkv(DEBUG_CALL, "Event_survivor_call_for_help: cant unlock room %d rescue %d", room, rescue);
	
	//LogError("Event_survivor_call_for_help: cant unlock room %d rescue %d", room, rescue);
	Search_Recue_Rooms(rescue);
	
	room = GetEntPropEnt(rescue, Prop_Data, "m_hOwnerEntity");
	
	LockRoom(room);
	UnLockRoom(room);
}

void Event_finale_start(Handle:event, const String:name[], bool:dontBroadcast)
{
	gb_finale_start = true;
	
	for (int i = 1; i <= MAX_TIMERS; i++)
	{
		if (IsValidHandle(gt_Timers[i]))
		{
			CloseHandle(gt_Timers[i]);
		}
		
		gi_waiting_rooms[i] = 0;
	}
	
	if (GetConVarInt(gc_rescue_mode) == 3)
	{
		return;
	}
	
	char targetname[MAX_CLASSNAME_LENGTH];
	
	int i = -1;
	while ((i = FindEntityByClassname(i, "info_target")) != -1)
	{
		GetEntPropString(i, Prop_Data, "m_iName", targetname, sizeof(targetname));
		if (!strcmp(targetname, ROOM_NAME))
		{
			UnLockRoom(i);
		}
	}
	
	InputTarget(DOOR_HANDLE_NAME, "Kill");
}

void Event_survivor_rescued(Handle:event, const String:name[], bool:dontBroadcast)
{
	int userid = GetEventInt(event, "victim");
	PrintToChatSkv(DEBUG_CALL, "%s %d", name, userid);
	
	int rescue = GetRescueFromActiveRoom(userid);
	PrintToChatSkv(DEBUG_CALL, "get rescue %d", rescue);
	
	if (rescue && IsValidEntity(rescue))
	{
		int room = GetEntPropEnt(rescue, Prop_Data, "m_hOwnerEntity");
		PrintToChatSkv(DEBUG_CALL, "get room %d", room);
		
		int i = -1; int owner_i;
		while ((i = FindEntityByClassname(i, "prop_door_rotating")) != -1)
		{
			owner_i = GetEntPropEnt(i, Prop_Data, "m_hOwnerEntity"); 
			if (owner_i == room)
			{
				ChangeDoorSprites(i);
			}
		}
		
		int rescue_mode = GetConVarInt(gc_rescue_mode);
		if (rescue_mode)
		{
			RemoveAllRescuesRoom(room);
		}
		else
		{
			i = -1;
			while ((i = FindEntityByClassname(i, "prop_door_rotating")) != -1)
			{
				if (!GetEntProp(i, Prop_Data, "m_iHammerID"))
				{
					owner_i = GetEntPropEnt(i, Prop_Data, "m_hOwnerEntity"); 
					if (owner_i == room)
					{
						RemoveAllRescuesRoom(room);
					}
				}
			}
		}
	}
	
	if (!GetDeathSurvivors())
	{
		ClearAllActiveRescue();
	}
}

void RemoveAllRescuesRoom(int room)
{
	if (!IsValidEntity(room))
	{
		return;
	}
	
	int i = -1; int owner_i;
	while ((i = FindEntityByClassname(i, "info_survivor_rescue")) != -1)
	{
		owner_i = GetEntPropEnt(i, Prop_Data, "m_hOwnerEntity"); 
		if (owner_i == room)
		{
			InputKill(i, 1.0);
			PrintToChatSkv(DEBUG_MODE, "RemoveAllRescuesRoom: room %d rescue %d", room, i);
		}
	}
}

Action:LockActiveRooms(Handle timer)
{
	PrintToChatSkv(DEBUG, "LockActiveRooms");
	
	char targetname[MAX_CLASSNAME_LENGTH];
		
	int i = -1; int flags;
	while ((i = FindEntityByClassname(i, "info_target")) != -1)
	{
		flags = GetEntProp(i, Prop_Data, "m_spawnflags");
		if (flags == 2) // если активирована
		{
			GetEntPropString(i, Prop_Data, "m_iName", targetname, sizeof(targetname));
			if (!strcmp(targetname, ROOM_NAME))
			{
				LockRoom(i);
			}
		}
	}
}

void LockRoom(int room)
{
	if (GetConVarInt(gc_rescue_mode) == 3)
	{
		return;
	}
	
	if (!IsValidEntity(room)) {return;}
	
	char classname[MAX_CLASSNAME_LENGTH];
	GetEntityClassname(room, classname, sizeof(classname));
	
	if (strcmp(classname, "info_target"))
	{
		return;
	}
	
	DispatchKeyValue(room, "spawnflags", "0"); // комната закрыта
	
	int owner_i;
	
	for (int i = MAX_PLAYERS; i <= MAX_ENTITIES; i++)
	{
		if (IsValidEntity(i))
		{
			GetEntityClassname(i, classname, sizeof(classname));
			if (!strcmp(classname, "prop_door_rotating") || !strcmp(classname, "func_door"))
			{
				owner_i = GetEntPropEnt(i, Prop_Data, "m_hOwnerEntity"); 
				if (owner_i == room)
				{
					InputEntity(i, "Close");
					InputEntity(i, "Lock");
									
					PrintToChatSkv(DEBUG, "LockRoom: room %d door %d", room, i);
					
					ChangeDoorSprites(i);
					SetDoorSprites(i, gs_handle_color_locked);
				}
			}
		}
	}
}

void OnFullyOpen_Door(char [] output, int door, int activator, float delay)
{
	if (!IsValidEntity(door)) {return;}
	
	char classname[MAX_CLASSNAME_LENGTH];
	GetEntityClassname(door, classname, sizeof(classname));
	
	if (strcmp(classname, "prop_door_rotating") && strcmp(classname, "func_door"))
	{
		return;
	}
	
	int room = GetEntPropEnt(door, Prop_Data, "m_hOwnerEntity");
	if (!IsValidEntity(room))
	{
		return;
	}
	
	InputEntity(door, "Unlock", _, 2.0);
	
	DispatchKeyValue(room, "spawnflags", "4"); // комната открыта
	PrintToChatSkv(DEBUG, "OnOpen_Door: room %d door %d", room, door);
	
	if (!gb_finale_start)
	{
		CreateTimer(2.0, LockActiveRooms, TIMER_FLAG_NO_MAPCHANGE);
				
		int rescue_mode = GetConVarInt(gc_rescue_mode);
		if (rescue_mode == 2)
		{
			int timer_slot = GetFreeTimerSlot();
			if (timer_slot)
			{
				gt_Timers[timer_slot] = CreateTimer(1.0, IsAnyClientNear, EntIndexToEntRef(room), TIMER_REPEAT);
			}
		}
	}
}

void OnOpen_Door(char [] output, int door, int activator, float delay)
{
	ChangeDoorSprites(door);
}

Action:IsAnyClientNear(Handle timer, int ref)
{
	if (gb_mission_lost)
	{
		return Plugin_Stop;
	}
	
	if (gb_finale_start)
	{
		return Plugin_Stop;
	}
	
	if (GetConVarInt(gc_rescue_mode) != 2)
	{
		return Plugin_Stop;
	}
	
	int room = EntRefToEntIndex(ref);
	if (!IsValidEntity(room))
	{
		return Plugin_Stop;
	}
	
	float room_pos[3];
	GetEntPropVector(room, Prop_Data, "m_vecOrigin", room_pos);
		
	float pos_i[3];
	
	int alive;
	
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		if (IsValidClientTeam2Alive(i))
		{
			alive ++;
		}
	}	
	
	int far;
	
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		if (IsValidClientTeam2Alive(i))
		{
			GetClientEyePosition(i, pos_i);
			
			if (GetVectorDistance(room_pos, pos_i) >= 500.0)
			{
				far ++;
			}
		}
	}
	
	if (alive != far)
	{
		return Plugin_Continue;
	}
	
	PrintToChatSkv(DEBUG, "IsAnyClientNear: all is far");
	
	int owner; char classname[MAX_CLASSNAME_LENGTH];
	
	int door_state;
	
	for (int i = MAX_PLAYERS; i <= MAX_ENTITIES; i++)
	{
		if (IsValidEntity(i))
		{
			GetEntityClassname(i, classname, sizeof(classname));
			if (!strcmp(classname, "prop_door_rotating") || !strcmp(classname, "func_door"))
			{
				owner = GetEntPropEnt(i, Prop_Data, "m_hOwnerEntity");
				if (owner == room)
				{
					if (!strcmp(classname, "prop_door_rotating"))
					{
						//0 - закрыта, 1 - открывается, 2 - открыта, 3 - закрывается
						door_state = GetEntProp(i, Prop_Send, "m_eDoorState");
						if (door_state == 0)
						{
							ReCreateAllRescuesRoom(room);
						}
						else
						{
							HookSingleEntityOutput(i, "OnFullyClosed", OnFullyClosed_Door, true);
						}
					}
					else
					{
						ReCreateAllRescuesRoom(room);
					}
					
					LockRoom(room);
					
					break;
				}
			}
		}
	}
	
	return Plugin_Stop;
}

void OnFullyClosed_Door(char [] output, int door, int activator, float delay)
{
	PrintToChatSkv(DEBUG, "OnFullyClosed_Door");
	
	if (!IsValidEntity(door)) {return;}
	
	char classname[MAX_CLASSNAME_LENGTH];
	GetEntityClassname(door, classname, sizeof(classname));
	
	if (strcmp(classname, "prop_door_rotating") && strcmp(classname, "func_door"))
	{
		return;
	}
	
	int room = GetEntPropEnt(door, Prop_Data, "m_hOwnerEntity");
	
	ReCreateAllRescuesRoom(room);
}

bool ReCreateAllRescuesRoom(int room)
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
	Format(temp, sizeof(temp), "%d", room);
	
	if (!KvJumpToKey(gk_rooms, temp, false))
	{
		KvRewind(gk_rooms);
		return false;
	}
	
	PrintToChatSkv(DEBUG_KV, "ReCreateAllRescuesRoom %s", temp);
	
	int amount = 1;
	Format(temp, sizeof(temp), "rescue %d", amount);
	
	char value[MAX_STRING_LENGTH];
	int len;
	
	float origin[3]; float angles[3];
	
	int entity;
	
	while (KvJumpToKey(gk_rooms, temp, false))
	{
		PrintToChatSkv(DEBUG_KV, "%s", temp);
		
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
			
			PrintToChatSkv(DEBUG_KV, "origin %d %d %d", RoundFloat(origin[0]), RoundFloat(origin[1]), RoundFloat(origin[2]));
			
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
				
				PrintToChatSkv(DEBUG_KV, "angles %d %d %d", RoundFloat(angles[0]), RoundFloat(angles[1]), RoundFloat(angles[2]));
			}
			
			entity = CreateEntityByName("info_survivor_rescue");
			if (IsValidEntity(entity))
			{
				DispatchKeyValue(entity, "model", "models/editor/playerstart.mdl");
				DispatchKeyValueVector(entity, "rescueEyePos", origin);
				DispatchKeyValueVector(entity, "angles", angles);
			
				SetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity", room);
			
				DispatchSpawn(entity);
				ActivateEntity(entity);
			
				TeleportEntity(entity, origin, angles);
			}
		}
				
		amount ++;
		Format(temp, sizeof(temp), "rescue %d", amount);
		
		PrintToChatSkv(DEBUG_KV, "temp %s", temp);
		
		KvGoBack(gk_rooms);
	}
	
	KvRewind(gk_rooms);
	
	return true;
}

public OnNeedUnlockRescueRoom(int door, float time)
{
	if (!IsValidEntity(door) || time < 0.0)
	{
		return;
	}
	
	int timer_slot = GetFreeTimerSlot();
	if (timer_slot)
	{
		gt_Timers[timer_slot] = CreateTimer(time, UnLockRoom_Delay, EntIndexToEntRef(door));
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

void Delete_Timers()
{
	for (int i = 1; i <= MAX_TIMERS; i++)
	{
		if (IsValidHandle(gt_Timers[i]))
		{
			CloseHandle(gt_Timers[i]);
		}
		
		gi_waiting_rooms[i] = 0;
	}
}
/*
Action:LockRoom_Delay(Handle timer, int ref)
{
	int room = EntRefToEntIndex(ref);
	LockRoom(room);
}
*/
Action:UnLockRoom_Delay(Handle timer, int ref)
{
	int door = EntRefToEntIndex(ref);
	if (!IsValidEntity(door))
	{
		return;
	}
	
	char classname[MAX_CLASSNAME_LENGTH];
	GetEntityClassname(door, classname, sizeof(classname));
	
	if (strcmp(classname, "prop_door_rotating") && strcmp(classname, "func_door"))
	{
		return;
	}
	
	int room = GetEntPropEnt(door, Prop_Data, "m_hOwnerEntity");
	UnLockRoom(room);
}

bool UnLockRoom(int room)
{
	if (!IsValidEntity(room)) 
	{
		return false;
	}
	
	char classname[MAX_CLASSNAME_LENGTH];
	GetEntityClassname(room, classname, sizeof(classname));
	
	if (strcmp(classname, "info_target"))
	{
		return false;
	}
	
	/*
	if (GetEntProp(room, Prop_Data, "m_spawnflags") == 2)
	{
		return true;
	}
	*/
	
	DispatchKeyValue(room, "spawnflags", "2"); // команта активирована
	
	bool result = false;
	
	int active_rescues = GetCountActiveRescues();
	
	float distance = gf_force_open_distance;
	int force_doors_open = GetConVarInt(gc_force_doors_open);
	
	int owner_i; int door_state;
	
	for (int i = MAX_PLAYERS; i <= MAX_ENTITIES; i++)
	{
		if (IsValidEntity(i))
		{
			GetEntityClassname(i, classname, sizeof(classname));
			if (!strcmp(classname, "prop_door_rotating") || !strcmp(classname, "func_door"))
			{
				owner_i = GetEntPropEnt(i, Prop_Data, "m_hOwnerEntity"); 
		
				if (owner_i == room)
				{
					result = true;
					
					InputEntity(i, "Unlock");
					PrintToChatSkv(DEBUG, "UnLockRoom: room %d door %d", room, i);
					
					HookSingleEntityOutput(i, "OnFullyOpen", OnFullyOpen_Door, true);
					HookSingleEntityOutput(i, "OnOpen", OnOpen_Door, true);
					
					if (!gb_finale_start)
					{
						if (!strcmp(classname, "prop_door_rotating"))
						{
							// 0 - закрыта, 1 - открывается, 2 - открыта, 3 - закрывается
							door_state = GetEntProp(i, Prop_Send, "m_eDoorState");
							PrintToChatSkv(DEBUG, "UnLockRoom: door %d door_state %d", i, door_state);
	
							if (door_state == 0 || door_state == 3)
							{
								if (!ChangeDoorSprites(i, gs_handle_color_unlocked))
								{
									SetDoorSprites(i, gs_handle_color_unlocked);
								}
							}
						}
						
						//PrintToChatSkv(DEBUG, "UnLockRoom: active_rescues %d GetDeathSurvivors() %d", active_rescues, GetDeathSurvivors());
						
						if (active_rescues >= GetDeathSurvivors() && force_doors_open != 0)
						{
							if (IsAnySurvivorNear(i, distance))
							{
								InputEntity(i, "Open", _, 0.1);
								
								if (!strcmp(classname, "prop_door_rotating"))
								{
									int	timer_slot = GetFreeTimerSlot();
									if (timer_slot)
									{
										gt_Timers[timer_slot] =CreateTimer(0.5, ForceOpenDoor, EntIndexToEntRef(i), TIMER_REPEAT);
									}
								}
							}
						}
					}
					else
					{
						if (!ChangeDoorSprites(i, gs_handle_color_unlocked))
						{
							SetDoorSprites(i, gs_handle_color_unlocked);
						}
						
						SetEntPropEnt(i, Prop_Data, "m_hOwnerEntity", -1);
					}
				}
			}
		}
	}
	
	return result;
}

Action:ForceOpenDoor(Handle timer, int ref)
{
	if (gb_mission_lost)
	{
		return Plugin_Stop;
	}
	
	if (GetConVarInt(gc_rescue_mode) == 3)
	{
		return Plugin_Stop;
	}
	
	int door = EntRefToEntIndex(ref);
	if (!IsValidEntity(door))
	{
		return Plugin_Stop;
	}
	
	char classname[MAX_CLASSNAME_LENGTH];
	GetEntityClassname(door, classname, sizeof(classname));
	
	if (strcmp(classname, "prop_door_rotating"))
	{
		return Plugin_Stop;
	}
	
	// 0 - закрыта, 1 - открывается, 2 - открыта, 3 - закрывается
	int door_state = GetEntProp(door, Prop_Send, "m_eDoorState");
	PrintToChatSkv(DEBUG, "ForceOpenDoor: door %d door_state %d", door, door_state);
	
	if (door_state == 1 || door_state == 2)
	{
		return Plugin_Stop;
	}
	
	if (door_state != 0)
	{
		return Plugin_Continue;
	}
	
	InputEntity(door, "Open");
	
	/*
	SetVariantString("OnUser1 !self:Open::0.1:-1");
	AcceptEntityInput(door, "AddOutput");
	
	AcceptEntityInput(door, "FireUser1");
	*/
	return Plugin_Continue;
}

bool Search_Recue_Rooms(int rescue)
{	
	if (!IsValidEntity(rescue))
	{
		return false;
	}
	
	float pos_rescue[3];
	GetEntPropVector(rescue, Prop_Data, "m_vecOrigin", pos_rescue);
	
	int sprite = SpawnDebugSprite(pos_rescue, "255 0 0");
		
	pos_rescue[2] += 70.0;
	
	float vec_buffer[3];
	vec_buffer = pos_rescue;
	
	if (IsSkyCheck(vec_buffer))
	{
		PrintToChatSkv(DEBUG_SCAN, "sky check rescue %d", rescue);
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
			PrintToChatSkv(DEBUG, "distance %f", distance);
			
			if (distance > STEP_SEARCH) //  && distance <= 400.0
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
	
	if (sprite && scan)
	{
		InputEntity(sprite, "color", "0 255 0");
	}
	
	return scan;
}

// ang_min - начинаем с угла
// ang_max - заканчиваем углом
bool ScanDoorAround(int rescue, float pos_rescue[3])
{
	SpawnDebugSprite(pos_rescue, "255 255 0");
		
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
				
				if (IsValidDoor(door) && SetRoomData(rescue, door))
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
	
	if (!IsValidEntity(door))
	{
		return false;
	}
	
	int owner_rescue = GetEntPropEnt(rescue, Prop_Data, "m_hOwnerEntity");
	int owner_door = GetEntPropEnt(door, Prop_Data, "m_hOwnerEntity");
	
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
		DoorSlaveForceOpendir(door);
		SetEntPropEnt(door, Prop_Data, "m_hOwnerEntity", room);
		
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
	
	char classname[MAX_CLASSNAME_LENGTH];
	GetEntityClassname(rescue, classname, sizeof(classname));
	
	if (strcmp(classname, "info_survivor_rescue"))
	{
		return 0;
	}
	
	if (!IsValidEntity(door))
	{
		return 0;
	}
	
	GetEntityClassname(door, classname, sizeof(classname));
	if (strcmp(classname, "prop_door_rotating") && strcmp(classname, "func_door"))
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
	if (IsValidEntity(rescue))
	{
		GetEntPropVector(rescue, Prop_Data, "m_vecOrigin", pos_spawn);
	}
	
	DispatchKeyValueVector(room, "origin", pos_spawn);
	DispatchKeyValue(room, "angles", "0 0 0");
			
	DispatchSpawn(room);
	
	SetEntPropEnt(rescue, Prop_Data, "m_hOwnerEntity", room);
	
	DoorSlaveForceOpendir(door);
	SetEntPropEnt(door, Prop_Data, "m_hOwnerEntity", room);
		
	return room;
}

void DoorSlaveForceOpendir(int door)
{
	if (!IsValidEntity(door))
	{
		return;
	}
	
	char classname[MAX_CLASSNAME_LENGTH];
	GetEntityClassname(door, classname, sizeof(classname));
	
	if (strcmp(classname, "prop_door_rotating"))
	{
		return;
	}
	
	int room = GetEntPropEnt(door, Prop_Data, "m_hOwnerEntity");
	if (IsValidEntity(room))
	{
		GetEntityClassname(room, classname, sizeof(classname));
		if (!strcmp(classname, "info_target"))
		{
			return;
		}
	}
	
	char slave_name[MAX_CLASSNAME_LENGTH];
	GetEntPropString(door, Prop_Data, "m_SlaveName", slave_name, sizeof(slave_name));
	PrintToChatSkv(DEBUG_OPENDIR, "DoorSlaveForceOpendir: door %d m_SlaveName %s", door, slave_name);
					
	if (!strlen(slave_name))
	{
		return;
	}
	
	SetEntProp(door, Prop_Data, "m_eOpenDirection", 1);
	PrintToChatSkv(DEBUG_OPENDIR, "DoorSlaveForceOpendir: door %d force opendir 1", door);
	
	int i = -1; char name[MAX_CLASSNAME_LENGTH];
	while ((i = FindEntityByClassname(i, "prop_door_rotating")) != -1)
	{
		GetEntPropString(i, Prop_Data, "m_iName", name, sizeof(name));
		if (!strcmp(name, slave_name))
		{
			SetEntProp(i, Prop_Data, "m_eOpenDirection", 2);
			PrintToChatSkv(DEBUG_OPENDIR, "DoorSlaveForceOpendir: slave door %d force opendir 2", door);
		}
	}
}

void SetActiveRescue(int rescue, int userid)
{
	if (IsRescueActive(rescue))
	{
		return;
	}
	
	for (int i = 0; i <= MAX_TIMERS; i++)
	{
		if (!gi_active_rescue[i][0])
		{
			gi_active_rescue[i][0] = rescue;
			gi_active_rescue[i][1] = userid;
			
			PrintToChatSkv(DEBUG_CALL, "SetActiveRescue: set rescue %d", rescue);
			return;
		}
	}
}

int GetRescueFromActiveRoom(int userid)
{
	for (int i = 0; i <= MAX_TIMERS; i++)
	{
		if (gi_active_rescue[i][1] == userid)
		{
			return gi_active_rescue[i][0];
		}
	}
	
	return 0;
}

bool IsRescueActive(int rescue)
{
	for (int i = 0; i <= MAX_TIMERS; i++)
	{
		if (gi_active_rescue[i][0] == rescue)
		{
			return true;
		}
	}
	
	return false;
}

int GetCountActiveRescues()
{
	int active_rescue;
	
	for (int i = 0; i <= MAX_TIMERS; i++)
	{
		if (gi_active_rescue[i][0])
		{
			active_rescue ++;
		}
	}
	
	return active_rescue;
}

void ClearAllActiveRescue()
{
	PrintToChatSkv(DEBUG_CALL, "ClearAllActiveRescue");
	
	for (int i = 0; i <= MAX_TIMERS; i++)
	{
		gi_active_rescue[i][0] = 0;
		gi_active_rescue[i][1] = 0;
	}
}

void SetDoorSprites(int door, char [] light_color)
{	
	if (!IsValidEntity(door)) {return;}
	
	char classname[MAX_CLASSNAME_LENGTH];
	GetEntityClassname(door, classname, sizeof(classname));
	
	if (strcmp(classname, "prop_door_rotating"))
	{
		return;
	}
	
	PrintToChatSkv(DEBUG_SPRITE, "SetDoorSprites: door %d color %s", door, light_color);
	
	if (LookupEntityAttachment(door, "LeftHandle") && LookupEntityAttachment(door, "RightHandle"))
	{
		int entity = CreateEntityByName("env_sprite");
		if (entity == -1)
		{
			return;
		}
		
		DispatchKeyValue(entity, "targetname", DOOR_HANDLE_NAME);
			
		DispatchKeyValue(entity, "spawnflags", "1");
		DispatchKeyValue(entity, "scale", "0.4");
		DispatchKeyValue(entity, "rendermode", "9");
		DispatchKeyValue(entity, "renderfx", "0");
		DispatchKeyValue(entity, "rendercolor", light_color);
		DispatchKeyValueInt(entity, "renderamt", gi_handle_color_brightness);
		DispatchKeyValue(entity, "model", gs_glow_model);
		DispatchKeyValue(entity, "HDRColorScale", "1.0");
		DispatchKeyValue(entity, "GlowProxySize", "1");
		
		DispatchSpawn(entity);
		ActivateEntity(entity);
		
		SetVariantString("!activator");
		AcceptEntityInput(entity, "SetParent", door);
		
		SetVariantString("LeftHandle");
		AcceptEntityInput(entity,"SetParentAttachment");
		
		entity = CreateEntityByName("env_sprite");
		if (entity == -1)
		{
			return;
		}
		
		DispatchKeyValue(entity, "targetname", DOOR_HANDLE_NAME);
			
		DispatchKeyValue(entity, "spawnflags", "1");
		DispatchKeyValue(entity, "scale", "0.4");
		DispatchKeyValue(entity, "rendermode", "9");
		DispatchKeyValue(entity, "renderfx", "0");
		DispatchKeyValue(entity, "rendercolor", light_color);
		DispatchKeyValueInt(entity, "renderamt", gi_handle_color_brightness);
		DispatchKeyValue(entity, "model", gs_glow_model);
		DispatchKeyValue(entity, "HDRColorScale", "1.0");
		DispatchKeyValue(entity, "GlowProxySize", "1");
		
		DispatchSpawn(entity);
		ActivateEntity(entity);
		
		SetVariantString("!activator");
		AcceptEntityInput(entity, "SetParent", door);
		
		SetVariantString("RightHandle");
		AcceptEntityInput(entity,"SetParentAttachment");
		
		return;
	}
	
	int entity = CreateEntityByName("env_sprite");
	if (entity == -1)
	{
		return;
	}
	
	DispatchKeyValue(entity, "targetname", DOOR_HANDLE_NAME);
		
	DispatchKeyValue(entity, "spawnflags", "1");
	DispatchKeyValue(entity, "scale", "0.4"); // 0.4
	DispatchKeyValue(entity, "rendermode", "9");
	DispatchKeyValue(entity, "renderfx", "0");
	DispatchKeyValue(entity, "rendercolor", light_color);
	
	int handle_color_brightness = RoundFloat(gi_handle_color_brightness * 1.28);
	if (handle_color_brightness > 255)
	{
		handle_color_brightness = 255;
	}
	
	DispatchKeyValueInt(entity, "renderamt", handle_color_brightness);
	DispatchKeyValue(entity, "model", gs_glow_model);
	DispatchKeyValue(entity, "HDRColorScale", "1.0");
	DispatchKeyValue(entity, "GlowProxySize", "2");
	
	DispatchSpawn(entity);
	ActivateEntity(entity);
	
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
	
	TeleportEntity(entity, pos_door);
		
	SetVariantString("!activator");
	AcceptEntityInput(entity, "SetParent", door);
}

bool ChangeDoorSprites(int door, char [] color = "")
{
	bool result;
	
	if (!IsValidEntity(door))
	{
		return result;
	}
	
	char classname[MAX_CLASSNAME_LENGTH];
	GetEntityClassname(door, classname, sizeof(classname));
	
	if (strcmp(classname, "prop_door_rotating"))
	{
		return result;
	}
	
	int i = -1; int parent;
	
	while ((i = FindEntityByClassname(i, "env_sprite")) != -1)
	{
		parent = GetEntPropEnt(i, Prop_Data, "m_pParent");
		if (parent == door)
		{
			if (strlen(color) < 5)
			{
				result = true;
				
				InputKill(i);
				PrintToChatSkv(DEBUG_SPRITE, "ChangeDoorSprites: kill sprite door %d", door);
			}
			else
			{
				result = true;
				
				InputEntity(i, "color", color);
				PrintToChatSkv(DEBUG_SPRITE, "ChangeDoorSprites: door %d set color %s", door, color);
			}
		}
	}
	
	return result;
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

bool IsAnySurvivorNear(int door, float distance, float door_pos[3] = NULL_VECTOR)
{
	if (IsValidEntity(door))
	{
		GetEntPropVector(door, Prop_Data, "m_vecOrigin", door_pos);
	}
	
	float pos_i[3]; int parent; float pos_parent[3]; float heigh;
		
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		if (IsValidClientTeam2Alive(i) && !IsFakeClient(i))
		{
			GetEntPropVector(i, Prop_Data, "m_vecOrigin", pos_i);
			
			heigh = door_pos[2] - pos_i[2];
			if (heigh < 0)
			{
				heigh *= -1;
			}
			
			if (GetVectorDistance(door_pos, pos_i) <= distance && heigh <= 60.0)
			{
				return true;
			}
			else if (IsValidEntity(door))
			{
				parent = GetEntPropEnt(door, Prop_Data, "m_pParent");
			
				if (IsValidEntity(parent))
				{
					GetEntPropVector(parent, Prop_Data, "m_vecOrigin", pos_parent);
					
					if (GetVectorDistance(pos_parent, pos_i) <= distance && heigh <= 60.0)
					{
						return true;
					}
				}
			}
		}
	}	
	
	return false;
}

bool IsValidDoor(int door)
{
	if (!IsValidEntity(door))
	{
		return false;
	}
	
	if (!IsValidHandle(gk_unlocked_doors))
	{
		return true;
	}
	
	KvRewind(gk_unlocked_doors);
	
	char map_current[PLATFORM_MAX_PATH];
	GetCurrentMap(map_current, sizeof(map_current));
	
	if (!KvJumpToKey(gk_unlocked_doors, map_current, false))
	{
		KvRewind(gk_unlocked_doors);
		return true;
	}
	
	int hammerid = GetEntProp(door, Prop_Data, "m_iHammerID");
	
	char section_name[MAX_NAME_LENGTH];
	char key_value[MAX_NAME_LENGTH];
	
	if (KvGotoFirstSubKey(gk_unlocked_doors, false))
	{
		KvGetSectionName(gk_unlocked_doors, section_name, sizeof(section_name));
		KvGetString(gk_unlocked_doors, NULL_STRING, key_value, sizeof(key_value));
		
		if (!strcmp(section_name, "hammerid"))
		{
			if (hammerid == StringToInt(key_value))
			{
				//PrintToChatSkv(DEBUG, "hammerid %d", StringToInt(key_value));
			
				KvRewind(gk_unlocked_doors);
				return false;
			}
		}
		else if (!strcmp(section_name, "index"))
		{
			if (door == StringToInt(key_value))
			{
				//PrintToChatSkv(DEBUG, "index %d", StringToInt(key_value));
			
				KvRewind(gk_unlocked_doors);
				return false;
			}
		}
		
		while (KvGotoNextKey(gk_unlocked_doors, false))
		{
			if (KvGetDataType(gk_unlocked_doors, NULL_STRING) != KvData_None)
			{
				KvGetSectionName(gk_unlocked_doors, section_name, sizeof(section_name));
				KvGetString(gk_unlocked_doors, NULL_STRING, key_value, sizeof(key_value));
				
				if (!strcmp(section_name, "hammerid"))
				{
					if (hammerid == StringToInt(key_value))
					{
						//PrintToChatSkv(DEBUG, "hammerid %d", StringToInt(key_value));
					
						KvRewind(gk_unlocked_doors);
						return false;
					}
				}
				else if (!strcmp(section_name, "index"))
				{
					if (door == StringToInt(key_value))
					{
						//PrintToChatSkv(DEBUG, "index %d", StringToInt(key_value));
					
						KvRewind(gk_unlocked_doors);
						return false;
					}
				}
			}
		}
		
		KvGoBack(gk_unlocked_doors);
	}
		
	return true;
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
/*
int ReCreateDoor(int door)
{
	if (!IsValidEntity(door))
	{
		return 0;
	}
	
	PrintToChatSkv(DEBUG_RENAME, "ReCreateDoor: hammerid %d", GetEntProp(door, Prop_Data, "m_iHammerID"));
	
	char modelname[MAX_CLASSNAME_LENGTH];
	GetEntPropString(door, Prop_Data, "m_ModelName", modelname, sizeof(modelname));
	
	float pos_door[3];
	GetEntPropVector(door, Prop_Data, "m_vecOrigin", pos_door);
	
	float ang_door[3];
	GetEntPropVector(door, Prop_Data, "m_angRotation", ang_door);
	
	float axis_door[3];
	GetEntPropVector(door, Prop_Data, "m_vecAxis", axis_door);
	
	int skin = GetEntProp(door, Prop_Data, "m_nSkin");
	int body = GetEntProp(door, Prop_Data, "m_nBody");
	
	int owner = GetEntPropEnt(door, Prop_Data, "m_hOwnerEntity");
	
	int entity = CreateEntityByName("prop_door_rotating");
	if (entity == -1)
	{
		return 0;
	}
	
	InputKill(door);
	
	DispatchKeyValue(entity, "model", modelname);
	DispatchKeyValue(entity, "speed", "200");
	DispatchKeyValue(entity, "spawnpos", "0");
	DispatchKeyValue(entity, "spawnflags", "8192");
	DispatchKeyValue(entity, "returndelay", "-1");
	DispatchKeyValue(entity, "opendir", "0");
	DispatchKeyValue(entity, "hardware", "1");
	DispatchKeyValue(entity, "forceclosed", "1");
	DispatchKeyValue(entity, "distance", "90");
	DispatchKeyValue(entity, "ajarangles", "0 0 0");
	
	DispatchKeyValueInt(entity, "skin", skin);
	DispatchKeyValueInt(entity, "body", body);
	
	DispatchKeyValueVector(entity, "origin", pos_door);
	DispatchKeyValueVector(entity, "angles", ang_door);
	DispatchKeyValueVector(entity, "axis", axis_door);
	
	SetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity", owner);
	
	DispatchSpawn(entity);
	ActivateEntity(entity);
	
	return entity;
}
*/
bool IsSkyAbove(float origin[3])
{
	float vec_mins[3];
	vec_mins[0] = -5.0;
	vec_mins[1] = vec_mins[0];
	vec_mins[2] = -1.0;
	
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

bool TraceFilter_SkyCheck(entity, contentsMask, any:client)
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

	//DispatchKeyValue(entity, "targetname", "lr_inputtarget_relay");
	DispatchKeyValue(entity, "spawnflags", "2");
	DispatchKeyValue(entity, "StartDisabled", "0");

	DispatchSpawn(entity);
	
	static char temp[MAX_STRING_LENGTH];
	Format(temp, sizeof(temp), "%s,%s,%s,%f,-1", targetname, input, value, delay);
	DispatchKeyValue(entity, "OnTrigger", temp);
	
	AcceptEntityInput(entity, "Trigger");
	AcceptEntityInput(entity, "Kill");
		
	return;
}

/**
 * перемещает координаты вперед-назад согласно углам
 *
 * vec_origin 	- начальные координаты
 * vec_angles 	- углы
 * distance		- расстояние, если +, то вперед, если минус назад
 */
void MovePos_Forward(float vec_origin[3], float vec_angles[3], float distance)
{
	float direction[3];
		
	GetAngleVectors(vec_angles, direction, NULL_VECTOR, NULL_VECTOR);
	
	vec_origin[0] = vec_origin[0] + direction[0] * distance;
	vec_origin[1] = vec_origin[1] + direction[1] * distance;
	vec_origin[2] = vec_origin[2] + direction[2] * distance;
}

/**
 * посылает сообщение в чат клиенту skv
 *
 * debug_status	- правда выводит на экран, ложь - нет
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
	Format(temp, sizeof(temp), "%d", room);
	
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
			Format(temp, sizeof(temp), "rescue %d", amount);
			
			if (KvJumpToKey(gk_rooms, temp, true))
			{
				//KvSetNum(gk_rooms, "disabled", 0);
				
				GetEntPropVector(rescue, Prop_Data, "m_vecOrigin", vec_temp);
				
				Format(temp, sizeof(temp), "%d %d %d", RoundFloat(vec_temp[0]), RoundFloat(vec_temp[1]), RoundFloat(vec_temp[2]));
				KvSetString(gk_rooms, "origin", temp);
				
				GetEntPropVector(rescue, Prop_Data, "m_angRotation", vec_temp);
				
				Format(temp, sizeof(temp), "%d %d %d", RoundFloat(vec_temp[0]), RoundFloat(vec_temp[1]), RoundFloat(vec_temp[2]));
				KvSetString(gk_rooms, "angles", temp);
				
				KvGoBack(gk_rooms);
			}
		}
	}
	
	KvRewind(gk_rooms);
}

void KeyValues_ToFile(Handle kv, char [] file_name)
{
	if (!DEBUG_KV)
	{
		return;
	}
	
	if (!IsValidHandle(kv))
	{
		return;
	}
	
	char buffer[MAX_STRING_LENGTH];
	Format(buffer, sizeof(buffer), "addons/sourcemod/data/LR_%s.txt", file_name);
	
	KeyValuesToFile(kv, buffer);
}

int SpawnDebugSprite(float origin[3], char [] color = "255 0 0", int brightness = 225, float timelife = -1.0)
{
	if (!DEBUG_SCAN)
	{
		return 0;
	}
	
	int entity = CreateEntityByName("env_sprite");
	if (entity == -1)
	{
		return 0;
	}
	
	DispatchKeyValue(entity, "spawnflags", "1");
	DispatchKeyValue(entity, "scale", "0.4");
	DispatchKeyValue(entity, "rendermode", "9");
	DispatchKeyValue(entity, "renderfx", "0");
	DispatchKeyValue(entity, "rendercolor", color);
	DispatchKeyValueInt(entity, "renderamt", brightness);
	DispatchKeyValue(entity, "model", gs_glow_model);
	DispatchKeyValue(entity, "HDRColorScale", "1.0");
	DispatchKeyValue(entity, "GlowProxySize", "1");
	
	DispatchKeyValueVector(entity, "origin", origin);
	
	DispatchSpawn(entity);
	ActivateEntity(entity);
	
	if (timelife >= 0.0)
	{
		InputKill(entity, timelife);
	}
	
	return entity;
}

void RenameRescueDoor(int door, float distance = 120.0)
{
	if (!IsValidEntity(door))
	{
		return;
	}
	
	char door_name[MAX_CLASSNAME_LENGTH];
	GetEntPropString(door, Prop_Data, "m_iName", door_name, sizeof(door_name));
	
	if (!strlen(door_name))
	{
		return; 
	}
	
	int door_owner = GetEntPropEnt(door, Prop_Data, "m_hOwnerEntity");
	
	PrintToChatSkv(DEBUG_RENAME, "RenameRescueDoor: door %d, hammerid %d", door, GetEntProp(door, Prop_Data, "m_iHammerID"));					
	
	float pos_door[3];
	GetEntPropVector(door, Prop_Data, "m_vecAbsOrigin", pos_door);
	
	float pos_i[3]; 
	float distance_entity_i;
	
	char i_name[MAX_CLASSNAME_LENGTH]; char i_slavename[MAX_CLASSNAME_LENGTH];
	
	int i = -1; int owner; bool find;
	while ((i = FindEntityByClassname(i, "prop_door_rotating")) != -1)
	{
		if (i != door)
		{  
			GetEntPropString(i, Prop_Data, "m_iName", i_name, sizeof(i_name));
			GetEntPropString(i, Prop_Data, "m_SlaveName", i_slavename, sizeof(i_slavename));
						
			if (!strcmp(door_name, i_name) || (strlen(i_slavename) && !strcmp(door_name, i_slavename)))
			{
				//PrintToChatSkv(DEBUG_RENAME, "RenameRescueDoor: door_name %s", door_name);
				
				GetEntPropVector(i, Prop_Data, "m_vecAbsOrigin", pos_i);
				distance_entity_i = GetVectorDistance(pos_door, pos_i);
				//PrintToChatSkv(DEBUG_RENAME, "RenameRescueDoor: distance_entity_i %f", distance_entity_i);
		
				if (distance_entity_i > distance)
				{
					owner = GetEntPropEnt(i, Prop_Data, "m_hOwnerEntity");
					if (owner != door_owner)
					{
						find = true;
						//PrintToChatSkv(DEBUG_RENAME, "RenameRescueDoor: door found by target name, hammerid %d", GetEntProp(i, Prop_Data, "m_iHammerID"));
					}
				}
			}
		}
	}
	
	if (find)
	{
		char targetname[MAX_CLASSNAME_LENGTH];
		Format(targetname, sizeof(targetname), "lr_door_renamed_%d", door);
		
		DispatchKeyValue(door, "targetname", targetname);
		//ReCreateDoor(door);
	}
}

