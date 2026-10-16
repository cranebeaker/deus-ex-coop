//=============================================================================
// HXFixTestTrainExit.
//
// 00_TrainingFinal's bNoDelete exit can't be swapped at load, the devices
// module must add a fixed no-items exit in its place. Map: 00_TrainingFinal.
//=============================================================================
class HXFixTestTrainExit extends HXFixTestBase;

var HXPlayerPawn H, R;
var HXMapExit Ex;

function float RunStep( int StepNum )
{
	local HXMapExit E;
	local int Carry, Num;

	switch ( StepNum )
	{
		case 0:
			H = Host();
			R = Remote();
			if ( !Check(H!=None && R!=None, "host and remote present") )
				return -1;
			foreach AllActors( class'HXMapExit', E )
			{
				Num++;
				Note( "exit" @ E @ E.Class.Name @ "dest=" $ E.DestMap @ "bItems=" $ E.bItems @ "collide=" $ E.bCollideActors @ "tag=" $ E.Tag @ "loc=" $ E.Location );
				if ( E.bItems )
					Carry++;
				if ( HXFixMapExit(E)!=None || HXFixMapExitNoItems(E)!=None )
					Ex = E;
			}
			Check( Num>0, "map has HX exits (" $ Num $ ")" );
			Check( Carry==0, "no exit carries items into mission 1 (" $ Carry $ " do)" );
			if ( !Check(Ex!=None, "exit is a fixed one (" $ Ex $ ")") )
				return -1;
			Check( Ex.DestMap=="01_NYC_UNATCOIsland", "exit goes to mission 1 (" $ Ex.DestMap $ ")" );
			Ex.bPlayTransition = False;
			return 2.0;

		case 1:
			Check( !Ex.bFired, "exit idle" );
			Ex.Trigger( R, R );
			Check( Ex.bFired, "exit travels when triggered" );
			return -1;
	}
	return -1;
}

defaultproperties
{
	TimeoutSeconds=90.000000
}
