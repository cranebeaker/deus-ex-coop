//=============================================================================
// HXFixTestFindActors.
//
// Not a test: logs the location of large or named landmark actors on the
// map, to place showcase cameras.
//=============================================================================
class HXFixTestFindActors extends HXFixTestBase;

function float RunStep( int StepNum )
{
	local Actor A;
	local string N;

	foreach AllActors( class'Actor', A )
	{
		N = Caps( string(A.Class.Name) $ " " $ A.Tag $ " " $ A.Mesh );
		if ( InStr(N,"STATUE")>=0 || InStr(N,"LIBERTY")>=0 || InStr(N,"TORCH")>=0 || A.IsA('PlayerStart') || A.IsA('MapExit') )
			Note( A @ A.Class.Name @ "tag=" $ A.Tag @ "mesh=" $ A.Mesh @ "at" @ A.Location @ "scale" @ A.DrawScale );
	}
	Note( "host at" @ Host().Location );
	return -1;
}

defaultproperties
{
	MinPlayers=1
}
