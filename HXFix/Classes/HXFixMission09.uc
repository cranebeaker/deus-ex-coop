//=============================================================================
// HXFixMission09.
//
// HX fires ship explosions with 66%/90% chance per tick instead of stock
// 33%/10%, flinging players around the ship. Pre-gate to stock odds.
//=============================================================================
class HXFixMission09 extends HXMission09;

// Statistics for the live test.
var int NumCalls, NumPassed;

function ShipExplosionEffects( bool bFragments )
{
	NumCalls++;

	// HX gates at 0.66 (bFragments) and 0.9 (otherwise) afterwards.
	if ( bFragments && FRand()>=0.5 )
		return;
	if ( !bFragments && FRand()>=0.111 )
		return;

	NumPassed++;
	Super.ShipExplosionEffects( bFragments );
}
