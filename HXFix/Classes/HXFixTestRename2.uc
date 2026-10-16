//=============================================================================
// HXFixTestRename2.
//
// Run with the host named like the client (both "Tester1"): the server renames
// the joining client to "Tester1_2" at login. The client's user ini must keep
// Name=Tester1 (checked by the caller).
//=============================================================================
class HXFixTestRename2 extends HXFixTestBase;

function float RunStep( int StepNum )
{
	local HXPlayerPawn R, H;

	R = Remote();
	H = Host();
	if ( StepNum==0 )
	{
		Check( R!=None && H!=None, "host and remote present" );
		Check( H.PlayerReplicationInfo.PlayerName=="Tester1", "host is Tester1 (" $ H.PlayerReplicationInfo.PlayerName $ ")" );
		Check( R.PlayerReplicationInfo.PlayerName=="Tester1_2", "joining duplicate renamed (" $ R.PlayerReplicationInfo.PlayerName $ ")" );
		return 6.0;
	}
	return -1;
}

defaultproperties
{
	TimeoutSeconds=90.000000
}
