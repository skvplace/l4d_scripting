#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#include <skvtools>
#include <skvtools_gamestartcoop>
#include <skvtools_timers_round>

public Plugin:myinfo = 
{
	name 		= "[skvtools] l4d_timers_round",
	author 		= "Skv",
	description = "Creates and manages timers that only run during active gameplay (round).",
	version 	= "1.0",
	url 		= ""
}

bool 			DEBUG_LOG 			= true;
#define 		FILE_PATH			"data/timers_%s.log"
char 			gs_logpath			[PLATFORM_MAX_PATH];

#define 		NAME_TIMER 			"round_timer"

Handle 			gh_plugin			[MAX_TIMERS + 1];
Function 		gh_func				[MAX_TIMERS + 1];
float 			gf_timer_firetime	[MAX_TIMERS + 1];
float 			gf_timer_interval	[MAX_TIMERS + 1];
any 			ga_timer_value		[MAX_TIMERS + 1];
int 			gi_timer_flags		[MAX_TIMERS + 1];

public APLRes AskPluginLoad2(Handle plugin, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_Left4Dead && GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left4Dead and Left4Dead 2");
		return APLRes_SilentFailure;
	}
	
	RegPluginLibrary("[skvtools] l4d_timers");
	
	CreateNative("RTimerCreate", 			native_RTimerCreate);
	
	CreateNative("RTimerGetRemaining", 		native_RTimerGetRemaining);
	CreateNative("RTimerGetInterval", 		native_RTimerGetInterval);
	CreateNative("RTimerGetValue", 			native_RTimerGetValue);
		
	CreateNative("RTimerAddInterval", 		native_RTimerAddInterval);
	CreateNative("RTimerSubInterval", 		native_RTimerSubInterval);
		
	CreateNative("RTimerSetInterval", 		native_RTimerSetInterval);
	CreateNative("RTimerSetValue", 			native_RTimerSetValue);
	
	CreateNative("RTimerTrigger", 			native_RTimerTrigger);
	CreateNative("RTimerShift", 			native_RTimerShift);
	CreateNative("RTimerRemove", 			native_RTimerRemove);
	
	return APLRes_Success;
}

public OnPluginStart()
{
	char data[64];
	FormatTime(data, sizeof(data), "20%y%m%d", GetTime());
	
	char buffer[64];
	FormatEx(buffer, sizeof(buffer), FILE_PATH, data);
	BuildPath(Path_SM, gs_logpath, sizeof(gs_logpath), buffer);
}

public OnAllPluginsLoaded()
{
	if (!LibraryExists("[skvtools] l4d_l4d2_gamestartcoop"))
	{
		SetFailState("The library [skvtools] l4d_l4d2_gamestartcoop was not found!");
	}
}

int native_RTimerCreate(Handle plugin, int numParams)
{
	if (!IsGameplayActive())
	{
		return 0;
	}
	
	float 		interval 	= GetNativeCell(1);
	Function 	func 		= GetNativeFunction(2);
	any 		value 		= GetNativeCell(3);
	int 		flags 		= GetNativeCell(4);
		
	for (int i = 1; i <= MAX_TIMERS; i++)
	{
		if (gf_timer_firetime[i])
		{
			gh_plugin			[i] = plugin;
			gh_func				[i] = func;
						
			gf_timer_firetime	[i] = GetGameTime() + interval;
			gf_timer_interval	[i] = interval;
			ga_timer_value		[i] = value;
			gi_timer_flags		[i] = flags;
			
			LogToDebug(DEBUG_LOG, gs_logpath, "native_RTimerCreate: create timer %d", i);
			Status();
			
			return i;
		}
	}
	
	LogError("native_RTimerCreate: no free slots");
	return 0;
}

