/*
	env_automaker

	This entities accept all keyvalues,
	transfered to spawned monster(s) and env_xenmaker,
	env_xenmaker spawnflags always 1+2 ('Try Once' and 'No Spawn')
	
	env_automaker special keyvalues :
	delay               ==> delay each spawn
	m_imaxlivechildren  ==> max. childrens
	m_bfreewhendead     ==> free a slot as soon as the monster dead, 1 for true _ 0 for false
*/

/* Remove this comment line to use this script directly as mapscript
void MapInit()
{
	PrecacheXenMaker();
	RegisterEnvAutoMaker();
}*/

void RegisterEnvAutoMaker()
{
	//test
	//g_Game.PrecacheModel( "models/vhe-models/trigger_camera.mdl" );
	g_Game.PrecacheMonster( "monster_zombie", false );
	//test

	g_CustomEntityFuncs.RegisterCustomEntity( "env_automaker", "env_automaker" );
}

void PrecacheXenMaker()
{
	// precache xenmaker
	g_SoundSystem.PrecacheSound( "debris/beamstart7.wav" );
	g_SoundSystem.PrecacheSound( "debris/beamstart2.wav" );
	g_Game.PrecacheModel( "sprites/lgtning.spr" );
	g_Game.PrecacheModel( "sprites/fexplo1.spr" );
	g_Game.PrecacheModel( "sprites/xflare1.spr" );
}

const uint  MAX_LOOP_SAFETY  =  10001;
const float COORD_RANDOM_MIN =   -128;
const float COORD_RANDOM_MAX =    128;

final class env_automaker : ScriptBaseEntity
{
	private CScheduledFunction@	m_PlayerScanTimer = null;
	private EHandle[] m_hChildrens;
	
	private string m_szWorldModel = "models/vhe-models/trigger_camera.mdl";
	dictionary m_dictKV = 
	{// Default configs
		//{ "spawnflags",			string(1) },
		{ "monstertype",		"monster_zombie" },
		{ "delay",				string(1) },
		{ "m_imaxlivechildren",	string(4) },
		{ "m_bfreewhendead",    string(1) }
	};

	bool KeyValue( const string& in szKey, const string& in szValue )
	{
		// make sure the value is a string
		m_dictKV.set( szKey, string(szValue) );

		// calls baseclass method for applying other kvs (effects, rendermode, etc.)
		BaseClass.KeyValue( szKey, szValue );
		return true; // always true
	}

	void Precache()
	{
		BaseClass.Precache();

		g_Game.PrecacheModel( self, m_szWorldModel );

		// precache the monster
		if( m_dictKV.exists( "monstertype" ) )
			g_Game.PrecacheMonster( string( m_dictKV["monstertype"] ), false );

		// precache xenmaker
		g_SoundSystem.PrecacheSound( "debris/beamstart7.wav" );
		g_SoundSystem.PrecacheSound( "debris/beamstart2.wav" );
		g_Game.PrecacheModel( "sprites/lgtning.spr" );
		g_Game.PrecacheModel( "sprites/fexplo1.spr" );
		g_Game.PrecacheModel( "sprites/xflare1.spr" );
	}

	void Spawn()
	{
		Precache();

		self.pev.solid    = SOLID_NOT;
		self.pev.movetype = MOVETYPE_NONE;

		//g_EntityFuncs.SetModel(self, m_szWorldModel);
		g_EntityFuncs.SetSize(self.pev, g_vecZero,g_vecZero);

		self.pev.flags    |= FL_NOTARGET;

		// Default configs
		self.pev.gamestate = 1; // on/off toggle
		self.pev.framerate = 3; // delay
		self.pev.impulse   = 1; // m_imaxlivechildren
		self.pev.watertype = 1; // m_bfreewhendead

		// Assign configs
		if( m_dictKV.exists( "delay" ) )
		{
			self.pev.framerate = atof( string(m_dictKV["delay"]) );
		}
		if( m_dictKV.exists( "m_imaxlivechildren" ) )
		{
			self.pev.impulse   = atoi( string(m_dictKV["m_imaxlivechildren"]) );
		}
		if( m_dictKV.exists( "m_bfreewhendead" ) )
		{
			self.pev.watertype = atoi( string(m_dictKV["m_bfreewhendead"]) );
		}

		// Init vars
		m_hChildrens.resize( uint(self.pev.impulse) );

		SetThink( ThinkFunction( this.TeleThink ) );
		self.pev.nextthink = g_Engine.time + self.pev.framerate;
	}

	void TeleThink()
	{
		if( IsOn() )
		{
			// Use scheduler instead, more likely a Java's Thread
			// so the engine won't paused when this is executed
			if( m_PlayerScanTimer is null )
			{
				@m_PlayerScanTimer = g_Scheduler.SetTimeout( @this, "ScanPlayer", 0.f );
			}

			self.pev.nextthink = g_Engine.time + self.pev.framerate;
		}
	}

	private void ScanPlayer()
	{
		if( IsSlotAvailable() )
		{
			uint connectedPlayers = uint( g_PlayerFuncs.GetNumPlayers() );
			uint[] checkedIndex;
			CBasePlayer@ pPlayer = null;
			do
			{
				uint currIndex = Math.RandomLong( 1, g_Engine.maxClients );
				if( checkedIndex.find( currIndex ) > -1 )
					continue;

				@pPlayer  = g_PlayerFuncs.FindPlayerByIndex( currIndex );
				if( pPlayer !is null )
				{
					checkedIndex.insertLast( currIndex );

					//alive is always connected
					if( pPlayer.IsAlive() )
					{
						SpawnMonster( pPlayer );
						break;
					}
				}
			}
			while( connectedPlayers > 0 && checkedIndex.length() < connectedPlayers );
		}

		if( m_PlayerScanTimer !is null )
		{
			g_Scheduler.RemoveTimer( m_PlayerScanTimer );
			@m_PlayerScanTimer = null;
		}
	}

