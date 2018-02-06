/*
* Drivable Tank Vehicle
* Ported from Half-Life : Invasion, a Singleplayer Mod
* Made by Invasion team, credits to those guys
*
* Source Code : https://github.com/jlecorre/hlinvasion/blob/master/SourceCode/dlls/tank.cpp
*
* Ported to Angelscript by Anggara_nothing
*/

void MapInit()
{
	HLI::TANK::RegisterTankEntity();
	HLI::SMOKE::RegisterEnvSmokeEntity();
}

namespace HLI
{
namespace TANK
{

void RegisterTankEntity()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "HLI::TANK::CTankCam", CTANKCAM_CLASSNAME );
	g_CustomEntityFuncs.RegisterCustomEntity( "HLI::TANK::CTank",    CTANK_CLASSNAME );
	g_CustomEntityFuncs.RegisterCustomEntity( "HLI::TANK::CTankBSP", CTANKBSP_CLASSNAME );

	g_CustomEntityFuncs.RegisterCustomEntity( "HLI::TANK::CMineAC",       CMINEAC_CLASSNAME );
	g_CustomEntityFuncs.RegisterCustomEntity( "HLI::TANK::CTankCharger",  CTANKCHARGER_CLASSNAME );

	g_Game.PrecacheOther( CMINEAC_CLASSNAME );
}

/****************************************************************************
*																			*
*			Tank.cpp par Julien												*
*																			*
****************************************************************************/


//========================================
// Fonctions externes
//========================================

//============================================================
// EnvSmokeCreate
//
// fonction globale
// permet d'être appelée de n'importe quel fichier
void EnvSmokeCreate( const Vector &in center, int m_iScale, float m_fFrameRate, int m_iTime, int m_iEndTime )
{

	// imite un keyvalue
	string szOutBuffer = string();

	CBaseEntity@ pSmoke = g_EntityFuncs.Create( "env_smoke", center, g_vecZero, true );

	if( pSmoke !is null )
	{
		snprintf( szOutBuffer, "%1", m_iScale );
		g_EntityFuncs.DispatchKeyValue( pSmoke.edict(), "m_iScale", szOutBuffer );

		snprintf( szOutBuffer, "%1", m_fFrameRate );
		g_EntityFuncs.DispatchKeyValue( pSmoke.edict(), "m_fFrameRate", szOutBuffer );

		snprintf( szOutBuffer, "%1", m_iTime );
		g_EntityFuncs.DispatchKeyValue( pSmoke.edict(), "m_iTime", szOutBuffer );

		snprintf( szOutBuffer, "%1", m_iEndTime );
		g_EntityFuncs.DispatchKeyValue( pSmoke.edict(), "m_iEndTime", szOutBuffer );


		// active la fumée
		g_EntityFuncs.DispatchSpawn( pSmoke.edict() );
		pSmoke.Use( null, null, USE_TOGGLE, 0 );
	}
}

//extern int gmsgTankView;

//=========================================
// Variables
//=========================================

const float NEXTTHINK_TIME 			=	0.1;
const float BSP_NEXTTHINK_TIME		=	0.05;

const int TANK_TOURELLE_ROT_SPEED	=	12;
const int TANK_ROT_SPEED			=	50;

const float TANK_REFIRE_DELAY		=	1.5;

const string SPRITE_SMOKE			=	"sprites/muzzleflash.spr";
const float SPRITE_SMOKE_SCALE		=	1.5;
const string SPRITE_MUZ				=	"sprites/muzzleflash1.spr";
const float SPRITE_MUZ_SCALE		=	1;
const string SPRITE_FEU				=	"sprites/lflammes02.spr";
const float SPRITE_FEU_SCALE		=	1;
const string SPRITE_SMOKEBALL		=	"sprites/tank_smokeball.spr";
const float SPRITE_SMOKEBALL_SCALE	=	2;

const string MITRAILLEUSE_SOUND		=	"tank/mitrailleuse.wav";
const string TIR_SOUND				=	"tank/tir.wav";
const string TANK_SOUND				=	"ambience/truck2.wav";
const string CHENILLES_SOUND		=	"tank/chenilles.wav";
const string CHOC_SOUND				=	"debris/metal3.wav";
const string ACCELERE_SOUND1		=	"tank/accelere1.wav";
const string ACCELERE_SOUND2		=	"tank/accelere2.wav";
const string ACCELERE_SOUND3		=	"tank/accelere3.wav";
const string DECCELERE_SOUND		=	"tank/deccelere1.wav";

const string TANK_EXPLO_SOUND1		=	"tank/explode.wav";
const string TANK_EXPLO_SOUND2		=	"weapons/mortarhit.wav";


const int TOURELLE_MAX_ROT_X		=	25;
const int TOURELLE_MAX_ROT_X2		=	-10;
const int TOURELLE_MAX_ROT_Y		=	120;

const int TANK_SPEED				=	200;
const int TANK_ACCELERATION			=	5;
const int TANK_DECCELERATION		=	30;

const int CAM_DIST_UP				=	100;
const int CAM_DIST_BACK				=	300;

/* Set it up later --Anggara_nothing */
//distances pour l' g_Utility.TraceLine()
//#define NEW_ORIGIN					( self.pev.origin + vecNewVelocity / 10 + g_Engine.v_up * 2 )

const int DIST_TOP					=	60;
const int DIST_FRONT				=	140;
const int DIST_FRONT_UP				=	185;
const int DIST_BACK					=	-150;
const int DIST_BACK_UP				=	-170;
const int DIST_SIDE					=	105;

const int MOVE_FORWARD				=	(1<<0);
const int MOVE_BACKWARD				=	(1<<1);
const int PUSH_FORWARD				=	(1<<2);
const int PUSH_BACKWARD				=	(1<<3);

const int TANK_LIFE					=	1200;
const int TANK_RECHARGE				=	15;		// charge du tank_charger par 10e de seconde


//=================================
// classes
//=================================


//==================================
// CTank
// 

const string CTANK_CLASSNAME = "info_tank_model";
final class CTank : ScriptBaseMonsterEntity
{
	private EHandle m_hCam, m_hPlayer, m_hTankBSP;

	bool bTankOn, bSetView, bTankDead;

	float	m_flLastAttack1, m_flNextSound;

	int		bCanon;
	int		m_soundPlaying;

	int		m_iTankmove;

	Vector	m_PlayerAngles, vecCamAim, vecCamTarget;

	float	m_flTempHealth;

	// TODO : wth is this? --Anggara_nothing
	uint16 m_usAdjustPitch;

	CTankCam@ m_pCam
	{
		get const	
		{ 
			return cast<CTankCam@>( CastToScriptClass( m_hCam.GetEntity() ) ); 
		}
		set
		{
			m_hCam = EHandle( @value.self );
		}
	}
	CBasePlayer@ m_pPlayer
	{
		get const	
		{ 
			return cast<CBasePlayer@>( m_hPlayer.GetEntity() ); 
		}
		set
		{
			m_hPlayer = EHandle( @value );
		}
	}
	CTankBSP@ m_pTankBSP
	{
		get const	
		{ 
			return cast<CTankBSP@>( CastToScriptClass( m_hTankBSP.GetEntity() ) ); 
		}
		set
		{
			m_hTankBSP = EHandle( @value.self );
		}
	}

	Vector vecCamOrigin()
	{ 
		Vector origin = self.pev.origin; 
		origin.z += 150; 
		return origin;
	};

	int Classify()   { return CLASS_NONE; }
	int BloodColor() { return DONT_BLEED; }

