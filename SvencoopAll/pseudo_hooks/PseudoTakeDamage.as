/**
 * [UTILITY] PseudoHooks
 *
 * An Angelscript library to emulate some essential event hooks that is not exposed yet in Sven Co-op.
 *
 *
 * Note :
 * This is NOT 100% ACCURATE, built-in hooks always doing the jobs better.
 *
 *
 *
 * Author : Anggara_nothing
 */


// Hook Indexes
namespace Hooks
{
namespace Pseudo
{
namespace Player
{
	const uint PlayerPostTakeDamage		= 100;
}
}
}


// TakeDamage Consts
enum PseudoTakeDamageTriggerFlags
{
	TAKEDAMAGE_ARMOR			= (1 << 0),
	TAKEDAMAGE_HEALTH			= (1 << 1),
	TAKEDAMAGE_DMG_TAKE			= (1 << 2),
	TAKEDAMAGE_DMG_INFLICTOR	= (1 << 3),
	TAKEDAMAGE_DMG_AMOUNT		= (1 << 4),
	TAKEDAMAGE_DMG_TYPE			= (1 << 5)
};


/**
 * Hooks::Pseudo::Player::PlayerPostTakeDamage.
 * Called when Player's TakeDamage is predicted (Post).
 *
 * Signature :
 * HookReturnCode Function( CBasePlayer@ pVictim, edict_t@ pEdInflictor, edict_t@ pEdAttacker, const float flDamage, const int bitsDamageType, const uint bitsTrigger )
 *
 * @param pVictim			Victim's CBasePlayer handle.
 * @param pEdInflictor		Inflictor's edict.
 * @param pEdAttacker		Attacker's edict.
 * @param flDamage			Damage amount.
 * @param bitsDamageType	Damage type bitflags.
 * @param bitsTrigger		Hook trigger bitflags that called this hook.
 * @return					Return value is ignored.
 */
funcdef HookReturnCode PseudoPlayerPostTakeDamageHook( CBasePlayer@, edict_t@, edict_t@, const float, const int, const uint );


