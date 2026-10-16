//=============================================================================
// HXFixMissionEndgame.
//
// HX switched on LocalURL (upper case, e.g. "ENDGAME1") against "Endgame1",
// so the ending conversation never started and players were stuck forever.
// Also ExplosionEffects used the never set MissionScript.Player.
//=============================================================================
class HXFixMissionEndgame extends HXMissionEndgame;

function StartCinematic()
{
	local string MapName;
	local Name ConName;
	local int MissionNumber;

	EndgameTimer = 0.0;

	// LocalURL is "NOTHING" here, go by the level name.
	MapName = Caps( string(Level.Outer.Name) );

	Log( Self $ ": StartCinematic on" @ MapName, 'HXFix' );
	if ( InStr(MapName,"ENDGAME1")>=0 )
		ConName = 'Endgame1';
	else if ( InStr(MapName,"ENDGAME2")>=0 )
		ConName = 'Endgame2';
	else if ( InStr(MapName,"ENDGAME3")>=0 )
		ConName = 'Endgame3';
	else
	{
		Log( Self $ ": no endgame conversation for" @ MapName, 'HXFix' );
		return;
	}

	// The GameInfo conversation list is only bound lazily by the datalink code.
	if ( Game.ConListItems==None && Game.DeusExLevelInfo!=None )
	{
		MissionNumber = Game.DeusExLevelInfo.MissionNumber;
		if ( MissionNumber>=0 && MissionNumber<=9 )
			class'HXActor'.static.BindConversationList( "DeusExConText.ConList_Mission0" $ MissionNumber, Game );
		else if ( MissionNumber>=10 && MissionNumber<=99 )
			class'HXActor'.static.BindConversationList( "DeusExConText.ConList_Mission" $ MissionNumber, Game );
	}

	if ( !Game.StartCinematicByName(ConName, Game) )
	{
		// Never leave players stuck: skip straight to the quote and credits.
		Log( Self $ ": failed to start" @ ConName $ ", skipping to quote", 'HXFix' );
		SetBoolFlag( class'HXActor'.static.StringToName(string(ConName)$"_Played"), True, True, 0 );
	}
}

// Same as stock, but stays on HXFixGameInfo (and keeps a live test running).
function FinishCinematic()
{
	local string URL;

	SetBoolFlag( 'EndgameExplosions', False, True, 1 );
	SetTimer( 0, False );

	URL = "00_Intro?Game=HXFix.HXFixGameInfo";
	if ( HXFixGameInfo(Game)!=None && HXFixGameInfo(Game).LiveTestName!="" )
		URL = URL $ "?HXFixTest=" $ HXFixGameInfo(Game).LiveTestName;
	Log( Self $ ": endgame finished, travelling to" @ URL, 'HXFix' );
	Level.ServerTravel( URL $ "#", False );
}

function ExplosionEffects()
{
	local Pawn P;

	for ( P=Level.PawnList; P!=None; P=P.NextPawn )
		if ( HXPlayerPawn(P)!=None && !P.bDeleteMe )
			ExplosionEffectsAt( P );
}

function ExplosionEffectsAt( Pawn Target )
{
	local float Size;
	local int i;
	local Vector Loc, EndLoc, HitLocation, HitNormal;
	local Actor HitActor;
	local MetalFragment Frag;

	if ( FRand()>=0.8 )
		return;

	// pick a random explosion size and modify everything accordingly
	Size = FRand();

	if ( Size<0.5 )
		Target.PlaySound( Sound'LargeExplosion1', SLOT_None, 2.0,, 16384 );
	else
		Target.PlaySound( Sound'LargeExplosion2', SLOT_None, 2.0,, 16384 );

	// have random metal fragments fall from the ceiling
	if ( FRand()>=0.8 )
		return;

	for ( i=0; i<Int(Size*10.0); i++ )
	{
		Loc = Target.Location + 512.0 * VRand();
		Loc.Z = Target.Location.Z;
		EndLoc = Loc;
		EndLoc.Z += 1024.0;
		HitActor = Trace( HitLocation, HitNormal, EndLoc, Loc, False );
		if ( HitActor==None )
			HitLocation = EndLoc;

		if ( Size<0.5 )
			Spawn( class'ExplosionMedium',,, HitLocation+8*HitNormal );
		else
			Spawn( class'ExplosionLarge',,, HitLocation+8*HitNormal );

		if ( FRand()<0.5 )
		{
			Frag = Spawn( class'MetalFragment',,, HitLocation );
			if ( Frag!=None )
			{
				Frag.CalcVelocity( vect(20000,0,0), 256 );
				Frag.DrawScale = 0.5 + 2.0 * FRand();
				if ( FRand()<0.75 )
					Frag.bSmoking = True;
			}
		}
	}
}
