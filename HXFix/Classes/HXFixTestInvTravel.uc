//=============================================================================
// HXFixTestInvTravel.
//
// The listen host and a client have their inventory screen open when the
// server changes map. Stock HX crashed in HXPersonaInventoryObjectBelt's
// DestroyWindow there. HXFixTestInvTravel2 checks everyone arrived.
//=============================================================================
class HXFixTestInvTravel extends HXFixTestBase;

var HXPlayerPawn H, R;

function float RunStep( int StepNum )
{
	switch ( StepNum )
	{
		case 0:
			H = Host();
			R = Remote();
			if ( !Check(H!=None && R!=None, "host and remote client present") )
				return -1;
			return 3.0;

		case 1:
			Check( HXRootWindow(H.rootWindow).ShowInventoryWindowClass==class'HXFixPersonaScreenInventory', "host uses the fixed inventory screen" );
			H.ShowInventoryWindow();
			ClientCmd( R, "ShowInventoryWindow" );
			return 3.0;

		case 2:
			Check( HXFixPersonaScreenInventory(HXRootWindow(H.rootWindow).GetTopWindow())!=None, "host inventory screen open" );
			Note( "travelling with inventory screens open" );
			bDone = True;
			SetTimer( 0, False );
			Level.ServerTravel( "01_NYC_UNATCOHQ?Game=HXFix.HXFixGameInfo?HXFixTest=HXFixTestInvTravel2", False );
			return 999; // No Finish(): that exits the host.
	}
	return -1;
}

defaultproperties
{
	TimeoutSeconds=200.000000
}
