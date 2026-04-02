/**
 * ========================================================================
 * Plugin [skvtools] l4d_rtimers
 * The plugin creates and manages timers that are active only during gameplay (round).
 * All Left 4 Dead and Left 4 Dead 2 game modes are currently supported.
 * ========================================================================
 *
 * This program is free software; you can redistribute it and/or modify it.
 *
**/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#include <skvtools_rtimers>

public Plugin myinfo = 
{
	name 		= "[skvtools] l4d_rtimers",
	author 		= "Skv",
	description = "Creates and manages timers that are active only during round",
	version 	= "1.8",
	url 		= "https://forums.alliedmods.net/showthread.php?p=2842880#post2842880"
}

#define 	NAME_RTIMER 					"skvtools_rtimer"
#define 	MIN_INTERVAL 					0.033 	// minimum timer operation interval >= 0.01
#define 	MAX_RTIMERS   					512 	// sets the maximum number of timers that can run simultaneously

Handle 		gh_timer						[MAX_RTIMERS + 1];
Handle 		gh_plugin						[MAX_RTIMERS + 1];
Function 	gh_func							[MAX_RTIMERS + 1];
Function 	gh_func_close					[MAX_RTIMERS + 1];
float 		gf_timer_create					[MAX_RTIMERS + 1];
float 		gf_timer_firetime				[MAX_RTIMERS + 1];
float 		gf_timer_interval				[MAX_RTIMERS + 1];
any 		ga_timer_value					[MAX_RTIMERS + 1];
int 		gi_timer_flags					[MAX_RTIMERS + 1];
int 		gi_timer_pause					[MAX_RTIMERS + 1];

#define 	MAX_PLAYERS 					18
int 		gi_users						[MAX_PLAYERS + 1];

bool 		gb_server_empty;

int 		gi_logic_timer;

int 		gi_timerid_current_count;

public APLRes AskPluginLoad2(Handle plugin, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_Left4Dead && GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left4Dead and Left4Dead 2");
		return APLRes_SilentFailure;
	}
	
	CreateNative("CreateRTimer",			native_CreateRTimer);
		
	CreateNative("RTimerTrigger", 			native_RTimerTrigger);
	CreateNative("RTimerPause", 			native_RTimerPause);
	CreateNative("RTimerRemove", 			native_RTimerRemove);
	
	CreateNative("RTimerGetRemaining", 		native_RTimerGetRemaining);
	
	CreateNative("RTimerGetInterval", 		native_RTimerGetInterval);
	CreateNative("RTimerSetInterval", 		native_RTimerSetInterval);
	
	CreateNative("RTimerGetFlags", 			native_RTimerGetFlags);
	CreateNative("RTimerSetFlags", 			native_RTimerSetFlags);
	
	CreateNative("RTimerGetValue", 			native_RTimerGetValue);
	CreateNative("RTimerValueSet", 			native_RTimerValueSet);
		
	CreateNative("RTimerAddInterval", 		native_RTimerAddInterval);
	CreateNative("RTimerSubInterval", 		native_RTimerSubInterval);
	CreateNative("RTimerShift", 			native_RTimerShift);
		
	return APLRes_Success;
}

public void OnPluginStart()
{
	HookEvent("round_end", 			Event_round_end);
	
	HookEvent("player_connect", 	Event_player_connect);
	HookEvent("player_disconnect", 	Event_player_disconnect);
}

