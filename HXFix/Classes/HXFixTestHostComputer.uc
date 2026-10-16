//=============================================================================
// HXFixTestHostComputer.
//
// The listen host must be able to use a computer: HXInvokeComputerScreen
// closed the session unless PlayerIsClient(). Control: a remote client can.
// Map: 01_NYC_UNATCOHQ.
//=============================================================================
class HXFixTestHostComputer extends HXFixTestDevBase;

var HXPlayerPawn H, R;
var HXComputers Comp;

function float RunStep( int StepNum )
{
	local HXComputerPersonal PC;

	switch ( StepNum )
	{
		case 0:
			H = Host();
			R = Remote();
			if ( !Check(H!=None && R!=None, "host and remote client present") )
				return -1;
			foreach AllActors( class'HXComputerPersonal', PC )
				break;
			Comp = PC;
			if ( !Check(Comp!=None, "personal computer found") )
				return -1;
			Note( "host PlayerIsClient=" $ H.PlayerIsClient() @ "GetPlayerPawn=" $ GetPlayerPawn() @ "host=" $ H );
			Check( TeleNear(R,Comp.Location), "remote moved next to the computer" );
			return 2.0;

		case 1:
			Comp.Frob( R, None );
			return 1.0;

		case 2:
			if ( Wait(Comp.bOn && Comp.curFrobber==R, 25) )
				return 1.0;
			if ( !Check(Comp.curFrobber==R, "control: remote client can use the computer") )
				return -1;
			R.HXCloseComputerScreen( Comp );
			return 1.0;

		case 3:
			if ( Wait(!Comp.bOn && !Comp.bAnimating && Comp.curFrobber==None, 25) )
				return 1.0;
			Check( Comp.curFrobber==None, "control: remote session closed" );
			Check( TeleNear(H,Comp.Location), "host moved next to the computer" );
			return 2.0;

		case 4:
			Comp.Frob( H, None );
			return 1.0;

		case 5:
			if ( Wait(Comp.bOn && Comp.curFrobber==H && H.HXActiveComputer==Comp, 25) )
				return 1.0;
			Check( Comp.curFrobber==H && H.HXActiveComputer==Comp, "listen host can use the computer (user=" $ Comp.curFrobber $ " active=" $ H.HXActiveComputer $ ")" );
			Check( Comp.termwindow!=None, "host terminal window open" );
			return -1;
	}
	return -1;
}

defaultproperties
{
	TimeoutSeconds=330.000000
}
