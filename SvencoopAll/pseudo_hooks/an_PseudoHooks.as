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

#include "PseudoTakeDamage"
#include "PseudoClientUserInfoChanged"


enum PseudoHookExecuteReturn
{
	PseudoHookExecute_True = 1,
	PseudoHookExecute_False = 0,
	PseudoHookExecute_Continue = -1
}

enum PseudoHookRegisterReturn
{
	PseudoHookRegister_True = 1,
	PseudoHookRegister_False = 0
}


// Global Instance
CANModulePseudoHookManager g_PseudoHooks();


// Module Base Class
final class CANModulePseudoHookManager : PseudoTakeDamage, PseudoClientUserInfoChanged
{
	// Registered Hook(s)
	private dictionary m_dictHandler = {};

	CANModulePseudoHookManager()
	{
		Enable();
	}

	~CANModulePseudoHookManager()
	{
		Disable();
	}

	void Enable()
	{
		g_Hooks.RegisterHook( Hooks::Player::ClientDisconnect, ClientDisconnectHook( @this.Pseudo_ClientDisconnect ) );
		g_Hooks.RegisterHook( Hooks::Player::PlayerSpawn, PlayerSpawnHook( @this.Pseudo_PlayerSpawn ) );
		//g_Hooks.RegisterHook( Hooks::Player::PlayerKilled, PlayerKilledHook( @this.Pseudo_PlayerKilled ) );
		g_Hooks.RegisterHook( Hooks::Player::ClientPutInServer, ClientPutInServerHook( @this.Pseudo_ClientPutInServer ) );
		g_Hooks.RegisterHook( Hooks::Player::PlayerPreThink, PlayerPreThinkHook( @this.Pseudo_PreThink ) );

		g_Log.PrintF( "CANModulePseudoHookManager is Enabled!\n" );
	}

	void Disable()
	{
		g_Hooks.RemoveHook( Hooks::Player::ClientDisconnect, ClientDisconnectHook( @this.Pseudo_ClientDisconnect ) );
		g_Hooks.RemoveHook( Hooks::Player::PlayerSpawn, PlayerSpawnHook( @this.Pseudo_PlayerSpawn ) );
		//g_Hooks.RemoveHook( Hooks::Player::PlayerKilled, PlayerKilledHook( @this.Pseudo_PlayerKilled ) );
		g_Hooks.RemoveHook( Hooks::Player::ClientPutInServer, ClientPutInServerHook( @this.Pseudo_ClientPutInServer ) );
		g_Hooks.RemoveHook( Hooks::Player::PlayerPreThink, PlayerPreThinkHook( @this.Pseudo_PreThink ) );

		g_Log.PrintF( "CANModulePseudoHookManager is Disabled!\n" );
	}

	/**
	 * Registers a pseudo hook. Pass in a hook function or delegate using "any@" handle.
	 * Simple method.
	 *
	 * @param id		Hook ID.
	 * @param handle	Hook handle.
	 * @return			True if registered, false otherwise.
	 */
	bool RegisterHook( const uint id, any@ handle )
	{
		return RegisterHook( id, @handle, void, null );
	}

	/**
	 * Registers a pseudo hook. Pass in a hook function or delegate using "any@" handle.
	 * Main method.
	 *
	 * @param id		Hook ID.
	 * @param handle	Hook handle.
	 * @param key		String buffer to store hook key.
	 * @param args		Hook specific argument(s).
	 * @return			True if registered, false otherwise.
	 */
	bool RegisterHook( const uint id, any@ handle, string &out key, dictionary@ args = null )
	{
		if( handle is null )
		{
			g_Log.PrintF( "(PseudoHooks) Hook Handler is NULL (%1)\n", id );
			return false;
		}

		int rslt = 0;
		switch( id )
		{
			case Hooks::Pseudo::Player::ClientUserInfoChanged:
			{
				rslt = PseudoClientUserInfoChanged_Register( id, @args );
				if( rslt == PseudoHookRegister_False )
				{
					return false;
				}
				break;
			}
			default: break;
		}

		string szText, szFwKey, szIndex;
		// random key (ID)
		do
		{
			szIndex = Math.RandomLong( 0, Math.INT32_MAX );
			szFwKey = string(id) + " @ " + szIndex;
			if( !m_dictHandler.exists( szFwKey ) ) break;
		}
		while( true );
		
		key = szIndex;
		m_dictHandler.set( szFwKey, @handle );
		
		g_Log.PrintF( "(PseudoHooks) RegisterHook => %1\n", szFwKey );

		return true;
	}

