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
	version 	= "1.3",
	url 		= "https://forums.alliedmods.net/showthread.php?p=2846695#post2846695"
}

#define MAX_ENTITIES				4096
#define NAME_BLOCKER 				"bb_blocker"
#define MAX_HAMMERID				32
int 	g_iHammerid					[MAX_HAMMERID + 1];
int 	g_iHammeridActive			[MAX_HAMMERID + 1];

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
	g_cDistanceLock 		= CreateConVar("bb_distance_lock", 			"750.0", "Sets the radius within which survivors must gather to unlock.", _, true, 100.0, true, 3000.0);
	g_cDistanceDoors		= CreateConVar("bb_distance_lock_doors", 	"300.0", "Sets the radius within which survivors must gather to unlock the door.", _, true, 100.0, true, 3000.0);
	g_cDistancePhysics		= CreateConVar("bb_distance_lock_physics", 	"1000.0", "Sets the radius within which survivors must gather to unlock physical objects.", _, true, 100.0, true, 3000.0);
	g_cMessageDistance 		= CreateConVar("bb_message_distance", 		"750.0", "Sets the radius within which messages are displayed.", _, true, 100.0, true, 3000.0);
	g_cMessageInterval 		= CreateConVar("bb_message_interval", 		"15.0", "How often (in seconds) can the message be repeated? 0 — disabled.", _, true, 0.0, true, 240.0); 
	g_cPercentUnLock 		= CreateConVar("bb_percent_unlock", 		"100", "Percentage of survivors required to unlock", _, true, 1.0, true, 100.0);
	g_cPercentUnLockBot 	= CreateConVar("bb_percent_unlock_bot", 	"0", "Should bots be taken into account when calculating the percentage?", _, true, 0.0, true, 1.0);
	g_cPluginEnabled		= CreateConVar("bb_plugin_enabled", 		"1", "Enables plugin", _, true, 0.0, true, 1.0); 
	g_cPluginGamemode 		= CreateConVar("bb_plugin_gamemode", 		"coop, realism, mutation, survival", "Set supported game modes");
	
	SetConVarFlags(g_cDistanceLock, 		GetConVarFlags(g_cDistanceLock) & ~FCVAR_NOTIFY);
	SetConVarFlags(g_cDistanceDoors, 		GetConVarFlags(g_cDistanceDoors) & ~FCVAR_NOTIFY);
	SetConVarFlags(g_cDistancePhysics, 		GetConVarFlags(g_cDistancePhysics) & ~FCVAR_NOTIFY);
	SetConVarFlags(g_cMessageDistance, 		GetConVarFlags(g_cMessageDistance) & ~FCVAR_NOTIFY);
	SetConVarFlags(g_cMessageInterval, 		GetConVarFlags(g_cMessageInterval) & ~FCVAR_NOTIFY);
	SetConVarFlags(g_cPercentUnLock, 		GetConVarFlags(g_cPercentUnLock) & ~FCVAR_NOTIFY);
	SetConVarFlags(g_cPercentUnLockBot, 	GetConVarFlags(g_cPercentUnLockBot) & ~FCVAR_NOTIFY);
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
								int result = IsButtonLinked(sName);
								if (result <= 0)
								{
									break;
								}
							}
						}
						else
						{
							
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
	if (GetHammerId(hammerid))
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

int GetHammerId(int hammerid)
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
			g_iHammerid[i] = 0;
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
	if (!GetHammerId(iHammerid))
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
				
				int iHammerid;
				
				if (KvGotoFirstSubKey(hKv, false))
				{
					KvGetSectionName(hKv, sKey, sizeof(sKey));
					KvGetString(hKv, NULL_STRING, sValue, sizeof(sValue));
					
					if (!strcmp(sKey, "lock", false))
					{
						iHammerid = StringToInt(sValue);
						if (iHammerid)
						{
							if (SetHammerId(iHammerid))
							{
								//LogMessage("(1) force lock hammerid %d", iHammerid);
							}
						}
					}
					else if (!strcmp(sKey, "unlock", false))
					{
						iHammerid = StringToInt(sValue);
						if (iHammerid)
						{
							if (RemoveHammerId(iHammerid))
							{
								//LogMessage("(1) unlock hammerid %d", iHammerid);
							}
						}
					}				
					
					while (KvGotoNextKey(hKv, false))
					{
						if (KvGetDataType(hKv, NULL_STRING) != KvData_None)
						{
							KvGetSectionName(hKv, sKey, sizeof(sKey));
							KvGetString(hKv, NULL_STRING, sValue, sizeof(sValue));
							
							if (!strcmp(sKey, "lock", false))
							{
								iHammerid = StringToInt(sValue);
								if (iHammerid)
								{
									if (SetHammerId(iHammerid))
									{
										//LogMessage("(2) force lock hammerid %d", iHammerid);
									}
								}
							}
							else if (!strcmp(sKey, "unlock", false))
							{
								iHammerid = StringToInt(sValue);
								if (iHammerid)
								{
									if (RemoveHammerId(iHammerid))
									{
										//LogMessage("(2) unlock hammerid %d", iHammerid);
									}
								}
							}	
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
		//HookSingleEntityOutput(iEntity, "OnUseLocked", OnUseLocked);
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
/*
void OnUseLocked(const char[] output, int entity, int client, float delay)
{
	PrintToChatSkv(DEBUG, "OnUseLocked: %d is locked", entity);
}
*/
Action OnTrigger(Handle timer, int ref)
{
	int iEntity = EntRefToEntIndex(ref);
	if (!IsEntityValid(iEntity))
	{
		return Plugin_Stop;
	}
	
	float vecOrigin[3];
	GetEntityOrigin(iEntity, vecOrigin);
	
	if (!IsAllSurvivorNear(iEntity))
	{
		float vecEyepos[3];
		float flDistance;
		
		float flMessageDistance = GetConVarFloat(g_cMessageDistance);
		
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClientTeam2Alive(i))
			{
				GetClientEyePosition(i, vecEyepos);
				
				flDistance = GetVectorDistance(vecOrigin, vecEyepos);
				if (flDistance < flMessageDistance && (IsSameFloor(vecOrigin[2], vecEyepos[2], 120.0) || IsVisibleOrigin(vecEyepos, vecOrigin)))
				{
					Message_Print(i, "Message1");
				}
			}
		}
		
		LockEntity(iEntity);
		return Plugin_Continue;
	}
	
	char sClassname[MAX_NAME_LENGTH];
	GetEntityClassname(iEntity, sClassname, sizeof(sClassname));
	
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
	if (!IsEntityValid(entity))
	{
		return 0;
	}
	
	//PrintToChatSkv(DEBUG, "IsAllSurvivorNearOfEntity");
	
	int 	iNear;
	int 	iAlive;
	
	float 	vecOrigin[3];
	GetEntityOrigin(entity, vecOrigin);
	
	float 	vecEyepos[3];
	float 	dist_temp;
	
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
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClientTeam2Alive(i))
		{
			if (bPercentUnLockBot && IsFakeClient(i) || !IsFakeClient(i))
			{
				iAlive ++;
				GetClientEyePosition(i, vecEyepos);
				
				dist_temp = GetVectorDistance(vecOrigin, vecEyepos);
				//PrintToChatSkv(DEBUG, "IsAllSurvivorNear: %N, distance %f", i, dist_temp);
				
				if (dist_temp <= flDistanceLock && (IsSameFloor(vecOrigin[2], vecEyepos[2], 120.0) || IsVisibleOrigin(vecEyepos, vecOrigin)))
				{
					iNear ++;
				}
			}
		}
	}
		
	int iPercent = RoundFloat(float(iNear) / float(iAlive) * 100.0);
	//PrintToChatSkv(DEBUG, "IsAllSurvivorNear: entity %d, alive %d, near %d, percent %d", entity, iAlive, iNear, iPercent);
	
	if (iPercent < GetConVarInt(g_cPercentUnLock))
	{
		return false;
	}
	
	return true;
}

