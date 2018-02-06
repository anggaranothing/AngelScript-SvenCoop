/*
*
*	[Plugin] Semiclip
*
*/
const string	PLUGIN_VERSION	=	"1.1.2";
const string	PLUGIN_AUTHOR	=	"Anggara_nothing";
const string	PLUGIN_CONTACT	=	"forums.svencoop.com";
const bool	DEBUG_ENABLED	=	true;

// Config file dir
const string g_szCfgPath = "scripts/plugins/an_semiclip/disabled_maplist.cfg";

array<PlayerData@> g_pCachedPlayerData();
CCVar@ g_pCvarCrouchAdjustment;
CCVar@ g_pCvarAllowStacking;
bool   g_bIsEnabled = true;

void PluginInit()
{
	g_Module.ScriptInfo.SetAuthor( PLUGIN_AUTHOR );
	g_Module.ScriptInfo.SetContactInfo( PLUGIN_CONTACT );
	
	@g_pCvarAllowStacking = CCVar( "semiclip_allow_stacking", 1.0, "Enable/Disable player stacking on each other ", ConCommandFlag::AdminOnly );
	@g_pCvarCrouchAdjustment = CCVar( "semiclip_crouch", 39.f, "Calibrate crouch height distance for disable semiclip", ConCommandFlag::AdminOnly );
}

void MapInit()
{
	g_pCachedPlayerData.resize( 0 ); // remove them all
	g_pCachedPlayerData.resize( g_Engine.maxClients+1 );
	
	g_bIsEnabled = true;
	CheckForbiddenMapList();
	
	// Hooks
	if( g_bIsEnabled )
	{
		g_Hooks.RegisterHook( Hooks::Player::ClientDisconnect,	@HookClientDisconnect );
		g_Hooks.RegisterHook( Hooks::Player::PlayerSpawn,	@HookPlayerSpawn );
		g_Hooks.RegisterHook( Hooks::Player::ClientPutInServer,	@HookClientPutInServer );
		
		g_CustomEntityFuncs.RegisterCustomEntity( "CTriggerSemiclip", "trigger_semiclip" );
		
		g_Game.AlertMessage( at_logged, "\n\n\nPLUGIN: AN SEMICLIP\nVERSION: "+PLUGIN_VERSION+"\nis ACTIVATED!\n\n\n" );
	}
	else
	{
		g_Hooks.RemoveHook( Hooks::Player::ClientDisconnect,	@HookClientDisconnect );
		g_Hooks.RemoveHook( Hooks::Player::PlayerSpawn,	@HookPlayerSpawn );
		g_Hooks.RemoveHook( Hooks::Player::ClientPutInServer,	@HookClientPutInServer );
	}
}

void CheckForbiddenMapList()
{
	File@ pFile = g_FileSystem.OpenFile( g_szCfgPath, OpenFile::READ );
	
	if( pFile !is null && pFile.IsOpen() )
	{
		while( !pFile.EOFReached() )
		{
			string szReadln;
			pFile.ReadLine( szReadln );
			
			szReadln.Trim();
			szReadln.Replace( ".bsp", "", String::CompareType::CaseInsensitive );
			
			if( string(g_Engine.mapname).opEquals( szReadln ) )
			{
				g_bIsEnabled = false;
				break;
			}
		}
		pFile.Close();
	}
}

int PlayerIdToBit( const int playerId )
{
	return  ( 1<<( playerId&31 ) );
}

PlayerData@ GetPlayerData( CBaseEntity@ pPlayer )
{
	return GetPlayerData( pPlayer.entindex() );
}
PlayerData@ GetPlayerData( const int playerIndex )
{
	return g_pCachedPlayerData[ playerIndex ];
}

PlayerData@ CreatePlayerData( CBasePlayer@ pPlayer )
{
	// Assign a new player data
	@g_pCachedPlayerData[ pPlayer.entindex() ] = @PlayerData( @pPlayer );
	
	PrintDebugMessage( "PlayerData["+pPlayer.entindex()+"] created & assigned!" );
	
	return @g_pCachedPlayerData[ pPlayer.entindex() ];
}

// Destruct old data
HookReturnCode HookClientDisconnect( CBasePlayer@ pPlayer )
{
	int player_id = pPlayer.entindex();
	
	@g_pCachedPlayerData[ player_id ] = null;
	
	return HOOK_CONTINUE;
}

