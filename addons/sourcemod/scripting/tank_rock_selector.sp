#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>
#include <colors>


public Plugin myinfo =
{
    name        = "Tank Rock Selector", // orig "Tank Attack Control"
    author      = "vintik, CanadaRox, Jacob, Visor",
    description = "",
    version     = "build_0000", // orig v0.7.2
    url         = "https://github.com/TouchMe-Inc/l4d2_tank_rock_selector"
}


#define L4D2Team_Infected 3
#define L4D2Infected_Tank 8

#define TANK_ROCK 48
#define THROW_ONE_HAND_OVERHAND 1
#define THROW_UNDERHAND 2
#define THROW_TWO_HAND_OVERHAND 3


ConVar g_cvBlockPunchRock = null;
ConVar g_cvBlockJumpRock = null;

int g_iQueuedThrow[MAXPLAYERS + 1] = {0, ...};

float g_fThrowQueuedAt[MAXPLAYERS + 1] = {0.0, ...};


public APLRes AskPluginLoad2(Handle myself, bool bLate, char[] sErr, int iErrLen)
{
    if (GetEngineVersion() != Engine_Left4Dead2)
    {
        strcopy(sErr, iErrLen, "Plugin only supports Left 4 Dead 2");
        return APLRes_SilentFailure;
    }

    return APLRes_Success;
}

public void OnPluginStart()
{
    LoadTranslations("tank_rock_selector.phrases");

    g_cvBlockPunchRock = CreateConVar("sm_block_punch_rock", "1", "Block tanks from punching and throwing a rock at the same time");
    g_cvBlockJumpRock = CreateConVar("sm_block_jump_rock", "0", "Block tanks from jumping and throwing a rock at the same time");

    HookEvent("tank_spawn", Event_TankSpawn);
}

void Event_TankSpawn(Event event, const char[] szEventName, bool dontBroadcast)
{
    int iTank = GetClientOfUserId(GetEventInt(event, "userid"));

    if (IsFakeClient(iTank)) {
        return;
    }

    PrintTankHelp(iTank);
}

public Action OnPlayerRunCmd(int iClient, int &iButtons, int &impulse, float vel[3], float angles[3], int &weapon)
{
    if (!IsClientInGame(iClient) || IsFakeClient(iClient)) {
        return Plugin_Continue;
    }

    //if iTank
    if (GetClientTeam(iClient) != L4D2Team_Infected || GetInfectedClass(iClient) != L4D2Infected_Tank) {
        return Plugin_Continue;
    }

    if ((iButtons & IN_JUMP) && ShouldCancelJump(iClient))
    {
        iButtons &= ~IN_JUMP;
    }

    if (iButtons & IN_RELOAD)
    {
        g_iQueuedThrow[iClient] = THROW_TWO_HAND_OVERHAND;
        iButtons |= IN_ATTACK2;
    }
    else if (iButtons & IN_USE)
    {
        g_iQueuedThrow[iClient] = THROW_UNDERHAND;
        iButtons |= IN_ATTACK2;
    }
    else
    {
        g_iQueuedThrow[iClient] = THROW_ONE_HAND_OVERHAND;
    }

    return Plugin_Continue;
}

public Action L4D_OnCThrowActivate(int iAbility)
{
    if (!IsValidEntity(iAbility))
    {
        LogMessage("Invalid 'ability_throw' index: %d. Continuing throwing.", iAbility);
        return Plugin_Continue;
    }

    int iClient = GetEntPropEnt(iAbility, Prop_Data, "m_hOwnerEntity");

    if ((GetClientButtons(iClient) & IN_ATTACK) && GetConVarBool(g_cvBlockPunchRock)) {
        return Plugin_Handled;
    }

    g_fThrowQueuedAt[iClient] = GetGameTime();

    return Plugin_Continue;
}

//throw sequences:
//48 - (not used unless tank_rock_overhead_percent is changed)

//49 - 1handed overhand (+attack2),
//50 - underhand (+use),
//51 - 2handed overhand (+reload)
public Action L4D2_OnSelectTankAttack(int iClient, int &sequence)
{
    if (sequence > TANK_ROCK && g_iQueuedThrow[iClient])
    {
        //rock throw
        sequence = g_iQueuedThrow[iClient] + TANK_ROCK;
        return Plugin_Handled;
    }

    return Plugin_Continue;
}

bool ShouldCancelJump(int iClient)
{
    if (!GetConVarBool(g_cvBlockJumpRock)) {
        return false;
    }

    return (1.5 > GetGameTime() - g_fThrowQueuedAt[iClient]);
}

void PrintTankHelp(int iClient)
{
    CPrintToChat(iClient, "%T%T", "BRACKET_START", iClient, "TAG", iClient);
    CPrintToChat(iClient, "%T%T", "BRACKET_MIDDLE", iClient, "HELP_ONE_HAND_OVERHAND", iClient);
    CPrintToChat(iClient, "%T%T", "BRACKET_MIDDLE", iClient, "HELP_UNDERHAND", iClient);
    CPrintToChat(iClient, "%T%T", "BRACKET_END", iClient, "HELP_TWO_HAND_OVERHAND", iClient);
}

/**
 * Gets the iClient L4D1/L4D2 zombie class id.
 *
 * @param iClient     Client index.
 * @return L4D1      1=SMOKER, 2=BOOMER, 3=HUNTER, 4=WITCH, 5=TANK, 6=NOT INFECTED
 * @return L4D2      1=SMOKER, 2=BOOMER, 3=HUNTER, 4=SPITTER, 5=JOCKEY, 6=CHARGER, 7=WITCH, 8=TANK, 9=NOT INFECTED
 */
int GetInfectedClass(int iClient) {
    return GetEntProp(iClient, Prop_Send, "m_zombieClass");
}