any native_RTimerGetRemaining(Handle plugin, int numParams)
{
	int timerid = GetNativeCell(1);
	if (timerid <= 0)
	{
		return 0;
	}
	
	for (int i = 1; i <= MAX_TIMERS; i++)
	{
		if (i == timerid)
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
	int timerid = GetNativeCell(1);
	if (timerid <= 0)
	{
		return 0;
	}
	
	for (int i = 1; i <= MAX_TIMERS; i++)
	{
		if (i == timerid)
		{
			return gf_timer_interval[i];
		}
	}
	
	return 0.0;
}

any native_RTimerGetValue(Handle plugin, int numParams)
{
	int timerid = GetNativeCell(1);
	if (timerid <= 0)
	{
		return 0;
	}
	
	for (int i = 1; i <= MAX_TIMERS; i++)
	{
		if (i == timerid)
		{
			return ga_timer_value[i];
		}
	}
	
	return 0;
}

any native_RTimerAddInterval(Handle plugin, int numParams)
{
	int 	timerid 		= GetNativeCell(1);
	float 	added_value 	= GetNativeCell(2);
	
	if (timerid <= 0)
	{
		return false;
	}
	
	if (added_value <= 0.0)
	{
		return false;
	}
	
	LogToDebug(DEBUG_LOG, gs_logpath, "native_RTimerAddInterval: timer %d, added_value %f", timerid, added_value);
	
	for (int i = 1; i <= MAX_TIMERS; i++)
	{
		if (i == timerid)
		{
			gf_timer_firetime	[i] += added_value;
			gf_timer_interval 	[i] += added_value;
				
			Status();
				
			return true;
		}
	}
	
	return false;
}

any native_RTimerSubInterval(Handle plugin, int numParams)
{
	int 	timerid 		= GetNativeCell(1);
	float 	subtrahend_value = GetNativeCell(2);
	
	if (timerid <= 0)
	{
		return false;
	}
	
	if (subtrahend_value <= 0.0)
	{
		return false;
	}
	
	LogToDebug(DEBUG_LOG, gs_logpath, "native_RTimerSubInterval: timer %d, subtrahend_value %f", timerid, subtrahend_value);
	
	for (int i = 1; i <= MAX_TIMERS; i++)
	{
		if (i == timerid)
		{
			gf_timer_firetime	[i] -= subtrahend_value;
			gf_timer_interval 	[i] -= subtrahend_value;
				
			if (gf_timer_interval[i] <= 0.0)
			{
				RTimerFire(i);
			}
				
			Status();
				
			return true;
		}
	}
	
	return false;
}

any native_RTimerSetInterval(Handle plugin, int numParams)
{
	int 	timerid 		= GetNativeCell(1);
	float 	interval_new 	= GetNativeCell(2);
	
	if (timerid <= 0)
	{
		return false;
	}
	
	if (interval_new < 0.0)
	{
		return false;
	}
	
	LogToDebug(DEBUG_LOG, gs_logpath, "native_RTimerSetInterval: timer %d, interval_new %f", timerid, interval_new);
	
	for (int i = 1; i <= MAX_TIMERS; i++)
	{
		if (i == timerid)
		{
			gf_timer_firetime	[i] = GetGameTime() + interval_new;
			gf_timer_interval	[i] = interval_new;
				
			Status();
				
			return true;
		}
	}
	
	return false;
}

any native_RTimerSetValue(Handle plugin, int numParams)
{
	int timerid 		= GetNativeCell(1);
	any value 			= GetNativeCell(2);
	
	if (timerid <= 0)
	{
		return false;
	}
	
	LogToDebug(DEBUG_LOG, gs_logpath, "native_RTimerSetInterval: timer %d, value %d", timerid, view_as<int>(value));
	
	for (int i = 1; i <= MAX_TIMERS; i++)
	{
		if (i == timerid)
		{
			if (IsValidHandle(ga_timer_value[i]))
			{
				CloseHandle(ga_timer_value[i]);
			}
			
			ga_timer_value		[i] = value;
				
			Status();
				
			return true;
		}
	}
	
	return false;
}

any native_RTimerTrigger(Handle plugin, int numParams)
{
	int timerid 		= GetNativeCell(1);
	if (timerid <= 0)
	{
		return false;
	}
	
	LogToDebug(DEBUG_LOG, gs_logpath, "native_RTimerTrigger: timer %d,", timerid);
	
	for (int i = 1; i <= MAX_TIMERS; i++)
	{
		if (i == timerid)
		{
			RTimerFire(i);
					
			return true;
		}
	}
	
	return false;
}

any native_RTimerShift(Handle plugin, int numParams)
{
	int 	timerid 	= GetNativeCell(1);
	float 	seconds		= GetNativeCell(2);
	
	if (timerid <= 0)
	{
		return false;
	}
	
	LogToDebug(DEBUG_LOG, gs_logpath, "native_RTimerShift: timer %d, seconds %f", timerid, seconds);
	
	for (int i = 1; i <= MAX_TIMERS; i++)
	{
		if (i == timerid)
		{
			gf_timer_firetime	[i] = GetGameTime() + seconds;
			
			Status();
				
			return true;
		}
	}
	
	return false;
}

any native_RTimerRemove(Handle plugin, int numParams)
{
	int timerid 		= GetNativeCell(1);
	if (timerid <= 0)
	{
		return false;
	}
	
	LogToDebug(DEBUG_LOG, gs_logpath, "native_RTimerRemove: timer %d", timerid);
	
	for (int i = 1; i <= MAX_TIMERS; i++)
	{
		if (i == timerid)
		{
			gh_plugin			[i] = null;
			gh_func				[i] = view_as<Function>(0);
			
			gf_timer_firetime	[i] = 0.0;
			gf_timer_interval	[i] = 0.0;
			
			if (IsValidHandle(ga_timer_value[i]))
			{
				CloseHandle(ga_timer_value[i]);
			}
			
			ga_timer_value		[i] = 0;
			gi_timer_flags		[i] = 0;
				
			Status();
				
			return true;
		}
	}
	
	return false;
}

public OnGameplayStart(int stage)
{
	if (stage)
	{
		return;
	}
	
	LogToDebug(DEBUG_LOG, gs_logpath, "OnGameplayStart");
	Status();
	
	int timer = GetRTimer();
	if (timer)
	{
		InputKill(timer);
	}
	
	Delete_RTimers();
	
	int entity = CreateEntityByName("logic_timer");
	if (entity == -1)
	{
		return;
	}
	
	DispatchKeyValue(entity, "targetname", NAME_TIMER);
	DispatchKeyValue(entity, "StartDisabled", "0");
	
	DispatchKeyValue(entity, "UseRandomTime", "0");
	DispatchKeyValue(entity, "RefireTime", "0.1");
		
	DispatchSpawn(entity);
	
	HookSingleEntityOutput(entity, "OnTimer", OnTimer);
}

int GetRTimer()
{
	char buffer[MAX_STRING_LENGTH];
	
	int i = -1;
	while ((i = FindEntityByClassname(i, "logic_timer")) != -1)
	{
		GetEntPropString(i, Prop_Data, "m_iName", buffer, sizeof(buffer));
		if (!strcmp(buffer, NAME_TIMER))
		{
			return i;
		}
	}
	
	return 0;
}

void OnTimer(char [] output, int timer, int activator, float delay)
{
	for (int i = 1; i <= MAX_TIMERS; i++)
	{
		if (gf_timer_firetime[i] <= GetGameTime())
		{
			RTimerFire(i);
			break;
		}
	}
}

void RTimerFire(int timerid)
{
	LogToDebug(DEBUG_LOG, gs_logpath, "RTimerFire: timer %d", timerid);
	
	if (!timerid)
	{
		return;
	}
	
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
	
	Call_StartFunction(gh_plugin[timerid], gh_func[timerid]);
	Call_PushCell(timerid);
	Call_PushCell(ga_timer_value[timerid]);
	Call_Finish(action);
	
	if ((gi_timer_flags[timerid] & TIMER_REPEAT) && action != 4 && gf_timer_interval[timerid] > 0.0)
	{
		gf_timer_firetime[timerid] = GetGameTime() + gf_timer_interval[timerid];
	}
	else
	{
		gh_plugin			[timerid] = null;
		gh_func				[timerid] = view_as<Function>(0);
		
		gf_timer_firetime	[timerid] = 0.0;
		gf_timer_interval	[timerid] = 0.0;
		ga_timer_value		[timerid] = 0;
		gi_timer_flags		[timerid] = 0;
	}
	
	Status();
}

public OnMissionLost()
{
	Delete_RTimers();
	
	LogToDebug(DEBUG_LOG, gs_logpath, "OnMissionLost");
	Status();
}

public OnMapStart()
{
	char data[64];
	FormatTime(data, sizeof(data), "20%y%m%d", GetTime());
	
	char buffer[64];
	FormatEx(buffer, sizeof(buffer), FILE_PATH, data);
	BuildPath(Path_SM, gs_logpath, sizeof(gs_logpath), buffer);
	
	Delete_RTimers();
	
	LogToDebug(DEBUG_LOG, gs_logpath, "OnMapStart");
	Status();
}

public OnMapEnd()
{
	Delete_RTimers();
	
	LogToDebug(DEBUG_LOG, gs_logpath, "OnMapEnd");
	Status();
}

public OnMapRestart()
{
	Delete_RTimers();
	
	LogToDebug(DEBUG_LOG, gs_logpath, "OnMapRestart");
	Status();
}

public OnMissionChange()
{
	Delete_RTimers();
	
	LogToDebug(DEBUG_LOG, gs_logpath, "OnMissionChange");
	Status();
}

void Delete_RTimers()
{
	for (int i = 1; i <= MAX_TIMERS; i++)
	{
		gh_plugin			[i] = null;
		gh_func				[i] = view_as<Function>(0);
				
		gf_timer_firetime	[i] = 0.0;
		gf_timer_interval	[i] = 0.0;
		
		if (IsValidHandle(ga_timer_value[i]))
		{
			CloseHandle(ga_timer_value[i]);
		}
		
		ga_timer_value		[i] = 0;
		gi_timer_flags		[i] = 0;
	}
}

public OnServerEmpty()
{
	Delete_RTimers();
	
	LogToDebug(DEBUG_LOG, gs_logpath, "OnServerEmpty");	
	Status();
}

void Status()
{
	LogToDebug(DEBUG_LOG, gs_logpath, " ");
	LogToDebug(DEBUG_LOG, gs_logpath, "-------------------------------");
	LogToDebug(DEBUG_LOG, gs_logpath, "Status:");
	
	bool no_found = true;
	
	for (int i = 1; i <= MAX_TIMERS; i++)
	{
		if (gf_timer_firetime[i])
		{
			no_found = false;
			
			LogToDebug(DEBUG_LOG, gs_logpath, "-------------------------------");
			LogToDebug(DEBUG_LOG, gs_logpath, "timerid %d", i);
			
			LogToDebug(DEBUG_LOG, gs_logpath, "gh_plugin %d",			view_as<int>(gh_plugin[i]));
			LogToDebug(DEBUG_LOG, gs_logpath, "gh_func %d", 			view_as<int>(gh_func[i]));
			
			LogToDebug(DEBUG_LOG, gs_logpath, "gf_timer_firetime %f", 	gf_timer_firetime[i]);
			LogToDebug(DEBUG_LOG, gs_logpath, "gf_timer_interval %f", 	gf_timer_interval[i]);
			
			LogToDebug(DEBUG_LOG, gs_logpath, "ga_timer_value %d", 		view_as<int>(ga_timer_value[i]));
			LogToDebug(DEBUG_LOG, gs_logpath, "gi_timer_flags %d", 		gi_timer_flags[i]);
			LogToDebug(DEBUG_LOG, gs_logpath, "-------------------------------");
			LogToDebug(DEBUG_LOG, gs_logpath, " ");
		}
	}
	
	if (no_found)
	{
		//PrintToChatAll("%f Status: no timers found", GetGameTme());
		LogToDebug(DEBUG_LOG, gs_logpath, "no timers found");
	}
	
	LogToDebug(DEBUG_LOG, gs_logpath, "-------------------------------");
	LogToDebug(DEBUG_LOG, gs_logpath, " ");
}
