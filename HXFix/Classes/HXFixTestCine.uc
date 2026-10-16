//=============================================================================
// HXFixTestCine.
//
// Cinematic map with a joining client: the host's pawn must not be hijacked
// by the client's cinematic, NotifyUp must run once per player.
//=============================================================================
class HXFixTestCine extends HXFixTestBase;

function float RunStep( int StepNum )
{
	local HXPlayerPawn R, H;

	R = Remote();
	H = Host();
	switch ( StepNum )
	{
		case 0:
			Check( R!=None && H!=None, "host and remote present" );
			Note( "host" @ H @ "state" @ H.GetStateName() @ "hidden" @ H.bHidden @ "collide" @ H.bCollideActors @ "bOnCinematicMap" @ H.bOnCinematicMap );
			Note( "remote" @ R @ "state" @ R.GetStateName() @ "hidden" @ R.bHidden @ "collide" @ R.bCollideActors @ "bOnCinematicMap" @ R.bOnCinematicMap );
			Check( H.GetStateName()=='Paralyzed' && R.GetStateName()=='Paralyzed' && H.bOnCinematicMap && R.bOnCinematicMap, "both players set up for the cinematic" );
			// Caller: Host log has exactly one ClientStartCinematicCamera (the host's own).
			return 4.0;

		case 1:
			Note( "host" @ H @ "state" @ H.GetStateName() @ "hidden" @ H.bHidden @ "loc" @ H.Location );
			Note( "remote" @ R @ "state" @ R.GetStateName() @ "hidden" @ R.bHidden @ "loc" @ R.Location );
			return -1;
	}
	return -1;
}

defaultproperties
{
	TimeoutSeconds=90.000000
}
