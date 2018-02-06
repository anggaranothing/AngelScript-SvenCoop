/*
*	weapon_frostnade
*
*	Reimplementation of Zombie Plague Mod's Frostnade, which is also based on XxAvalanchexX's FrostNades
*	https://forums.alliedmods.net/showthread.php?t=72505
*	https://forums.alliedmods.net/showthread.php?p=350439
*
*	ReGameDLL_CS's wpn_hegrenade.cpp as a weapon code reference
*	https://github.com/s1lentq/ReGameDLL_CS/blob/master/regamedll/dlls/wpn_shared/wpn_hegrenade.cpp
*
*	Anggara_nothing
*/

namespace FROSTNADE
{
	void RegisterEntity()
	{
		g_CustomEntityFuncs.RegisterCustomEntity( "CockedFrostnade", "frostnade" );
		g_CustomEntityFuncs.RegisterCustomEntity( "CFrostNade",      "weapon_frostnade" );

		g_ItemRegistry.RegisterWeapon( "weapon_frostnade", "an_frostnade", "weapon_frostnade" );

		g_Game.PrecacheMonster( "frostnade",             false );
		g_Game.PrecacheMonster( "weapon_frostnade",      false );
	}

	// ~-~-~-~-~-~-~-~-~-~-~-~-~-~- //
	// Custom Setting goes here...  //
	// ~-~-~-~-~-~-~-~-~-~-~-~-~-~- //

	enum hegrenade_e
	{
		HEGRENADE_IDLE,
		HEGRENADE_PULLPIN,
		HEGRENADE_THROW,
		HEGRENADE_DRAW
	};

	const string W_MODEL = "models/an_frostnade/w_grenade_frost.mdl";
	const string P_MODEL = "models/an_frostnade/p_grenade_frost.mdl";
	const string V_MODEL = "models/an_frostnade/v_grenade_frost.mdl";

	const string SOUND_EXPLOSION = "an_frostnade/frostnova.wav";
	const string SOUND_BOUNCEHIT = "an_frostnade/he_bounce-1.wav";
	const string SOUND_FREEZED   = "an_frostnade/impalehit.wav";
	const string SOUND_UNFREEZED = "an_frostnade/impalelaunch1.wav";

	const int DEFAULT_GIVE = 1;
	const int MAX_AMMO     = 1;
	const int WEIGHT       = 2;

	// Explosion radius for custom grenades
	const float EXPLOSION_RADIUS = 240.f;

	const float FROZEN_DURATION  = 3.f;
}

final class CFrostNade : ScriptBasePlayerWeaponEntity
{
	// hle time creep vars
	private float m_flPrevPrimaryAttack;
	private float m_flLastFireTime;

	// specific CHEGrenade vars
	private float m_flStartThrow, m_flReleaseThrow;
	private bool m_blRemoveMe;
	
	private CBasePlayer@ m_pPlayer
	{
		get const { return cast<CBasePlayer@>( self.m_hPlayer.GetEntity() ); }
		set { self.m_hPlayer = EHandle( @value ); }
	}
	
	bool GetItemInfo( ItemInfo& out info )
	{
		info.iMaxAmmo1		= FROSTNADE::MAX_AMMO;
		info.iMaxAmmo2		= WEAPON_NOCLIP;
		info.iMaxClip		= WEAPON_NOCLIP;
		info.iSlot		= 4;
		info.iPosition		= 5;
		info.iWeight		= FROSTNADE::WEIGHT;
		info.iFlags		= ITEM_FLAG_LIMITINWORLD | ITEM_FLAG_EXHAUSTIBLE | ITEM_FLAG_ESSENTIAL;
		return true;
	}

	void Precache()
	{
		self.PrecacheCustomModels();
		
		g_Game.PrecacheModel( FROSTNADE::V_MODEL );
		g_Game.PrecacheModel( FROSTNADE::W_MODEL );
		g_Game.PrecacheModel( FROSTNADE::P_MODEL );

		PrecacheGenericSound("an_frostnade/pinpull.wav");

		PrecacheHud( "an_frostnade/640hud19.spr" );
		PrecacheHud( "an_frostnade/weapon_frostnade.txt" );
		
		BaseClass.Precache();
	}

