//=============================================================================
// HXFixTestStartup.
//
// The startup message (location banner) must be shown on the remote client by
// HXFixGameReplicationInfo.
//=============================================================================
class HXFixTestStartup extends HXFixTestConBase;

var HXPlayerPawn R;

function float RunStep( int StepNum )
{
	local DeusExLevelInfo Info;

	switch ( StepNum )
	{
		case 0:
			R = Remote();
			if ( !Check(R!=None, "remote present") )
				return -1;
			foreach AllActors( class'DeusExLevelInfo', Info )
				Note( "startup message[0]:" @ Info.StartupMessage[0] );
			Check( Game.bShowStartupMessage, "server wants the startup message shown" );
			return 8.0;

		case 1:
			Probe( R, "startup", "" );
			return 2.0;

		case 2:
			if ( Pending(R) )
				return Again();
			Check( ProbeValue(R)==1, "remote showed the startup message (" $ ProbeValue(R) $ ")" );
			return -1;
	}
	return -1;
}

defaultproperties
{
	TimeoutSeconds=120.000000
}
