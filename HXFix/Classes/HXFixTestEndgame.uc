//=============================================================================
// HXFixTestEndgame.
//
// Start on 99_Endgame1/2/3 with 2 players. The ending conversation (or the
// fallback) must set Endgame<N>_Played, then the script travels on to
// 00_Intro, where the test finishes (stage 1).
//=============================================================================
class HXFixTestEndgame extends HXFixTestTravelBase;

var bool bSawConPlay;
var int Waited;

function PostBeginPlay()
{
	TimeoutSeconds = 240.0;
	Super.PostBeginPlay();
}

function Name PlayedFlag()
{
	local string M;

	M = string( Level.Outer.Name );
	if ( InStr(Caps(M),"ENDGAME2")>=0 )
		return 'Endgame2_Played';
	if ( InStr(Caps(M),"ENDGAME3")>=0 )
		return 'Endgame3_Played';
	return 'Endgame1_Played';
}

function float RunStep( int StepNum )
{
	local Pawn P;
	local int Num;

	if ( Stage()>=1 || InStr(Caps(string(Level.Outer.Name)),"INTRO")>=0 )
	{
		for ( P=Level.PawnList; P!=None; P=P.NextPawn )
			if ( HXPlayerPawn(P)!=None && PlayerPawn(P).Player!=None )
				Num++;
		Check( Level.Outer.Name=='00_Intro' || InStr(Caps(string(Level.Outer.Name)),"INTRO")>=0, "travelled on to the intro map:" @ Level.Outer.Name );
		Check( Num>=2, "both players arrived:" @ Num );
		return -1;
	}

	if ( StepNum==0 )
		Note( "map" @ Level.Outer.Name @ "script" @ Game.MissionScript.Class @ "watching" @ PlayedFlag() );

	if ( Game.ConPlay!=None && !bSawConPlay )
	{
		bSawConPlay = True;
		Note( "ending conversation running:" @ Game.ConPlay.Con @ "after" @ Waited @ "s" );
	}

	if ( Game.Steve.FlagBase.GetBool(PlayedFlag()) )
	{
		Check( True, PlayedFlag() @ "set after" @ Waited @ "s (conversation seen:" @ bSawConPlay $ ")" );
		// Now the script must travel on by itself.
		SetStage( 1 );
		return 200.0;
	}

	Waited++;
	return 1.0;
}