	void Spawn()
	{
		Precache();

		g_EntityFuncs.SetModel( self, self.GetW_Model( FROSTNADE::W_MODEL ) );

		self.pev.dmg = 4;

		self.m_iDefaultAmmo = FROSTNADE::DEFAULT_GIVE;
		this.m_flStartThrow = 0;
		this.m_flReleaseThrow = -1.0f;

		// Get ready to fall down
		self.FallInit();

		// extend
		BaseClass.Spawn();
	}
	
	// Better ammo extraction --- Anggara_nothing
	bool CanHaveDuplicates()
	{
		return true;
	}

	bool AddToPlayer( CBasePlayer@ pPlayer )
	{
		bool result = BaseClass.AddToPlayer( pPlayer );

		if( result )
		{
			NetworkMessage message( MSG_ONE, NetworkMessages::WeapPickup, pPlayer.edict() );
				message.WriteLong( self.m_iId );
			message.End();

			return true;
		}

		return result;
	}

	bool Deploy()
	{
		this.m_flReleaseThrow = -1.0f;
		
		return self.DefaultDeploy( self.GetV_Model( FROSTNADE::V_MODEL ), self.GetP_Model( FROSTNADE::P_MODEL ), FROSTNADE::HEGRENADE_DRAW, "gren", 0 );
	}
	
