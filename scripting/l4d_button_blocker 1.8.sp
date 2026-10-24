/**
 * ========================================================================
 * Plugin [L4D/L4D2] Button Blocker
 * Blocking objects that trigger a panic event.
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

#include <skvtools_gamestart>
#include <skvtools_survivorid>
#include <skvtools_rtimers>

public Plugin myinfo = 
{
	name 		= "[L4D/L4D2] Button Blocker",
	author 		= "Skv",
	description = "Blocking objects that trigger a panic event",
	version 	= "1.7",
	url 		= "https://forums.alliedmods.net/showthread.php?p=2846695#post2846695"
}

#define MAX_ENTITIES				4096
#define NAME_BLOCKER 				"bb_blocker"

#define MAX_HAMMERID				128

int 	g_iHammerid					[MAX_HAMMERID + 1];
int 	g_iHammeridActive			[MAX_HAMMERID + 1];
int 	g_iDistanceLock				[MAX_HAMMERID + 1];
int 	g_iMessageDistance			[MAX_HAMMERID + 1];

bool 	g_sMessage					[MAX_SURVIVORID + 1];
bool 	g_sMessageAll;

ConVar 	g_cDistanceLock;
ConVar 	g_cDistanceDoors;
ConVar 	g_cDistancePhysics;
ConVar 	g_cMessageDistance;
ConVar 	g_cMessageInterval;
ConVar 	g_cPercentUnLock;
ConVar 	g_cPercentUnLockBot;
ConVar 	g_cPluginEnabled;
ConVar 	g_cPluginGamemode;

ConVar 	g_cAdminUnlock;
ConVar 	g_cAdminWait;

bool 	g_bPluginEnabled;

char 	g_sClassname[][] =
{
	"func_button",
	"prop_door_rotating",
	"trigger",
	"prop_physics",
	"func_breakable"
};

bool IsValidClassname(const char [] classname)
{
	for (int j = 0; j < sizeof(g_sClassname); j++)
	{
		if (StrContains(classname, g_sClassname[j]) > -1)
		{
			return true;
		}
	}
	
	return false;
}

public APLRes AskPluginLoad2(Handle plugin, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_Left4Dead && GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left4Dead & Left4dead 2");
		return APLRes_SilentFailure;
	}
			
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_cDistanceLock 		= CreateConVar("bb_distance_lock", 			"750.0", 	"Sets the radius within which survivors must gather to unlock.", _, true, 100.0, true, 3000.0);
	g_cDistanceDoors		= CreateConVar("bb_distance_lock_doors", 	"300.0", 	"Sets the radius within which survivors must gather to unlock the door.", _, true, 100.0, true, 3000.0);
	g_cDistancePhysics		= CreateConVar("bb_distance_lock_physics", 	"1000.0", 	"Sets the radius within which survivors must gather to unlock physical objects.", _, true, 100.0, true, 3000.0);
	g_cMessageDistance 		= CreateConVar("bb_message_distance", 		"0.0", 		"Sets the radius within which messages are displayed. 0 - the value bb_distance_* is used", _, true, 0.0, true, 3000.0);
	g_cMessageInterval 		= CreateConVar("bb_message_interval", 		"15.0", 	"How often (in seconds) can the message be repeated? 0 — disabled.", _, true, 0.0, true, 240.0); 
	g_cPercentUnLock 		= CreateConVar("bb_percent_unlock", 		"100", 		"Percentage of survivors required to unlock", _, true, 1.0, true, 100.0);
	g_cPercentUnLockBot 	= CreateConVar("bb_percent_unlock_bot", 	"0", 		"Should bots be taken into account when calculating the percentage?", _, true, 0.0, true, 1.0);
	g_cAdminUnlock 			= CreateConVar("bb_admin_unlock", 			"1", 		"If the administrator is nearby, can the other parameters be ignored?", _, true, 0.0, true, 1.0);
	g_cAdminWait 			= CreateConVar("bb_admin_wait", 			"1", 		"If the administrator is far away, do need to wait for them?", _, true, 0.0, true, 1.0);
	
	g_cPluginEnabled		= CreateConVar("bb_plugin_enabled", 		"1", 		"Enables plugin", _, true, 0.0, true, 1.0);
	g_cPluginGamemode 		= CreateConVar("bb_plugin_gamemode", 		"coop, realism, mutation", "Set supported game modes");
		
	SetConVarFlags(g_cDistanceLock, 		GetConVarFlags(g_cDistanceLock) & ~FCVAR_NOTIFY);
	SetConVarFlags(g_cDistanceDoors, 		GetConVarFlags(g_cDistanceDoors) & ~FCVAR_NOTIFY);
	SetConVarFlags(g_cDistancePhysics, 		GetConVarFlags(g_cDistancePhysics) & ~FCVAR_NOTIFY);
	SetConVarFlags(g_cMessageDistance, 		GetConVarFlags(g_cMessageDistance) & ~FCVAR_NOTIFY);
	SetConVarFlags(g_cMessageInterval, 		GetConVarFlags(g_cMessageInterval) & ~FCVAR_NOTIFY);
	SetConVarFlags(g_cPercentUnLock, 		GetConVarFlags(g_cPercentUnLock) & ~FCVAR_NOTIFY);
	SetConVarFlags(g_cPercentUnLockBot, 	GetConVarFlags(g_cPercentUnLockBot) & ~FCVAR_NOTIFY);
	SetConVarFlags(g_cAdminUnlock, 			GetConVarFlags(g_cAdminUnlock) & ~FCVAR_NOTIFY);
	SetConVarFlags(g_cAdminWait, 			GetConVarFlags(g_cAdminWait) & ~FCVAR_NOTIFY);
	
	SetConVarFlags(g_cPluginEnabled, 		GetConVarFlags(g_cPluginEnabled) & ~FCVAR_NOTIFY);
	SetConVarFlags(g_cPluginGamemode, 		GetConVarFlags(g_cPluginGamemode) & ~FCVAR_NOTIFY);
	
	LoadTranslations("button_blocker.phrases");
	AutoExecConfig(true, "button_blocker");
	
	g_bPluginEnabled = GetConVarBool(g_cPluginEnabled);
	
	if (g_bPluginEnabled)
	{
		char sGamemodeSupported[PLATFORM_MAX_PATH];
		GetConVarString(g_cPluginGamemode, sGamemodeSupported, sizeof(sGamemodeSupported));
		
		char sGamemode[MAX_NAME_LENGTH];
		GetConVarString(FindConVar("mp_gamemode"), sGamemode, sizeof(sGamemode));
		if (StrContains(sGamemodeSupported, sGamemode) == -1)
		{
			g_bPluginEnabled = false;
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
	g_bPluginEnabled = GetConVarBool(g_cPluginEnabled);
	
	if (g_bPluginEnabled)
	{
		char sGamemodeSupported[MAX_NAME_LENGTH];
		GetConVarString(g_cPluginGamemode, sGamemodeSupported, sizeof(sGamemodeSupported));
		
		char sGamemode[MAX_NAME_LENGTH];
		GetConVarString(FindConVar("mp_gamemode"), sGamemode, sizeof(sGamemode));
			
		if (StrContains(sGamemodeSupported, sGamemode) == -1)
		{
			g_bPluginEnabled = false;
			LogMessage("The plugin is disabled because mp_gamemode is not supported!");
		}
	}
	else
	{
		LogMessage("The plugin is disabled because bb_plugin_enabled = 0!");
	}
	
	if (!g_bPluginEnabled)
	{
		return;
	}
	
	RemoveAllHammerId();
	
	char sKey		[PLATFORM_MAX_PATH];
	char sKeyvalue	[PLATFORM_MAX_PATH];
	char sTemp		[PLATFORM_MAX_PATH];
	char sName		[PLATFORM_MAX_PATH];
		
	int iHammerid;
	
	EntityLumpEntry entry;
	
	for (int i, n = EntityLump.Length(); i < n; i++)
	{
		entry = EntityLump.Get(i);
				
		for (int j = 0; j < entry.Length; j++)
		{
			entry.Get(j, sKey, sizeof(sKey), sKeyvalue, sizeof(sKeyvalue));
			if (strcmp(sKey, "targetname") && StrContains(sKeyvalue, "PanicEvent") > -1)
			{
				if (entry.GetNextKey("classname", sTemp, sizeof(sTemp)) != -1)
				{
					if (IsValidClassname(sTemp))
					{
						if (entry.GetNextKey("hammerid", sKeyvalue, sizeof(sKeyvalue)) != -1)
						{
							iHammerid = StringToInt(sKeyvalue);
							SetHammerId(iHammerid);
						}
					}
					else
					{
						if (entry.GetNextKey("targetname", sName, sizeof(sName)) != -1)
						{
							for (int k = 0; k <= 8; k ++)
							{
								if (IsButtonLinked(sName) <= 0)
								{
									break;
								}
							}
						}
					}
				}
			}
		}
		
		delete entry;
	}
}

int IsButtonLinked(char sName[PLATFORM_MAX_PATH])
{
	char sKey		[PLATFORM_MAX_PATH];
	char sKeyvalue	[PLATFORM_MAX_PATH];
	char sTemp		[PLATFORM_MAX_PATH];
	char sTarget	[PLATFORM_MAX_PATH];
	
	EntityLumpEntry entry;
	
	int iHammerid;
	
	for (int i, n = EntityLump.Length(); i < n; i++)
	{
		entry = EntityLump.Get(i);
		
		entry.GetNextKey("targetname", sTarget, sizeof(sTarget));
		
		entry.GetNextKey("hammerid", sKeyvalue, sizeof(sKeyvalue));
		iHammerid = StringToInt(sKeyvalue);
			
		entry.GetNextKey("classname", sTemp, sizeof(sTemp));
						
		for (int j = 0; j < entry.Length; j++)
		{
			entry.Get(j, sKey, sizeof(sKey), sKeyvalue, sizeof(sKeyvalue));
			if (StrContains(sKeyvalue, sName, false) > -1 && strcmp(sTarget, sName))
			{
				if (IsValidClassname(sTemp))
				{
					SetHammerId(iHammerid);
					
					delete entry;
					return 0;
				}
				
				if (!strlen(sTarget))
				{
					break;
				}
											
				FormatEx(sName, sizeof(sName), sTarget);
				
				delete entry;
				return j + 1;
			}
		}
				
		delete entry;
	}
	
	return -1;
}

bool SetHammerId(int hammerid)
{
	if (GetId(hammerid))
	{
		return false;
	}
	
	for (int i = 1; i <= MAX_HAMMERID; i++)
	{
		if (!g_iHammerid[i])
		{
			g_iHammerid[i] = hammerid;
			
			return true;
		}
	}
	
	return false;
}

int GetId(int hammerid)
{
	for (int i = 1; i <= MAX_HAMMERID; i++)
	{
		if (g_iHammerid[i] && g_iHammerid[i] == hammerid)
		{
			return i;
		}
	}
	
	return 0;
}

bool RemoveHammerId(int hammerid)
{
	for (int i = 1; i <= MAX_HAMMERID; i++)
	{
		if (g_iHammerid[i] && g_iHammerid[i] == hammerid)
		{
			g_iHammerid			[i] = 0;
			g_iHammeridActive	[i] = 0;
			g_iDistanceLock		[i] = 0;
			g_iMessageDistance	[i] = 0;
			
			return true;
		}
	}
	
	return false;
}

void RemoveAllHammerId()
{
	for (int i = 1; i <= MAX_HAMMERID; i++)
	{
		g_iHammerid			[i] = 0;
		g_iHammeridActive	[i] = 0;
		g_iDistanceLock		[i] = 0;
		g_iMessageDistance	[i] = 0;
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (!IsGameplayActive())
	{
		return;
	}
	
	if (IsValidClassname(classname))
	{
		RTimerCreate(0.2, OnEntitySpawned, entity, TIMER_FLAG_NO_ROUNDCHANGE);
	}
}

void OnEntitySpawned(Handle timer, int entity)
{
	if (!IsEntityValid(entity))
	{
		return;
	}
	
	int iHammerid = GetEntProp(entity, Prop_Data, "m_iHammerID");
	if (!GetId(iHammerid))
	{
		return;
	}
	
	if (GetHammerIdActive(iHammerid))
	{
		return;
	}
	
	if (LockEntity(entity))
	{
		char sClassname[MAX_NAME_LENGTH];
		GetEntityClassname(entity, sClassname, sizeof(sClassname));
		
		char sName[MAX_NAME_LENGTH];
		GetEntPropString(entity, Prop_Data, "m_iName", sName, sizeof(sName));
		
		LogMessage("OnEntitySpawned: force lock hammerid %d, class \"%s\", name \"%s\"", iHammerid, sClassname, sName);
		
		RTimerCreate(1.0, OnTrigger, EntIndexToEntRef(entity), TIMER_REPEAT | TIMER_FLAG_NO_ROUNDCHANGE);
	}
}

bool SetHammerIdActive(int hammerid)
{
	if (GetHammerIdActive(hammerid))
	{
		return false;
	}
	
	for (int i = 1; i <= MAX_HAMMERID; i++)
	{
		if (!g_iHammeridActive[i])
		{
			g_iHammeridActive[i] = hammerid;
			
			return true;
		}
	}
	
	return false;
}

int GetHammerIdActive(int hammerid)
{
	for (int i = 1; i <= MAX_HAMMERID; i++)
	{
		if (g_iHammeridActive[i] && g_iHammeridActive[i] == hammerid)
		{
			return i;
		}
	}
	
	return 0;
}

bool RemoveHammerIdActive(int hammerid)
{
	for (int i = 1; i <= MAX_HAMMERID; i++)
	{
		if (g_iHammeridActive[i] && g_iHammeridActive[i] == hammerid)
		{
			g_iHammeridActive[i] = 0;
			return true;
		}
	}
	
	return false;
}

public void OnGameplayStart(int stage)
{
	if (!stage)
	{
		for (int i = 1; i <= MAX_HAMMERID; i++)
		{
			g_iHammeridActive[i] = 0;
		}
		
		return;
	}
	else if (stage != 2) // 5
	{
		return;
	}
	
	g_bPluginEnabled = GetConVarBool(g_cPluginEnabled);
	
	if (g_bPluginEnabled)
	{
		char sGamemodeSupported[PLATFORM_MAX_PATH];
		GetConVarString(g_cPluginGamemode, sGamemodeSupported, sizeof(sGamemodeSupported));
		
		char sGamemode[MAX_NAME_LENGTH];
		GetConVarString(FindConVar("mp_gamemode"), sGamemode, sizeof(sGamemode));
		if (StrContains(sGamemodeSupported, sGamemode) == -1)
		{
			g_bPluginEnabled = false;
		}
	}
	
	if (!g_bPluginEnabled)
	{
		return;
	}
	
	for (int i = 0; i <= MAX_SURVIVORID; i++)
	{
		g_sMessage[i] = true;
	}
	
	g_sMessageAll = true;
	
	Handle hKv = CreateKeyValues("blocked_buttons");
	if (hKv != null)
	{
		if (FileToKeyValues(hKv, "addons/sourcemod/configs/blocked_buttons.cfg"))
		{
			char sMap[PLATFORM_MAX_PATH];
			GetCurrentMap(sMap, sizeof(sMap));
			
			if (KvJumpToKey(hKv, sMap, false))
			{
				char sKey[MAX_NAME_LENGTH];
				char sValue[MAX_NAME_LENGTH];
				
				if (KvGotoFirstSubKey(hKv, false))
				{
					KvGetSectionName(hKv, sKey, sizeof(sKey));
					KvGetString(hKv, NULL_STRING, sValue, sizeof(sValue));
					
					CheckKey(sKey, sValue);			
					
					while (KvGotoNextKey(hKv, false))
					{
						if (KvGetDataType(hKv, NULL_STRING) != KvData_None)
						{
							KvGetSectionName(hKv, sKey, sizeof(sKey));
							KvGetString(hKv, NULL_STRING, sValue, sizeof(sValue));
							
							CheckKey(sKey, sValue);	
						}
					}
					
					KvGoBack(hKv);
				}
			}
		}
		
		delete hKv;
	}
	
	int iEntity;
	
	char sClassname	[MAX_NAME_LENGTH];
	char sName		[MAX_NAME_LENGTH];
	
	for (int i = 1; i <= MAX_HAMMERID; i++)
	{
		if (g_iHammerid[i])
		{
			iEntity = FindEntityByHammerid(g_iHammerid[i]);
			if (IsEntityValid(iEntity))
			{
				if (LockEntity(iEntity))
				{
					GetEntityClassname(iEntity, sClassname, sizeof(sClassname));
					GetEntPropString(iEntity, Prop_Data, "m_iName", sName, sizeof(sName));
					
					LogMessage("OnGameplayStart: force lock hammerid %d, class \"%s\", name \"%s\"", g_iHammerid[i], sClassname, sName);
					
					RTimerCreate(1.0, OnTrigger, EntIndexToEntRef(iEntity), TIMER_REPEAT | TIMER_FLAG_NO_ROUNDCHANGE);
				}
			}
		}
	}
}

void CheckKey(char [] sKey, char [] sValue)
{
	int iHammerid = StringToInt(sValue);
	if (!iHammerid)
	{
		return;
	}
	
	if (!strcmp(sKey, "lock", false))
	{
		SetHammerId(iHammerid);
	}
	else if (!strcmp(sKey, "unlock", false))
	{
		RemoveHammerId(iHammerid);
	}
	else if (StrContains(sKey, "distance", false) > -1)
	{
		SetDistanceLock(iHammerid, GetNumString(sKey));
	}
	else if (StrContains(sKey, "message", false) > -1)
	{
		SetDistanceMessage(iHammerid, GetNumString(sKey));
	}
}

int GetNumString(char sub_name [MAX_NAME_LENGTH])
{
	char temp[MAX_NAME_LENGTH];
	
	SplitString(sub_name, " ", temp, sizeof(temp));
	int len = strlen(temp) + 1;
						
	strcopy(sub_name, sizeof(sub_name), sub_name[len]);
	
	int result;
	
	if (strlen(sub_name) > 0)
	{
		result = StringToInt(sub_name);
	}
		
	return result;
}

bool SetDistanceLock(int hammerid, int distance)
{
	int iD = GetId(hammerid);
	if (!iD)
	{
		return false;
	}
	
	g_iDistanceLock[iD] = distance;
	
	LogMessage("SetDistanceLock: blocking distance changed to %d for hammerid %d.", distance, hammerid);
	
	return true;
}

bool SetDistanceMessage(int hammerid, int distance)
{
	int iD = GetId(hammerid);
	if (!iD)
	{
		return false;
	}
	
	g_iMessageDistance[iD] = distance;
	
	LogMessage("SetDistanceMessage: message distance changed to %d for hammerid %d.", distance, hammerid);
	
	return true;
}

int GetDistanceLock(int hammerid)
{
	return g_iDistanceLock[GetId(hammerid)];
}

int GetDistanceMessage(int hammerid)
{
	return g_iMessageDistance[GetId(hammerid)];
}

bool LockEntity(int iEntity)
{
	if (!IsEntityValid(iEntity))
	{
		return false;
	}
	
	int iHammerid = GetEntProp(iEntity, Prop_Data, "m_iHammerID");
	
	char sClassname[MAX_NAME_LENGTH];
	GetEntityClassname(iEntity, sClassname, sizeof(sClassname));
				
	char sName[MAX_NAME_LENGTH]; 
	GetEntPropString(iEntity, Prop_Data, "m_iName", sName, sizeof(sName));
				
	if (StrContains(sClassname, "func_button") > -1)
	{
		InputEntity(iEntity, "Lock");
	}
	else if (StrContains(sClassname, "trigger", false) > -1)
	{
		Blocker_Spawn(iEntity);
		InputEntity(iEntity, "Disable");
	}
	else if (StrContains(sClassname, "prop_physics", false) > -1 || !strcmp(sClassname, "func_breakable"))
	{
		if (strlen(sName))
		{
			InputTarget(sName, "SetHealth", "50000");
		}
		else
		{
			InputEntity(iEntity, "SetHealth", "50000");
		}
	}
	else if (!strcmp(sClassname, "prop_door_rotating"))
	{
		if (strlen(sName))
		{
			InputTarget(sName, "Lock");
		}
		else
		{
			InputEntity(iEntity, "Lock");
		}
	}
	else
	{
		return false;
	}
		
	if (SetHammerIdActive(iHammerid))
	{
		return true;
	}
	
	return false;
}

public void OnMissionLost()
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
}

void Delete_Timers()
{
	for (int i = 0; i <= MAX_SURVIVORID; i++)
	{
		g_sMessage[i] = false;
	}
	
	g_sMessageAll = false;
}

int FindEntityByHammerid(int hammerid)
{
	for (int i = MaxClients; i <= MAX_ENTITIES; i++)
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

Action OnTrigger(Handle timer, int ref)
{
	int iEntity = EntRefToEntIndex(ref);
	if (!IsEntityValid(iEntity))
	{
		return Plugin_Stop;
	}
	
	float vecOrigin[3];
	GetEntityOrigin(iEntity, vecOrigin);
	
	char sClassname[MAX_NAME_LENGTH];
	GetEntityClassname(iEntity, sClassname, sizeof(sClassname));
	
	if (!IsAllSurvivorNear(iEntity))
	{
		float flMessageDistance;
		
		int iDist = GetDistanceMessage(GetEntProp(iEntity, Prop_Data, "m_iHammerID"));
		if (iDist > 0)
		{
			flMessageDistance = float(iDist);
		}
		else
		{
			flMessageDistance = GetConVarFloat(g_cMessageDistance);
		}
		
		if (!flMessageDistance)
		{
			iDist = GetDistanceLock(GetEntProp(iEntity, Prop_Data, "m_iHammerID"));
			if (iDist > 0)
			{
				flMessageDistance = float(iDist);
			}
			else
			{
				if (!strcmp(sClassname, "prop_door_rotating"))
				{
					flMessageDistance = GetConVarFloat(g_cDistanceDoors);
				}
				else if (StrContains(sClassname, "prop_physics", false) > -1)
				{
					flMessageDistance = GetConVarFloat(g_cDistancePhysics);
				}
				else
				{
					flMessageDistance = GetConVarFloat(g_cDistanceLock);
				}
			}
		}
		
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClientTeam2Alive(i))
			{
				if (IsInArea(i, iEntity, flMessageDistance))
				{
					Message_Print(i, "Message1");
				}
			}
		}
		
		LockEntity(iEntity);
		return Plugin_Continue;
	}
	
	char sName[MAX_NAME_LENGTH]; 
	GetEntPropString(iEntity, Prop_Data, "m_iName", sName, sizeof(sName));
	
	if (StrContains(sClassname, "func_button") > -1)
	{
		InputEntity(iEntity, "UnLock");
	}
	else if (StrContains(sClassname, "trigger", false) > -1)
	{
		int i;
		while ((i = FindEntityByClassname(i, "env_player_blocker")) != -1)
		{
			if (iEntity == GetEntPropEnt(i, Prop_Data, "m_hOwnerEntity"))
			{
				InputKill(i);
				break;
			}
		}
		
		InputEntity(iEntity, "Enable");
	}
	else if (StrContains(sClassname, "prop_physics", false) > -1 || !strcmp(sClassname, "func_breakable"))
	{
		if (strlen(sName))
		{
			InputTarget(sName, "SetHealth", "1");
		}
		else
		{
			InputEntity(iEntity, "SetHealth", "1");
		}
	}
	else if (!strcmp(sClassname, "prop_door_rotating"))
	{
		if (strlen(sName))
		{
			InputTarget(sName, "UnLock");
		}
		else
		{
			InputEntity(iEntity, "UnLock");
		}
	}
	else
	{
		return Plugin_Stop;
	}
	
	RemoveHammerIdActive(GetEntProp(iEntity, Prop_Data, "m_iHammerID"));
	
	MessageAll_Print();
	
	return Plugin_Stop;
}

bool IsBlockerSpawned(int entity)
{
	int i;
	while ((i = FindEntityByClassname(i, "env_player_blocker")) != -1)
	{
		if (entity == GetEntPropEnt(i, Prop_Data, "m_hOwnerEntity"))
		{
			return true;
		}
	}
	
	return false;
}

int Blocker_Spawn(int trigger)
{
	if (!IsEntityValid(trigger))
	{
		return 0;
	}
	
	if (IsBlockerSpawned(trigger))
	{
		return 0;
	}
	
	float vecPosSpawn[3], vecMins[3], vecMaxs[3];
	GetEntityOrigin(trigger, vecPosSpawn);
	
	GetEntPropVector(trigger, Prop_Data, "m_vecMins", vecMins);
	GetEntPropVector(trigger, Prop_Data, "m_vecMaxs", vecMaxs);
	
	int iBlocker = CreateEntityByName("env_player_blocker");
	if (iBlocker == -1)
	{
		return 0;
	}
	
	SetEntPropEnt(iBlocker, Prop_Data, "m_hOwnerEntity", trigger);
	
	char sBlockerName[MAX_NAME_LENGTH];
	FormatEx(sBlockerName, sizeof(sBlockerName), "%s_%d", NAME_BLOCKER, iBlocker);
	DispatchKeyValue(iBlocker, "targetname", sBlockerName);
	
	InputEntityTarget(trigger, "OnKilled", sBlockerName, "Kill");
	
	DispatchKeyValueVector(iBlocker, "origin", vecPosSpawn);
	DispatchKeyValueVector(iBlocker, "mins", vecMins);
	DispatchKeyValueVector(iBlocker, "maxs", vecMaxs);
	
	DispatchKeyValue(iBlocker, "initialstate", "1");
	DispatchKeyValue(iBlocker, "solidbsp", "1");
	DispatchKeyValue(iBlocker, "BlockType", "1");
			
	DispatchSpawn(iBlocker);
	ActivateEntity(iBlocker);
	
	return iBlocker;
}
		
bool IsAllSurvivorNear(int entity)
{
	int 	iNear;
	int 	iAlive;
	
	float 	vecOrigin[3];
	GetEntityOrigin(entity, vecOrigin);
		
	float 	vecEyepos[3];
	
	float 	flDistanceLock 		= GetConVarFloat(g_cDistanceLock);
	bool 	bPercentUnLockBot 	= GetConVarBool(g_cPercentUnLockBot);
	
	char sClassname[MAX_NAME_LENGTH];
	GetEntityClassname(entity, sClassname, sizeof(sClassname));
	
	if (!strcmp(sClassname, "prop_door_rotating"))
	{
		flDistanceLock = GetConVarFloat(g_cDistanceDoors);
	}
	else if (StrContains(sClassname, "prop_physics", false) > -1)
	{
		flDistanceLock = GetConVarFloat(g_cDistancePhysics);
	}
		
	int iDist = GetDistanceLock(GetEntProp(entity, Prop_Data, "m_iHammerID"));
	if (iDist > 0)
	{
		flDistanceLock = float(iDist);
	}
	
	int iAdmin;
	int iAdminNear;
	int iAdminFlags;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClientTeam2Alive(i))
		{
			iAdminFlags = GetUserFlagBits(i);
			if (iAdminFlags)
			{
				iAdmin ++;
			}
			
			if (bPercentUnLockBot && IsFakeClient(i) || !IsFakeClient(i))
			{
				iAlive ++;
				GetClientEyePosition(i, vecEyepos);
				
				if (IsInArea(i, entity, flDistanceLock))
				{
					iNear ++;
					
					if (iAdminFlags)
					{
						iAdminNear ++;
					}
				}
			}
		}
	}
	
	if (iAdmin)
	{
		if (GetConVarBool(g_cAdminWait) && !iAdminNear)
		{
			return false;
		}
		
		if (GetConVarBool(g_cAdminUnlock) && iAdminNear)
		{
			return true;
		}
	}
	
	int iPercent = RoundFloat(float(iNear) / float(iAlive) * 100.0);
	if (iPercent < GetConVarInt(g_cPercentUnLock))
	{
		return false;
	}
	
	return true;
}

void GetEntityOrigin(int entity, float vecOrigin[3])
{
	char sClassname[MAX_NAME_LENGTH];
	GetEntityClassname(entity, sClassname, sizeof(sClassname));
	
	if (!strcmp(sClassname, "prop_door_rotating"))
	{
		GetDoorOrigin(entity, vecOrigin);
		return;
	}
		
	if (HasEntProp(entity, Prop_Data, "m_vecAbsOrigin"))
	{
		GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vecOrigin);
	}
	else
	{
		int iParent = GetEntPropEnt(entity, Prop_Data, "m_pParent");
		if (IsEntityValid(iParent))
		{
			GetEntPropVector(iParent, Prop_Data, "m_vecOrigin", vecOrigin);
		}
		else
		{
			GetEntPropVector(entity, Prop_Data, "m_vecOrigin", vecOrigin);
		}
	}
}

void GetDoorOrigin(int entity, float vecPosDoor[3])
{
	int iDoor = entity;
		
	GetEntPropVector(iDoor, Prop_Data, "m_vecOrigin", vecPosDoor);
			
	float vecAngDoor[3];
	GetEntPropVector(iDoor, Prop_Data, "m_angRotation", vecAngDoor);
			
	vecAngDoor[0] = 0.0;
	vecAngDoor[1] += 90.0;
	vecAngDoor[2] = 0.0;
			
	float vecMaxs[3], vecMins[3];
				
	GetEntPropVector(iDoor, Prop_Send, "m_vecMaxs", vecMaxs);
	GetEntPropVector(iDoor, Prop_Send, "m_vecMins", vecMins);
			
	float flDist = (vecMins[1] * (-1) + vecMaxs[1]) * 0.5;
			
	MovePos_Forward(vecPosDoor, vecAngDoor, flDist);
		
	vecPosDoor[2] += vecMins[2];
	vecPosDoor[2] += (vecMins[2] * (-1) + vecMaxs[2]) * 0.36;
}

bool IsInArea(int client, int entity, float distance)
{
	float 	vecEyepos[3];
	GetClientEyePosition(client, vecEyepos);
	
	float 	vecOrigin[3];
	GetEntityOrigin(entity, vecOrigin);
	
	char sClassname[MAX_NAME_LENGTH];
	GetEntityClassname(entity, sClassname, sizeof(sClassname));
	
	if (StrContains(sClassname, "trigger", false) == -1)
	{
		if (GetVectorDistance(vecOrigin, vecEyepos) <= distance)
		{
			if (IsVisibleOrigin(vecEyepos, vecOrigin))
			{
				return true;
			}
		}
		
		return false;
	}
	
	float vecMins[3], vecMaxs[3];
	
	GetEntPropVector(entity, Prop_Send, "m_vecMins", vecMins);
	GetEntPropVector(entity, Prop_Send, "m_vecMaxs", vecMaxs);
	
	if (IsInLevel(vecOrigin, vecEyepos, vecMaxs, vecMins, distance))
	{
		return true;
	}
	
	float vecAngles[3], vecPos[3];
	vecPos = vecOrigin;
	
	MovePos_Up(vecOrigin, vecAngles, vecMaxs[2] * 0.5);
	if (IsInLevel(vecOrigin, vecEyepos, vecMaxs, vecMins, distance))
	{
		return true;
	}
	
	vecOrigin = vecPos;
	
	MovePos_Up(vecOrigin, vecAngles, vecMins[2] * 0.5);
	if (IsInLevel(vecOrigin, vecEyepos, vecMaxs, vecMins, distance))
	{
		return true;
	}
	
	return false;
}

bool IsInLevel(float vecOrigin[3], float vecEyepos[3], float vecMaxs[3], float vecMins[3], float distance)
{		
	float scale = 0.95;
	
	float vecAngles[3], vecPos[3];
	
	vecPos = vecOrigin;

	//сдвиг вперед
	MovePos_Forward(vecPos, vecAngles, vecMaxs[0] * scale);
	if (GetVectorDistance(vecPos, vecEyepos) <= distance && IsVisibleOrigin(vecEyepos, vecPos))
	{
		return true;
	}
	
	vecPos = vecOrigin;
	
	//сдвиг назад
	MovePos_Forward(vecPos, vecAngles, vecMins[0] * scale);
	if (GetVectorDistance(vecPos, vecEyepos) <= distance && IsVisibleOrigin(vecEyepos, vecPos))
	{
		return true;
	}
	
	vecPos = vecOrigin;
	
	//сдвиг влево
	MovePos_Right(vecPos, vecAngles, vecMins[1] * scale);
	if (GetVectorDistance(vecPos, vecEyepos) <= distance && IsVisibleOrigin(vecEyepos, vecPos))
	{
		return true;
	}
	
	vecPos = vecOrigin;
	
	// сдвиг вправо
	MovePos_Right(vecPos, vecAngles, vecMaxs[1] * scale);
	if (GetVectorDistance(vecPos, vecEyepos) <= distance && IsVisibleOrigin(vecEyepos, vecPos))
	{
		return true;
	}
	
	return false;
}

bool IsVisibleOrigin(float pos_start[3], float pos_end[3])
{
	Handle trace = TR_TraceRayFilterEx(pos_start, pos_end, MASK_VISIBLE, RayType_EndPoint, TraceFilter_Visible);
	if (TR_DidHit(trace))
	{
		delete trace;
		return false;
	}
	
	delete trace;
	return true;
}

bool TraceFilter_Visible(int entity, int contentsMask)
{
	if (IsValidEntity(entity)) return false;
	
	return true;
}

void Message_Print(int client, char[] message)
{
	if (!g_sMessageAll)
	{
		return;
	}
	
	if (!IsValidClientTeam2Alive(client))
	{
		return;
	}
	
	int iSurvivorId = GetClientSurvivorId(client);	
	if (!g_sMessage[iSurvivorId])
	{
		return;
	}
	
	float flMessageInterval = GetConVarFloat(g_cMessageInterval);
	if (flMessageInterval <= 0.0)
	{
		return;
	}
	
	RTimerCreate(flMessageInterval, Message_Enable, iSurvivorId, TIMER_FLAG_NO_ROUNDCHANGE);
	
	g_sMessage[iSurvivorId] = false;
	
	PrintHintText(client, "%t", message);
}

void Message_Enable(Handle timer, int survivorid)
{
	g_sMessage[survivorid] = true;
}

void MessageAll_Print()
{
	if (!g_sMessageAll)
	{
		return;
	}
	
	float flMessageInterval = GetConVarFloat(g_cMessageInterval);
	if (flMessageInterval <= 0.0)
	{
		return;
	}
	
	RTimerCreate(flMessageInterval, MessageAll_Enable, _, TIMER_FLAG_NO_ROUNDCHANGE);
	
	g_sMessageAll = false;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClientTeam2Alive(i))
		{
			g_sMessage[GetClientSurvivorId(i)] = true;
			
			PrintHintText(i, "%t", "Message2");
		}
	}
}

void MessageAll_Enable(Handle timer)
{
	g_sMessageAll = true;
}

// #include <skvtools>

/**
 * Проверяет клиента команды 2
 *
 * client 			- Client index.
 * return 			- true если client valid и false если нет
 */
