//=============================================================================
// HXFixTestJumpSync.
//
// Another player must see a jump: rise in the air and play a jump animation.
// Control: the listen host jumps, a remote client watches. Then remote client
// A jumps through its real input (the jump key's bPressedJump) and remote client B watches.
// Needs 2 remote clients.
//=============================================================================
class HXFixTestJumpSync extends HXFixTestBase;

var HXPlayerPawn H, A, B;
var HXFixJumpWatchDriver DB, DA;
var int LastSeq;
var float ServerStartZ, ServerMaxRise;
var bool bTrackServer;

function Tick( float DeltaTime )
{
	Super.Tick( DeltaTime );
	if ( bTrackServer && A!=None )
		ServerMaxRise = FMax( ServerMaxRise, A.Location.Z - ServerStartZ );
}

function float RunStep( int StepNum )
{
	switch ( StepNum )
	{
		case 0:
			H  = Host();
			A  = Remote(0);
			B  = Remote(1);
			DB = HXFixJumpWatchDriver( DriverFor(B) );
			DA = HXFixJumpWatchDriver( DriverFor(A) );
			if ( !Check(H!=None && A!=None && B!=None && DB!=None && DA!=None, "host and two remote clients with probes") )
				return -1;
			H.ReducedDamageType = 'All'; A.ReducedDamageType = 'All'; B.ReducedDamageType = 'All';
			return 2.0;

		case 1:
			// Control: host jumps, B watches.
			LastSeq = DB.Seq;
			DB.ClientWatch( H, 2.0 );
			H.DoJump();
			return 3.0;

		case 2:
			Check( DB.Seq>LastSeq, "observer reported (host jump)" );
			Note( "B saw host: rise=" $ DB.RMaxRise @ "anims:" $ DB.RAnims );
			Check( DB.RMaxRise>20, "control: observer sees the host rise (" $ DB.RMaxRise $ ")" );
			return 1.0;

		case 3:
			// Remote client A jumps with its real input, B watches, server tracks.
			LastSeq = DB.Seq;
			DB.ClientWatch( A, 2.0 );
			DA.ClientWatch( A, 2.0 );
			ServerStartZ = A.Location.Z;
			ServerMaxRise = 0;
			bTrackServer = True;
			DA.ClientPressJump();
			return 3.0;

		case 4:
			bTrackServer = False;
			Note( "server saw A: rise=" $ ServerMaxRise );
			Note( "B saw A: rise=" $ DB.RMaxRise @ "anims:" $ DB.RAnims );
			Note( "A saw itself: rise=" $ DA.RMaxRise @ "anims:" $ DA.RAnims @ "physics=" $ A.Physics @ "state=" $ A.GetStateName() );
			Check( ServerMaxRise>20, "server sees remote client A jump (" $ ServerMaxRise $ ")" );
			Check( DB.Seq>LastSeq && DB.RMaxRise>20, "observer B sees remote client A rise (" $ DB.RMaxRise $ ")" );
			Check( InStr(DB.RAnims, "Jump")>=0 || InStr(DB.RAnims, "Land")>=0 || InStr(DB.RAnims, "Fall")>=0, "observer B sees a jump animation on A (" $ DB.RAnims $ ")" );
			return -1;
	}
	return -1;
}

defaultproperties
{
	MinPlayers=3
	DriverClass=Class'HXFixJumpWatchDriver'
	TimeoutSeconds=200.000000
}