	void Holster( int skiplocal )
	{
		m_pPlayer.m_flNextAttack = g_WeaponFuncs.WeaponTimeBase() + 0.5; 

		this.m_flStartThrow   = 0;
		this.m_flReleaseThrow = -1.0f;

		if( m_blRemoveMe )
		{
			BaseClass.Holster( skiplocal );
			return;
		}

		if ( m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) <= 0 )
		{
			m_blRemoveMe = true;
			self.DestroyItem();
		}
	}

	void PrimaryAttack()
	{
		if ( m_flStartThrow <= 0 && m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) > 0 )
		{
			m_flReleaseThrow = 0;
			m_flStartThrow   = g_Engine.time;

			self.SendWeaponAnim( FROSTNADE::HEGRENADE_PULLPIN, 0 );
			self.m_flTimeWeaponIdle = WeaponTimeBase() + 0.5f;
		}
	}

	void  WeaponIdle()
	{
		if ( m_flReleaseThrow == 0 && m_flStartThrow != 0.0f )
			m_flReleaseThrow = g_Engine.time;

		if (self.m_flTimeWeaponIdle > WeaponTimeBase())
			return;

		if (m_flStartThrow > 0)
		{
			//m_pPlayer.Radio("%!MRAD_FIREINHOLE", "#Fire_in_the_hole");

			Vector angThrow = m_pPlayer.pev.v_angle + m_pPlayer.pev.punchangle;

			if (angThrow.x < 0)
				angThrow.x = -10 + angThrow.x * ((90 - 10) / 90.0);
			else
				angThrow.x = -10 + angThrow.x * ((90 + 10) / 90.0);

			float flVel = (90.0f - angThrow.x) * 6.0f;

			if (flVel > 750.0f)
				flVel = 750.0f;

			Math.MakeVectors(angThrow);

			Vector vecSrc  = m_pPlayer.pev.origin + m_pPlayer.pev.view_ofs + g_Engine.v_forward * 16;
			Vector vecThrow = g_Engine.v_forward * flVel + m_pPlayer.pev.velocity;

			ShootTimed2(m_pPlayer.pev, vecSrc, vecThrow, 1.5, m_pPlayer.Classify() );

			self.SendWeaponAnim( FROSTNADE::HEGRENADE_THROW, 0 );

			// player "shoot" animation
			m_pPlayer.SetAnimation(PLAYER_ATTACK1);

			m_flStartThrow = 0;
			self.m_flNextPrimaryAttack = GetNextAttackDelay(0.5);
			self.m_flTimeWeaponIdle = WeaponTimeBase() + 0.75f;

			int ammoLeft = m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType );
			--ammoLeft;
			m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType, ammoLeft );
			if ( ammoLeft <= 0 )
			{
				// just threw last grenade
				// set attack times in the future, and weapon idle in the future so we can see the whole throw
				// animation, weapon idle will automatically retire the weapon for us.
				// ensure that the animation can finish playing
				self.m_flTimeWeaponIdle = self.m_flNextSecondaryAttack = self.m_flNextPrimaryAttack = GetNextAttackDelay(0.5);
			}
		}
		else if (m_flReleaseThrow > 0)
		{
			// we've finished the throw, restart.
			m_flStartThrow = 0;

			if (m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) > 0)
			{
				self.SendWeaponAnim( FROSTNADE::HEGRENADE_DRAW, 0 );
			}
			else
			{
				self.RetireWeapon();
				return;
			}

			self.m_flTimeWeaponIdle = WeaponTimeBase() + Math.RandomFloat(10, 15);
			m_flReleaseThrow = -1.0f;
		}
		else if (m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) > 0)
		{
			self.SendWeaponAnim( FROSTNADE::HEGRENADE_IDLE, 0 );

			// how long till we do this again.
			self.m_flTimeWeaponIdle = WeaponTimeBase() + Math.RandomFloat(10, 15);
		}
	}

	CBaseEntity@ ShootTimed2( entvars_t@ pevOwner, Vector vecStart, Vector vecVelocity, float time, int iTeam )
	{
		CBaseEntity@ pGrenade = g_EntityFuncs.CreateEntity( "frostnade", null );

		if( pGrenade !is null )
		{
			g_EntityFuncs.SetOrigin( pGrenade, vecStart );
			pGrenade.pev.velocity = vecVelocity;
			pGrenade.pev.angles   = pevOwner.angles;
			@pGrenade.pev.owner   = @pevOwner.get_pContainingEntity();

			// SetTouch & SetThink moved to CockedFrostnade::Spawn() --Anggara_nothing
			//pGrenade.SetTouch(&BounceTouch);

			pGrenade.pev.dmgtime   = g_Engine.time + time;
			//pGrenade.SetThink(&TumbleThink);
			pGrenade.pev.nextthink = g_Engine.time + 0.1f;

			pGrenade.pev.sequence  = Math.RandomLong(3, 6);
			pGrenade.pev.framerate = 1.0f;

			//pGrenade.m_bJustBlew = true;

			pGrenade.pev.gravity  = 0.55f;
			pGrenade.pev.friction = 0.7f;

			pGrenade.SetClassification( iTeam );

			g_EntityFuncs.SetModel( pGrenade, self.GetW_Model( FROSTNADE::W_MODEL ) );
			pGrenade.pev.dmg = 100.0f;
		}

		return pGrenade;
	}

	bool CanDeploy()
	{
		return ( m_pPlayer !is null && m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) > 0 );
	}

	float WeaponTimeBase()
	{
		return g_Engine.time;
	}

	// GetNextAttackDelay - An accurate way of calcualting the next attack time.
	float GetNextAttackDelay(float delay)
	{
		if (m_flLastFireTime == 0.0f || self.m_flNextPrimaryAttack == -1.0f)
		{
			// At this point, we are assuming that the client has stopped firing
			// and we are going to reset our book keeping variables.
			m_flPrevPrimaryAttack = delay;
			m_flLastFireTime = g_Engine.time;
		}

		float flNextAttack = WeaponTimeBase() + delay;

		// save the last fire time
		m_flLastFireTime = g_Engine.time;

		// we need to remember what the m_flNextPrimaryAttack time is set to for each shot,
		// store it as m_flPrevPrimaryAttack.
		m_flPrevPrimaryAttack = flNextAttack - WeaponTimeBase();

		return flNextAttack;
	}
}

final class CockedFrostnade : ScriptBaseMonsterEntity
{
	void  Detonate3()
	{
		TraceResult tr;
		Vector vecSpot; // trace starts here!

		vecSpot = self.pev.origin + Vector(0, 0, 8);
		g_Utility.TraceLine( vecSpot, vecSpot + Vector(0, 0, -40), ignore_monsters, self.edict(), tr );

		Explode3( tr, DMG_SLOWFREEZE );
	}

