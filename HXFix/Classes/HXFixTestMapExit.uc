//=============================================================================
// HXFixTestMapExit.
//
// Non-players (decoration, NPC) touching a map exit must not travel, a
// player touching it must. Map: 01_NYC_UNATCOHQ.
//=============================================================================
class HXFixTestMapExit extends HXFixTestDevBase;

var HXPlayerPawn H, R;
var HXFixMapExit Ex;
var Actor Thing, Thing2;
var Vector Base, Dir;

function bool IsTouching( Actor A )
{
	local int i;

	for ( i=0; i<4; i++ )
		if ( Ex.Touching[i]==A )
			return true;
	return false;
}

function float RunStep( int StepNum )
{
	switch ( StepNum )
	{
		case 0:
			H = Host();
			H.ReducedDamageType = 'All';
			R = Remote();
			if ( R!=None )
				R.ReducedDamageType = 'All';
			if ( !Check(H!=None && R!=None, "host and remote present") )
				return -1;
			if ( !Check(FindOpen(H,400,100,Base,Dir), "open spot found" @ Base) )
				return -1;
			TeleNear( H, Base );
			TeleNear( R, Base, 4 );
			Ex = Spawn( class'HXFixMapExit',,, Base+Dir*400 );
			if ( !Check(Ex!=None, "exit spawned") )
				return -1;
			Ex.DestMap = "01_NYC_UNATCOHQ";
			Ex.bPlayTransition = False;
			Ex.SetCollision( True, False, False );
			Ex.SetCollisionSize( 80, 80 );
			Thing = Spawn( class'HXCrateUnbreakableSmall',,, Ex.Location - Dir*150 );
			Thing2 = SpawnNear( class'HXMJ12Troop', Ex.Location - Dir*200 );
			Check( Thing!=None, "crate spawned in the exit" );
			Check( Thing2!=None, "NPC spawned in the exit" );
			if ( Thing!=None )
				Check( Thing.SetLocation(Ex.Location), "crate moved into the exit" );
			if ( Thing2!=None )
				Check( Thing2.SetLocation(Ex.Location+Vect(0,0,5)), "NPC moved into the exit" );
			return 3.0;

		case 1:
			Note( "touching:" @ Ex.Touching[0] @ Ex.Touching[1] @ Ex.Touching[2] @ Ex.Touching[3] );
			Check( IsTouching(Thing) || IsTouching(Thing2), "control: the non-player actually touches the exit" );
			Check( !Ex.bFired, "non-player touching the exit does not travel" );
			// Player walks in.
			R.SetLocation( Ex.Location );
			return 1.0;

		case 2:
			Check( Ex.bFired, "player touching the exit travels" );
			return 1.0;
	}
	return -1;
}

defaultproperties
{
	TimeoutSeconds=60.000000
}
