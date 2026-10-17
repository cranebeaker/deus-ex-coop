//=============================================================================
// HXFixJumpWatchDriver.
//
// Client side probe for HXFixTestJumpSync: watches another player's pawn as
// this client sees it (height above its start, animations played) for a few
// seconds and reports back.
//=============================================================================
class HXFixJumpWatchDriver extends HXFixTestDriver;

var Pawn Watched;
var float WatchLeft, StartZ, MaxRise;
var string Anims;
var int Seq;
var float RMaxRise;
var string RAnims;

replication
{
	reliable if ( Role==ROLE_Authority )
		ClientWatch, ClientPressJump;
	reliable if ( Role<ROLE_Authority )
		ServerWatchReport;
}

simulated function ClientWatch( Pawn P, float Seconds )
{
	Watched = P;
	WatchLeft = Seconds;
	MaxRise = 0;
	Anims = "";
	if ( P!=None )
		StartZ = P.Location.Z;
}

// What pressing the jump key does: the "Jump" binding is an input alias
// (Axis aUp), so typing "Jump" as a console command does nothing.
simulated function ClientPressJump()
{
	if ( PlayerPawn(Owner)!=None )
		PlayerPawn(Owner).bPressedJump = True;
}

simulated function Tick( float DeltaTime )
{
	local string A;

	Super.Tick( DeltaTime );
	if ( Role==ROLE_Authority || WatchLeft<=0 )
		return;
	WatchLeft -= DeltaTime;
	if ( Watched!=None )
	{
		MaxRise = FMax( MaxRise, Watched.Location.Z - StartZ );
		A = string( Watched.AnimSequence );
		if ( InStr(" " $ Anims $ " ", " " $ A $ " ")<0 && Len(Anims)<200 )
			Anims = Anims @ A;
	}
	if ( WatchLeft<=0 )
		ServerWatchReport( MaxRise, Anims, Watched==None );
}

function ServerWatchReport( float Rise, string AnimList, bool bNoPawn )
{
	RMaxRise = Rise;
	RAnims = AnimList;
	Seq++;
	Log( "HXFixTest: watch report rise=" $ Rise @ "anims=" $ AnimList @ "nopawn=" $ bNoPawn, 'HXFixTest' );
}
