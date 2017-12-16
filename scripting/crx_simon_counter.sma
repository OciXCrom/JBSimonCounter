#include <amxmodx>
#include <amxmisc>
#include <cromchat>

#if AMXX_VERSION_NUM < 183
	#include <dhudmessage>
#endif

/*	
 	Comment these two lines if you want to use the plugin on all mods (admins only).
	Change "is_user_simon" if you have a different native.
*/
native is_user_simon(id)
#define IS_SIMON(%1) is_user_simon(%1)

#define PLUGIN_VERSION "1.0.2"
#define TASK_TIMER 433987
#define SYM_ETC "..."
#define PLUGIN_TIMER g_eSettings[HIDE_COMMAND_IN_CHAT]
#define clr(%1) %1 == -1 ? random(256) : %1

enum
{
	CMD_NULL = 0,
	CMD_TIMER,
	CMD_STOP
}

enum _:Settings
{
	TIMER_COMMAND[16],
	STOP_COMMAND[16],
	HIDE_COMMAND_IN_CHAT,
	bool:CHAT_MESSAGES,
	Float:TIMER_SPEED,
	SPEECH_PATH[64],
	STOP_SOUND[64],
	TIMER_FOR_ADMINS[2],
	bool:HUD_USE_DHUD,
	HUD_RED,
	HUD_GREEN,
	HUD_BLUE,
	Float:HUD_X,
	Float:HUD_Y,
	HUD_EFFECTS,
	Float:HUD_FXTIME
}

new g_eSettings[Settings]

new Trie:g_tTimer,
	Float:g_fSpeed,
	g_iCmdLen[3],
	g_iObject,
	g_iTimer
	
new g_szFileName[512]

public plugin_init()
{
	register_plugin("JB: Simon Counter", PLUGIN_VERSION, "OciXCrom")
	register_cvar("CRXSimonCounter", PLUGIN_VERSION, FCVAR_SERVER|FCVAR_SPONLY|FCVAR_UNLOGGED)
	register_dictionary("SimonCounter.txt")
	register_logevent("StopTimer", 2, "1=Round_End")
	register_logevent("StopTimer", 2, "0=World triggered", "1=Round_Start")
	
	register_clcmd("say", "OnSay")
	register_clcmd("say_team", "OnSay")
	register_concmd("jbcounter_reload", "ReloadCounter", ADMIN_RCON)
	
	new szPrefix[32]
	formatex(szPrefix, charsmax(szPrefix), "%L", LANG_SERVER, "JBTIMER_CHAT_PREFIX")
	CC_SetPrefix(szPrefix)
}

public plugin_precache()
{
	g_tTimer = TrieCreate()
	get_configsdir(g_szFileName, charsmax(g_szFileName))
	formatex(g_szFileName, charsmax(g_szFileName), "%s/SimonCounter.ini", g_szFileName)
	ReadFile()
}

public plugin_end()
	TrieDestroy(g_tTimer)