	void Precache()
	{
		g_Game.PrecacheOther( CTANKCAM_CLASSNAME );

		g_Game.PrecacheModel( self, "models/tank.mdl" );

		g_Game.PrecacheModel( self, SPRITE_SMOKE );
		g_Game.PrecacheModel( self, SPRITE_MUZ );
		g_Game.PrecacheModel( self, SPRITE_SMOKEBALL );
		g_Game.PrecacheModel( self, SPRITE_FEU );

		g_Game.PrecacheModel( self, "models/mechgibs.mdl" );

		g_SoundSystem.PrecacheSound( self, MITRAILLEUSE_SOUND);
		g_SoundSystem.PrecacheSound( self, TIR_SOUND);
		g_SoundSystem.PrecacheSound( self, TANK_SOUND);
		g_SoundSystem.PrecacheSound( self, CHOC_SOUND);
		g_SoundSystem.PrecacheSound( self, CHENILLES_SOUND);
		g_SoundSystem.PrecacheSound( self, ACCELERE_SOUND1);
		g_SoundSystem.PrecacheSound( self, ACCELERE_SOUND2);
		g_SoundSystem.PrecacheSound( self, ACCELERE_SOUND3);
		g_SoundSystem.PrecacheSound( self, DECCELERE_SOUND);
		g_SoundSystem.PrecacheSound( self, TANK_EXPLO_SOUND1);
		g_SoundSystem.PrecacheSound( self, TANK_EXPLO_SOUND2);


		//m_usAdjustPitch = PRECACHE_EVENT( 1, "events/train.sc" );

	}

	void Spawn()
	{
		Precache();

	//	self.pev.movetype = MOVETYPE_NOCLIP;
		self.pev.movetype = MOVETYPE_FLY;
		self.pev.solid    = SOLID_BBOX;
		/* Svenengine will handle this --Anggara_nothing */
		//self.pev.classname = string("info_tank_model");	//necessaire pour le passage a la sauvegarde : getclassptr ne cree pas de self.pev.classname et donc l entite n est pas prise en compte

		g_EntityFuncs.SetModel( self, "models/tank.mdl" );
		g_EntityFuncs.SetSize( self.pev, g_vecZero, g_vecZero );
		g_EntityFuncs.SetOrigin( self, self.pev.origin );

		/* HACKHACK : Let this thing triggers entities --Anggara_nothing */
		self.pev.flags			|= FL_MONSTER | FL_CLIENT | FL_NOTARGET;
		self.pev.takedamage		=  DAMAGE_NO;
		self.pev.sequence		=  0;
		self.pev.health			=  100;

		self.SetClassification( CLASS_NONE );

		if( m_pTankBSP !is null )
		{
			m_flTempHealth		= m_pTankBSP.self.pev.health;

			// Monster always non-solid to owner
			// Anggara_nothing
			@self.pev.owner = m_pTankBSP.self.edict();
		}

		self.ResetSequenceInfo();
		self.pev.frame = Math.RandomLong(0,0xFF);
		self.InitBoneControllers();

		bTankOn = bSetView = bTankDead = false;
		m_flLastAttack1 = m_soundPlaying = 0;

		SetThink( ThinkFunction( this.IdleThink ) );
		self.pev.nextthink = g_Engine.time + 1;
	}

	void TraceAttack(entvars_t@ pevAttacker, float flDamage, const Vector& in vecDir, TraceResult& in ptr, int bitsDamageType)
	{
		return;
	}

	int TakeDamage(entvars_t@ pevInflictor, entvars_t@ pevAttacker, float flDamage, int bitsDamageType)
	{
		return 0;
	}

	void UseTank(CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue = 0.0f)
	{
		if( bTankDead )
		{
			//g_Game.AlertMessage( at_console , "info_tank_model : Tank is destroyed, CAN'T USE !!!\n" );
			return;
		}

		if( bTankOn )
		{
			//g_Game.AlertMessage( at_console , "info_tank_model : Tank is already ON !!!\n" );
			return;
		}

		CBaseEntity@ pFind = g_EntityFuncs.FindEntityByClassname( null, "info_teleport_destination" );

		if ( pFind is null )
		{
			g_Game.AlertMessage( at_console , "info_tank_model : pas de teleport destination !!!\n" );
			return;
		}
		else
		{
			Vector vecTeleport = pFind.pev.origin;
			g_EntityFuncs.SetOrigin( pActivator, vecTeleport );

			@m_pPlayer = cast<CBasePlayer@>( pActivator );

			//m_pPlayer.m_iDrivingTank	= true;

			//m_pPlayer.m_iHideHUD |= HIDEHUD_ALL;


			/*m_pCam = GetClassPtr( (CTankCam*)NULL );
			UTIL_SetOrigin( m_pCam.pev, vecCamOrigin() );
			m_pCam.pev.angles = TourelleAngle();
			m_pCam.Spawn();
			m_pCam.pev.velocity = ( UpdateCam () - vecCamOrigin() ) /2;
			m_pCam.m_pTankModel = this;*/

			// Create tank camera --Anggara_nothing
			CBaseEntity@ pEntity = g_EntityFuncs.Create( CTANKCAM_CLASSNAME, vecCamOrigin(), TourelleAngle(), true, self.edict() );
			CTankCam@ pCam = cast<CTankCam@>( CastToScriptClass( @pEntity ) );

			if( pCam is null )
			{
				// failed to create CTankCam!!! mission abort!! mission abort!!
				g_EntityFuncs.Remove( @pEntity );
			}
			else
			{
				@m_pCam = pCam;
				g_EntityFuncs.DispatchSpawn( pEntity.edict() );
				pEntity.pev.velocity = ( ( UpdateCam() - vecCamOrigin() ) /2 );
				@pCam.m_pTankModel = @this;
			}


			UpdateCamAngle ( UpdateCam(), 2 );

			m_pCam.SetPlayerTankView ( true );

			SetThink( ThinkFunction( this.DriveThink ) );
			self.pev.nextthink = g_Engine.time + 2;
		}
	}


	//===============================================================
	//===============================================================
	// Fonctions Think

	void IdleThink()
	{
		UpdateSound();
		UpdateMyClassification();
		self.pev.nextthink = g_Engine.time + 0.1;
	}
	
