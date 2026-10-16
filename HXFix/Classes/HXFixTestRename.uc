//=============================================================================
// HXFixTestRename.
//
// Name rules: 20 characters, reserved internal names rejected, unique names.
// A server assigned "Name_2" must not end up in the client's user ini
// (checked by the caller: Client1User.ini Name= must be Tester1 afterwards).
//=============================================================================
class HXFixTestRename extends HXFixTestBase;

var HXPlayerPawn R, H;

function string RName() { return R.PlayerReplicationInfo.PlayerName; }

function float RunStep( int StepNum )
{
	switch ( StepNum )
	{
		case 0:
			R = Remote();
			H = Host();
			if ( !Check(R!=None && H!=None, "host and remote present") )
				return -1;
			Note( "host name" @ H.PlayerReplicationInfo.PlayerName @ "remote name" @ RName() );
			ClientCmd( R, "SetName Fresh1" );
			return 2.0;

		case 1:
			Check( RName()=="Fresh1", "control: SetName Fresh1 (now" @ RName() $ ")" );
			ClientCmd( R, "SetName ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789" );
			return 2.0;

		case 2:
			Check( Len(RName())<=20 && Left(RName(),5)=="ABCDE", "long name cut to 20 (now" @ RName() $ ")" );
			ClientCmd( R, "SetName __INTERNAL_Steve_X" );
			return 2.0;

		case 3:
			Check( InStr(Caps(RName()),"__INTERNAL_STEVE_")==-1, "reserved name rejected (now" @ RName() $ ")" );
			ClientCmd( R, "SetName " $ H.PlayerReplicationInfo.PlayerName );
			return 2.0;

		case 4:
			Check( RName()==(H.PlayerReplicationInfo.PlayerName$"_2"), "SetName to host name made unique (now" @ RName() $ ")" );
			// Caller: Client1User.ini must now say Name=<typed name> (what the user typed), not <typed name>_2.
			return 6.0;

		case 5:
			return -1;
	}
	return -1;
}

defaultproperties
{
	TimeoutSeconds=90.000000
}