mixin class PseudoTakeDamage
{
	// TakeDamage
	private bool[] blTDReadyToListen(g_Engine.maxClients+1, false);
	private float[] flLastArmor(g_Engine.maxClients+1, 0);
	private float[] flLastHealth(g_Engine.maxClients+1, 0);
	private float[] flLastDmgTake(g_Engine.maxClients+1, 0);
	private edict_t@[] pLastDmgInflictor(g_Engine.maxClients+1, null);
	private int[] iLastPlayerDamageAmount(g_Engine.maxClients+1, 0);
	private int[] iLastBitsDamageType(g_Engine.maxClients+1, 0);

	private void PseudoTakeDamage_Reset( CBasePlayer@ pPlayer, const bool disconnect )
	{
		// Invalid player
		if( pPlayer is null )
			return;

		int index = pPlayer.entindex();

		blTDReadyToListen[index] = false;

		// Assign new value
		flLastArmor[index]				= ( disconnect ? 0 : int( pPlayer.pev.armorvalue ) );
		flLastHealth[index]				= ( disconnect ? 0 : pPlayer.pev.health );
		flLastDmgTake[index]			= ( disconnect ? 0 : pPlayer.pev.dmg_take );
		@pLastDmgInflictor[index]		= ( disconnect ? null : @pPlayer.pev.dmg_inflictor );
		iLastPlayerDamageAmount[index]	= ( disconnect ? 0 : pPlayer.m_lastPlayerDamageAmount );
		iLastBitsDamageType[index]		= ( disconnect ? 0 : pPlayer.m_bitsDamageType );

		if( !disconnect ) blTDReadyToListen[index] = true;
	}

	private bool PseudoTakeDamage_Listen( CBasePlayer@ pPlayer )
	{
		// Invalid player
		if( pPlayer is null )
			return false;

		int index = pPlayer.entindex();

		// Not ready
		if( !blTDReadyToListen[index] )
			return false;

		uint needExecute = 0;

		// BUGFIX :	Armor value is not a whole number, and rounded later,
		//			this caused double forward calls.
		//			Don't asks me why, asks them (SC Developers). :v
		// Different armor at last time
		if( flLastArmor[index] != int( pPlayer.pev.armorvalue ) )
		{
			// Store old armor to check
			float oldArmor = flLastArmor[index];

			// Assign new value
			flLastArmor[index] = int( pPlayer.pev.armorvalue );

			// Decrement?
			if( oldArmor > flLastArmor[index] )
			{
				// Tells them
				needExecute |= TAKEDAMAGE_ARMOR;

				g_Game.AlertMessage( at_aiconsole, "(PseudoTakeDamage) Triggered By : Armor (%1)\n", flLastArmor[index] );
			}
		}
		// Same value, ignore...

		// Different health at last time?
		if( flLastHealth[index] != pPlayer.pev.health )
		{
			// Store old health to check
			float oldHealth = flLastHealth[index];

			// Assign new value
			flLastHealth[index] = pPlayer.pev.health;

			// Decrement
			if( oldHealth > flLastHealth[index] )
			{
				// Tells them
				needExecute |= TAKEDAMAGE_HEALTH;

				g_Game.AlertMessage( at_aiconsole, "(PseudoTakeDamage) Triggered By : Health (%1)\n", flLastHealth[index] );
			}
		}
		// Same value, ignore...

		// TODO : Not effective!
		// Different dmg_take at last time
		if( flLastDmgTake[index] != pPlayer.pev.dmg_take )
		{
			// Assign new value
			flLastDmgTake[index] = pPlayer.pev.dmg_take;

			// Positive non-zero?
			if( flLastDmgTake[index] > 0.f )
			{
				// Tells them
				needExecute |= TAKEDAMAGE_DMG_TAKE;

				g_Game.AlertMessage( at_aiconsole, "(PseudoTakeDamage) Triggered By : dmg_take (%1)\n", flLastDmgTake[index] );
			}
		}
		// Same value, ignore...

		// Different inflictor at last time?
		if( @pLastDmgInflictor[index] !is @pPlayer.pev.dmg_inflictor )
		{
			// Assign new value
			@pLastDmgInflictor[index] = @pPlayer.pev.dmg_inflictor;

			// Valid inflictor?
			if( pLastDmgInflictor[index] !is null )
			{
				// Tells them
				needExecute |= TAKEDAMAGE_DMG_INFLICTOR;

				g_Game.AlertMessage( at_aiconsole, "(PseudoTakeDamage) Triggered By : dmg_inflictor\n" );
			}
		}
		// Same value, ignore...

		// Different dmg_value at last time?
		if( iLastPlayerDamageAmount[index] != pPlayer.m_lastPlayerDamageAmount )
		{
			// Assign new value
			iLastPlayerDamageAmount[index] = pPlayer.m_lastPlayerDamageAmount;

			// Positive damage?
			if( iLastPlayerDamageAmount[index] >= 0 )
			{
				// Tells them
				needExecute |= TAKEDAMAGE_DMG_AMOUNT;

				g_Game.AlertMessage( at_aiconsole, "(PseudoTakeDamage) Triggered By : m_lastPlayerDamageAmount (%1)\n", iLastPlayerDamageAmount[index] );
			}
		}
		// Same value, ignore...

		// Different dmg_type at last time?
		if( iLastBitsDamageType[index] != pPlayer.m_bitsDamageType )
		{
			// This means DMG_GENERIC will NOT trigger this
			// Positive non-zero?
			if( pPlayer.m_bitsDamageType > 0 )
			{
				// Assign new value
				iLastBitsDamageType[index] = pPlayer.m_bitsDamageType;

				// Tells them
				needExecute |= TAKEDAMAGE_DMG_TYPE;

				g_Game.AlertMessage( at_aiconsole, "(PseudoTakeDamage) Triggered By : m_bitsDamageType (%1)\n", iLastBitsDamageType[index] );
			}
		}
		// Same value, ignore...
		
		// Nothing changed?
		if( needExecute == 0 )
			return false;

		// If this damage is using projectile mechanism (not hitscan),
		// Mostly, owner of the projectile is the attacker
		// Otherwise, attacker is the inflictor
		// If not, well, good luck to find it out by yourself :v
		edict_t@ pDmgAttacker = @pLastDmgInflictor[index];
		if( pLastDmgInflictor[index] !is null && pLastDmgInflictor[index].vars.owner !is null )
		{
			@pDmgAttacker = @pLastDmgInflictor[index].vars.owner;
		}

		ExecutePseudoHook( Hooks::Pseudo::Player::PlayerPostTakeDamage, void, 
			dictionary={ 
				{'pVictim',@pPlayer}, 
				{'pEdInflictor',@pLastDmgInflictor[index]}, 
				{'pEdAttacker',@pDmgAttacker}, 
				{'flDamage',float(iLastPlayerDamageAmount[index])}, 
				{'bitsDamageType',iLastBitsDamageType[index]}, 
				{'bitsTrigger',needExecute} 
			} 
		);

		return true;
	}

	private int PseudoTakeDamage_Execute( const string &in key, any@ handle, dictionary@ parameters, uint &out ret )
	{
		PseudoPlayerPostTakeDamageHook@ fwd;
		if( !handle.retrieve( @fwd ) )
		{
			g_Log.PrintF( "(ExecutePseudoHook) FAILED (%1)\n", key );
			return PseudoHookExecute_False;
		}

		if( fwd is null )
		{
			g_Log.PrintF( "(ExecutePseudoHook) Forward is NULL (%1)\n", key );
			return PseudoHookExecute_Continue;
		}

		if( parameters is null )
		{
			g_Log.PrintF( "(ExecutePseudoHook) Parameter(s) is NULL (%1)\n",  key );
			return PseudoHookExecute_Continue;
		}

		CBasePlayer@ pVictim; edict_t@ pEdInflictor; edict_t@ pEdAttacker; float flDamage; int bitsDamageType; uint bitsTrigger;
		if( !parameters.get('pVictim',@pVictim)
			|| !parameters.get('pEdInflictor',@pEdInflictor)
			|| !parameters.get('pEdAttacker',@pEdAttacker)
			|| !parameters.get('flDamage',flDamage)
			|| !parameters.get('bitsDamageType',bitsDamageType)
			|| !parameters.get('bitsTrigger',bitsTrigger) )
		{
			g_Log.PrintF( "(ExecutePseudoHook) Parameter(s) Mismatch(es) (%1)\n", key );
			return PseudoHookExecute_Continue;
		}

		ret = fwd( @pVictim, @pEdInflictor, @pEdAttacker, flDamage, bitsDamageType, bitsTrigger );
		return PseudoHookExecute_True;
	}
}