	//============================================
	//	Le bone controller 0 correspond au déplacement haut-bas
	//	il équivaut à l axe X du joueur
	//	le bone 1 est le déplacement gauche-droite
	//	et l axe y du joueur
	void DriveThink()
	{
		self.pev.nextthink = g_Engine.time + NEXTTHINK_TIME;
		self.StudioFrameAdvance();

		if ( self.pev.sequence == 1 )
			self.pev.sequence = 0;

		UpdateMyClassification();

		//	ALERT ( at_console, "playerdrivetank : %s\n", m_pPlayer.m_iDrivingTank == true ? "true" : "false" ); 

		// apres le changement de niveau, reinitialisation de la vue
		if ( bSetView == true )
		{
			// actualisation de la vie du bsp

			m_pTankBSP.self.pev.health = m_flTempHealth;

			// réglages camera & hud

			m_pCam.SetPlayerTankView ( true );
			bSetView = false;
		}

		//quitte le tank
		if ( m_pPlayer.pev.button & IN_USE != 0 )
		{
			self.pev.velocity = self.pev.avelocity = m_pTankBSP.self.pev.velocity = m_pTankBSP.self.pev.avelocity = g_vecZero;
			m_pTankBSP.self.pev.origin = self.pev.origin;
			m_pTankBSP.self.pev.angles = self.pev.angles;

			m_pCam.self.pev.velocity = ( vecCamOrigin() - m_pCam.self.pev.origin ) /2;
			UpdateCamAngle( m_pCam.self.pev.origin, 2 );

			UpdateSound();

			SetThink( ThinkFunction( this.StopThink ) );
			self.pev.nextthink = g_Engine.time + 2;
			return;
		}


		float flNextVAngleY = self.pev.v_angle.y;
		float flNextVAngleX = self.pev.v_angle.x;
		float flNewAVelocity;
		Vector vecNewVelocity;

		//---------------------------------------------_-_-_ _  _
		//modifications de la direction de la tourelle
		if ( bTankOn == false )
		{
			bTankOn = true;
			m_PlayerAngles.x = m_pPlayer.pev.angles.x ;
			m_PlayerAngles.y = m_pPlayer.pev.angles.y ;
		}

		if ( m_pPlayer.pev.angles.y != m_PlayerAngles.y )
		{
			int iSens;
			int iDist = ModifAngles( int(m_pPlayer.pev.angles.y) ) - ModifAngles( int(m_PlayerAngles.y) );

			if ( abs(iDist) > 180 )
			{
				if ( iDist > 0 )
					iDist = iDist - 360;
				else
					iDist = iDist + 360;
			}

			iSens = ( iDist == abs(iDist) ? 1 : -1 );
			iDist = int( abs(iDist) );


			if ( iDist < TANK_TOURELLE_ROT_SPEED )
				flNextVAngleY += iDist * iSens;

			else
				flNextVAngleY += TANK_TOURELLE_ROT_SPEED * iSens;

			if ( flNextVAngleY > TOURELLE_MAX_ROT_Y )
				flNextVAngleY = TOURELLE_MAX_ROT_Y;

			if ( flNextVAngleY < -TOURELLE_MAX_ROT_Y )
				flNextVAngleY = -TOURELLE_MAX_ROT_Y;

		}

		if ( m_pPlayer.pev.angles.x != m_PlayerAngles.x )
		{
			int iSens;
			int iDist = ModifAngles( int(m_pPlayer.pev.angles.x) ) - ModifAngles( int(m_PlayerAngles.x) );

			if ( abs(iDist) > 180 )
			{
				if ( iDist > 0 )
					iDist = iDist - 360;
				else
					iDist = iDist + 360;
			}

			iSens = iDist == abs(iDist) ? 1 : -1 ;
			iDist = int( abs(iDist) );

			if ( iDist < TANK_TOURELLE_ROT_SPEED )
				flNextVAngleX += iDist * iSens;

			else
				flNextVAngleX += TANK_TOURELLE_ROT_SPEED * iSens;

			if ( flNextVAngleX > TOURELLE_MAX_ROT_X )
				flNextVAngleX = TOURELLE_MAX_ROT_X;

			if ( flNextVAngleX < TOURELLE_MAX_ROT_X2 )
				flNextVAngleX = TOURELLE_MAX_ROT_X2;

		}

		m_PlayerAngles.y = m_pPlayer.pev.angles.y;
		m_PlayerAngles.x = m_pPlayer.pev.angles.x;


		//---------------------------------
		// sons d'acceleration du tank
		float flSpeed = self.pev.velocity.Length();

		if ( m_flNextSound < g_Engine.time)
		{
			if  ( (m_pPlayer.pev.button & IN_FORWARD != 0) && ((flSpeed==0) || (m_iTankmove & MOVE_BACKWARD != 0)) )
			{
				g_SoundSystem.EmitSoundDyn(self.edict(), CHAN_ITEM, ACCELERE_SOUND1, 1 , ATTN_NONE, 0, 100 );
				m_flNextSound = g_Engine.time + 2.5;
			}
			else if  ( (m_pPlayer.pev.button & IN_BACK != 0) && (m_iTankmove & MOVE_FORWARD != 0) )
			{
				g_SoundSystem.EmitSoundDyn(self.edict(), CHAN_ITEM, DECCELERE_SOUND, 1 , ATTN_NONE, 0, 100 );
				m_flNextSound = g_Engine.time + 2.5;
			}
			else if  ( (m_pPlayer.pev.button & IN_FORWARD != 0) && (m_iTankmove & MOVE_FORWARD != 0) && !(m_iTankmove & PUSH_FORWARD != 0))
			{
				if ( Math.RandomLong( 0,1 ) > 0 )
					g_SoundSystem.EmitSoundDyn(self.edict(), CHAN_ITEM, ACCELERE_SOUND2, 1 , ATTN_NONE, 0, 100 );
				else
					g_SoundSystem.EmitSoundDyn(self.edict(), CHAN_ITEM, ACCELERE_SOUND3, 1 , ATTN_NONE, 0, 100 );
				m_flNextSound = g_Engine.time + 2.5;
			}
		}


		//-------------------------------
		//modification de la vitesse du tank
		Math.MakeVectors( self.pev.angles );

		int iSens = int( Math.AngleDiff( Math.VecToAngles( self.pev.velocity ).y,  Math.VecToAngles( g_Engine.v_forward ).y ) );

		if ( flSpeed == 0 )
			iSens = 0;
		else if ( iSens < -45 || iSens > 45 )
			iSens = -1;
		else 
			iSens = 1;

		if ( m_pPlayer.pev.button & IN_FORWARD != 0 )
		{
			m_iTankmove |= PUSH_FORWARD;
			m_iTankmove &= ~PUSH_BACKWARD;		

			if ( iSens == -1 )
			{
				if ( flSpeed > TANK_DECCELERATION * 2 )
					vecNewVelocity = g_Engine.v_forward * - ( flSpeed - TANK_DECCELERATION );
				else
					vecNewVelocity = g_vecZero;
			}
			else if ( flSpeed < 250 )
				vecNewVelocity = g_Engine.v_forward * ( flSpeed + TANK_ACCELERATION );
			else
				vecNewVelocity = g_Engine.v_forward * 250;
		}
		else if ( m_pPlayer.pev.button & IN_BACK != 0 )
		{
			m_iTankmove |= PUSH_BACKWARD;
			m_iTankmove &= ~PUSH_FORWARD;		

			if ( iSens == 1 )
			{
				if ( flSpeed > TANK_DECCELERATION * 2 )
					vecNewVelocity = g_Engine.v_forward * ( flSpeed - TANK_DECCELERATION );
				else
					vecNewVelocity = g_vecZero;
			}
			else if ( flSpeed < 150 )
				vecNewVelocity = g_Engine.v_forward * - ( flSpeed + TANK_ACCELERATION );
			else
				vecNewVelocity = g_Engine.v_forward * -150;
		}		
		else
		{
			if ( flSpeed > 5 )
				vecNewVelocity = g_Engine.v_forward * ( flSpeed - 1 ) * iSens;
			else
				vecNewVelocity = g_Engine.v_forward * flSpeed * iSens;


			m_iTankmove &= ~PUSH_BACKWARD;
			m_iTankmove &= ~PUSH_FORWARD;
		}


		if ( iSens == 1)
		{
			m_iTankmove |= MOVE_FORWARD;
			m_iTankmove &= ~MOVE_BACKWARD;
		}
		else
		{
			m_iTankmove |= MOVE_BACKWARD;
			m_iTankmove &= ~MOVE_FORWARD;
		}



		//modification de la direction du tank
		if ( m_pPlayer.pev.button & IN_MOVELEFT != 0 )
			flNewAVelocity = TANK_ROT_SPEED;
		else if ( m_pPlayer.pev.button & IN_MOVERIGHT != 0 )
			flNewAVelocity = -TANK_ROT_SPEED;
		else
			flNewAVelocity = 0;


		// test de la position envisagée
		Math.MakeVectors ( self.pev.angles + Vector( 0, flNewAVelocity / 10 , 0) );

		TraceResult[] tr(4);/*1,tr2,tr3,tr4*/;
		Vector vecFrontLeft, vecFrontRight, vecBackLeft, vecBackRight;

		Vector NEW_ORIGIN = ( self.pev.origin + (vecNewVelocity / 10) + (g_Engine.v_up * 2) );
		vecFrontLeft =	NEW_ORIGIN + (g_Engine.v_forward * DIST_FRONT_UP) + (g_Engine.v_right * -DIST_SIDE) + (g_Engine.v_up * DIST_TOP);
		vecFrontRight = NEW_ORIGIN + (g_Engine.v_forward * DIST_FRONT_UP) + (g_Engine.v_right * DIST_SIDE)  + (g_Engine.v_up * DIST_TOP);
		vecBackLeft =	NEW_ORIGIN + (g_Engine.v_forward * DIST_BACK_UP)  + (g_Engine.v_right * -DIST_SIDE) + (g_Engine.v_up * DIST_TOP);
		vecBackRight =	NEW_ORIGIN + (g_Engine.v_forward * DIST_BACK_UP)  + (g_Engine.v_right * DIST_SIDE)  + (g_Engine.v_up * DIST_TOP);
						
		g_Utility.TraceLine(vecFrontLeft,  vecFrontRight, ignore_monsters, m_pTankBSP.self.edict(), tr[0] );
		g_Utility.TraceLine(vecFrontRight, vecBackRight,  ignore_monsters, m_pTankBSP.self.edict(), tr[1] );
		g_Utility.TraceLine(vecBackRight,  vecBackLeft,	  ignore_monsters, m_pTankBSP.self.edict(), tr[2] );
		g_Utility.TraceLine(vecBackLeft,   vecFrontLeft,  ignore_monsters, m_pTankBSP.self.edict(), tr[3] );


		//pas de collision - application de la nouvelle position
		if ( tr[0].vecEndPos == vecFrontRight && tr[1].vecEndPos == vecBackRight && tr[2].vecEndPos == vecBackLeft && tr[3].vecEndPos == vecFrontLeft )
		{
			self.StudioFrameAdvance( 0.1 );

			self.pev.velocity  = vecNewVelocity;
			self.pev.avelocity = Vector( 0, flNewAVelocity, 0 );

			m_pCam.m_vecTourelleAngle = self.pev.v_angle;
			m_pCam.m_flNextFrameTime  = self.pev.nextthink;

			self.pev.v_angle.y = flNextVAngleY;
			self.pev.v_angle.x = flNextVAngleX;

			m_pTankBSP.self.pev.velocity = (( self.pev.origin + vecNewVelocity * 10 ) - m_pTankBSP.self.pev. origin ) / 10 ;
			m_pTankBSP.self.pev.avelocity = (( self.pev.angles + Vector( 0, flNewAVelocity * 10, 0 ) - m_pTankBSP.self.pev.angles )) / 10;
			// pour combler la différence de vitesse entre le bsp et le mdl
		}
		//collision - arret du tank
		else
		{
			self.pev.velocity = self.pev.avelocity = g_vecZero;
			m_pTankBSP.self.pev.velocity  = ( self.pev.origin - m_pTankBSP.self.pev. origin ) / 10 ;
			m_pTankBSP.self.pev.avelocity = ( self.pev.angles - m_pTankBSP.self.pev.angles )  / 10;

			if ( flSpeed > 50 )	// choc violent
			{
				g_SoundSystem.EmitSoundDyn(self.edict(), CHAN_VOICE, CHOC_SOUND, 0.9, ATTN_NORM, 0, 60 );

			}
		}


		// application des dommages
		vecFrontLeft  = vecFrontLeft  + Vector( 0, 0, 10 - DIST_TOP );
		vecFrontRight = vecFrontRight + Vector( 0, 0, 10 - DIST_TOP );
		vecBackRight  = vecBackRight  + Vector( 0, 0, 10 - DIST_TOP );
		vecBackLeft   = vecBackLeft   + Vector( 0, 0, 10 - DIST_TOP );

		g_Utility.TraceLine(vecFrontLeft,  vecFrontRight, dont_ignore_monsters, m_pTankBSP.self.edict(), tr[0]);
		g_Utility.TraceLine(vecFrontRight, vecBackRight, dont_ignore_monsters,  m_pTankBSP.self.edict(), tr[1]);
		g_Utility.TraceLine(vecBackRight, vecBackLeft,	 dont_ignore_monsters,  m_pTankBSP.self.edict(), tr[2]);
		g_Utility.TraceLine(vecBackLeft,  vecFrontLeft,  dont_ignore_monsters,  m_pTankBSP.self.edict(), tr[3]);

		CBaseEntity@ pEntity = null;

		for ( uint i = 0; i < 4 ; i++ )
		{
			if ( tr[i].pHit !is null )
			{
				@pEntity = g_EntityFuncs.Instance( tr [ i ].pHit );

				if ( pEntity !is null && pEntity.pev.takedamage != DAMAGE_NO  )
				{
					float fDamage;

					if( tr[i].pHit.vars.ClassNameIs( "func_breakable" ) )
					{
						fDamage =  pEntity.pev.health;
					}
					else
					{
						fDamage = self.pev.velocity.Length() * 1.5 + 20;
					}

					pEntity.TakeDamage( self.pev, self.pev , fDamage , DMG_CRUSH );
				}
			}
		}

		//rectification de la position de la camera
		vecCamAim = UpdateCam();

		if ( m_pCam.self.pev.origin != vecCamAim )
			m_pCam.self.pev.velocity = ( vecCamAim - m_pCam.self.pev.origin ) * 10;

		UpdateCamAngle ( vecCamAim, NEXTTHINK_TIME );



		//tir de la tourelle
		if ( ( m_pPlayer.pev.button & IN_ATTACK != 0 ) && ( g_Engine.time > m_flLastAttack1 + TANK_REFIRE_DELAY ) )
		{
			Fire( bCanon );
			bCanon = ( bCanon == 1 ? 0 : 1 );

			g_SoundSystem.EmitSound(self.edict(), CHAN_AUTO, TIR_SOUND, 1, ATTN_NORM);
			m_flLastAttack1 = g_Engine.time;

			m_pCam.self.pev.avelocity.x -= 45;
		}

		//tir de la mitrailleuse
		if ( m_pPlayer.pev.button & IN_ATTACK2 != 0 )
		{
			Vector posGun, dirGun, sampah;
			self.GetAttachment( 3, posGun, sampah );
			//UTIL_MakeVectorsPrivate( TourelleAngle(), dirGun, NULL, NULL );
			Math.MakeVectors( TourelleAngle() );
			dirGun = g_Engine.v_forward;
			self.FireBullets( 1, posGun, dirGun, VECTOR_CONE_5DEGREES, 8192, BULLET_MONSTER_12MM );

			g_SoundSystem.EmitSound(self.edict(), CHAN_WEAPON, MITRAILLEUSE_SOUND, 1, ATTN_NORM);

			/*if ( !FStrEq(STRING(g_Engine.mapname), "l3m10") && !FStrEq(STRING(g_Engine.mapname), "l3m12")  && !FStrEq(STRING(g_Engine.mapname), "l3m14")  )*/
			{			
				CSprite@ pSprite = g_EntityFuncs.CreateSprite( SPRITE_MUZ, posGun, true );
				pSprite.AnimateAndDie( 15 );
				pSprite.SetTransparency( kRenderTransAdd, 255, 255, 255, 255, kRenderFxNoDissipation );
				pSprite.SetAttachment( self.edict(), 4 );
				pSprite.SetScale( SPRITE_MUZ_SCALE );
			}
		}


		//sond du tank
		UpdateSound();

		CSoundEnt@ pSoundEnt = GetSoundEntInstance();
		if( pSoundEnt !is null )
		{
			pSoundEnt.InsertSound( bits_SOUND_DANGER, self.pev.origin + (self.pev.velocity * 2.5), 150,  NEXTTHINK_TIME, null );
			pSoundEnt.InsertSound( bits_SOUND_PLAYER, self.pev.origin                            , 2000, 0.5,            null );
		}

		// Now player "sticked" to tank itself for better pain indicator
		if( m_pPlayer !is null )
		{
			g_EntityFuncs.SetOrigin( m_pPlayer, self.Center() );
		}
	}