any native_CreateRTimer(Handle plugin, int numParams)
{
	float 	interval 	= GetNativeCell(1);
	if (interval < MIN_INTERVAL)
	{
		interval = MIN_INTERVAL;
	}
	
	float gametime = GetGameTime();
	
	if (!IsRtimerSpawn())
	{
		if (interval < 0.04 || (gametime < 1.21 && gametime + interval <= 1.21 + MIN_INTERVAL)) // 1.21 - время спавна logic_timer
		{
			ThrowNativeError(429, "\"Attempt to create a timer outside of a round with interval %f!\"", GetNativeCell(1));
			
			return false;
		}
	}
	
	if (gi_timerid_current_count < 1)
	{
		gi_timerid_current_count = 1;
	}
	else if (gi_timerid_current_count > MAX_RTIMERS)
	{
		ServerCommand("sm_dump_handles addons/sourcemod/logs/error_creatertimer.txt");
		LogError("\"native_CreateRTimer: The array size is not sufficient, MAX_RTIMERS must be at least %d\"", gi_timerid_current_count);
		
		return false;
	}
	
	for (int i = 1; i <= gi_timerid_current_count; i++)
	{
		if (gh_timer[i] == null)
		{
			gh_plugin			[i] = plugin;
			gh_func				[i] = GetNativeFunction(2);
			
			gf_timer_create		[i] = gametime;
			
			gf_timer_firetime	[i] = gametime + interval;
			gf_timer_interval	[i] = interval;
			
			ga_timer_value		[i] = GetNativeCell(3);
			gi_timer_flags		[i] = GetNativeCell(4);
			
			gh_func_close		[i] = GetNativeFunction(5);
			gh_timer			[i] = GetNativeCell(6);
			
			if (i == gi_timerid_current_count)
			{
				gi_timerid_current_count ++;
			}
			
			return true;
		}
	}
	
	LogError("\"native_CreateRTimer: The array size is to small no free slots! gi_timerid_current_count %d\"", gi_timerid_current_count);
	return false;
}

any native_RTimerGetRemaining(Handle plugin, int numParams)
{
	int i = RTimerGetId(GetNativeCell(1));
	if (!i)
	{
		return 0.0;
	}
	
	return gf_timer_firetime[i] - GetGameTime();
}

any native_RTimerGetInterval(Handle plugin, int numParams)
{
	int i = RTimerGetId(GetNativeCell(1));
	if (!i)
	{
		return 0.0;
	}
	
	return gf_timer_interval[i];
}

any native_RTimerGetFlags(Handle plugin, int numParams)
{
	int i = RTimerGetId(GetNativeCell(1));
	if (!i)
	{
		return -1;
	}
	
	return gi_timer_flags[i];
}

any native_RTimerSetFlags(Handle plugin, int numParams)
{
	int i = RTimerGetId(GetNativeCell(1));
	if (!i)
	{
		return false;
	}
	
	gi_timer_flags[i] = GetNativeCell(2);
	
	return true;
}

any native_RTimerGetValue(Handle plugin, int numParams)
{
	int i = RTimerGetId(GetNativeCell(1));
	if (!i)
	{
		return 0;
	}
	
	return ga_timer_value[i];
}

any native_RTimerAddInterval(Handle plugin, int numParams)
{
	int i = RTimerGetId(GetNativeCell(1));
	if (!i)
	{
		return false;
	}
	
	float 	added_value 	= GetNativeCell(2);
	if (added_value <= 0.0)
	{
		return false;
	}
	
	gf_timer_firetime	[i] += added_value;
	gf_timer_interval 	[i] += added_value;
				
	return true;
}

any native_RTimerSubInterval(Handle plugin, int numParams)
{
	int i = RTimerGetId(GetNativeCell(1));
	if (!i)
	{
		return false;
	}
	
	float subtrahend_value = GetNativeCell(2);
	if (subtrahend_value <= 0.0)
	{
		return false;
	}
	
	gf_timer_firetime	[i] -= subtrahend_value;
	gf_timer_interval 	[i] -= subtrahend_value;
				
	if (gf_timer_interval[i] <= 0.0)
	{
		RTimerFire(i);
	}
	else if (gf_timer_interval[i] < MIN_INTERVAL)
	{
		gf_timer_interval[i] = MIN_INTERVAL;
	}			
			
	return true;
}

