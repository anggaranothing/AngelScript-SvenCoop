#include "an_PseudoHooks"

void MapInit()
{
	g_PseudoHooks.RegisterHook( Hooks::Pseudo::Player::PlayerPostTakeDamage, any( @TestPseudoPostTakeDamage ) );
}

HookReturnCode TestPseudoPostTakeDamage( CBasePlayer@ pVictim, edict_t@ pEdInflictor, edict_t@ pEdAttacker, const float flDamage, const int bitsDamageType, const uint bitsTrigger )
{
	// TEST TEST TEST TEST TEST
	string inflictor, attacker;

	// Inflictor ID
	inflictor = ( pEdInflictor !is null ? string( g_EngineFuncs.IndexOfEdict(pEdInflictor) ) : "NULL" );

	// Attacker ID
	attacker = ( pEdAttacker !is null ? string( g_EngineFuncs.IndexOfEdict(pEdAttacker) ) : "NULL" );

	string message;
	message += "\n\nHP: " + pVictim.pev.health;
	message += "\nArmor: " + pVictim.pev.armorvalue;
	message += "\nInflictor: " + inflictor;
	message += "\nAttacker: " + attacker;
	message += "\nflDamage: " + flDamage;
	message += "\nbitsDamageType: " + bitsDamageType;

	g_PlayerFuncs.ClientPrintAll( HUD_PRINTCENTER, message );
	g_PlayerFuncs.ClientPrintAll( HUD_PRINTCONSOLE, "bitsTrigger: " + bitsTrigger+"\n" );

	return HOOK_CONTINUE;
}