	void StopThink()
	{
		m_pCam.SetPlayerTankView ( false );

		/*m_pCam.SetThink ( m_pCam.SUB_Remove() );
		m_pCam.pev.nextthink = g_Engine.time + 0.1;

		@m_pCam = null;*/

		g_EntityFuncs.Remove( m_pCam.self );

	//	if ( m_pPlayer.m_pActiveItem )
	//		m_pPlayer.m_pActiveItem.Deploy();

		//m_pPlayer.m_iDrivingTank	= false;
		//m_pPlayer.m_iHideHUD &= ~HIDEHUD_ALL;

		g_EntityFuncs.SetOrigin( m_pPlayer, Vector( vecCamOrigin().x, vecCamOrigin().y, vecCamOrigin().z + 30 ) );
		m_pPlayer.pev.velocity = g_vecZero;

		bTankOn = false;
		@m_pPlayer = null;

		self.pev.nextthink = g_Engine.time + 0.1;
		SetThink( ThinkFunction( this.IdleThink ) );
	}

	void DeadThink()
	{
		bTankOn = false;

		self.pev.nextthink = g_Engine.time + 0.1;

		self.pev.sequence = 0;

		// camera tournante
		self.pev.v_angle.y += 3;

		UpdateMyClassification();

		//rectification de la position de la camera
		vecCamAim = UpdateCam();

		if ( m_pCam.pev.origin != vecCamAim )
			m_pCam.pev.velocity = ( vecCamAim - m_pCam.pev.origin ) * 10;

		UpdateCamAngle ( vecCamAim, NEXTTHINK_TIME );

		// sprites de feu
		for ( uint i=0; i<4; i++ )
		{
			CSprite@ pSpr = g_EntityFuncs.CreateSprite( SPRITE_FEU, Vector(pev.origin.x,pev.origin.y,pev.origin.z + 100), true );
			pSpr.SetScale( SPRITE_FEU_SCALE );
			pSpr.AnimateAndDie( Math.RandomFloat(20,25) );
			pSpr.SetTransparency( kRenderTransAdd, 255, 255, 255, 120, kRenderFxNone );

			pSpr.pev.velocity = Vector( Math.RandomFloat(-50,50),Math.RandomFloat(-50,50),140/*Math.RandomFloat(130,150)*/ );
		}

		for ( uint i=0; i<1; i++ )
		{
			CSprite@ pSpr = g_EntityFuncs.CreateSprite( SPRITE_SMOKEBALL, Vector(pev.origin.x,pev.origin.y,pev.origin.z + 100), true );
			pSpr.SetScale ( SPRITE_SMOKEBALL_SCALE );
			pSpr.AnimateAndDie ( Math.RandomFloat(3,4) );
			pSpr.SetTransparency ( kRenderTransAlpha, 255, 255, 255, 200, kRenderFxNone );
			pSpr.pev.velocity = Vector ( Math.RandomFloat(-50,50),Math.RandomFloat(-50,50),Math.RandomFloat(130,150) );
		}
	}