any native_RTimerSetInterval(Handle plugin, int numParams)
{
	int i = RTimerGetId(GetNativeCell(1));
	if (!i)
	{
		return false;
	}
	
	float interval_new 	= GetNativeCell(2);
		
	if (interval_new < MIN_INTERVAL)
	{
		interval_new = MIN_INTERVAL;
	}
	
	gf_timer_firetime	[i] = gf_timer_firetime[i] - gf_timer_interval[i] + interval_new;
	gf_timer_interval	[i] = interval_new;
							
	return true;
}

any native_RTimerValueSet(Handle plugin, int numParams)
{
	int i = RTimerGetId(GetNativeCell(1));
	if (!i)
	{
		return false;
	}
	
	any value = GetNativeCell(2);
		
	ga_timer_value[i] = value;
	
	return true;
}

any native_RTimerTrigger(Handle plugin, int numParams)
{
	int i = RTimerGetId(GetNativeCell(1));
	if (!i)
	{
		return false;
	}
	
	RTimerFire(i);
					
	return true;
}

any native_RTimerShift(Handle plugin, int numParams)
{
	int i = RTimerGetId(GetNativeCell(1));
	if (!i)
	{
		return false;
	}
	
	float seconds = GetNativeCell(2);
		
	gf_timer_firetime	[i] = GetGameTime() + seconds;
							
	return true;
}

any native_RTimerPause(Handle plugin, int numParams)
{
	int i = RTimerGetId(GetNativeCell(1));
	if (!i)
	{
		return false;
	}
	
	gi_timer_pause[i] = GetNativeCell(2);
							
	return true;
}

any native_RTimerRemove(Handle plugin, int numParams)
{
	int i = RTimerGetId(GetNativeCell(1));
	if (!i)
	{
		return false;
	}
	
	RTimerDelete(i);
			
	return true;
}

int RTimerGetId(Handle timer)
{
	if (timer == null)
	{
		return 0;
	}
	
	for (int i = 1; i <= gi_timerid_current_count; i++)
	{
		if (gh_timer[i] == timer)
		{
			return i;
		}
	}
	
	return 0;
}

void RTimerSpawn()
{
	if (IsRtimerSpawn())
	{
		return;
	}
	
	gi_logic_timer = -1;
	
	int entity = CreateEntityByName("logic_timer");
	if (entity == -1)
	{
		return;
	}
	
	DispatchKeyValue(entity, "targetname", NAME_RTIMER);
	DispatchKeyValue(entity, "StartDisabled", "0");
	
	DispatchKeyValue(entity, "UseRandomTime", "0");
	DispatchKeyValueFloat(entity, "RefireTime", MIN_INTERVAL); // 0.1
		
	DispatchSpawn(entity);
	
	gi_logic_timer = entity;
	
	HookSingleEntityOutput(entity, "OnTimer", OnTimer);
	HookSingleEntityOutput(entity, "OnKilled", OnKilled);
}

bool IsRtimerSpawn()
{
	char buffer[MAX_NAME_LENGTH];
	
	int i = -1;
	while ((i = FindEntityByClassname(i, "logic_timer")) != -1)
	{
		GetEntPropString(i, Prop_Data, "m_iName", buffer, sizeof(buffer));
		if (!strcmp(buffer, NAME_RTIMER))
		{
			return true;
		}
	}
	
	return false;
}

void OnKilled(char [] output, int timer, int activator, float delay)
{
	if (gb_server_empty)
	{
		return;
	}
	
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			RequestFrame(RTimerSpawn);
			return;
		}
	}
}

public void OnEntityCreated(int entity, const char [] classname)
{
	if (!strcmp(classname, "logic_auto"))
	{
		HookSingleEntityOutput(entity, "OnMapSpawn", OnHook_logic_auto);
	}
}

void OnHook_logic_auto(char [] output, int caller, int activator, float delay)
{
	if (gb_server_empty)
	{
		return;
	}
	
	RTimerSpawn();
}