ReadFile(bReload = false)
{
	new iFilePointer = fopen(g_szFileName, "rt")
	
	if(iFilePointer)
	{
		new szData[128], szValue[96], szKey[32], szNum[5], szLeft[5], szRight[5]
		
		while(!feof(iFilePointer))
		{
			fgets(iFilePointer, szData, charsmax(szData))
			trim(szData)
			
			switch(szData[0])
			{
				case EOS, ';', '[': continue
				default:
				{
					strtok(szData, szKey, charsmax(szKey), szValue, charsmax(szValue), '=')
					trim(szKey); trim(szValue)
					
					if(!szValue[0])
						continue

					if(equal(szKey, "TIMER_COMMAND"))
					{
						copy(g_eSettings[TIMER_COMMAND], charsmax(g_eSettings[TIMER_COMMAND]), szValue)
						g_iCmdLen[CMD_TIMER] = strlen(szValue)
					}
					else if(equal(szKey, "STOP_COMMAND"))
					{
						copy(g_eSettings[STOP_COMMAND], charsmax(g_eSettings[STOP_COMMAND]), szValue)
						g_iCmdLen[CMD_STOP] = strlen(szValue)
					}
					else if(equal(szKey, "TIMER_SECONDS"))
					{
						while(szValue[0] != 0 && strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ','))
						{
							trim(szKey); trim(szValue)
							
							if(contain(szKey, SYM_ETC) != -1)
							{
								split(szKey, szLeft, charsmax(szLeft), szRight, charsmax(szRight), SYM_ETC)
								
								for(new i = str_to_num(szLeft); i <= str_to_num(szRight); i++)
								{
									num_to_str(i, szNum, charsmax(szNum))
									TrieSetCell(g_tTimer, szNum, 1)
								}
							}
							else TrieSetCell(g_tTimer, szKey, 1)
						}
					}
					else if(equal(szKey, "HIDE_COMMAND_IN_CHAT"))
						g_eSettings[HIDE_COMMAND_IN_CHAT] = clamp(str_to_num(szValue), PLUGIN_CONTINUE, PLUGIN_HANDLED)
					else if(equal(szKey, "CHAT_MESSAGES"))
						g_eSettings[CHAT_MESSAGES] = bool:(clamp(str_to_num(szValue), false, true))
					else if(equal(szKey, "TIMER_SPEED"))
						g_eSettings[TIMER_SPEED] = _:floatclamp(str_to_float(szValue), 0.1, 10.0)
					else if(equal(szKey, "SPEECH_PATH"))
						copy(g_eSettings[SPEECH_PATH], charsmax(g_eSettings[SPEECH_PATH]), szValue)
					else if(equal(szKey, "STOP_SOUND"))
					{
						copy(g_eSettings[STOP_SOUND], charsmax(g_eSettings[STOP_SOUND]), szValue)
						
						if(!bReload)
							precache_sound(szValue)
					}
					else if(equal(szKey, "TIMER_FOR_ADMINS"))
						copy(g_eSettings[TIMER_FOR_ADMINS], charsmax(g_eSettings[TIMER_FOR_ADMINS]), szValue)
					else if(equal(szKey, "HUD_USE_DHUD"))
					{
						g_eSettings[HUD_USE_DHUD] = bool:(clamp(str_to_num(szValue), false, true))
						
						if(!g_eSettings[HUD_USE_DHUD])
							g_iObject = CreateHudSyncObj()
					}
					else if(equal(szKey, "HUD_RED"))
						g_eSettings[HUD_RED] = clamp(str_to_num(szValue), -1, 255)
					else if(equal(szKey, "HUD_GREEN"))
						g_eSettings[HUD_GREEN] = clamp(str_to_num(szValue), -1, 255)
					else if(equal(szKey, "HUD_BLUE"))
						g_eSettings[HUD_BLUE] = clamp(str_to_num(szValue), -1, 255)
					else if(equal(szKey, "HUD_X"))
						g_eSettings[HUD_X] = _:floatclamp(str_to_float(szValue), -1.0, 1.0)
					else if(equal(szKey, "HUD_Y"))
						g_eSettings[HUD_Y] = _:floatclamp(str_to_float(szValue), -1.0, 1.0)
					else if(equal(szKey, "HUD_EFFECTS"))
						g_eSettings[HUD_EFFECTS] = clamp(str_to_num(szValue), 0, 2)
					else if(equal(szKey, "HUD_FXTIME"))
						g_eSettings[HUD_FXTIME] = _:floatclamp(str_to_float(szValue), 0.1, 10.0)
				}
			}
		}
		
		fclose(iFilePointer)
	}
}

public ReloadCounter(id, iLevel, iCid)
{
	if(!cmd_access(id, iLevel, iCid, 1))
		return PLUGIN_HANDLED
	
	ReadFile(true)
	
	new szName[32]
	get_user_name(id, szName, charsmax(szName))
	console_print(id, "%L", id, "JBTIMER_RELOADED")
	log_amx("%L", LANG_SERVER, "JBTIMER_RELOADED_LOG", szName)
	return PLUGIN_HANDLED
}