	void TankDeath()
	{
		bTankDead = true;

		self.pev.sequence = 2;/*LookupSequence( "die" );*/
		self.ResetSequenceInfo();

		/* omae wa mou shindeiru --Anggara_nothing */
		if( m_pPlayer !is null )
		{
			/* Force driver out --Anggara_nothing */
			if( m_pCam !is null )
			{
				g_EntityFuncs.SetOrigin( m_pPlayer, Vector( vecCamOrigin().x, vecCamOrigin().y, vecCamOrigin().z + 90 ) );
				m_pPlayer.SetViewMode( ViewMode_ThirdPerson );
				m_pCam.SetPlayerTankView ( false );
			}

			m_pPlayer.TakeDamage( m_pPlayer.pev, m_pPlayer.pev, 31337, DMG_CRUSH );	// mouru

			@m_pPlayer = null;
		}

		self.pev.velocity = self.pev.avelocity = m_pTankBSP.pev.velocity = m_pTankBSP.pev.avelocity = g_vecZero;
		m_pTankBSP.pev.origin = self.pev.origin;
		m_pTankBSP.pev.angles = self.pev.angles;

		m_pCam.pev.velocity = m_pCam.pev.avelocity = g_vecZero;

		UpdateSound();

		SetThink( ThinkFunction( this.DeadThink ) );
		self.pev.nextthink = (g_Engine.time + 29) / 21.0;

		// maman, c'est quoi qu'a fait boum ?
		g_SoundSystem.EmitSound(self.edict(), CHAN_AUTO,   TANK_EXPLO_SOUND1, 1, ATTN_NORM);	
		g_SoundSystem.EmitSound(self.edict(), CHAN_WEAPON, TANK_EXPLO_SOUND2, 1, ATTN_NORM);	


		// sprites de feu - explosion
		for ( uint i=0; i<20; i++ )
		{
			CSprite@ pSpr = g_EntityFuncs.CreateSprite( SPRITE_FEU, Vector(self.pev.origin.x,self.pev.origin.y,self.pev.origin.z + 50), true );
			pSpr.SetScale ( SPRITE_FEU_SCALE*2 );
			pSpr.AnimateAndDie ( Math.RandomFloat(20,22) );
			pSpr.SetTransparency ( kRenderTransAdd, 255, 255, 255, 120, kRenderFxNone );

			pSpr.pev.velocity = Vector ( Math.RandomFloat(-150,150),Math.RandomFloat(-150,150),100/*Math.RandomFloat(130,150)*/ );
		}

		// sprites de feu en colonne
		for ( uint i=0; i<6; i++ )
		{
			CSprite@ pSpr = g_EntityFuncs.CreateSprite( SPRITE_FEU, Vector(self.pev.origin.x,self.pev.origin.y,self.pev.origin.z + 100), true );
			pSpr.SetScale ( SPRITE_FEU_SCALE );
			pSpr.AnimateAndDie ( Math.RandomFloat(20,25) );
			pSpr.SetTransparency ( kRenderTransAdd, 255, 255, 255, 120, kRenderFxNone );

			pSpr.pev.velocity = Vector ( Math.RandomFloat(-50,50),Math.RandomFloat(-50,50),140/*Math.RandomFloat(130,150)*/ );
		}

		for ( uint i=0; i<10; i++ )
		{
			CSprite@ pSpr = g_EntityFuncs.CreateSprite( SPRITE_SMOKEBALL, Vector(self.pev.origin.x,self.pev.origin.y,self.pev.origin.z + 100), true );
			pSpr.SetScale( SPRITE_SMOKEBALL_SCALE );
			pSpr.AnimateAndDie ( Math.RandomFloat(2,3) );
			pSpr.SetTransparency ( kRenderTransAlpha, 255, 255, 255, 255, kRenderFxNone );
			pSpr.pev.velocity = Vector ( Math.RandomFloat(-50,50),Math.RandomFloat(-50,50),Math.RandomFloat(50,50) );
		}


		// gibs
		for ( uint i = 0; i<20; i++ )
		{
			CGib@ pGib = g_EntityFuncs.CreateGib( g_vecZero, g_vecZero );

			pGib.Spawn( "models/mechgibs.mdl" );
			pGib.m_bloodColor = DONT_BLEED;
			pGib.pev.body     = Math.RandomLong (1,5);

			pGib.pev.origin    = self.pev.origin + Vector( 0, 0, 250 );
			pGib.pev.velocity  = Vector( Math.RandomFloat(-200,200),   Math.RandomFloat(-200,200),   Math.RandomFloat(0,400) );
			pGib.pev.avelocity = Vector( Math.RandomFloat(-1000,1000), Math.RandomFloat(-1000,1000), Math.RandomFloat(-1000,1000) );

			pGib.pev.solid     = SOLID_NOT;
			/*pGib.SetThink(SUB_Remove);
			pGib.pev.nextthink = g_Engine.time + 1;*/

			g_Scheduler.SetTimeout( @pGib, "SUB_Remove", 1.f );
		}

		// étincelles
		for ( uint i = 0; i < 10; i++ )
		{
			g_EntityFuncs.Create( "spark_shower", self.pev.origin, Vector(0,0,1), false, null );
		}
	}


