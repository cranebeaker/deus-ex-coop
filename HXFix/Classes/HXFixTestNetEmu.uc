//=============================================================================
// HXFixTestNetEmu.
//
// Measures the host <-> client round trip through the test driver, to check
// that ?HXFixNetEmu=PktLag=... really slows the connection down. The test
// timer runs in 0.25s steps, so the reported ping is the finer number.
//=============================================================================
class HXFixTestNetEmu extends HXFixTestBase;

var HXPlayerPawn R;
var HXFixTestDriver D;
var int Sent, Got, LastReports;
var float SentAt, Total, Worst;

function float RunStep( int StepNum )
{
	if ( StepNum==0 )
	{
		R = Remote();
		D = DriverFor( R );
		if ( !Check(R!=None && D!=None, "remote client and driver present") )
			return -1;
		return 2.0;
	}

	if ( Sent>Got )
	{
		if ( D.Reports>LastReports )
		{
			Got++;
			Total += Level.TimeSeconds-SentAt;
			Worst  = FMax( Worst, Level.TimeSeconds-SentAt );
		}
		else if ( Level.TimeSeconds-SentAt>10 )
		{
			Check( False, "reply" @ Sent @ "lost" );
			return -1;
		}
		else
			return 0.05;
	}

	if ( Got>=10 )
	{
		Note( "round trip avg=" $ int(1000*Total/Got) $ "ms worst=" $ int(1000*Worst) $ "ms ping=" $ R.PlayerReplicationInfo.Ping );
		Check( True, "10 round trips completed" );
		return -1;
	}

	LastReports = D.Reports;
	SentAt = Level.TimeSeconds;
	Sent++;
	ClientCmd( R, "get Engine.GameEngine CacheSizeMegs" );
	return 0.05;
}
