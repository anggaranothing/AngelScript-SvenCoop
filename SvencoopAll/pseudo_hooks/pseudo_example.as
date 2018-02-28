#include "an_PseudoHooks"

// Stores hooks unique ID
// Use these to unhook/remove the hooks
string g_TestPTDKey;
string g_TestCUICKey;

void MapInit()
{
	RegisterPseudoHooksCallback( null );
}

// Test Pseudo Hooks Registry
CClientCommand CCCRegisterPseudoHooks( "hook", "hook", @RegisterPseudoHooksCallback );
void RegisterPseudoHooksCallback( const CCommand@ args )
{
	// Test PlayerPostTakeDamage
	g_PseudoHooks.RegisterHook( Hooks::Pseudo::Player::PlayerPostTakeDamage, 
								any( @TestPseudoPostTakeDamage ), 
								g_TestPTDKey );

	// Test ClientUserInfoChanged
	// Notices the last parameters
	// to listen specific Keyvalue
	g_PseudoHooks.RegisterHook( Hooks::Pseudo::Player::ClientUserInfoChanged, 
								any( @TestPseudoClientUserInfoChanged ), 
								g_TestCUICKey, 
								dictionary=
								{
									{ CUIC_ARG_KEY, "model" }
								} );
}

// Test Pseudo Hooks Removal
CClientCommand CCCRemovePseudoHooks( "unhook", "unhook", @RemovePseudoHooksCallback );
void RemovePseudoHooksCallback( const CCommand@ args )
{
	g_PseudoHooks.RemoveHook( Hooks::Pseudo::Player::PlayerPostTakeDamage, g_TestPTDKey );
	g_PseudoHooks.RemoveHook( Hooks::Pseudo::Player::ClientUserInfoChanged, g_TestCUICKey );
}
CClientCommand CCCRemoveAllPseudoHooks( "unhookall", "unhookall", @RemoveAllPseudoHooksCallback );
void RemoveAllPseudoHooksCallback( const CCommand@ args )
{
	g_PseudoHooks.RemoveHook( Hooks::Pseudo::Player::PlayerPostTakeDamage  );
	g_PseudoHooks.RemoveHook( Hooks::Pseudo::Player::ClientUserInfoChanged );
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

	g_PlayerFuncs.ClientPrint( @pVictim, HUD_PRINTCENTER, message );
	g_PlayerFuncs.ClientPrint( @pVictim, HUD_PRINTCONSOLE, "bitsTrigger: " + bitsTrigger+"\n" );

	return HOOK_CONTINUE;
}

HookReturnCode TestPseudoClientUserInfoChanged( KeyValueBuffer@ pKVB, const string &in szKey, const string &in szOldValue )
{
	// Prevent non-"gordon" player model
	if( szKey == "model" )
	{
		if( pKVB.GetValue("model") != "gordon" )
		{
			CBasePlayer@ pPlayer = cast<CBasePlayer>( g_EntityFuncs.Instance( pKVB.GetClient() ) );

			if( pPlayer !is null )
			{
				g_PlayerFuncs.ClientPrint( @pPlayer, HUD_PRINTCONSOLE, "Only model 'gordon' is allowed!\n" );

				// Override!
				pKVB.SetValue( szKey, "gordon" );
				return HOOK_HANDLED;
			}
		}
	}
	return HOOK_CONTINUE;
}