	void Explode3(TraceResult &in pTrace, int bitsDamageType)
	{
		self.pev.model      = string_t(); // invisible
		self.pev.solid      = SOLID_NOT;   // intangible
		self.pev.takedamage = DAMAGE_NO;

		if ( pTrace.flFraction != 1.0f )
		{
			self.pev.origin = pTrace.vecEndPos + (pTrace.vecPlaneNormal * (self.pev.dmg - 24.0f) * 0.6f);
		}

		GetSoundEntInstance().InsertSound( bits_SOUND_COMBAT, self.pev.origin, NORMAL_EXPLOSION_VOLUME, 3, self );

		entvars_t@ pevOwner = self.pev.owner.vars;
		@self.pev.owner = null;
		//RadiusDamage( self.pev, pevOwner, self.pev.dmg, CLASS_NONE, bitsDamageType );

		if (Math.RandomFloat(0, 1) < 0.5f)
			g_Utility.DecalTrace(pTrace, DECAL_SCORCH1);
		else
			g_Utility.DecalTrace(pTrace, DECAL_SCORCH2);

		// play "exploded" sound
		g_SoundSystem.EmitSound(self.edict(), CHAN_VOICE, FROSTNADE::SOUND_EXPLOSION, VOL_NORM, ATTN_NORM);

		// beamcylinder effects
		create_blast3( self.pev.origin );

		// freeze players / npc around me
		CBaseEntity@ pEnt = null;
		while( ( @pEnt = g_EntityFuncs.FindEntityInSphere( pEnt, self.pev.origin, FROSTNADE::EXPLOSION_RADIUS, "*", "classname" ) ) !is null )
		{
			CBasePlayer@   pOwner  = cast<CBasePlayer@>(  g_EntityFuncs.Instance( pevOwner ) );
			CBaseMonster@  pVictim = cast<CBaseMonster@>( pEnt );

			if( pOwner is null )
			{
				// owner is gone, get out!
				break;
			}

			// Victim is self or friendly npc?
			if( pVictim is pOwner || pOwner.IRelationship( pVictim ) <= R_NO)
				continue;

			if( pVictim !is null && pVictim.IsAlive() )
			{
				// set global effects
				pVictim.pev.takedamage = DAMAGE_NO;
				//pVictim.pev.flags      |= FL_DORMANT; // just a marker

				// store freeze duration
				pVictim.pev.message = string( g_Engine.time + FROSTNADE::FROZEN_DURATION );

				if( pVictim.IsPlayer() )
				{
					// Player using more "natural" way
					pVictim.pev.flags |= FL_FROZEN;

					// Freeze icon
					NetworkMessage m( MSG_ONE_UNRELIABLE, NetworkMessages::Damage, pVictim.edict() );
						m.WriteByte( 0 ); // damage save
						m.WriteByte( 1 ); // damage take
						m.WriteLong( bitsDamageType ); // damage type
						m.WriteCoord( pevOwner.origin.x ); // x
						m.WriteCoord( pevOwner.origin.y ); // y
						m.WriteCoord( pevOwner.origin.z ); // z
					m.End();

					// Add a blue tint to their screen
					g_PlayerFuncs.ScreenFade( pVictim, Vector( 0,5,200 ), 0, 0, 100, FFADE_STAYOUT );

					// Update player entity rendering
					ApplyFrozenRendering( EHandle(@pVictim) );
				}
				else
				if( pVictim.IsMonster() )
				{
					pVictim.Stop();
					pVictim.pev.nextthink = 0; // Freeze!
					pVictim.pev.framerate = 0.f;

					// Special handling for barnacle
					if( pVictim.pev.ClassNameIs( "monster_barnacle" ) )
					{
						// has prey? release it!
						CBaseMonster@ pPrey = cast<CBaseMonster@>( pVictim.m_hEnemy.GetEntity() );

						// https://github.com/ValveSoftware/halflife/blob/master/dlls/monsters.cpp#L187
						if( pPrey !is null )
						{
							pVictim.pev.solid         = SOLID_NOT;

							pPrey.m_IdealMonsterState = MONSTERSTATE_IDLE;
							pPrey.pev.velocity        = g_vecZero;

							CBasePlayer@ pPlayer = cast<CBasePlayer@>( @pPrey );
							if( pPlayer is null )
							{
								// simply set normal movetype
								pPrey.pev.movetype = MOVETYPE_STEP;
							}
							else
							{
								// https://github.com/ValveSoftware/halflife/blob/master/dlls/player.cpp#L4208
								pPlayer.m_afPhysicsFlags &= ~PFLAG_ONBARNACLE;

								// Enable weapon usage again
								pPlayer.UnblockWeapons( pPlayer );

								// Reset HideHUD
								NetworkMessage m( MSG_ONE, NetworkMessages::HideHUD, pPlayer.edict() );
									m.WriteByte(  0 );
								m.End();
							}
						}
					}

					// cleanup
					pVictim.StudioFrameAdvance(); // temporary fix for "monster running" sequence
					//pVictim.ClearSchedule();
					pVictim.ClearEnemyList();
					pVictim.SentenceStop();
					pVictim.m_hEnemy = null;
					//pVictim.m_vecEnemyLKP = g_vecZero;

					// Show freeze glow
					pVictim.ShockGlowEffect( true );
				}

				// Freeze sound
				g_SoundSystem.EmitSoundDyn( pVictim.edict(), CHAN_BODY, FROSTNADE::SOUND_FREEZED, 1.0, ATTN_NORM, 0, PITCH_NORM );

				// Set the timer here
				g_Scheduler.SetTimeout( "UnFreezeMe", FROSTNADE::FROZEN_DURATION, EHandle( @pVictim ) );
			}
		}

		self.pev.effects |= EF_NODRAW;
		SetThink( ThinkFunction( this.Smoke3_C ) );
		self.pev.velocity = g_vecZero;
		self.pev.nextthink = g_Engine.time + 0.55f;

		uint sparkCount = Math.RandomLong(0, 3);
		for (uint i = 0; i < sparkCount; i++)
		{
			dictionary dict =
			{
				{ "origin", "" +int(self.pev.origin.x)+       " " +int(self.pev.origin.y)+       " " +int(self.pev.origin.z) },
				{ "angles", "" +int(pTrace.vecPlaneNormal.x)+ " " +int(pTrace.vecPlaneNormal.y)+ " " +int(pTrace.vecPlaneNormal.z) }
			};
			g_EntityFuncs.CreateEntity( "spark_shower", dict );
		}
	}