	private void SpawnMonster( CBasePlayer@ pPlayer )
	{
		if( pPlayer is null )
			return;

		Vector vecBaseOrigin = pPlayer.Center();
		// TODO : Better player crouching handling
		if( pPlayer.pev.FlagBitSet( FL_DUCKING ) )
		{
			//vecBaseOrigin.x   = (self.pev.absmax.x + self.pev.absmin.x)*0.5;
			//vecBaseOrigin.y   = (self.pev.absmax.y + self.pev.absmin.y)*0.5;
			vecBaseOrigin.z   = vecBaseOrigin.z*2;
		}

		uint loopSafety = MAX_LOOP_SAFETY;
		Vector vecNewOrigin;
		do
		{
			--loopSafety;
			vecNewOrigin = vecBaseOrigin + Vector( Math.RandomFloat(COORD_RANDOM_MIN,COORD_RANDOM_MAX), Math.RandomFloat(COORD_RANDOM_MIN,COORD_RANDOM_MAX), vecBaseOrigin.z*0.5 );
		}
		while( pPlayer !is null && ( !is_hull_vacant( vecNewOrigin ) || !pPlayer.FVisibleFromPos( vecNewOrigin, vecBaseOrigin ) ) && loopSafety > 0 );

		// System failing... abort!
		if( loopSafety == 0 )
		{
			g_Game.AlertMessage( at_console, "env_automaker safety loop reached... abort!\n" );
			g_Game.AlertMessage( at_console, "" +vecNewOrigin.x+ " " +vecNewOrigin.y+ " " +vecNewOrigin.z+ "\n" );
			return;
		}

		uint slotIndex = GetFreeSlot();
		if( slotIndex != Math.UINT32_MAX )
		{
			// Real monster is here
			dictionary dictNpc = m_dictKV;
			dictNpc.set( "origin", string( "" +int(vecNewOrigin.x)+ " " +int(vecNewOrigin.y)+ " " +int(vecNewOrigin.z) ) );
			// notice me, senpai!
			float yaw = Math.VecToYaw( vecBaseOrigin - vecNewOrigin );
			dictNpc.set( "angles", string( "" +0+ " " +int(yaw)+ " " +0 ) );

			CBaseEntity@ pMonster = g_EntityFuncs.CreateEntity( string(dictNpc["monstertype"]), dictNpc );
			if( pMonster !is null )
			{
				if( g_EngineFuncs.DropToFloor( pMonster.edict() ) == -1 )
				{
					g_Game.AlertMessage( at_console, "env_automaker spawned npc is stuck in the world, removing\n" );
					g_EntityFuncs.Remove( pMonster );
					return;
				}

				//set into the slot
				m_hChildrens[slotIndex] = EHandle( @pMonster );

				// XenMaker only used for effect
				dictionary dictXen = dictNpc;
				dictXen.set( "spawnflags",	string(3) );
				CBaseEntity@ pMaker = g_EntityFuncs.CreateEntity( "env_xenmaker", dictXen );

				if( pMaker !is null )
				{
					pMaker.Use( self, self, USE_ON );
					// omae wa mou shindeiru
					g_Scheduler.SetTimeout( @pMaker, "Killed", 5.f, @pMaker.pev, 0 );
				}
			}
		}

		g_Game.AlertMessage( at_console, "env_automaker " +vecNewOrigin.x+ " " +vecNewOrigin.y+ " " +vecNewOrigin.z+ "\n" );
	}

	void Use(CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue = 0.0f)
	{
		BaseClass.Use( @pActivator, @pCaller, useType, flValue );

		bool status = IsOn();
		if ( self.ShouldToggle( useType, status ) )
		{
			if ( status )
				TurnOff();
			else
				TurnOn();
		}
	}

	void TurnOff()
	{
		self.pev.gamestate = 0;
		self.pev.nextthink = 0;
	}

	void TurnOn()
	{
		self.pev.gamestate = 1;
		self.pev.nextthink = g_Engine.time + self.pev.framerate;
	}

	bool IsOn()
	{
		return self.pev.gamestate > 0;
	}

	bool IsSlotAvailable()
	{
		return ( GetFreeSlot() != Math.UINT32_MAX );
	}

	uint GetFreeSlot()
	{
		for( uint i = 0; i < m_hChildrens.length(); i++ )
		{
			if( !m_hChildrens[i].IsValid() || m_hChildrens[i].GetEntity() is null || ( self.pev.watertype > 0 && !m_hChildrens[i].GetEntity().IsAlive() ) )
				return i;
		}

		return Math.UINT32_MAX;
	}
}

bool is_hull_vacant( const Vector &in vecOrigin, const HULL_NUMBER hull = large_hull )
{
	TraceResult ptr;
	g_Utility.TraceHull( vecOrigin, vecOrigin, dont_ignore_monsters, hull, null, ptr );
    
    return ( ptr.fAllSolid <= 0 && ptr.fStartSolid <= 0 && ptr.fInOpen > 0 );
}