void OnTimer(char [] output, int timer, int activator, float delay)
{
	if (gb_server_empty)
	{
		return;
	}
	
	float gametime = GetGameTime();
	
	for (int i = 1; i <= gi_timerid_current_count; i ++)
	{
		if (gh_timer[i] != null)
		{
			if (IsValidHandle(gh_timer[i]))
			{
				if (gf_timer_firetime[i] <= gametime)
				{
					RTimerFire(i);
				}
				else
				{
					if (gi_timer_pause[i])
					{
						gf_timer_firetime[i] += MIN_INTERVAL;
					}
				}
			}
			else
			{
				RTimerDelete(i);
			}
		}
	}
}

void RTimerFire(int i)
{
	/*
	enum Action
	{
		Plugin_Continue = 0,    //< Continue with the original action
		Plugin_Changed = 1,     //< Inputs or outputs have been overridden with new values
		Plugin_Handled = 3,     //< Handle the action at the end (don't call it)
		Plugin_Stop = 4         //< Immediately stop the hook chain and handle the original
	};
	*/
	
	int action;
	
	if (IsValidPlugin(gh_plugin[i]) && gh_func[i])
	{
		Call_StartFunction(gh_plugin[i], gh_func[i]);
		Call_PushCell(gh_timer[i]);
		Call_PushCell(ga_timer_value[i]);
				
		Call_Finish(action);
	}
	else
	{
		action = 4;
	}

	float gametime = GetGameTime();

	if (gametime - gf_timer_create[i] < MIN_INTERVAL)
	{
		return;
	}
	
	if ((gi_timer_flags[i] & TIMER_REPEAT) && action != 4 && gf_timer_interval[i] > 0.0)
	{
		gf_timer_firetime[i] = gametime + gf_timer_interval[i];
			
		return;
	}
	
	RTimerDelete(i);
}

void RTimerDelete(int i)
{
	if (IsValidPlugin(gh_plugin[i]) && gh_func_close[i] && IsValidHandle(gh_timer[i]))
	{
		Call_StartFunction(gh_plugin[i], gh_func_close[i]);
		
		Call_PushCell(gh_timer[i]);
		Call_PushCell(ga_timer_value[i]);
		Call_PushCell(gi_timer_flags[i]);
			
		Call_Finish();
	}
	
	RTimerClearId(i);
}

bool IsValidPlugin(Handle plugin)
{
	if (!plugin)
	{
		return false;
	}
	
	Handle iterator = GetPluginIterator();
	
	while (MorePlugins(iterator))
	{
		if (ReadPlugin(iterator) == plugin)
		{
			CloseHandle(iterator);
			return true;
		}
	}
	
	CloseHandle(iterator);
	return false;
}

public void OnMapStart()
{
	Delete_RTimers(TIMER_FLAG_NO_MAPCHANGE | TIMER_FLAG_NO_ROUNDCHANGE);
}

void Event_round_end(Handle event, const char [] name, bool dontBroadcast)
{
	Delete_RTimers(TIMER_FLAG_NO_ROUNDCHANGE);
}

public void OnMapEnd()
{
	Delete_RTimers(TIMER_FLAG_NO_MAPCHANGE | TIMER_FLAG_NO_ROUNDCHANGE);
	
	Transfer_RTimers();
}

void Transfer_RTimers()
{
	if (gi_logic_timer && IsValidEntity(gi_logic_timer))
	{
		UnhookSingleEntityOutput(gi_logic_timer, "OnTimer", OnTimer);
		UnhookSingleEntityOutput(gi_logic_timer, "OnKilled", OnKilled);
	}
	
	gi_logic_timer = -1;
	
	if (gb_server_empty)
	{
		return;
	}
	
	float gametime = GetGameTime();
	
	for (int i = 1; i <= gi_timerid_current_count; i ++)
	{
		if (gh_timer[i] != null && gf_timer_firetime[i] > gametime)
		{
			gf_timer_firetime[i] -= gametime;
							
			if (gi_timer_flags[i] & TIMER_REPEAT)
			{
				
			}
			else
			{
				gf_timer_interval[i] = gf_timer_firetime[i];
			}
		}
	}
}