	// Frost Grenade: Freeze Blast
	void create_blast3( Vector &in originF )
	{
		uint spriteId = g_EngineFuncs.ModelIndex("sprites/shockwave.spr");

		// Smallest ring
		NetworkMessage small( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, originF );
			small.WriteByte(TE_BEAMCYLINDER); // TE id
			small.WriteCoord(originF.x); // x
			small.WriteCoord(originF.y); // y
			small.WriteCoord(originF.z); // z
			small.WriteCoord(originF.x); // x axis
			small.WriteCoord(originF.y); // y axis
			small.WriteCoord(originF.z + 385.0); // z axis
			small.WriteShort(spriteId); // sprite
			small.WriteByte(0); // startframe
			small.WriteByte(0); // framerate
			small.WriteByte(4); // life
			small.WriteByte(60); // width
			small.WriteByte(0); // noise
			small.WriteByte(0); // red
			small.WriteByte(100); // green
			small.WriteByte(200); // blue
			small.WriteByte(200); // brightness
			small.WriteByte(0); // speed
		small.End();
		
		// Medium ring
		NetworkMessage medium( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, originF );
			medium.WriteByte(TE_BEAMCYLINDER); // TE id
			medium.WriteCoord(originF.x); // x
			medium.WriteCoord(originF.y); // y
			medium.WriteCoord(originF.z); // z
			medium.WriteCoord(originF.x); // x axis
			medium.WriteCoord(originF.y); // y axis
			medium.WriteCoord(originF.z + 470.0); // z axis
			medium.WriteShort(spriteId); // sprite
			medium.WriteByte(0); // startframe
			medium.WriteByte(0); // framerate
			medium.WriteByte(4); // life
			medium.WriteByte(60); // width
			medium.WriteByte(0); // noise
			medium.WriteByte(0); // red
			medium.WriteByte(100); // green
			medium.WriteByte(200); // blue
			medium.WriteByte(200); // brightness
			medium.WriteByte(0); // speed
		medium.End();
		
		// Largest ring
		NetworkMessage large( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, originF );
			large.WriteByte(TE_BEAMCYLINDER); // TE id
			large.WriteCoord(originF.x); // x
			large.WriteCoord(originF.y); // y
			large.WriteCoord(originF.z); // z
			large.WriteCoord(originF.x); // x axis
			large.WriteCoord(originF.y); // y axis
			large.WriteCoord(originF.z + 555.0); // z axis
			large.WriteShort(spriteId); // sprite
			large.WriteByte(0); // startframe
			large.WriteByte(0); // framerate
			large.WriteByte(4); // life
			large.WriteByte(60); // width
			large.WriteByte(0); // noise
			large.WriteByte(0); // red
			large.WriteByte(100); // green
			large.WriteByte(200); // blue
			large.WriteByte(200); // brightness
			large.WriteByte(0); // speed
		large.End();
	}

