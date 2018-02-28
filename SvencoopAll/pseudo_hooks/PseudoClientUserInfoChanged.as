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
	const uint ClientUserInfoChanged	= 110; 
}
}
}


// ClientUserInfoChanged Consts
const string CUIC_ARG_KEY	= "key";


/**
 * Hooks::Pseudo::Player::ClientUserInfoChanged.
 * Called when Player's ClientUserInfoChanged is predicted (Post).
 * To override the new value, simply pKVB.SetValue( szKey,value ) and return HOOK_HANDLED.
 *
 * Signature :
 * HookReturnCode Function( KeyValueBuffer@ pKVB, const string &in szKey, const string &in szOldValue )
 *
 * @param pKVB				Player's KeyValueBuffer handle.
 * @param szKey				User info key.
 * @param szOldValue		Old value.
 * @return					Return HOOK_HANDLED to tells the hook is overridden the value.
 */
funcdef HookReturnCode PseudoPlayerClientUserInfoChangedHook( KeyValueBuffer@, const string &in, const string &in );


mixin class PseudoClientUserInfoChanged
{
	// ClientUserInfoChanged
	private bool[] blCUICReadyToListen(g_Engine.maxClients+1, false);
	private dictionary dictOldUserInfo = {};

	private int PseudoClientUserInfoChanged_Register( const uint id, dictionary@ args )
	{
		if( args is null )
		{
			g_Log.PrintF( "(PseudoHooks) Hook Arguments is NULL (%1)", id );
			return PseudoHookRegister_False;
		}
		
		string keyvalue;
		if( !args.get(CUIC_ARG_KEY, keyvalue) )
		{
			g_Log.PrintF( "(PseudoHooks) Hook Arguments is MISMATCH(ES) (%1)", id );
			return PseudoHookRegister_False;
		}

		// OK, insert new key to listen here...
		if( !dictOldUserInfo.exists(keyvalue) )
			dictOldUserInfo.set( keyvalue , @array<string>(g_Engine.maxClients+1,string()) );

		return PseudoHookRegister_True;
	}

	private void PseudoClientUserInfoChanged_Reset( CBasePlayer@ pPlayer, const bool disconnect )
	{
		// Invalid player
		if( pPlayer is null )
			return;

		int index = pPlayer.entindex();

		blCUICReadyToListen[index] = false;

		array<string> keys = dictOldUserInfo.getKeys();
		array<string>@ values = null;
		string key;
		for( uint i = 0; i < keys.length(); i++ )
		{
			key = keys[i];

			if( !dictOldUserInfo.get( key,@values ) )
				continue;

			// Assign new value
			values[index] = string();
			if( !disconnect )
			{
				KeyValueBuffer@ kvb = g_EngineFuncs.GetInfoKeyBuffer( pPlayer.edict() );
				if( kvb !is null )
				{
					values[index] = kvb.GetValue( key );
				}
			}

			// No need to set, pointer will handles of it :v
			//dictOldUserInfo.set( key,@values );
		}

		if( !disconnect ) blCUICReadyToListen[index] = true;
	}

	private bool PseudoClientUserInfoChanged_Listen( CBasePlayer@ pPlayer )
	{
		// Invalid player
		if( pPlayer is null )
			return false;

		int index = pPlayer.entindex();

		// Not ready
		if( !blCUICReadyToListen[index] )
			return false;

		// Relax, execute one at a time...
		blCUICReadyToListen[index] = false;

		array<string> keys = dictOldUserInfo.getKeys();
		array<string>@ values = null;
		string key;
		for( uint i = 0; i < keys.length(); i++ )
		{
			key = keys[i];

			if( !dictOldUserInfo.get( key,@values ) )
				continue;

			KeyValueBuffer@ kvb = g_EngineFuncs.GetInfoKeyBuffer( pPlayer.edict() );
			if( kvb is null )
				continue;

			string oldValue = values[index], newValue = kvb.GetValue( key );
			if( values[index] != newValue )
			{
				// Update new value
				values[index] = newValue;

				uint result = HOOK_CONTINUE;
				ExecutePseudoHook( Hooks::Pseudo::Player::ClientUserInfoChanged, result, 
					dictionary={ 
						{'pKVB',@kvb}, 
						{'szKey',key}, 
						{'szOldValue',oldValue}
					} 
				);

				// One of the registered hooks tells value is changed
				if( result >= HOOK_HANDLED )
				{
					// Re-assign again
					values[index] = kvb.GetValue( key );
				}

				// No need to set, pointer will handles of it :v
				//dictOldUserInfo.set( key,@values );
			}
		}

		// OK, i'm ready for it...
		blCUICReadyToListen[index] = true;

		return true;
	}

	private int PseudoClientUserInfoChanged_Execute( const string &in key, any@ handle, dictionary@ parameters, uint &out ret )
	{
		PseudoPlayerClientUserInfoChangedHook@ fwd;
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

		KeyValueBuffer@ pKVB; string szKey, szOldValue;
		if( !parameters.get('pKVB',@pKVB)
			|| !parameters.get('szKey',szKey)
			|| !parameters.get('szOldValue',szOldValue) )
		{
			g_Log.PrintF( "(ExecutePseudoHook) Parameter(s) Mismatch(es) (%1)\n", key );
			return PseudoHookExecute_Continue;
		}

		ret = fwd( @pKVB, szKey, szOldValue );
		return PseudoHookExecute_True;
	}
}
