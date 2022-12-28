#include <sdkhooks>
#include <sdktools>
#include <sourcemod>
#include <cstrike>
#include <colors_csgo>

#pragma dynamic 0
#pragma newdecls required
#pragma semicolon 1

// VERSION
#define VERSION "1.0.8"

// CONVARS
ConVar g_hLPBEnable;

// BOOLS
bool g_bWasBeaconed[MAXPLAYERS+1];

// BEACON
ConVar g_Cvar_BeaconRadius;
char g_BlipSound[PLATFORM_MAX_PATH];
int g_BeaconSerial[MAXPLAYERS+1] = { 0, ... };
int g_BeamSprite = -1;
int g_HaloSprite = -1;
int g_ExternalBeaconColor[4];
int g_Team1BeaconColor[4];
int g_Team2BeaconColor[4];
int g_Team3BeaconColor[4];
int g_Team4BeaconColor[4];
int g_TeamUnknownBeaconColor[4];
int g_Serial_Gen = 0;

#define DEFAULT_TIMER_FLAGS TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE

public Plugin myinfo =
{
	name = "lastpbeacon",
	author = "Audite",
	description = "HNS Easyblock, if there is last terrorist then activate a beacon on client.",
	version = VERSION,
	url = "https://github.com/Leakoni/lastpbeacon"
};

public void OnPluginStart()
{

	LoadTranslations("common.phrases");
	LoadTranslations("funcommands.phrases");
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("round_end", Event_RoundEnd);
	CreateConVar("lpb_version", VERSION, "Last Person Beacon Plugin Version", FCVAR_NOTIFY|FCVAR_DONTRECORD|FCVAR_SPONLY);
	RegAdminCmd("sm_obeacon", Command_Beacon, ADMFLAG_SLAY, "sm_obeacon <#userid|name> [0/1]");
	g_Cvar_BeaconRadius = CreateConVar("sm_beacon_radius", "375", "Sets the radius for beacon's light rings.", 0, true, 50.0, true, 1500.0);
	g_hLPBEnable = CreateConVar("lpb_enable", "1", "Enable the Last Person Beacon", FCVAR_NOTIFY);

}

public void OnMapStart()
{
	GameData gameConfig = new GameData("funcommands.games");
	if (gameConfig == null)
	{
		SetFailState("Unable to load game config funcommands.games");
		return;
	}
	if (gameConfig.GetKeyValue("SoundBlip", g_BlipSound, sizeof(g_BlipSound)) && g_BlipSound[0])
	{
		PrecacheSound(g_BlipSound, true);
	}
	char buffer[PLATFORM_MAX_PATH];

	if (gameConfig.GetKeyValue("SpriteBeam", buffer, sizeof(buffer)) && buffer[0])
	{
		g_BeamSprite = PrecacheModel(buffer);
	}
	
	if (gameConfig.GetKeyValue("SpriteHalo", buffer, sizeof(buffer)) && buffer[0])
	{
		g_HaloSprite = PrecacheModel(buffer);
	}
	
	if (gameConfig.GetKeyValue("ExternalBeaconColor", buffer, sizeof(buffer)) && buffer[0])
	{
		g_ExternalBeaconColor = ParseColor(buffer);
	}
	
	if (gameConfig.GetKeyValue("Team1BeaconColor", buffer, sizeof(buffer)) && buffer[0])
	{
		g_Team1BeaconColor = ParseColor(buffer);
	}
	
	if (gameConfig.GetKeyValue("Team2BeaconColor", buffer, sizeof(buffer)) && buffer[0])
	{
		g_Team2BeaconColor = ParseColor(buffer);
	}
	
	if (gameConfig.GetKeyValue("Team3BeaconColor", buffer, sizeof(buffer)) && buffer[0])
	{
		g_Team3BeaconColor = ParseColor(buffer);
	}
	
	if (gameConfig.GetKeyValue("Team4BeaconColor", buffer, sizeof(buffer)) && buffer[0])
	{
		g_Team4BeaconColor = ParseColor(buffer);
	}
	
	if (gameConfig.GetKeyValue("TeamUnknownBeaconColor", buffer, sizeof(buffer)) && buffer[0])
	{
		g_TeamUnknownBeaconColor = ParseColor(buffer);
	}
	
	delete gameConfig;
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

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast){

	if(g_hLPBEnable.BoolValue){

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

		if(iTAlive == 1 && iCTAlive >= 1 && !g_bWasBeaconed[lastTId]){
			g_bWasBeaconed[lastTId] = true;
			CreateBeacon(lastTId);
			PrintToChatAll("\x01[\x0CONIPLAY\x01]\x01 %sBeacon was activated for last terrorist!", Color_Lightgreen);
		}

	}

}

