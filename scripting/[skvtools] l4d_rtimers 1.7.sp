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

public Plugin myinfo = 
{
	name 		= "[skvtools] l4d_rtimers",
	author 		= "Skv",
	description = "Creates and manages timers that are active only during round",
	version 	= "1.7",
	url 		= ""
}

#define FILE_PATH	"data/S15_L%s.log"
char 	gs_logpath	[PLATFORM_MAX_PATH];

#define 	TIMER_FLAG_NO_ROUNDCHANGE   	(1<<2)	/* < Timer will not carry over round */

#define 	NAME_RTIMER 					"skvtools_rtimer"
#define 	MIN_INTERVAL 					0.05 // minimum timer operation interval >= 0.01
#define 	MAX_RTIMERS   					2048 // sets the maximum number of timers that can run simultaneously

Handle 		gh_timer						[MAX_RTIMERS + 1];
Handle 		gh_plugin						[MAX_RTIMERS + 1];
Function 	gh_func							[MAX_RTIMERS + 1];
Function 	gh_func_close					[MAX_RTIMERS + 1];
float 		gf_timer_firetime				[MAX_RTIMERS + 1];
float 		gf_timer_interval				[MAX_RTIMERS + 1];
any 		ga_timer_value					[MAX_RTIMERS + 1];
int 		gi_timer_flags					[MAX_RTIMERS + 1];
int 		gi_timer_pause					[MAX_RTIMERS + 1];

#define 	MAX_PLAYERS 					18

int 		gi_timers_maxcount;
int 		gi_timers_maxcreate;

bool 		gb_server_empty;

int 		gi_users						[MAX_PLAYERS + 1];

public APLRes AskPluginLoad2(Handle plugin, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_Left4Dead && GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left4Dead and Left4Dead 2");
		return APLRes_SilentFailure;
	}
	
	RegPluginLibrary("[skvtools] l4d_rtimers");
	
	CreateNative("CreateRTimer",			native_CreateRTimer);
		
	CreateNative("RTimerTrigger", 			native_RTimerTrigger);
	CreateNative("RTimerPause", 			native_RTimerPause);
	CreateNative("RTimerRemove", 			native_RTimerRemove);
	
	CreateNative("RTimerGetRemaining", 		native_RTimerGetRemaining);
	
	CreateNative("RTimerGetInterval", 		native_RTimerGetInterval);
	CreateNative("RTimerSetInterval", 		native_RTimerSetInterval);
	
	CreateNative("RTimerGetId", 			native_RTimerGetId);
	CreateNative("RTimerGetFlags", 			native_RTimerGetFlags);
	CreateNative("RTimerGetValue", 			native_RTimerGetValue);
	CreateNative("RTimerValueSet", 			native_RTimerValueSet);
		
	CreateNative("RTimerAddInterval", 		native_RTimerAddInterval);
	CreateNative("RTimerSubInterval", 		native_RTimerSubInterval);
	CreateNative("RTimerShift", 			native_RTimerShift);
		
	return APLRes_Success;
}

public void OnPluginStart()
{
	char data[64];
	FormatTime(data, sizeof(data), "20%y%m%d", GetTime());
	
	char buffer[64];
	FormatEx(buffer, sizeof(buffer), FILE_PATH, data);
	BuildPath(Path_SM, gs_logpath, sizeof(gs_logpath), buffer);
	
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
	
	if (!IsRtimerSpawn())
	{
		//LogToFileEx(gs_logpath, "native_CreateRTimer: time %f", GetGameTime());
				
		if (interval < 0.04)
		{
			ThrowNativeError(429, "\"Attempt to create a timer outside of a round with interval %f!\"", interval);
			
			return false;
		}
	}
		
	int i;
	
	for (i = 1; i <= MAX_RTIMERS; i++)
	{
		if (!gh_timer[i] || !IsValidHandle(gh_timer[i]))
		{
			gh_plugin			[i] = plugin;
			gh_func				[i] = GetNativeFunction(2);
						
			gf_timer_firetime	[i] = GetGameTime() + interval;
			gf_timer_interval	[i] = interval;
			
			ga_timer_value		[i] = GetNativeCell(3);
			gi_timer_flags		[i] = GetNativeCell(4);
			
			gh_func_close		[i] = GetNativeFunction(5);
			gh_timer			[i] = GetNativeCell(6);
			
			//PrintToChatAll("native_RTimerCreateValue: create timer %d", view_as<int>(gh_timer[i]));
			
			if (gi_timers_maxcreate < i)
			{
				gi_timers_maxcreate = i;
			}
			
			return true;
		}
	}
	
	LogError("\"native_CreateRTimer: The array size is not sufficient, MAX_RTIMERS must be at least %d\"", i);
	return false;
}

