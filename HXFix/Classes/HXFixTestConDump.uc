//=============================================================================
// HXFixTestConDump.
//
// Discovery helper: logs the conversations of every actor on the map.
//=============================================================================
class HXFixTestConDump extends HXFixTestBase;

function float RunStep( int StepNum )
{
	local Actor A;
	local ConListItem Item;

	foreach AllActors( class'Actor', A )
	{
		if ( A.ConListItems==None )
			continue;
		for ( Item=ConListItem(A.ConListItems); Item!=None; Item=Item.Next )
			Note( "CON" @ A @ A.BindName @ Item.Con.ConName @ "fp=" $ Item.Con.bFirstPerson @ "dl=" $ Item.Con.bDataLinkCon @ "loc=" $ A.Location );
	}
	return -1;
}

defaultproperties
{
	MinPlayers=1
	TimeoutSeconds=60.000000
}