	void Fire( int canon )
	{
		Vector vecGun, sampah;
		self.GetAttachment( canon, vecGun, sampah );

		/*if ( !FStrEq(STRING(gpGlobals.mapname), "l3m10") && !FStrEq(STRING(gpGlobals.mapname), "l3m12")  && !FStrEq(STRING(gpGlobals.mapname), "l3m14")  )*/
		{			
			CSprite@ pSprite = g_EntityFuncs.CreateSprite( SPRITE_SMOKE, vecGun, true );
			pSprite.AnimateAndDie( 15 );
			pSprite.SetTransparency( kRenderTransAdd, 255, 255, 255, 255, kRenderFxNoDissipation );
			pSprite.SetAttachment( self.edict(), canon+1 );
			pSprite.SetScale( SPRITE_SMOKE_SCALE );
		}


		TraceResult tr;

		Math.MakeVectors( TourelleAngle() );
		g_Utility.TraceLine( vecGun, vecGun + g_Engine.v_forward * 8192, dont_ignore_monsters, self.edict(), tr );

		// pas de dommages - la fonction standart donne un rayon 2.5 fois les dommages
		// 250 * 2.5 = 625	- bcp trop grand

		g_EntityFuncs.CreateExplosion( tr.vecEndPos, pev.angles, null, 250, false );

		// on applique nous-même les dommages - rayon : 250
		g_WeaponFuncs.RadiusDamage( tr.vecEndPos, self.pev, self.pev, 300, 300, CLASS_NONE, DMG_BLAST );
		
		//effet de fumée
		EnvSmokeCreate( tr.vecEndPos, 4, 10, 2, 0 );

	/*	// sprites de feu

		for ( int i=0; i<4; i++ )
		{
			for ( int j=0; j<3; j++ )
			{
				CSprite *pSpr = CSprite::SpriteCreate ( SPRITE_FEU, tr.vecEndPos + Vector(0,0,50), true );
				pSpr.SetTransparency ( kRenderTransAdd, 255, 255, 255, 180, kRenderFxNone );

				pSpr.pev.scale		= (float)((float)SPRITE_FEU_SCALE*2*(1/(i+1)));
				pSpr.pev.framerate	= Math.RandomFloat(18,24);
				pSpr.pev.velocity		= Vector ( Math.RandomFloat(-50,50)*(3-i)/3,Math.RandomFloat(-50,50)*(3-i)/3, 50*(i));
				pSpr.pev.spawnflags  |= SF_SPRITE_ONCE;
				pSpr.TurnOn();
			}
		}
	*/
	/*	for ( i=0; i<1; i++ )
		{
			CSprite *pSpr = CSprite::SpriteCreate ( SPRITE_SMOKEBALL, Vector(pev.origin.x,pev.origin.y,pev.origin.z + 100), true );
			pSpr.SetScale ( SPRITE_SMOKEBALL_SCALE );
			pSpr.AnimateAndDie ( Math.RandomFloat(3,4) );
			pSpr.SetTransparency ( kRenderTransAlpha, 255, 255, 255, 200, kRenderFxNone );
			pSpr.pev.velocity = Vector ( Math.RandomFloat(-50,50),Math.RandomFloat(-50,50),Math.RandomFloat(130,150) );
		}
	*/

		/* Mod-specific feature, removed --Anggaranothing */
		//breakable spéciaux
		//if( tr.pHit.vars.ClassNameIs("func_breakable") && tr.pHit.vars.SpawnFlagBitSet(SF_BREAK_TANKTOUCH) )
		//{
		//	CBaseEntity@ pBreak = g_EntityFuncs.Instance(tr.pHit);
		//	if ( pBreak !is null && pBreak.CheckTankPrev() )
		//	{
		//		pBreak.pev.health = 0;
		//		//pBreak.Killed( self.pev, GIB_NORMAL );
		//		//pBreak.Die();
		//	}
		//}
	}

	int ModifAngles( int angle )
	{
		if ( angle < 0 )
			return 360 - int( abs( angle ) );
		else
			return angle;
	}

	Vector UpdateCam()
	{
		TraceResult tr;
		int up   = CAM_DIST_UP;
		int back = CAM_DIST_BACK;
		Vector Aim;
		Math.MakeVectors( TourelleAngle() );

		do
		{
			Aim   = vecCamOrigin() +  ( g_Engine.v_up * up )  -  ( g_Engine.v_forward * back );
			up   -= CAM_DIST_UP / 20;
			back -= CAM_DIST_BACK / 20;

			g_Utility.TraceLine( vecCamOrigin(), Aim, ignore_monsters, self.edict(), tr );
		}
		while ( tr.vecEndPos != Aim /*|| CAM_DIST_UP == 0*/ );

		return Aim;
	}

	void UpdateCamAngle ( Vector vecNewPosition, float flTime )
	{
		Vector vecNewAngle, sampah;
		self.GetAttachment( 2, vecCamTarget, sampah );

		vecNewAngle = Math.VecToAngles( vecCamTarget - vecNewPosition );
		vecNewAngle.x = -vecNewAngle.x;

		float distX = Math.AngleDistance( m_pCam.pev.angles.x, vecNewAngle.x );
		m_pCam.pev.avelocity.x = -distX / flTime;
		
		float distY = Math.AngleDistance( m_pCam.pev.angles.y, vecNewAngle.y );
		m_pCam.pev.avelocity.y = -distY / flTime;
	}

	Vector TourelleAngle()
	{
		Math.MakeVectors( self.pev.angles );

		Vector angle = 	Math.VecToAngles( g_Engine.v_forward );

		angle.x += self.pev.v_angle.x;
		angle.y += self.pev.v_angle.y;
		
		angle.y = Math.AngleMod( angle.y );
		angle.x = -angle.x;

		return angle;
	}

	void UpdateSound()
	{
		if ( m_soundPlaying == 0 )
		{
			g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_STATIC, TANK_SOUND,      1.0, ATTN_NORM, 0, 100 );
			g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_STREAM, CHENILLES_SOUND, 0.9, ATTN_NORM, 0, 100 );
			m_soundPlaying = 1;
		}
		else
		{
			//moteur
			int pitch = int( ( self.pev.velocity.Length() * 170 / 255 ) + 80 );
			pitch = pitch > 255 ? 255 : pitch ;
			g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_BODY,   TANK_SOUND, 1.0, ATTN_NORM, SND_CHANGE_PITCH | SND_CHANGE_VOL, pitch );

			//chenilles
			int volume = int( (pev.velocity.Length()) - 30 ) / 80;
			volume = volume < 0 ? 0 : volume;
			volume = volume > 1 ? 1 : volume;
			g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_STREAM, CHENILLES_SOUND, volume, ATTN_NORM, SND_CHANGE_PITCH | SND_CHANGE_VOL, 100 );
		}
	}

	/* Update BSP classification --Anggara_nothing */
	void UpdateMyClassification()
	{
		if( m_pTankBSP !is null )
		{
			// dont use self.Classify(), it will call on scope CBaseMonster::, not CTankBSP:: !!!!!!
			m_pTankBSP.self.SetClassification( m_pTankBSP.Classify() );

			if( !bTankOn )
			{
				m_pTankBSP.self.pev.flags |= FL_NOTARGET;
			}
			else
			{
				m_pTankBSP.self.pev.flags &= ~FL_NOTARGET;
			}
		}
	}
};


//=================================
// TankCam
//

const string CTANKCAM_CLASSNAME = "info_tank_camera";
final class CTankCam : ScriptBaseEntity
{
	private EHandle m_hTankModel;
	float m_skin;
	Vector m_vecTourelleAngle;
	float m_flNextFrameTime;

	CTank@ m_pTankModel
	{
		get const { return cast<CTank@>( CastToScriptClass( m_hTankModel.GetEntity() ) ); }
		set { m_hTankModel = EHandle( @value.self ); }
	}

	void Precache()
	{
		BaseClass.Precache();

		g_Game.PrecacheModel( self, "models/tank_cam.mdl" );
	}

	void Spawn()
	{
		Precache();

		g_EntityFuncs.SetModel( self, "models/tank_cam.mdl" );
		g_EntityFuncs.SetSize( self.pev, g_vecZero, g_vecZero );

		g_EntityFuncs.SetOrigin( self, self.pev.origin );

		self.pev.movetype  = MOVETYPE_NOCLIP;
		self.pev.solid     = SOLID_NOT;

		/* Svenengine will handle this --Anggara_nothing */
		//self.pev.classname = string("info_tank_camera");	//necessaire pour le passage a la sauvegarde : getclassptr ne cree pas de self.pev.classname et donc l entite n est pas prise en compte

		self.pev.takedamage		= DAMAGE_NO;

		SetThink( ThinkFunction( this.CamThink ) );
		self.pev.nextthink = g_Engine.time + 1.5;

	}

	void CamThink()
	{
		self.pev.nextthink = g_Engine.time + BSP_NEXTTHINK_TIME;

		// fonction appelée tous les 1/20 de seconde
		// le skin des chenilles a besoin d un taux de rafraichissement eleve pour etre realiste

		// skin des chenilles
		// nombre d images : 9

		if ( m_pTankModel is null )
			return;


		m_skin += m_pTankModel.pev.velocity.Length() / 20;

		if ( int( m_skin ) != m_pTankModel.pev.skin )
		{
			while ( int( m_skin ) > 8 )	//de 0 à 8 : 9 images
			{
				m_skin -= 8;
			}
			m_pTankModel.pev.skin = int( m_skin );
		}


		if ( g_Engine.time < m_flNextFrameTime )
		{

			float flDifY = m_pTankModel.pev.v_angle.y - m_vecTourelleAngle.y;
			float flDifX = m_pTankModel.pev.v_angle.x - m_vecTourelleAngle.x;

			float flNewAngleY = ( ( g_Engine.time - ( m_flNextFrameTime - NEXTTHINK_TIME ) ) * flDifY ) / NEXTTHINK_TIME;
			float flNewAngleX = ( ( g_Engine.time - ( m_flNextFrameTime - NEXTTHINK_TIME ) ) * flDifX ) / NEXTTHINK_TIME;

			m_pTankModel.pev.set_controller( 1, GetTurretControllerValue( 1, m_vecTourelleAngle.y + flNewAngleY ) );
			m_pTankModel.pev.set_controller( 0, GetTurretControllerValue( 0, m_vecTourelleAngle.x + flNewAngleX ) );

		}

	//	if ( m_pTankModel.bSetView == true )
	//		SetPlayerTankView(true);	// rafraichissement de la positon de la camera pour le client


		if ( m_pTankModel.bTankOn == true )
			SetPlayerTankView( true );	// rafraichissement de la positon de la camera pour le client

	}