any native_RTimerGetRemaining(Handle plugin, int numParams)
{
	Handle timer = GetNativeCell(1);
	if (!timer)
	{
		return 0.0;
	}
	
	if (!IsValidHandle(timer))
	{
		int timerid = GetTimerId(timer);
		if (timerid)
		{
			RTimerDelete(timerid);
		}
		
		return 0.0;
	}
	
	for (int i = 1; i <= MAX_RTIMERS; i++)
	{
		if (gh_timer[i] == timer)
		{
			if (gf_timer_firetime[i] - GetGameTime() > 0.0)
			{
				return gf_timer_firetime[i] - GetGameTime();
			}
			else
			{
				return 0.0;
			}
		}
	}
	
	return 0.0;
}

any native_RTimerGetInterval(Handle plugin, int numParams)
{
	Handle timer = GetNativeCell(1);
	if (!timer)
	{
		return 0.0;
	}
	
	if (!IsValidHandle(timer))
	{
		int timerid = GetTimerId(timer);
		if (timerid)
		{
			RTimerDelete(timerid);
		}
		
		return 0.0;
	}
		
	for (int i = 1; i <= MAX_RTIMERS; i++)
	{
		if (gh_timer[i] == timer)
		{
			return gf_timer_interval[i];
		}
	}
	
	return 0.0;
}

any native_RTimerGetId(Handle plugin, int numParams)
{
	Handle timer = GetNativeCell(1);
	if (!timer)
	{
		return 0;
	}
	
	if (!IsValidHandle(timer))
	{
		int timerid = GetTimerId(timer);
		if (timerid)
		{
			RTimerDelete(timerid);
		}
		
		return 0;
	}
		
	for (int i = 1; i <= MAX_RTIMERS; i++)
	{
		if (gh_timer[i] == timer)
		{
			return i;
		}
	}
	
	return 0;
}

any native_RTimerGetFlags(Handle plugin, int numParams)
{
	Handle timer = GetNativeCell(1);
	if (!timer)
	{
		return -1;
	}
	
	if (!IsValidHandle(timer))
	{
		int timerid = GetTimerId(timer);
		if (timerid)
		{
			RTimerDelete(timerid);
		}
		
		return -1;
	}
		
	for (int i = 1; i <= MAX_RTIMERS; i++)
	{
		if (gh_timer[i] == timer)
		{
			return gi_timer_flags[i];
		}
	}
	
	return -1;
}

any native_RTimerGetValue(Handle plugin, int numParams)
{
	Handle timer = GetNativeCell(1);
	if (!timer)
	{
		return 0;
	}
	
	if (!IsValidHandle(timer))
	{
		int timerid = GetTimerId(timer);
		if (timerid)
		{
			RTimerDelete(timerid);
		}
		
		return 0;
	}
		
	for (int i = 1; i <= MAX_RTIMERS; i++)
	{
		if (gh_timer[i] == timer)
		{
			return ga_timer_value[i];
		}
	}
	
	return 0;
}

