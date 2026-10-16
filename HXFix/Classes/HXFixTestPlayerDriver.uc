//=============================================================================
// HXFixTestPlayerDriver.
//
// Client side probes of the player tests. ClientProbe() runs on the owning
// client (locally for the listen host) and calls the RPCs a real player would.
//=============================================================================
class HXFixTestPlayerDriver extends HXFixTestDriver;

replication
{
	reliable if ( Role==ROLE_Authority )
		ClientProbe;
}

simulated function ClientProbe( string Kind, string Arg )
{
	local HXPlayerPawn P;
	local Inventory Inv;
	local HXBioelectricCell Cell;
	local int N;

	P = HXPlayerPawn( Owner );
	if ( P==None )
		return;

	Log( "HXFixTest: client probe" @ Kind @ Arg @ "on" @ P, 'HXFixTest' );
	switch ( Kind )
	{
		case "connext":
			P.ServerPlayNextConPlayEvent();
			break;

		case "conchoice":
			P.ServerPlayConPlayChoice( int(Arg) );
			break;

		// What the "Use Cell" button of the augmentation screen does.
		case "cell":
			Inv = P.FindInventoryType( class'HXBioelectricCell' );
			Cell = HXBioelectricCell( Inv );
			ServerReport( "cell found=" $ (Cell!=None) $ " energyBefore=" $ P.Energy );
			if ( Cell!=None )
				Cell.Activate();
			break;

		case "disconnect":
			P.ConsoleCommand( "disconnect" );
			break;
	}
}

defaultproperties
{
}