// Create new data
HookReturnCode HookClientPutInServer( CBasePlayer@ pPlayer )
{
	int player_id = pPlayer.entindex();
	
	PlayerData@ pData = CreatePlayerData( @pPlayer );
	if( pData is null )
	{
		PrintDebugMessage( "PlayerData["+player_id+"] can't be created!" );
		return HOOK_CONTINUE;
	}
	
	// Since pPlayer has spawned, we need to trigger PlayerSpawn hook manually here
	HookPlayerSpawn( pPlayer );
	
	return HOOK_CONTINUE;
}

HookReturnCode HookPlayerSpawn( CBasePlayer@ pPlayer )
{
	int player_id = pPlayer.entindex();
	
	PlayerData@ pData = GetPlayerData( @pPlayer );
	if( pData is null )
	{
		PrintDebugMessage( "Player [ID "+player_id+"] didn't have PlayerData!" );
		return HOOK_CONTINUE;
	}
	
	pData.SetPlayerSemiclip( false );
	pData.CreateTrigger();
	
	return HOOK_CONTINUE;
}

final class PlayerData
{
	private bool	m_bIsSemiclip;
	private int	m_iPlayerId;
	private EHandle m_hPlayer;
	private EHandle m_hTrigger;
	
	CBasePlayer@ PlayerEnt
	{
		get const	{ return cast<CBasePlayer@>( m_hPlayer.GetEntity() ); }
		set		{ m_hPlayer = EHandle( @value ); }
	}
	
	CBaseEntity@ TriggerEnt
	{
		get const	{ return m_hTrigger.GetEntity(); }
		set		{ m_hTrigger = EHandle( @value ); }
	}
	
	bool isSemiclipOn()
	{
		return m_bIsSemiclip;
	}
	
	// Constructor
	PlayerData( CBasePlayer@ pPlayer )
	{
		@this.PlayerEnt = @pPlayer;
		this.m_iPlayerId = pPlayer.entindex();
	}
	// Implement the destructor if explicit cleanup is needed
	~PlayerData()
    	{
		// Perform explicit cleanup here
		Destruct();
	}
	void Destruct()
	{
		DestroyTrigger();
		
		m_hPlayer = null;
		m_hTrigger = null;
		
		PrintDebugMessage( "PlayerData[" +m_iPlayerId+ "] has been destructed!" );
	}
	
	void SetPlayerSemiclip( bool turnOn = true )
	{
		int bits = 0;
		
		PrintDebugMessage( "PlayerData[" +m_iPlayerId+ "] Current pev_groupinfo: " + PlayerEnt.pev.groupinfo );
		
		if( turnOn )
		{
			m_bIsSemiclip = true;
			
			bits = PlayerIdToBit( m_iPlayerId );
		}
		else
		{
			m_bIsSemiclip = false;
		}
		
		// Set specific player bit into groupinfo
		PlayerEnt.pev.groupinfo = bits;
		
		PrintDebugMessage( "PlayerData[" +m_iPlayerId+ "] New pev_groupinfo: " + PlayerEnt.pev.groupinfo );
	}
	
	CBaseEntity@ CreateTrigger()
	{
		// Already spawned!
		if( m_hTrigger.IsValid() )
			return @TriggerEnt;
		
		@TriggerEnt = g_EntityFuncs.Create( "trigger_semiclip", PlayerEnt.pev.origin, g_vecZero, true );
		@TriggerEnt.pev.owner = @PlayerEnt.edict();
		g_EntityFuncs.DispatchKeyValue( TriggerEnt.edict(), "targetname", get_targetname() );
		g_EntityFuncs.DispatchSpawn( TriggerEnt.edict() );
		
		return @TriggerEnt;
	}
	
	void DestroyTrigger()
	{
		if( m_hTrigger.IsValid() )
			g_EntityFuncs.Remove( TriggerEnt );
	}

	private string get_targetname()
	{
		return "an_sm_" + m_iPlayerId;
	}
}

class CTriggerSemiclip : ScriptBaseEntity
{
	private Vector		m_vecMins, m_vecMaxs;
	private float		m_flLastTouch;
	
	CBaseEntity@ OwnerEnt
	{
		get const	{ return g_EntityFuncs.Instance( pev.owner ); }
	}
	
	bool KeyValue( const string& in szKey, const string& in szValue )
	{
		return BaseClass.KeyValue( szKey, szValue );
	}
	
	void Precache()
	{
		BaseClass.Precache();
		
		/**
		*	Here's hoping this model is never renamed or removed.
		*/
		g_Game.PrecacheModel( self, "models/player.mdl" );
		g_Game.PrecacheModel( self, "models/playert.mdl" );
	}
	
