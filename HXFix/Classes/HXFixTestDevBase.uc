//=============================================================================
// HXFixTestDevBase.
//
// Shared helpers for the device live tests.
//=============================================================================
class HXFixTestDevBase extends HXFixTestBase;

var int Tries;

// Returns true (and repeats this step in a second) while bCond is false.
function bool Wait( bool bCond, int Max )
{
	if ( bCond )
	{
		Tries = 0;
		return false;
	}
	if ( Tries++<Max )
	{
		Step--;
		return true;
	}
	Tries = 0;
	return false;
}

// Teleports P next to Where, trying several offsets. Returns success.
function bool TeleNear( Pawn P, Vector Where, optional int Start )
{
	local Vector Off;
	local Rotator Rt;
	local int i;

	// Falling onto each other hurts.
	P.ReducedDamageType = 'All';
	for ( i=0; i<24; i++ )
	{
		Rt.Yaw = ((i+Start)%8)*8192;
		Off = (Vect(70,0,0) >> Rt) + Vect(0,0,1)*(i/8*40);
		if ( P.SetLocation(Where+Off) && VSize(P.Location-Where)<200 )
		{
			P.Velocity = vect(0,0,0);
			return true;
		}
	}
	return false;
}

// Teleports P somewhere in this HQ map at least MinDist from Origin.
function bool TeleFar( Pawn P, Vector Origin, float MinDist )
{
	local Vector Spots[8];
	local int i;

	Spots[0] = Vect(250,-96,320);
	Spots[1] = Vect(-359,-1107,0);
	Spots[2] = Vect(989,1033,0);
	Spots[3] = Vect(2673,1707,95);
	Spots[4] = Vect(-1662,657,780);
	Spots[5] = Vect(612,1608,340);
	Spots[6] = Vect(1759,433,120);
	Spots[7] = Vect(-1026,562,500);
	for ( i=0; i<8; i++ )
		if ( VSize(Spots[i]-Origin)>MinDist && TeleNear(P,Spots[i]) && VSize(P.Location-Origin)>MinDist )
			return true;
	return false;
}

function Actor SpawnNear( class<Actor> C, Vector Where )
{
	local Vector Off;
	local Rotator Rt;
	local Actor A;
	local int i;

	for ( i=0; i<32 && A==None; i++ )
	{
		Rt.Yaw = (i%8)*8192;
		Off = (Vect(60,0,0) >> Rt) + Vect(0,0,1)*(i/8*50-50);
		A = Spawn( C,,, Where+Off );
	}
	return A;
}

// Finds a clear direction around Base, sets Dir. Needs room Fwd in front and Back behind.
function bool FindDir( Vector Base, float Fwd, float Back, out Vector Dir )
{
	local int i;
	local Rotator Rt;
	local Vector V;

	for ( i=0; i<8; i++ )
	{
		Rt.Yaw = i*8192;
		V = Vector(Rt);
		if ( FastTrace(Base+V*Fwd, Base) && FastTrace(Base-V*Back, Base) )
		{
			Dir = V;
			return true;
		}
	}
	return false;
}

// Finds open space somewhere in the map: a Base (at a navigation point, so it is valid
// empty space) with a clear line Fwd along Dir and Back behind it.
function bool FindOpen( Pawn Ref, float Fwd, float Back, out Vector Base, out Vector Dir )
{
	local NavigationPoint N;
	local Vector Up;

	Up = Vect(0,0,30);
	if ( FindDir(Ref.Location+Up,Fwd,Back,Dir) )
	{
		Base = Ref.Location+Up;
		return true;
	}
	foreach AllActors( class'NavigationPoint', N )
		if ( FindDir(N.Location+Up,Fwd,Back,Dir) )
		{
			Base = N.Location+Up;
			return true;
		}
	return false;
}
