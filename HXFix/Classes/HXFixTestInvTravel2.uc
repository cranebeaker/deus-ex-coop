//=============================================================================
// HXFixTestInvTravel2.
//
// Second map of HXFixTestInvTravel: host and client made it.
//=============================================================================
class HXFixTestInvTravel2 extends HXFixTestBase;

function float RunStep( int StepNum )
{
	Check( Host()!=None && Remote()!=None, "host and client arrived on the next map" );
	Check( Host()!=None && Host().Health>0 && Remote()!=None && Remote().Health>0, "both alive" );
	return -1;
}

defaultproperties
{
	TimeoutSeconds=200.000000
}