	void SetPlayerTankView( bool setOn )
	{

		// bug des dommages à la sauvegarde

		m_pTankModel.m_flTempHealth = m_pTankModel.m_pTankBSP.pev.health;

		// message client

		/*MESSAGE_BEGIN( MSG_ONE, gmsgTankView, NULL, m_pTankModel.m_pPlayer.pev );

			WRITE_BYTE	( setOn == true );
			WRITE_COORD ( ENTINDEX ( edict() ) );
			WRITE_LONG ( m_pTankModel.m_pTankBSP.pev.health );

		MESSAGE_END();*/

		CBasePlayer@ pPlr = m_pTankModel.m_pPlayer;
		if( pPlr !is null )
		{
			pPlr.ResetEffects();

			edict_t@ pPlrEdict = pPlr.edict();

			if( setOn == true )
			{
				g_EngineFuncs.SetView( pPlrEdict, self.edict() );

				pPlr.m_iEffectInvulnerable = pPlr.m_iEffectInvisible = pPlr.m_iEffectNonSolid = pPlr.m_iEffectBlockWeapons = 1;
				pPlr.m_flEffectSpeed = 0.f;
				pPlr.ApplyEffects();
			}
			else
			{
				g_EngineFuncs.SetView( pPlrEdict, pPlrEdict );

				pPlr.m_iEffectInvulnerable = pPlr.m_iEffectInvisible = pPlr.m_iEffectNonSolid = pPlr.m_iEffectBlockWeapons = 0;
				pPlr.m_flEffectSpeed = 1.f;
				pPlr.ApplyEffects();
			}
		}

	}

	int ObjectCaps() { return FCAP_ACROSS_TRANSITION; };	// traverse les changelevels

	int8 GetTurretControllerValue( int iController, float flValue )
	{
		int start_pos, end_pos;

		/* TODO : Hardcoded value, studiohdr_t is not exposed yet in Angelscript --Anggara_nothing */
		switch( iController )
		{
			case 0 :
				start_pos = -10;
				end_pos   =  25;
				break;

			case 1 :
				start_pos = -120;
				end_pos   =  120;
				break;
		}

		/*studiohdr_t *pstudiohdr;
		
		pstudiohdr = (studiohdr_t *)pmodel;
		if (! pstudiohdr)
			return flValue;

		mstudiobonecontroller_t	*pbonecontroller = (mstudiobonecontroller_t *)((byte *)pstudiohdr + pstudiohdr->bonecontrollerindex);

		// find first controller that matches the index
		for (int i = 0; i < pstudiohdr->numbonecontrollers; i++, pbonecontroller++)
		{
			if (pbonecontroller->index == iController)
				break;
		}
		if (i >= pstudiohdr->numbonecontrollers)
			return flValue;*/

		// wrap 0..360 if it's a rotational controller
		//if (pbonecontroller->type & (STUDIO_XR | STUDIO_YR | STUDIO_ZR))
		{
			// ugly hack, invert value if end < start
			if( end_pos < start_pos )
				flValue = -flValue;

			// does the controller not wrap?
			if( start_pos + 359.0 >= end_pos )
			{
				if (flValue > ((start_pos + end_pos) / 2.0) + 180)
					flValue = flValue - 360;
				if (flValue < ((start_pos + end_pos) / 2.0) - 180)
					flValue = flValue + 360;
			}
			else
			{
				if (flValue > 360)
					flValue = flValue - int( (flValue / 360.0) ) * 360.0;
				else if (flValue < 0)
					flValue = flValue + int( ((flValue / -360.0) + 1) ) * 360.0;
			}
		}

		int setting = int( 255 * (flValue - start_pos) / (end_pos - start_pos) );

		if (setting < 0) setting = 0;
		if (setting > 255) setting = 255;
		
		return int8( setting );
	}

};




//==================================
// TankBSP

const string CTANKBSP_CLASSNAME = "vehicle_tank";
final class CTankBSP : ScriptBaseEntity/*Monster*/
{
	private EHandle m_hTankModel;

	CTank@ m_pTankModel
	{
		get const { return cast<CTank@>( CastToScriptClass( m_hTankModel.GetEntity() ) ); }
		set { m_hTankModel = EHandle( @value.self ); }
	}

	void Precache()
	{
		g_Game.PrecacheOther( CTANK_CLASSNAME );
	}

	void Spawn()
	{
		Precache();

		self.pev.solid			= SOLID_BSP;
		self.pev.movetype		= MOVETYPE_PUSH;

		g_EntityFuncs.SetModel( self, self.pev.model );
		
		g_EntityFuncs.SetSize( self.pev, self.pev.mins, self.pev.maxs );
		g_EntityFuncs.SetOrigin( self, self.pev.origin );

		//self.pev.flags			|= FL_MONSTER;
		self.pev.takedamage		= DAMAGE_YES;
		self.pev.rendermode		= kRenderTransTexture;
		self.pev.renderamt		= 0;
		self.pev.view_ofs		= Vector( 0,0,100 );

		self.pev.health			= TANK_LIFE;

		/*m_pTankModel = GetClassPtr( (CTank*)NULL );
		UTIL_SetOrigin( m_pTankModel.pev, self.pev.origin );
		m_pTankModel.self.pev.angles = self.pev.angles;
		m_pTankModel.m_pTankBSP = this;
		m_pTankModel.Spawn();*/

		// Create tank "monster" --Anggara_nothing
		CBaseEntity@ pEntity = g_EntityFuncs.Create( CTANK_CLASSNAME, self.pev.origin, self.pev.angles, true, self.edict() );
		CTank@ pTankModel = cast<CTank@>( CastToScriptClass( @pEntity ) );

		if( pTankModel is null )
		{
			// failed to create CTank!!! mission abort!! mission abort!!
			g_EntityFuncs.Remove( @pEntity );
		}
		else
		{
			@m_pTankModel = @pTankModel;
			@m_pTankModel.m_pTankBSP = @this;
			g_EntityFuncs.DispatchSpawn( pEntity.edict() );
		}

		SetThink( ThinkFunction( this.TankThink ) );
		SetTouch( TouchFunction( this.TouchPlayer ) );
		self.pev.nextthink = self.pev.ltime + 0xFF;

	}

	int Classify()
	{
		// trouve le model

		//edict_t *pent = FIND_ENTITY_BY_CLASSNAME ( NULL, "info_tank_model" );

		if ( m_pTankModel is null )
			return CLASS_NONE;

		//CTank *pTank = (CTank*) CBaseEntity::Instance(pent);

		// classe selon l'état du tank

		if ( m_pTankModel.bTankOn == true )
			return CLASS_PLAYER_ALLY;

		return CLASS_NONE;
	}

	void TankThink()
	{
		//ne sert strictement à rien mais sans cette fonction think, les vecteurs vitesse ne veulent pas s'appliquer à mon tank
		self.pev.nextthink = self.pev.ltime + 0xFF;
	}

	void Blocked( CBaseEntity@ pOther )
	{
		pOther.TakeDamage( self.pev, self.pev, 0xFF, DMG_CRUSH );
	}

	void TraceAttack(entvars_t@ pevAttacker, float flDamage, const Vector& in vecDir, TraceResult& in ptr, int bitsDamageType)
	{
		BaseClass.TraceAttack( pevAttacker, flDamage, vecDir, ptr, bitsDamageType );
	}

