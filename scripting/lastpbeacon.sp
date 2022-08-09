#include <sdkhooks>
#include <sdktools>
#include <sourcemod>
#include <cstrike>

#pragma dynamic 0
#pragma newdecls required
#pragma semicolon 1

#define WHITE x01
#define DARKRED x02
#define PURPLE x03
#define GREEN x04
#define MOSSGREEN x05
#define LIMEGREEN x06
#define RED x07
#define GRAY x08
#define YELLOW x10
#define LIGHTYELLOW x09
#define DARKGREY x0A
#define BLUE x0B
#define DARKBLUE x0C
#define LIGHTBLUE x0D
#define PINK x0E
#define LIGHTRED x0F

bool g_wasBeaconed[MAXPLAYERS+1];

public Plugin myinfo =
{
	name = "lastpbeacon",
	author = "Audite",
	description = "HNS Easyblock, if there is last terrorist then activate a beacon on client.",
	version = "1.0.5",
	url = "https://github.com/Leakoni/lastpbeacon"
};

public void OnAllPluginsLoaded(){

	if(!CommandExists("sm_beacon")){
		ThrowError("funcommands.smx was not found. Beacon for last player wont be activated.");
	}

}

public void OnPluginStart()
{

	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("round_end", Event_RoundEnd);

}

public APLRes AskPluginLoad2(Handle hMySelf, bool bLate, char[] szError, int iLength)
{
	if (GetEngineVersion() != Engine_CSGO)
	{
		strcopy(szError, iLength, "This plugin works only on CS:GO.");

		return APLRes_SilentFailure;
	}

	return APLRes_Success;
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast){
	for (int i = 1; i <= MaxClients; i++)
	{
		// Skip bots or non connected indexes.
		if (!IsClientConnected(i) || IsFakeClient(i))
			continue;

		if(IsPlayerAlive(i)){
			int client = GetClientUserId(i);

			if(g_wasBeaconed[client]){
				g_wasBeaconed[client] = false;
			}
		}


	}
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast){

	int iTAlive = 0;
	int iCTAlive = 0;
	int lastTId;

	for (int i = 1; i <= MaxClients; i++)
	{
		int iTeam;

		// Skip bots or non connected indexes.
		if (!IsClientConnected(i) || IsFakeClient(i))
			continue;

		iTeam = GetClientTeam(i);
		if(iTeam == CS_TEAM_CT){
			if(IsPlayerAlive(i)){
				iCTAlive++;
			}
		} else if(iTeam == CS_TEAM_T){
			if(IsPlayerAlive(i)){
				iTAlive++;
				lastTId = i;
			}
		}
	}

	if(iTAlive == 1 && iCTAlive >= 1 && !g_wasBeaconed[GetClientUserId(lastTId)]){
		int client = GetClientUserId(lastTId);
		g_wasBeaconed[client] = true;
		ServerCommand("sm_beacon #%d", client);
		PrintToChatAll("\x01[\x0CONIPLAY\x01]\x01 Beacon var aktiverad för sista terroristen!");
	}
}