any native_RTimerAddInterval(Handle plugin, int numParams)
{
	Handle timer = GetNativeCell(1);
	if (!timer)
	{
		return false;
	}
	
	if (!IsValidHandle(timer))
	{
		int timerid = GetTimerId(timer);
		if (timerid)
		{
			RTimerDelete(timerid);
		}
		
		return false;
	}
		
	float 	added_value 	= GetNativeCell(2);
	if (added_value <= 0.0)
	{
		return false;
	}
	
	for (int i = 1; i <= MAX_RTIMERS; i++)
	{
		if (gh_timer[i] == timer)
		{
			gf_timer_firetime	[i] += added_value;
			gf_timer_interval 	[i] += added_value;
				
			return true;
		}
	}
	
	return false;
}

any native_RTimerSubInterval(Handle plugin, int numParams)
{
	Handle timer = GetNativeCell(1);
	if (!timer)
	{
		return false;
	}
	
	if (!IsValidHandle(timer))
	{
		int timerid = GetTimerId(timer);
		if (timerid)
		{
			RTimerDelete(timerid);
		}
		
		return false;
	}
		
	float 	subtrahend_value = GetNativeCell(2);
	if (subtrahend_value <= 0.0)
	{
		return false;
	}
	
	for (int i = 1; i <= MAX_RTIMERS; i++)
	{
		if (gh_timer[i] == timer)
		{
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
	}
	
	return false;
}

any native_RTimerSetInterval(Handle plugin, int numParams)
{
	Handle timer = GetNativeCell(1);
	if (!timer)
	{
		return false;
	}
	
	if (!IsValidHandle(timer))
	{
		int timerid = GetTimerId(timer);
		if (timerid)
		{
			RTimerDelete(timerid);
		}
		
		return false;
	}
		
	float 	interval_new 	= GetNativeCell(2);
	if (interval_new <= 0.0)
	{
		return false;
	}
	
	if (interval_new < MIN_INTERVAL)
	{
		interval_new = MIN_INTERVAL;
	}
	
	for (int i = 1; i <= MAX_RTIMERS; i++)
	{
		if (gh_timer[i] == timer)
		{
			gf_timer_firetime	[i] = gf_timer_firetime[i] - gf_timer_interval[i] + interval_new;
			gf_timer_interval	[i] = interval_new;
							
			return true;
		}
	}
	
	return false;
}

any native_RTimerValueSet(Handle plugin, int numParams)
{
	Handle timer = GetNativeCell(1);
	if (!timer)
	{
		return false;
	}
	
	if (!IsValidHandle(timer))
	{
		int timerid = GetTimerId(timer);
		if (timerid)
		{
			RTimerDelete(timerid);
		}
		
		return false;
	}
	
	any value = GetNativeCell(2);
		
	for (int i = 1; i <= MAX_RTIMERS; i++)
	{
		if (gh_timer[i] == timer)
		{
			ga_timer_value[i] = value;
							
			return true;
		}
	}
	
	return false;
}

any native_RTimerTrigger(Handle plugin, int numParams)
{
	Handle timer = GetNativeCell(1);
	if (!timer)
	{
		return false;
	}
	
	if (!IsValidHandle(timer))
	{
		int timerid = GetTimerId(timer);
		if (timerid)
		{
			RTimerDelete(timerid);
		}
		
		return false;
	}
		
	for (int i = 1; i <= MAX_RTIMERS; i++)
	{
		if (gh_timer[i] == timer)
		{
			RTimerFire(i);
					
			return true;
		}
	}
	
	return false;
}

any native_RTimerShift(Handle plugin, int numParams)
{
	Handle 	timer = GetNativeCell(1);
	if (!timer)
	{
		return false;
	}
	
	if (!IsValidHandle(timer))
	{
		int timerid = GetTimerId(timer);
		if (timerid)
		{
			RTimerDelete(timerid);
		}
		
		return false;
	}
	
	float 	seconds		= GetNativeCell(2);
		
	for (int i = 1; i <= MAX_RTIMERS; i++)
	{
		if (gh_timer[i] == timer)
		{
			gf_timer_firetime	[i] = GetGameTime() + seconds;
							
			return true;
		}
	}
	
	return false;
}

any native_RTimerPause(Handle plugin, int numParams)
{
	Handle timer = GetNativeCell(1);
	if (!timer)
	{
		return false;
	}
	
	if (!IsValidHandle(timer))
	{
		int timerid = GetTimerId(timer);
		if (timerid)
		{
			RTimerDelete(timerid);
		}
		
		return false;
	}
	
	for (int i = 1; i <= MAX_RTIMERS; i++)
	{
		if (gh_timer[i] == timer)
		{
			gi_timer_pause[i] = GetNativeCell(2);
							
			return true;
		}
	}
	
	return false;
}

any native_RTimerRemove(Handle plugin, int numParams)
{
	Handle timer = GetNativeCell(1);
	if (!timer)
	{
		return false;
	}
	
	for (int i = 1; i <= MAX_RTIMERS; i++)
	{
		if (gh_timer[i] == timer)
		{
			RTimerDelete(i);
			
			return true;
		}
	}
	
	return false;
}

int GetTimerId(Handle timer)
{
	for (int i = 1; i <= MAX_RTIMERS; i++)
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
	
	HookSingleEntityOutput(entity, "OnTimer", OnTimer);
	HookSingleEntityOutput(entity, "OnKilled", OnKilled);
	
	float game_time = GetGameTime();
	LogToFileEx(gs_logpath, "RTimerSpawn: time %f", game_time);
	
	for (int i = 1; i <= MAX_RTIMERS; i++)
	{
		if (gf_timer_firetime[i] > 0.0)
		{
			if (game_time < 10.0)
			{
				gf_timer_firetime[i] += game_time;
			}
		}
	}
	
	LogToFileEx(gs_logpath, "RTimerSpawn");
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
	
	LogToFileEx(gs_logpath, "%s time %f", output, GetGameTime());
	
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		if (IsValidClient(i) && !IsFakeClient(i))
		{
			LogToFileEx(gs_logpath, "%s force spawn rtimer", output);
			
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
	
	LogToFileEx(gs_logpath, "%s time %f", output, GetGameTime());
	RTimerSpawn();
}

void Event_player_connect(Handle event, const char [] name, bool dontBroadcast)
{
	int bot = GetEventInt(event, "bot");
	if (bot)
	{
		return;
	}
	
	//LogToFileEx(gs_logpath, "%s: userid %d", name, GetEventInt(event, "userid"));
	
	gb_server_empty = false;
	
	SetUserConnect(GetEventInt(event, "userid"));
}

void Event_player_disconnect(Handle event, const char [] name, bool dontBroadcast)
{
	if (gb_server_empty)
	{
		return;
	}
	
	//LogToFileEx(gs_logpath, "%s: userid %d", name, GetEventInt(event, "userid"));
	
	SetUserDisconnect(GetEventInt(event, "userid"));
	
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		if (gi_users[i])
		{
			return;
		}
	}
	
	gb_server_empty = true;
	
	LogToFileEx(gs_logpath, "l4d_timers server SERVER_EMPTY");
	
	LogToFileEx(gs_logpath, "gi_timers_maxcount %d", gi_timers_maxcount);
	gi_timers_maxcount = 0;
	
	LogToFileEx(gs_logpath, "gi_timers_maxcreate %d", gi_timers_maxcreate);
	gi_timers_maxcreate = 0;
	
	Delete_RTimers(0);
	
	/*char plugin_name[PLATFORM_MAX_PATH];
	GetPluginFilename(INVALID_HANDLE, plugin_name, sizeof(plugin_name));
	
	ServerCommand("sm plugins reload \"%s\"", plugin_name);*/
}

void OnTimer(char [] output, int timer, int activator, float delay)
{
	if (gb_server_empty)
	{
		//LogToFileEx(gs_logpath, "%s server empty!", output);
		return;
	}
	
	int timers_count;
	
	for (int i = 1; i <= MAX_RTIMERS; i++)
	{
		if (IsValidHandle(gh_timer[i]))
		{
			if (gf_timer_firetime[i] <= GetGameTime())
			{
				RTimerFire(i);
			}
			else
			{
				if (gi_timer_pause[i])
				{
					gf_timer_firetime[i] += MIN_INTERVAL;
				}
					
				timers_count ++;
			}
		}
		else if (gh_timer[i])
		{
			RTimerDelete(i);
		}
	}
	
	if (gi_timers_maxcount < timers_count)
	{
		gi_timers_maxcount = timers_count;
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
	
	Call_StartFunction(gh_plugin[i], gh_func[i]);
	Call_PushCell(gh_timer[i]);
	Call_PushCell(ga_timer_value[i]);
			
	Call_Finish(action);
			
	if ((gi_timer_flags[i] & TIMER_REPEAT) && action != 4 && gf_timer_interval[i] > 0.0)
	{
		gf_timer_firetime[i] = GetGameTime() + gf_timer_interval[i];
			
		return;
	}
		
	RTimerDelete(i);
}

void RTimerDelete(int i)
{
	//PrintToChatAll("RTimerDelete handle %d", view_as<int>(gh_timer[i]));
	
	if (IsValidHandle(gh_plugin[i]) && gh_func_close[i])
	{
		Call_StartFunction(gh_plugin[i], gh_func_close[i]);
		
		Call_PushCell(gh_timer[i]);
		Call_PushCell(ga_timer_value[i]);
		Call_PushCell(gi_timer_flags[i]);
			
		Call_Finish();
	}
	
	gh_timer			[i] = null;
	
	gh_plugin			[i] = INVALID_HANDLE;
	gh_func				[i] = view_as<Function>(0);
	gh_func_close 		[i] = view_as<Function>(0);
	
	gf_timer_firetime	[i] = 0.0;
	gf_timer_interval	[i] = 0.0;
	
	ga_timer_value		[i] = 0;
	gi_timer_flags		[i] = 0;
	gi_timer_pause		[i] = 0;
}

public void OnMapStart()
{
	Delete_RTimers(TIMER_FLAG_NO_MAPCHANGE | TIMER_FLAG_NO_ROUNDCHANGE);
}

void Event_round_end(Handle event, const char [] name, bool dontBroadcast)
{
	LogToFileEx(gs_logpath, "gi_timers_maxcount %d", gi_timers_maxcount);
	gi_timers_maxcount = 0;
	
	LogToFileEx(gs_logpath, "gi_timers_maxcreate %d", gi_timers_maxcreate);
	gi_timers_maxcreate = 0;
	
	Delete_RTimers(TIMER_FLAG_NO_ROUNDCHANGE);
}

public void OnMapEnd()
{
	Delete_RTimers(TIMER_FLAG_NO_MAPCHANGE | TIMER_FLAG_NO_ROUNDCHANGE);
	
	Transfer_RTimers();
	
	char data[64];
	FormatTime(data, sizeof(data), "20%y%m%d", GetTime());
	
	char buffer[64];
	FormatEx(buffer, sizeof(buffer), FILE_PATH, data);
	BuildPath(Path_SM, gs_logpath, sizeof(gs_logpath), buffer);
	
	LogToFileEx(gs_logpath, "gi_timers_maxcount %d", gi_timers_maxcount);
	gi_timers_maxcount = 0;
	
	LogToFileEx(gs_logpath, "gi_timers_maxcreate %d", gi_timers_maxcreate);
	gi_timers_maxcreate = 0;
}

void Transfer_RTimers()
{
	for (int i = 1; i <= MAX_RTIMERS; i++)
	{
		if (IsValidHandle(gh_timer[i]) && gf_timer_firetime[i] > GetGameTime())
		{
			gf_timer_firetime[i] -= GetGameTime();
			
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
	for (int i = 1; i <= MAX_RTIMERS; i++)
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