	int TakeDamage(entvars_t@ pevInflictor, entvars_t@ pevAttacker, float flDamage, int bitsDamageType)
	{
		if( m_pTankModel is null )
			return 0;

		m_pTankModel.m_flTempHealth = self.pev.health;

		if ( m_pTankModel.bTankOn == false )
			return 1;

		// le joueur ne le blesse pas - debug
		if ( pevInflictor.ClassNameIs("player") )
			return 1;

		// que des dégâts par explosifs
		if ( (bitsDamageType & DMG_BLAST) == 0 )
			return 1;

		// ne se blesse pas lui meme
		if ( pevInflictor is m_pTankModel.pev )
			return 1;

		// déjà mort
		if ( pev.health == 0 )
			return 1;

		// mine antichar
		if ( pevInflictor.ClassNameIs(CMINEAC_CLASSNAME) || pevAttacker.ClassNameIs(CMINEAC_CLASSNAME) )
			self.pev.health = 0;

		self.pev.health -= flDamage;

		// pas quand le tank est eteint
		if ( m_pTankModel.m_pCam !is null )
		{
			m_pTankModel.m_pCam.SetPlayerTankView( true );	// rafraichissement de la vie côté client

			if ( self.pev.health <= 0 )
			{
				self.pev.health = 0;
				m_pTankModel.TankDeath();
				return 0;
			}
		}

		return 1;
	}

	void TouchPlayer(CBaseEntity@ pOther)
	{
		if ( !pOther.IsPlayer() )
			return;

		// le joueur n active le tank que s il le touche et qu il  est a peu pres au meme niveau que le tank pour eviter que le joueur sortant sur le toit du tank ne l active a nouveau
		if ( pOther.pev.origin.z > self.pev.origin.z + 48 )
			return;

		//	m_pTankModel.UseTank( pOther, pOther, USE_TOGGLE, 0 );

		/*edict_t *pent = FIND_ENTITY_BY_CLASSNAME ( NULL, "info_tank_model" );

		if ( pent == NULL )
			return;

		CTank *pTank = (CTank*) CBaseEntity::Instance(pent);*/

		if ( m_pTankModel is null )
			return;

		m_pTankModel.UseTank( pOther, pOther, USE_TOGGLE, 0 );

	}

	int BloodColor() { return DONT_BLEED; };
	int ObjectCaps() { return BaseClass.ObjectCaps() & ~FCAP_ACROSS_TRANSITION; }
};


//----------------------------------------------------------
// mine anti char
const string CMINEAC_CLASSNAME = "monster_mine_ac";
final class CMineAC : ScriptBaseEntity
{
	void Precache()
	{
		g_Game.PrecacheModel( self, "models/dxmine.mdl" );
	}

	void Spawn()
	{
		Precache();

		g_EntityFuncs.SetModel(  self, "models/dxmine.mdl" );

		g_EntityFuncs.SetSize(   self.pev, VEC_HUMAN_HULL_MIN, VEC_HUMAN_HULL_MAX);
		g_EntityFuncs.SetOrigin( self, self.pev.origin );

		self.pev.movetype = MOVETYPE_NOCLIP;
		self.pev.solid = SOLID_NOT;

		SetThink( ThinkFunction( this.MineThink ) );
		self.pev.nextthink = g_Engine.time + 0.1;
	}

	void MineThink()
	{
		self.pev.nextthink = g_Engine.time + 0.1;

		TraceResult tr;
		g_Utility.TraceHull( self.pev.origin, self.pev.origin + Vector(0,0,20), dont_ignore_monsters, head_hull, self.edict(), tr );

		if ( tr.pHit is null )
			return;

		// Added classname check --Anggara_nothing
		if ( tr.pHit.vars.FlagBitSet(FL_MONSTER) || tr.pHit.vars.FlagBitSet(FL_CLIENT) || tr.pHit.vars.ClassNameIs( CTANKBSP_CLASSNAME ) )
		{
			g_EntityFuncs.CreateExplosion( self.pev.origin + Vector(0,0,30), Vector(0,0,0), self.edict(), 200, true );
			g_EntityFuncs.Remove( self );
		}
	}
};


//-------------------------------------------------------
// Tank Charger
const string CTANKCHARGER_CLASSNAME = "func_tank_charger";
final class CTankCharger : ScriptBaseEntity
{
	void Spawn()
	{
		self.pev.movetype = MOVETYPE_NONE;
		self.pev.solid    = SOLID_TRIGGER;
		g_EntityFuncs.SetModel( self, self.pev.model );    // set size and link into world

		self.pev.effects |= EF_NODRAW;

		SetThink( ThinkFunction( this.ChargerThink ) );
		self.pev.nextthink = g_Engine.time + 0.1;
	}

	void ChargerThink()
	{
		self.pev.nextthink = g_Engine.time + 0.1;

		Vector vecStart = (self.pev.mins+self.pev.maxs)*0.5,
	           vecEnd   = vecStart + Vector(0,0,100);

		TraceResult tr;
		g_Utility.TraceHull( vecStart, vecEnd, dont_ignore_monsters, head_hull, self.edict(), tr );

		if ( tr.pHit is null )
				return;

		// Monster flag removed because not working correctly --Anggara_nothing
		if ( /*tr.pHit.vars.FlagBitSet(FL_MONSTER) &&*/ tr.pHit.vars.ClassNameIs( CTANKBSP_CLASSNAME ) )
		{
			CTankBSP@ pBsp = cast<CTankBSP@>( CastToScriptClass( g_EntityFuncs.Instance(tr.pHit) ) );

			if( pBsp !is null )
			{
				pBsp.self.pev.health = Math.min( pBsp.self.pev.health + TANK_RECHARGE, TANK_LIFE );

				// rafraichissement de l'affichage
				if ( pBsp.m_pTankModel !is null && pBsp.m_pTankModel.bTankOn == true )
					pBsp.m_pTankModel.m_pCam.SetPlayerTankView ( true );
			}
		}
	}
};

} // End of HLI::TANK namespace

namespace SMOKE
{
int g_sModelIndexSmoke;
void RegisterEnvSmokeEntity()
{
	g_sModelIndexSmoke = g_Game.PrecacheModel("sprites/steam1.spr");// smoke

	g_CustomEntityFuncs.RegisterCustomEntity( "HLI::SMOKE::CEnvSmoke", CENVSMOKE_CLASSNAME );
}

const string CENVSMOKE_CLASSNAME = "env_smoke";
//-----------------------------------------------------
//	Modif de Julien
//	Env_smoke
//-----------------------------------------------------
// entité permettant d'émettre de la fumée
final class CEnvSmoke : ScriptBaseEntity
{
	int	m_iScale;
	float m_fFrameRate;
	int m_iTime;
	float m_iEndTime;

	bool KeyValue( const string& in szKeyName, const string& in szValue )
	{
		if (szKeyName == "m_iScale")
		{
			m_iScale = atoi( szValue );
			return true;
		}
		else if (szKeyName == "m_iFrameRate")
		{
			m_fFrameRate = atof( szValue );
			return true;
		}
		else if (szKeyName == "m_iTime")
		{
			m_iTime = atoi( szValue );
			return true;
		}
		else
			return BaseClass.KeyValue( szKeyName, szValue );
	}

	void Spawn()
	{
		self.pev.solid   = SOLID_NOT;
		self.pev.effects = EF_NODRAW;
	}

	void Use(CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue = 0.0f)
	{
		m_iEndTime = g_Engine.time + m_iTime;

		SetThink( ThinkFunction( this.SmokeThink ) );
		self.pev.nextthink = g_Engine.time + 0.1;
	}

	void SmokeThink()
	{
		self.pev.nextthink = g_Engine.time + 0.5;

		if ( g_Engine.time > m_iEndTime )
		{
			SetThink( null );
			g_Scheduler.SetTimeout( @self, "SUB_Remove", 0.f );
		}

		NetworkMessage m( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, self.pev.origin );
			m.WriteByte(TE_SMOKE);
			m.WriteCoord(self.pev.origin.x);
			m.WriteCoord(self.pev.origin.y);
			m.WriteCoord(self.pev.origin.z);
			m.WriteShort( g_sModelIndexSmoke );
			m.WriteByte( m_iScale * 10 ); // scale * 10
			m.WriteByte( uint8( Math.RandomFloat( m_fFrameRate + 5, m_fFrameRate ) ) ); // framerate
		m.End();
	}
};

} // End of HLI::SMOKE namespace
} // End of HLI namespace