bool IsValidClient(int client)
{
	if (client > 0  && client <= MaxClients)
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
 * Посылает действие на все сущности с одинаковым targetname 
 *
 * targetname 		- имя сущностей на которых хотим подействовать
 * input 			- название действия
 * value 			- значение действия (например 1, если на свет передается brightness 1)
 * delay 			- кол-во секунд, через которое запускается действие
*/
void InputTarget(char [] targetname, char [] input, char [] value = "", float delay = 0.0)
{
	int entity = CreateEntityByName("logic_relay");
	if (entity == -1)
	{
		return;
	}

	char name[MAX_NAME_LENGTH];
	FormatEx(name, sizeof(name), "inputtarget_relay_%d", entity);

	DispatchKeyValue(entity, "targetname", name);
	DispatchKeyValue(entity, "spawnflags", "1"); // 2
	DispatchKeyValue(entity, "StartDisabled", "0");

	DispatchSpawn(entity);
	
	static char temp[MAX_NAME_LENGTH];
	Format(temp, sizeof(temp), "%s,%s,%s,%f,0", targetname, input, value, delay); // -1
	DispatchKeyValue(entity, "OnTrigger", temp);
	
	AcceptEntityInput(entity, "Trigger");
	AcceptEntityInput(entity, "Kill");
}

/**
 * Посылает на сущность действие от другой сущности
 *
 * entity 			- сущность для передачи последовательности действий
 * output 			- название действия на сущность
 * targetname 		- имя другой сущности на которую хотим подействовать
 * input 			- название действия на другую сущность
 * value 			- значение действия (например 1, если на свет передается brightness 1)
 * time_start 		- кол-во секунд, через которое запускается действие на другую сущность
 * time_life 		- кол-во секунд, через которое удаляется другая сущность, если 0 - то не удаляется
*/
void InputEntityTarget(int entity, char[] output, char[] targetname, char[] input, char[] value = "", float time_start = 0.0, float time_life = -1.0)
{
	if (!IsEntityValid(entity))
	{
		return;
	}
	
	char temp[PLATFORM_MAX_PATH];
	Format(temp, sizeof(temp), "%s %s:%s:%s:%f:-1", output, targetname, input, value, time_start);
	
	SetVariantString(temp);
	AcceptEntityInput(entity, "AddOutput");
	
	if (time_life < 0.0)
	{
		return;
	}
	
	Format(temp, sizeof(temp), "%s %s:Kill::%f:-1", output, targetname, time_start + time_life);
	
	SetVariantString(temp);
	AcceptEntityInput(entity, "AddOutput");
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
void InputEntity(int entity, char[] input, char[] value = "", float time_start = 0.0, float time_life = 0.0)
{
	if (!IsEntityValid(entity))
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
 * Удаляет сущность через интервал НЕ УДАЛЯЮТСЯ СУЩНОСТИ МЕНЬШЕ ЧЕМ MaxClients
 *
 * entity 			- сущность, которая удаляется
 * time 			- кол-во секунд, через которое удаляется
*/
void InputKill(int entity, float time = 0.0)
{
	if (!IsEntityValid(entity) || (entity >= 0 && entity <= MaxClients)) {return;}
	
	if (time == 0.0)
	{
		if (HasEntProp(entity, Prop_Data, "m_pParent"))
		{
			if (IsEntityValid(GetEntPropEnt(entity, Prop_Data, "m_pParent")))
			{
				AcceptEntityInput(entity, "ClearParent");
			}
		}
		
		AcceptEntityInput(entity, "Kill");
	}
	else if (time > 0.0)
	{
		static char temp[PLATFORM_MAX_PATH];
		
		if (HasEntProp(entity, Prop_Data, "m_pParent"))
		{
			if (IsEntityValid(GetEntPropEnt(entity, Prop_Data, "m_pParent")))
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
 * Проверяет клиента команды 2
 *
 * client 			- Client index.
 * return 			- true если client valid и false если нет
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

bool IsEntityValid(int entity)
{
	if (entity && IsValidEntity(entity))
	{
		return true;
	}
	
	return false;
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

/**
 * перемещает координаты вправо-лево согласно углам
 *
 * vec_origin 		- начальные координаты
 * vec_angles 		- углы
 * distance			- расстояние, если +, то вправо, если минус влево
 */
void MovePos_Right(float vec_origin[3], float vec_angles[3], float distance)
{
	float direction[3];
		
	GetAngleVectors(vec_angles, NULL_VECTOR, direction, NULL_VECTOR);
	
	vec_origin[0] = vec_origin[0] + direction[0] * distance;
	vec_origin[1] = vec_origin[1] + direction[1] * distance;
	vec_origin[2] = vec_origin[2] + direction[2] * distance;
}

/**
 * перемещает координаты вверх-вниз согласно углам
 *
 * vec_origin 		- начальные координаты
 * vec_angles 		- углы
 * distance			- расстояние, если +, то вверх, если минус вниз
 */
void MovePos_Up(float vec_origin[3], float vec_angles[3], float distance)
{
	float direction[3];
		
	GetAngleVectors(vec_angles, NULL_VECTOR, NULL_VECTOR, direction);
	
	vec_origin[0] = vec_origin[0] + direction[0] * distance;
	vec_origin[1] = vec_origin[1] + direction[1] * distance;
	vec_origin[2] = vec_origin[2] + direction[2] * distance;
}
