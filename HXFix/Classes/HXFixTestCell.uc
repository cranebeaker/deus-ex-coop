//=============================================================================
// HXFixTestCell.
//
// The augmentation screen's "Use Cell" button calls bioCell.Activate() on the
// client. Control: the host does the same. The remote client must recharge too.
//=============================================================================
class HXFixTestCell extends HXFixTestBase;

var HXPlayerPawn R, H;
var int RCells, HCells;

function HXBioelectricCell GiveCell( HXPlayerPawn P )
{
	local HXBioelectricCell Cell;

	Cell = Spawn( class'HXBioelectricCell' );
	Cell.NumCopies = 3;
	Cell.GiveTo( P );
	return Cell;
}

function float RunStep( int StepNum )
{
	switch ( StepNum )
	{
		case 0:
			R = Remote();
			H = Host();
			if ( !Check(R!=None && H!=None, "host and remote present") )
				return -1;
			GiveCell( H );
			GiveCell( R );
			H.Energy = 10;
			R.Energy = 10;
			Check( R.FindInventoryType(class'HXBioelectricCell')!=None, "server finds the remote's cell" );
			return 2.0;

		case 1:
			CDriver( H ).ClientProbe( "cell", "" );
			return 3.0;

		case 2:
			Check( H.Energy>10, "control: host cell recharges (energy" @ H.Energy $ ")" );
			CDriver( R ).ClientProbe( "cell", "" );
			return 3.0;

		case 3:
			Check( R.Energy>10, "remote client cell recharges (energy" @ R.Energy $ ")" );
			return -1;
	}
	return -1;
}

function HXFixTestPlayerDriver CDriver( Pawn P )
{
	return HXFixTestPlayerDriver( DriverFor(P) );
}

defaultproperties
{
	DriverClass=Class'HXFixTestPlayerDriver'
	TimeoutSeconds=90.000000
}