	void Smoke3_C()
	{
		if ( g_EngineFuncs.PointContents( self.pev.origin ) == CONTENTS_WATER )
		{
			g_Utility.Bubbles( self.pev.origin - Vector(64, 64, 64), self.pev.origin + Vector(64, 64, 64), 100 );
		}
		else
		{
			NetworkMessage m( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, self.pev.origin );
				m.WriteByte( TE_SMOKE );
				m.WriteCoord( self.pev.origin.x );
				m.WriteCoord( self.pev.origin.y );
				m.WriteCoord( self.pev.origin.z );
				m.WriteShort( g_EngineFuncs.ModelIndex("sprites/steam1.spr") );
				m.WriteByte( 35 + Math.RandomLong(0, 10) ); // scale * 10
				m.WriteByte( 5 ); // framerate
			m.End();
		}

		g_EntityFuncs.Remove( self );
	}

	void BounceTouch(CBaseEntity@ pOther)
	{
		// don't hit the guy that launched this grenade
		if (pOther.edict() is self.pev.owner)
			return;

		if ( pOther.pev.ClassNameIs( "func_breakable" ) && pOther.pev.rendermode != kRenderNormal )
		{
			self.pev.velocity = self.pev.velocity * -2.0f;
			return;
		}

		Vector vecTestVelocity;

		// this is my heuristic for modulating the grenade velocity because grenades dropped purely vertical
		// or thrown very far tend to slow down too quickly for me to always catch just by testing velocity.
		// trimming the Z velocity a bit seems to help quite a bit.
		vecTestVelocity = self.pev.velocity;
		vecTestVelocity.z *= 0.7f;

		if ( !m_fRegisteredSound && vecTestVelocity.Length() <= 60.0f )
		{
			// grenade is moving really slow. It's probably very close to where it will ultimately stop moving.
			// go ahead and emit the danger sound.

			// register a radius louder than the explosion, so we make sure everyone gets out of the way
			GetSoundEntInstance().InsertSound( bits_SOUND_DANGER, self.pev.origin, int(self.pev.dmg / 0.4f), 0.3, self );
			m_fRegisteredSound = true;
		}

		if ( self.pev.flags & FL_ONGROUND != 0 )
		{
			// add a bit of static friction
			self.pev.velocity = self.pev.velocity * 0.8f;
			self.pev.sequence = Math.RandomLong(1, 1); // TODO: what?
		}
		else
		{
			if (m_iBounceCount < 5)
			{
				// play bounce sound
				BounceSound();
			}

			if (m_iBounceCount >= 10)
			{
				@self.pev.groundentity  = g_EntityFuncs.IndexEnt(0);
				self.pev.flags         |= FL_ONGROUND;
				self.pev.velocity       = g_vecZero;
			}

			m_iBounceCount++;
		}

		self.pev.framerate = pev.velocity.Length() / 200.0f;

		if ( self.pev.framerate > 1 )
		{
			self.pev.framerate = 1.0f;
		}
		else if ( self.pev.framerate < 0.5f )
		{
			self.pev.framerate = 0.0f;
		}
	}

	void BounceSound()
	{
		g_SoundSystem.EmitSound(self.edict(), CHAN_VOICE, FROSTNADE::SOUND_BOUNCEHIT, 0.25, ATTN_NORM);
	}