void GetEntityOrigin(int entity, float vecOrigin[3])
{
	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", vecOrigin);
	
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
	}
	
	//PrintToChatSkv(DEBUG, "GetEntityOrigin: vecOrigin %d", RoundFloat(vecOrigin[0]), RoundFloat(vecOrigin[1]), RoundFloat(vecOrigin[2]));
}

bool IsSameFloor(float z1, float z2, float floor_heigh)
{
	float glZfloor;
	
	glZfloor = z1 - z2;
	if (glZfloor < 0) {glZfloor *= -1;}
						
	if (glZfloor <= floor_heigh)
	{
		return true;
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
		CloseHandle(trace);
		return false;
	}
	
	CloseHandle(trace);
	return true;
}

bool TraceFilter_Visible(int entity, int contentsMask)
{
	char classname[MAX_NAME_LENGTH];
	GetEntityClassname(entity, classname, sizeof(classname));
	
	if (!strcmp(classname, "prop_door_rotating") || !strcmp(classname, "func_door"))
	{
		return true;
	}
		
	if (entity > 0 && IsEntityValid(entity)) return false;
	
	return true;
}

void Message_Print(int client, char[] message)
{
	if (!IsValidClientTeam2Alive(client))
	{
		return;
	}
	
	int iSurvivorId = GetClientSurvivorId(client);	
	if (!g_sMessage[iSurvivorId])
	{
		return;
	}
	
	PrintHintText(client, "%t", message);
	
	float flMessageInterval = GetConVarFloat(g_cMessageInterval);
	if (flMessageInterval <= 0.0)
	{
		return;
	}
	
	RTimerCreate(flMessageInterval, Message_Enable, iSurvivorId, TIMER_FLAG_NO_ROUNDCHANGE);
	
	g_sMessage[iSurvivorId] = false;
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
stock bool IsValidClient(int client)
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
 * Посылает действие на все сущности с одинаковым targetname 
 *
 * targetname 		- имя сущностей на которых хотим подействовать
 * input 			- название действия
 * value 			- значение действия (например 1, если на свет передается brightness 1)
 * delay 			- кол-во секунд, через которое запускается действие
*/
stock void InputTarget(char [] targetname, char [] input, char [] value = "", float delay = 0.0)
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
stock void InputEntityTarget(int entity, char[] output, char[] targetname, char[] input, char[] value = "", float time_start = 0.0, float time_life = -1.0)
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
stock void InputEntity(int entity, char[] input, char[] value = "", float time_start = 0.0, float time_life = 0.0)
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
stock void InputKill(int entity, float time = 0.0)
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
		/*if (IsValidEdict(entity))
		{
			RemoveEdict(entity);
		}*/
	}
	else if (time > 0.0)
	{
		static char temp[MAX_NAME_LENGTH];
		
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

stock bool IsEntityValid(int entity)
{
	if (entity && IsValidEntity(entity))
	{
		return true;
	}
	
	return false;
}