//=============================================================================
// HXFixTestNanoKey.
//
// A key the team holds must make the client side datalink NK_<KeyID> check
// take the same branch as the server (HasKey). Missing key is the control.
//=============================================================================
class HXFixTestNanoKey extends HXFixTestBase;

var HXPlayerPawn R;
var HXFixTestWeaponDriver D;
var int LastSeq;

function float RunStep( int StepNum )
{
	local HXGameInfo G;

	switch ( StepNum )
	{
		case 0:
			R = Remote();
			if ( !Check(R!=None, "remote client present") )
				return -1;
			D = HXFixTestWeaponDriver( DriverFor(R) );
			if ( !Check(D!=None, "driver present") )
				return -1;
			G = HXGameInfo( Level.Game );
			G.GiveKey( 'HXFixTestKeyAbc', "HXFix Test Key Description", True );
			Check( G.HasKey('HXFixTestKeyAbc'), "server has the key" );
			return 3.0;

		case 1:
			LastSeq = D.MSeq;
			D.ClientProbeKey( "NK_HXFixTestKeyAbc" );
			return 2.0;

		case 2:
			Check( D.MSeq>LastSeq && D.bKeyHas, "client datalink: team key found via NK_ID (label '" $ D.KeyLabel $ "')" );
			LastSeq = D.MSeq;
			D.ClientProbeKey( "NK_HXFixNoSuchKey" );
			return 2.0;

		case 3:
			Check( D.MSeq>LastSeq && !D.bKeyHas && D.KeyLabel=="FAILED", "control: missing key takes fail branch (label '" $ D.KeyLabel $ "')" );
			LastSeq = D.MSeq;
			D.ClientProbeKey( "NK_hxfixtestkeyabc" );
			return 2.0;

		case 4:
			Check( D.MSeq>LastSeq && D.bKeyHas, "client key check is case-insensitive like the server (label '" $ D.KeyLabel $ "')" );
			HXGameInfo(Level.Game).RemoveKey( 'HXFixTestKeyAbc' );
			return 3.0;
		case 5:
			LastSeq = D.MSeq;
			D.ClientProbeKey( "NK_HXFixTestKeyAbc" );
			return 2.0;

		case 6:
			Check( D.MSeq>LastSeq && !D.bKeyHas, "removed key no longer found on client (label '" $ D.KeyLabel $ "')" );
			HXGameInfo(Level.Game).GiveKey( 'HXFixTestKeyAbc', "HXFix Test Key Description", True );
			return 3.0;
		case 7:
			// Key ring screen prints every description slot: the key must be listed once.
			Check( CountSlots("HXFix Test Key Description")==1 && CountSlots("HXFixTestKeyAbc")==0, "key listed once in the key ring (desc=" $ CountSlots("HXFix Test Key Description") $ " id=" $ CountSlots("HXFixTestKeyAbc") $ ")" );
			return -1;
	}
	return -1;
}

function int CountSlots( string What )
{
	local HXFixNanoKeyInfo Info;
	local int i, Num;

	Info = HXFixNanoKeyInfo( HXGameInfo(Level.Game).NanoKeyReplicationInfo );
	if ( Info==None )
		return -1;
	for ( i=0; i<Info.NanoKeyCount; i++ )
		if ( Info.SlotAt(i)~=What )
			Num++;
	return Num;
}

defaultproperties
{
	DriverClass=Class'HXFixTestWeaponDriver'
	TimeoutSeconds=330.000000
}
