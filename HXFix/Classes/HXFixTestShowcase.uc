//=============================================================================
// HXFixTestShowcase.
//
// Not a test: makes material for a showcase GIF. The remote client's camera
// circles the armed host and takes an engine screenshot at every step.
//=============================================================================
class HXFixTestShowcase extends HXFixTestBase;

var HXPlayerPawn H, R;
var HXFixShowcaseDriver D;
var Vector Center;
var int Shots, Tries;

function float RunStep( int StepNum )
{
	local Inventory Inv;
	local Vector Loc;
	local Rotator Rot;
	local float A;

	if ( StepNum==0 )
	{
		H = Host();
		R = Remote();
		D = HXFixShowcaseDriver( DriverFor(R) );
		if ( !Check(H!=None && R!=None && D!=None, "host, client and camera driver") )
			return -1;
		H.ReducedDamageType = 'All';
		R.ReducedDamageType = 'All';
		Inv = Spawn( class'HXWeaponAssaultGun',,, H.Location );
		if ( Inv!=None )
		{
			Inv = Inv.SpawnCopy( H );
			H.PutInHand( Inv );
		}
		Center = H.Location;
		return 2.0;
	}

	if ( Shots>=40 || Tries>=120 )
	{
		Check( True, "40 frames taken" );
		return -1;
	}

	// Walk the circle in 120 small steps; only shoot where the camera fits.
	A = Tries * 2 * Pi / 120;
	Tries++;
	Loc = Center + Vect(1,0,0)*Cos(A)*190 + Vect(0,1,0)*Sin(A)*190 + Vect(0,0,10);
	if ( !R.SetLocation(Loc) || !FastTrace(Center, R.Location) )
		return 0.05;
	Loc = R.Location;
	Rot = Rotator( Center - Loc );
	R.ViewRotation = Rot;
	H.SetRotation( Rotator(Loc - Center) );
	H.ViewRotation = Rotator(Loc - Center);
	D.ClientShot( Loc, Rot );
	Shots++;
	return 0.3;
}

defaultproperties
{
	DriverClass=Class'HXFixShowcaseDriver'
	TimeoutSeconds=200.000000
}
