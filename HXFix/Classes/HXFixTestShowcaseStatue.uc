//=============================================================================
// HXFixTestShowcaseStatue.
//
// Not a test: showcase GIF material on 01_NYC_UNATCOIsland. Two armed players
// stand in front of the Statue of Liberty; a third client is the camera (no
// HUD) and pulls back and tilts up while the players jump and fire.
// Needs 2 remote clients: Remote(0) is player 2, Remote(1) the camera.
//=============================================================================
class HXFixTestShowcaseStatue extends HXFixTestBase;

var HXPlayerPawn H, P2, Cam;
var HXFixShowcaseDriver D;
var int Frame;

const FRAMES = 56;

function Arm( HXPlayerPawn P )
{
	local Inventory Inv;

	P.ReducedDamageType = 'All';
	Inv = Spawn( class'HXWeaponAssaultGun',,, P.Location );
	if ( Inv!=None )
	{
		Inv = Inv.SpawnCopy( P );
		P.PutInHand( Inv );
	}
}

function Face( HXPlayerPawn P, Vector Loc, Rotator R )
{
	P.SetLocation( Loc );
	P.SetRotation( R );
	P.ViewRotation = R;
	if ( P!=Host() )
		P.ClientSetLocation( Loc, R );
}

function float RunStep( int StepNum )
{
	local Vector CamLoc, Mid;
	local Rotator CamRot;
	local float T;

	if ( StepNum==0 )
	{
		H   = Host();
		P2  = Remote(0);
		Cam = Remote(1);
		D   = HXFixShowcaseDriver( DriverFor(Cam) );
		if ( !Check(H!=None && P2!=None && Cam!=None && D!=None, "two players and a camera") )
			return -1;
		Arm( H );
		Arm( P2 );
		Cam.ReducedDamageType = 'All';
		Cam.PutInHand( None );
		Cam.SetCollision( False, False, False );
		D.ClientCameraMode();
		return 2.0;
	}
	if ( StepNum==1 )
	{
		// Side by side on the walkway west of the statue, facing west (the camera).
		Face( H,  Vect(-1350,200,-125), Rot(0,32768,0) );
		Face( P2, Vect(-1350,330,-125), Rot(0,32768,0) );
		return 1.5;
	}

	if ( Frame>=FRAMES )
	{
		Check( True, FRAMES @ "frames taken" );
		return -1;
	}

	// Keep both facing the camera.
	if ( Frame%6==0 )
	{
		H.SetRotation( Rot(0,32768,0) );
		H.ViewRotation = Rot(0,32768,0);
		P2.ClientSetLocation( P2.Location, Rot(0,32768,0) );
	}

	// Actions: jump, fire, jump together.
	if ( Frame==10 || Frame==38 )
	{
		H.DoJump();
		HXFixShowcaseDriver( DriverFor(P2) ).ClientPressJump();
	}
	if ( Frame==22 )
	{
		ClientCmd( H, "Fire" );
		ClientCmd( P2, "Fire" );
	}
	if ( Frame==30 )
	{
		ClientCmd( H, "StopFire" );
		ClientCmd( P2, "StopFire" );
	}

	T = float(Frame) / (FRAMES-1);
	Mid = Vect(-1350,265,-105);
	CamLoc = Vect(-1600,265,-85) + Vect(-1,0,0)*(530*T) + Vect(0,0,1)*(40*T) + Vect(0,1,0)*(120*T - 60);
	CamRot = Rotator( Mid - CamLoc );
	CamRot.Pitch = CamRot.Pitch + int(4800*T*T);
	Cam.SetLocation( CamLoc );
	D.ClientShot( CamLoc, CamRot );
	Frame++;
	return 0.25;
}

defaultproperties
{
	MinPlayers=3
	DriverClass=Class'HXFixShowcaseDriver'
	TimeoutSeconds=240.000000
}