	/**
	 * Removes all functions hooked into the given hook.
	 *
	 * @param id		Hook ID.
	 * @return			True if exists and removed, false otherwise.
	 */
	bool RemoveHook( const uint id )
	{
		bool result = false;
		array<string> keys = m_dictHandler.getKeys();
		string key, forward_name = string(id) + " @";

		for( uint i = 0; i < keys.length(); i++ )
		{
			key = keys[i];
			if( key.StartsWith( forward_name ) )
			{
				g_Log.PrintF( "(PseudoHooks) RemoveHook => %1\n", key );
				result = m_dictHandler.delete( key );
			}
		}

		return result;
	}

	/**
	 * Removes all functions hooked into the given hook.
	 *
	 * @param id		Hook ID.
	 * @param key		Hook unique register key.
	 * @return			True if exists and removed, false otherwise.
	 */
	bool RemoveHook( const uint id, string &in key )
	{
		// Prepare the key...
		key.Trim();

		// Not an integer?
		if( !isalnum(key) )
		{
			g_Log.PrintF( "(PseudoHooks) Hook key is not an integer! => %1\n", key );
			return false;
		}

		bool result = false;
		key = string(id) + " @ " + key;

		result = m_dictHandler.delete( key );

		if( result )
		{
			g_Log.PrintF( "(PseudoHooks) RemoveHook => %1\n", key );
		}
		else
		{
			g_Log.PrintF( "(PseudoHooks) Failed to remove hook! => %1\n", key );
		}

		return result;
	}

	private HookReturnCode Pseudo_ClientDisconnect( CBasePlayer@ pPlayer )
	{
		PseudoTakeDamage_Reset( @pPlayer, true );
		PseudoClientUserInfoChanged_Reset( @pPlayer, true );
		return HOOK_CONTINUE;
	}

	private HookReturnCode Pseudo_PlayerSpawn( CBasePlayer@ pPlayer )
	{
		PseudoTakeDamage_Reset( @pPlayer, false );
		return HOOK_CONTINUE;
	}

	// TODO : Need more conditions !
	/*private HookReturnCode Pseudo_PlayerKilled( CBasePlayer@ pPlayer, CBaseEntity@ pAttacker, int iGib )
	{
		PseudoTakeDamage_Reset( @pPlayer, false );
		return HOOK_CONTINUE;
	}*/

	private HookReturnCode Pseudo_ClientPutInServer( CBasePlayer@ pPlayer )
	{
		PseudoClientUserInfoChanged_Reset( @pPlayer, false );
		return HOOK_CONTINUE;
	}

	private HookReturnCode Pseudo_PreThink( CBasePlayer@ pPlayer, uint& out uiFlags )
	{
		PseudoTakeDamage_Listen( @pPlayer );
		PseudoClientUserInfoChanged_Listen( @pPlayer );
		return HOOK_CONTINUE;
	}

	private bool ExecutePseudoHook( const uint id, uint &out ret, dictionary@ parameters )
	{
		ret = HOOK_CONTINUE;
		uint total = 0;
		array<string> keys = m_dictHandler.getKeys();
		string key, forward_name = string(id) + " @";

		for( uint i = 0; i < keys.length(); i++ )
		{
			key = keys[i];
			if( key.StartsWith( forward_name ) )
			{
				any@ handle = null;

				if( m_dictHandler.get(key, @handle) )
				{
					if( handle is null )
						continue;

					/*
					 * TakeDamage Hooks
					*/
					if( id == Hooks::Pseudo::Player::PlayerPostTakeDamage )
					{
						int rslt = PseudoTakeDamage_Execute( key, @handle, @parameters, ret );

						if( rslt == PseudoHookExecute_False )
							return false;
						else
						if( rslt == PseudoHookExecute_Continue )
							continue;
					}

					/*
					 * ClientUserInfoChanged Hooks
					*/
					else
					if( id == Hooks::Pseudo::Player::ClientUserInfoChanged )
					{
						int rslt = PseudoClientUserInfoChanged_Execute( key, @handle, @parameters, ret );

						if( rslt == PseudoHookExecute_False )
							return false;
						else
						if( rslt == PseudoHookExecute_Continue )
							continue;
					}

					total++;
				}
			}
		}

		//g_Log.PrintF( "(ExecutePseudoHook) %1 total( %2 )\n", id, total );

		return true;
	}
}
