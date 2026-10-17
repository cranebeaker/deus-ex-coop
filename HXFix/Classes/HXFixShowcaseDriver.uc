//=============================================================================
// HXFixShowcaseDriver.
//
// Client side camera for HXFixTestShowcase: puts the client's view at a
// position and rotation and takes an engine screenshot ("shot").
//=============================================================================
class HXFixShowcaseDriver extends HXFixTestDriver;

var bool bShotPending;
var float ShotDelay;

replication
{
	reliable if ( Role==ROLE_Authority )
		ClientShot, ClientCameraMode, ClientPressJump;
}

simulated function ClientShot( Vector Loc, Rotator Rot )
{
	local PlayerPawn P;

	P = PlayerPawn(Owner);
	if ( P==None )
		return;
	P.SetLocation( Loc );
	P.ViewRotation = Rot;
	P.SetRotation( Rot );
	bShotPending = True;
	ShotDelay = 0.08;
}

// Same as pressing the jump key (the "Jump" binding is an input alias).
simulated function ClientPressJump()
{
	if ( PlayerPawn(Owner)!=None )
		PlayerPawn(Owner).bPressedJump = True;
}

// Turn this client into a clean camera: no HUD, nothing in hand.
simulated function ClientCameraMode()
{
	if ( HXPlayerPawn(Owner)!=None )
		HXPlayerPawn(Owner).ShowHud( False );
}

simulated function Tick( float DeltaTime )
{
	Super.Tick( DeltaTime );
	if ( !bShotPending || Role==ROLE_Authority )
		return;
	ShotDelay -= DeltaTime;
	if ( ShotDelay<=0 )
	{
		bShotPending = False;
		PlayerPawn(Owner).ConsoleCommand( "shot" );
	}
}