	void Spawn()
	{
		Precache();
		
		g_EntityFuncs.SetModel( self, "models/player.mdl" );
		
		//Save off so we can toggle later on.
		m_vecMins = pev.mins;
		m_vecMaxs = pev.maxs;
		
		Setup( true );
		
		//This must be done after setup because the engine will only insert this entity into the list of triggerable entities if it has a model.
		g_EntityFuncs.SetOrigin( self, pev.origin );
	}
	
	private void Setup( bool bOn )
	{
		if( bOn )
		{
			if( pev.owner !is null )
			{
				AttachToOwner();
				m_vecMins = VEC_DUCK_HULL_MIN; //VEC_HUMAN_HULL_MIN; //pev.owner.vars.mins;
				m_vecMaxs = VEC_HUMAN_HULL_MAX; //pev.owner.vars.maxs;
			}
			
			g_EntityFuncs.SetSize( pev, m_vecMins, m_vecMaxs );
			
			pev.solid = SOLID_TRIGGER;
			
			SetTouch( TouchFunction( this.CheckTouch ) );
			
			g_EntityFuncs.SetOrigin( self, pev.origin );
		}
		else
		{
			g_EntityFuncs.SetSize( pev, g_vecZero, g_vecZero );
			
			pev.solid = SOLID_NOT;
			
			SetTouch( null );
		}
	}
	
	void AttachToOwner()
	{
		@pev.owner		= @pev.owner;
		pev.movetype	= MOVETYPE_FOLLOW;
		@pev.aiment		= @pev.owner;
		//pev.solid		= SOLID_NOT;
		pev.effects		= EF_NODRAW; // ??
		//pev.modelindex	= 0;// server won't send down to clients if modelindex == 0
		pev.model		= string_t();
		pev.nextthink	= g_Engine.time + .1;
	}
	
	void CheckTouch( CBaseEntity@ pOther )
	{
		BaseClass.Touch( @pOther );
		
		if( !isAllowSemiclip( pOther ) )
			return;
		
		int playerId = pOther.entindex();
		PlayerData@ pPlayerData = GetPlayerData( playerId );
		if( pPlayerData is null )
		{
			PrintDebugMessage( "CTriggerSemiclip >> PlayerData["+playerId+"] is NULL!" );
			return;
		}
		
		m_flLastTouch = g_Engine.time + 0.2;
		
		if( !pPlayerData.isSemiclipOn() ) pPlayerData.SetPlayerSemiclip( true );
	}
	
	void Think()
	{
		BaseClass.Think();
		
		if( m_flLastTouch > 0.f && m_flLastTouch < g_Engine.time )
		{
			m_flLastTouch = 0.f;
			
			PlayerData@ pPlayerData = GetPlayerData( OwnerEnt );
			if( pPlayerData !is null )
			{
				pPlayerData.SetPlayerSemiclip( false );
			}
		}
		
		if( pev.solid != SOLID_NOT )
			pev.nextthink = g_Engine.time + 0.1;
	}
	
	bool isAllowSemiclip( CBaseEntity@ pOther )
	{
		return ( pOther !is null && pev.owner !is null
		&& pOther.IsPlayer() && pOther.edict() !is pev.owner
		&& pev.owner.vars.deadflag == DEAD_NO && pOther.pev.deadflag == DEAD_NO 
		&& ( isOnLadder( pOther ) || !isStacking( pOther ) )
		);
	}
	
	bool isStacking( CBaseEntity@ pOther )
	{
		return g_pCvarAllowStacking.GetInt() > 0 && ( pev.owner.vars.groundentity is pOther.edict() || pOther.pev.groundentity is pev.owner || fabs(pev.owner.vars.origin.z - pOther.pev.origin.z) >= g_pCvarCrouchAdjustment.GetFloat() );
	}
	
	bool isOnLadder( CBaseEntity@ pOther )
	{
		CBasePlayer@ pPlayerOwner = cast<CBasePlayer@>( @OwnerEnt );
		CBasePlayer@ pPlayerOther = cast<CBasePlayer@>( @pOther );
		
		return ( pPlayerOwner !is null && pPlayerOwner.IsOnLadder() ) || ( pPlayerOther !is null && pPlayerOther.IsOnLadder() );
	}
}

float fabs(float x)
{
	return ((x) > 0 ? (x) : 0 - (x));
}
void PrintDebugMessage( const string &in messages )
{
	if( DEBUG_ENABLED == false ) return;
	
	g_Game.AlertMessage( at_console, messages + "\n" );
}