	void TumbleThink()
	{
		if (!self.IsInWorld())
		{
			g_EntityFuncs.Remove( self );
			return;
		}

		self.StudioFrameAdvance();
		self.pev.nextthink = g_Engine.time + 0.1f;

		if ( self.pev.dmgtime - 1 < g_Engine.time )
		{
			GetSoundEntInstance().InsertSound( bits_SOUND_DANGER, self.pev.origin + self.pev.velocity * (self.pev.dmgtime - g_Engine.time), 400, 0.1, self );
		}

		if ( self.pev.dmgtime <= g_Engine.time )
		{
			SetThink( ThinkFunction( this.Detonate3 ) );
		}

		if ( self.pev.waterlevel != 0 )
		{
			self.pev.velocity  = self.pev.velocity * 0.5f;
			self.pev.framerate = 0.2f;
		}
	}

	void Precache()
	{
		g_Game.PrecacheModel( self, "models/grenade.mdl" );
		g_Game.PrecacheModel( self, "models/glassgibs.mdl" );
		PrecacheGenericSound( FROSTNADE::SOUND_BOUNCEHIT );
		PrecacheGenericSound( FROSTNADE::SOUND_EXPLOSION );
		PrecacheGenericSound( FROSTNADE::SOUND_FREEZED );
		PrecacheGenericSound( FROSTNADE::SOUND_UNFREEZED );
	}

	void Spawn()
	{
		Precache();

		m_iBounceCount = 0;
		self.pev.movetype = MOVETYPE_BOUNCE;

		//MAKE_STRING_CLASS("grenade", pev);

		//m_bIsC4 = false;
		self.pev.solid = SOLID_BBOX;

		g_EntityFuncs.SetModel( self, "models/grenade.mdl" );
		g_EntityFuncs.SetSize( self.pev, g_vecZero, g_vecZero );

		self.pev.dmg = 30.0f;
		m_fRegisteredSound = false;

		// Give it a glow
		self.pev.rendermode  = kRenderNormal;
		self.pev.renderfx    = kRenderFxGlowShell;
		self.pev.renderamt   = 16;
		self.pev.rendercolor = Vector( 0, 100, 200 );
		
		// And a colored trail
		NetworkMessage m( MSG_BROADCAST, NetworkMessages::SVC_TEMPENTITY );
			m.WriteByte(  TE_BEAMFOLLOW ); // TE id
			m.WriteShort( self.entindex() ); // entity
			m.WriteShort( g_EngineFuncs.ModelIndex("sprites/laserbeam.spr") ); // sprite
			m.WriteByte(  10 ); // life
			m.WriteByte(  10 ); // width
			m.WriteByte(   0 ); // r
			m.WriteByte( 100 ); // g
			m.WriteByte( 200 ); // b
			m.WriteByte( 200 );   // brightness
		m.End();

		// Here we go --Anggara_nothing
		SetTouch( TouchFunction( this.BounceTouch ) );
		SetThink( ThinkFunction( this.TumbleThink ) );
	}

	private bool m_fRegisteredSound;
	private int  m_iBounceCount;
}