void Delete_RTimers(int flag)
{
	for (int i = 1; i <= gi_timerid_current_count; i ++)
	{
		if (!flag)
		{
			RTimerDelete(i);
		}
		else if (gi_timer_flags[i] & flag)
		{
			RTimerDelete(i);
		}
	}
	
	int timerid[MAX_RTIMERS + 1];
	int size;
	
	for (int i = 1; i <= gi_timerid_current_count; i ++)
	{
		if (gh_timer[i] != null)
		{
			size ++;
			timerid[size] = i;
		}
	}
	
	gi_timerid_current_count = size;
	
	int ref;
	
	for (int i = 1; i <= gi_timerid_current_count; i ++)
	{
		ref = timerid[i];
		
		if (i != ref)
		{
			gh_timer			[i] = gh_timer			[ref];
		
			gh_plugin			[i] = gh_plugin			[ref];
			gh_func				[i] = gh_func			[ref];
			gh_func_close 		[i] = gh_func_close		[ref];
			
			gf_timer_create		[i] = gf_timer_create	[ref];
			gf_timer_firetime	[i] = gf_timer_firetime	[ref];
			gf_timer_interval	[i] = gf_timer_interval	[ref];
			
			ga_timer_value		[i] = ga_timer_value	[ref];
			gi_timer_flags		[i] = gi_timer_flags	[ref];
			gi_timer_pause		[i] = gi_timer_pause	[ref];
			
			RTimerClearId(ref);
		}
	}
	
	gi_timerid_current_count ++;
}

void RTimerClearId(int i)
{
	gh_timer			[i] = null;
	
	gh_plugin			[i] = null;
	gh_func				[i] = view_as<Function>(0);
	gh_func_close 		[i] = view_as<Function>(0);
	
	gf_timer_create		[i] = 0.0;
	gf_timer_firetime	[i] = 0.0;
	gf_timer_interval	[i] = 0.0;
	
	ga_timer_value		[i] = 0;
	gi_timer_flags		[i] = 0;
	gi_timer_pause		[i] = 0;
}

public void OnClientPostAdminCheck(int client)
{
	if (IsFakeClient(client))
	{
		return;
	}
	
	gb_server_empty = false;
	
	SetUserConnect(GetClientUserId(client));
}

void Event_player_connect(Handle event, const char [] name, bool dontBroadcast)
{
	int bot = GetEventInt(event, "bot");
	if (bot)
	{
		return;
	}
	
	gb_server_empty = false;
	
	SetUserConnect(GetEventInt(event, "userid"));
}

void Event_player_disconnect(Handle event, const char [] name, bool dontBroadcast)
{
	SetUserDisconnect(GetEventInt(event, "userid"));
	
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		if (gi_users[i])
		{
			return;
		}
	}
	
	if (gb_server_empty)
	{
		return;
	}
	
	gb_server_empty = true;
	
	Delete_RTimers(0);
	
	gi_timerid_current_count = 0; // очистка должна быть строго после Delete_RTimers
}

bool SetUserConnect(int userid)
{
	if (GetUserSlot(userid))
	{
		return false;
	}
	
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		if (!gi_users[i])
		{
			gi_users[i] = userid;
			return true;
		}
	}
	
	return false;
}

bool SetUserDisconnect(int userid)
{
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		if (gi_users[i] == userid)
		{
			gi_users[i] = 0;
			return true;
		}
	}
	
	return false;
}

int GetUserSlot(int userid)
{
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		if (gi_users[i] == userid)
		{
			return i;
		}
	}

	return 0;
}