public void OnMapEnd()
{
	KillAllBeacons();
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	KillAllBeacons();

	return Plugin_Continue;
}

void CreateBeacon(int client)
{
	g_BeaconSerial[client] = ++g_Serial_Gen;
	CreateTimer(3.0, Timer_Beacon, client | (g_Serial_Gen << 7), DEFAULT_TIMER_FLAGS);	
}

void KillBeacon(int client)
{
	g_BeaconSerial[client] = 0;

	if (IsClientInGame(client))
	{
		SetEntityRenderColor(client, 255, 255, 255, 255);
	}
}

void KillAllBeacons()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		KillBeacon(i);
		g_bWasBeaconed[i] = false;
	}
}

void PerformBeacon(int client, int target)
{
	if (g_BeaconSerial[target] == 0)
	{
		CreateBeacon(target);
		LogAction(client, target, "\"%L\" set a obeacon on \"%L\"", client, target);
	}
	else
	{
		KillBeacon(target);
		LogAction(client, target, "\"%L\" removed a obeacon on \"%L\"", client, target);
	}
}

public Action Timer_Beacon(Handle timer, any value)
{
	int client = value & 0x7f;
	int serial = value >> 7;

	if (!IsClientInGame(client)
		|| !IsPlayerAlive(client)
		|| g_BeaconSerial[client] != serial)
	{
		KillBeacon(client);
		return Plugin_Stop;
	}

	float vec[3];
	GetClientAbsOrigin(client, vec);
	vec[2] += 10;
	
	if (g_BeamSprite > -1 && g_HaloSprite > -1)
	{
		int teamBeaconColor[4];

		switch (GetClientTeam(client))
		{
			case 1: teamBeaconColor = g_Team1BeaconColor;
			case 2: teamBeaconColor = g_Team2BeaconColor;
			case 3: teamBeaconColor = g_Team3BeaconColor;
			case 4: teamBeaconColor = g_Team4BeaconColor;
			default: teamBeaconColor = g_TeamUnknownBeaconColor;
		}

		TE_SetupBeamRingPoint(vec, 10.0, g_Cvar_BeaconRadius.FloatValue, g_BeamSprite, g_HaloSprite, 0, 10, 0.6, 10.0, 0.5, teamBeaconColor, 10, 0);
		TE_SendToAll();
	}
	
	if (g_BlipSound[0])
	{
		GetClientEyePosition(client, vec);
		EmitAmbientSound(g_BlipSound, vec, client, SNDLEVEL_RAIDSIREN);	
	}
		
	return Plugin_Continue;
}

public Action Command_Beacon(int client, int args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_obeacon <#userid|name>");
		return Plugin_Handled;
	}

	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));

	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	
	if ((target_count = ProcessTargetString(
			arg,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_ALIVE,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	for (int i = 0; i < target_count; i++)
	{
		PerformBeacon(client, target_list[i]);
	}
	
	if (tn_is_ml)
	{
		ShowActivity2(client, "[SM] ", "%t", "Toggled obeacon on target", target_name);
	}
	else
	{
		ShowActivity2(client, "[SM] ", "%t", "Toggled obeacon on target", "_s", target_name);
	}
	
	return Plugin_Handled;
}

int[] ParseColor(const char[] buffer)
{
	char sColor[16][4];
	ExplodeString(buffer, ",", sColor, sizeof(sColor), sizeof(sColor[]));
	
	int iColor[4];
	iColor[0] = StringToInt(sColor[0]);
	iColor[1] = StringToInt(sColor[1]);
	iColor[2] = StringToInt(sColor[2]);
	iColor[3] = StringToInt(sColor[3]);

	return iColor;
}