/**
*	Here we are handling freezed npc/player
*
**/
void UnFreezeMe( EHandle hMonster )
{
	CBaseMonster@ pMonster = cast<CBaseMonster@>( hMonster.GetEntity() );

	if( pMonster is null || !pMonster.IsAlive() /*|| !pMonster.pev.FlagBitSet( FL_DORMANT )*/ )
		return;

	// get last freeze time
	float lastFreezeTime = atof( string(pMonster.pev.message) ); 

	// Too soon? abort!
	if( lastFreezeTime <= 0 || lastFreezeTime > g_Engine.time )
		return;

	// Unset global effects
	//pMonster.pev.flags &= ~FL_DORMANT;

	// Player
	if( pMonster.IsPlayer() )
	{
		// Unfreeze flag
		pMonster.pev.flags &= ~FL_FROZEN;

		// Restore rendering
		pMonster.pev.renderfx    = int( pMonster.pev.vuser3.x );
		pMonster.pev.rendermode  = int( pMonster.pev.vuser3.y );
		pMonster.pev.renderamt   = pMonster.pev.vuser3.z;
		pMonster.pev.rendercolor = pMonster.pev.vuser4;

		// Gradually remove screen's blue tint
		g_PlayerFuncs.ScreenFade( pMonster, Vector( 0,5,200 ), (1<<12), 0, 100, FFADE_IN );
	}
	// Monster
	else if( pMonster.IsMonster() )
	{
		// Restore glow setting
		// especially for machine-based monsters
		pMonster.ShockGlowEffect( false );

		// Barnacle?
		if( pMonster.pev.ClassNameIs( "monster_barnacle") )
		{
			// Give me back my solid type!
			pMonster.pev.solid = SOLID_SLIDEBOX;
		}

		// wake up, dude!
		pMonster.pev.framerate = 1.f;
		pMonster.pev.nextthink = g_Engine.time + 0.1f;
	}

	// Vulnerable now
	pMonster.pev.takedamage = DAMAGE_YES;

	// Broken glass sound
	g_SoundSystem.EmitSoundDyn( pMonster.edict(), CHAN_STATIC, FROSTNADE::SOUND_UNFREEZED, 1.0, ATTN_NORM, 0, PITCH_NORM );

	// Glass shatter
	NetworkMessage m( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, pMonster.pev.origin );
		m.WriteByte(TE_BREAKMODEL);
		m.WriteCoord( pMonster.pev.origin.x ); // x
		m.WriteCoord( pMonster.pev.origin.y ); // y
		m.WriteCoord( pMonster.pev.origin.z + 24 ); // z
		m.WriteCoord( 16 ); // size x
		m.WriteCoord( 16 ); // size y
		m.WriteCoord( 16 ); // size z
		m.WriteCoord( Math.RandomLong(-50, 50) ); // velocity x
		m.WriteCoord( Math.RandomLong(-50, 50) ); // velocity y
		m.WriteCoord( 25 ); // velocity z
		m.WriteByte(  10 ); // random velocity
		m.WriteShort( g_EngineFuncs.ModelIndex( "models/glassgibs.mdl" ) ); //sprite
		m.WriteByte( 10 ); // count
		m.WriteByte( 25 );  // life
		m.WriteByte( 0x01 ); // flags
	m.End();
}

/**
*	For player only
**/
void ApplyFrozenRendering(EHandle hPlayer)
{
	CBasePlayer@ pPlayer = cast<CBasePlayer@>( hPlayer.GetEntity() );

	if( pPlayer is null || !pPlayer.IsAlive() )
		return;

	// Get current rendering
	int    rendering_fx     = pPlayer.pev.renderfx;
	Vector rendering_color  = pPlayer.pev.rendercolor;
	int    rendering_render = pPlayer.pev.rendermode;
	float  rendering_amount = pPlayer.pev.renderamt;
	
	// Already set, no worries...
	if (rendering_fx == kRenderFxGlowShell && rendering_color[0] == 0.0 && rendering_color[1] == 100.0
		&& rendering_color[2] == 200.0 && rendering_render == kRenderNormal && rendering_amount == 25.0)
		return;
	
	// Save player's old rendering	
	pPlayer.pev.vuser4 = rendering_color;
	pPlayer.pev.vuser3 = Vector( rendering_fx, rendering_render, rendering_amount );
	
	// Light blue glow while frozen
	pPlayer.pev.renderfx    = kRenderFxGlowShell;
	pPlayer.pev.rendercolor = Vector( 0, 100, 200 );
	pPlayer.pev.rendermode  = kRenderNormal;
	pPlayer.pev.renderamt   = 25;
}

/**
*
*	PrecacheGenericSound
*	Combination of PrecacheSound and PrecacheGeneric
*
*	@param	soundfile	File path
*
**/
void PrecacheGenericSound( const string &in soundfile )
{
	if( !soundfile.IsEmpty() )
	{
		g_SoundSystem.PrecacheSound( soundfile );
		g_Game.PrecacheGeneric( "sound/" + soundfile );
	}
}

/**
*
*	PrecacheHud
*	Precache HUD files (.txt config and sprite files) with PrecacheGeneric
*
*	@param	filepath	File path
*
**/
void PrecacheHud( const string &in filepath )
{
	g_Game.PrecacheGeneric( "sprites/" + filepath );
}