public OnSay(id)
{
	new szArgs[32], iCmd = CMD_NULL
	read_args(szArgs, charsmax(szArgs))
	remove_quotes(szArgs)
	
	if(equali(szArgs[0], g_eSettings[TIMER_COMMAND], g_iCmdLen[CMD_TIMER]))
		iCmd = CMD_TIMER
	else if(equali(szArgs[0], g_eSettings[STOP_COMMAND], g_iCmdLen[CMD_STOP]))
		iCmd = CMD_STOP
	else return PLUGIN_CONTINUE
	
	#if defined IS_SIMON
	if(!IS_SIMON(id))
	{
		if(has_access(id))
			goto @ALL_GOOD
		
		CC_SendMessage(id, "%L", id, "JBTIMER_NOT_SIMON")
		return PLUGIN_TIMER
	}
	else goto @ALL_GOOD
	#endif
	
	if(!has_access(id))
	{
		CC_SendMessage(id, "%L", id, "JBTIMER_NO_ACCESS")
		return PLUGIN_TIMER
	}
	
	#if defined IS_SIMON
	@ALL_GOOD:
	#endif
	
	switch(iCmd)
	{
		case CMD_TIMER:
		{
			new szTime[5], szSpeed[5]
			parse(szArgs, szArgs, charsmax(szArgs), szTime, charsmax(szTime), szSpeed, charsmax(szSpeed))
			
			if(!szTime[0])
				CC_SendMessage(id, "%L", id, "JBTIMER_USAGE", g_eSettings[TIMER_COMMAND])
			else if(!is_str_num(szTime))
				CC_SendMessage(id, "%L", id, "JBTIMER_INVALID_TIMER", szTime)
			else if(!TrieKeyExists(g_tTimer, szTime))
				CC_SendMessage(id, "%L", id, "JBTIMER_INVALID_NUMBER", szTime)
			else if(g_iTimer)
				CC_SendMessage(id, "%L", id, "JBTIMER_ALREADY_ACTIVE", g_iTimer)
			else
			{
				g_iTimer = str_to_num(szTime)
				g_fSpeed = szSpeed[0] ? str_to_float(szSpeed) : g_eSettings[TIMER_SPEED]
				
				new szName[32]
				get_user_name(id, szName, charsmax(szName))
				
				if(g_eSettings[CHAT_MESSAGES])
				{
					if(g_fSpeed != g_eSettings[TIMER_SPEED])
						CC_SendMessage(0, "%L", LANG_PLAYER, "JBTIMER_STARTED_SPEED", szName, g_iTimer, g_fSpeed)
					else
						CC_SendMessage(0, "%L", LANG_PLAYER, "JBTIMER_STARTED", szName, g_iTimer)
				}
				
				set_task(g_fSpeed, "DisplayTimer", TASK_TIMER, .flags = "b")
				DisplayTimer()
			}
		}
		case CMD_STOP:
		{
			if(!g_iTimer)
				CC_SendMessage(id, "%L", id, "JBTIMER_NOT_ACTIVE")
			else
			{
				StopTimer()
				
				new szName[32]
				get_user_name(id, szName, charsmax(szName))
				client_cmd(0, "spk %s", g_eSettings[STOP_SOUND])
				
				if(g_eSettings[CHAT_MESSAGES])
					CC_SendMessage(0, "%L", LANG_PLAYER, "JBTIMER_STOPPED", szName)
			}
		}
	}
	
	return PLUGIN_TIMER
}

public DisplayTimer()
{	
	static szMessage[192], szWord[16]
	num_to_word(g_iTimer, szWord, charsmax(szWord))
	client_cmd(0, "spk ^"%s/%s^"", g_eSettings[SPEECH_PATH], szWord)
	formatex(szMessage, charsmax(szMessage), "%L", LANG_PLAYER, "JBTIMER_DISPLAY", g_iTimer, LANG_PLAYER, g_iTimer == 1 ? "JBTIMER_SECOND" : "JBTIMER_SECONDS")
	
	switch(g_eSettings[HUD_USE_DHUD])
	{
		case true:
		{
			set_dhudmessage(clr(g_eSettings[HUD_RED]), clr(g_eSettings[HUD_GREEN]), clr(g_eSettings[HUD_BLUE]),\
			g_eSettings[HUD_X], g_eSettings[HUD_Y], g_eSettings[HUD_EFFECTS], g_eSettings[HUD_FXTIME], g_eSettings[TIMER_SPEED])
			
			show_dhudmessage(0, szMessage)
		}
		case false:
		{
			set_hudmessage(clr(g_eSettings[HUD_RED]), clr(g_eSettings[HUD_GREEN]), clr(g_eSettings[HUD_BLUE]),\
			g_eSettings[HUD_X], g_eSettings[HUD_Y], g_eSettings[HUD_EFFECTS], g_eSettings[HUD_FXTIME], g_eSettings[TIMER_SPEED])
			
			ShowSyncHudMsg(0, g_iObject, szMessage)
		}
	}
	
	if(!--g_iTimer)
	{
		remove_task(TASK_TIMER)
		
		if(g_eSettings[CHAT_MESSAGES])
			set_task(g_fSpeed, "StopMessage")
	}
}

public StopMessage()
	CC_SendMessage(0, "%L", LANG_PLAYER, "JBTIMER_TIMER_END")

public StopTimer()
{
	g_iTimer = 0
	remove_task(TASK_TIMER)
}

bool:has_access(id)
	return (g_eSettings[TIMER_FOR_ADMINS][0] && has_flag(id, g_eSettings[TIMER_FOR_ADMINS]))