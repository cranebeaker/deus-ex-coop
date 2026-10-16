//=============================================================================
// HXFixTestCompRange.
//
// A computer session must end when the user walks out of range (client
// window closed, computer released) and another player can then use it.
// Map: 01_NYC_UNATCOHQ.
//=============================================================================
class HXFixTestCompRange extends HXFixTestDevBase;

var HXPlayerPawn H, R;
var HXFixTestDevDriver DR, DH;
var HXComputers Comp;
var HXComputerPersonal PC;

function float RunStep( int StepNum )
{
	switch ( StepNum )
	{
		case 0:
			H = Remote(1);
			R = Remote();
			if ( !Check(H!=None && R!=None, "two remote clients present") )
				return -1;
			DR = HXFixTestDevDriver( DriverFor(R) );
			DH = HXFixTestDevDriver( DriverFor(H) );
			foreach AllActors( class'HXComputerPersonal', PC )
				break;
			Comp = PC;
			if ( !Check(Comp!=None, "personal computer found (" $ Comp $ ")") )
				return -1;
			Check( TeleNear(H,Comp.Location) && TeleNear(R,Comp.Location,4), "players moved next to the computer" );
			return 2.0;

		case 1:
			Comp.Frob( R, None );
			return 1.0;

		case 2:
			if ( Wait(Comp.bOn && Comp.curFrobber==R, 25) )
				return 1.0;
			Check( Comp.curFrobber==R, "remote client is using the computer" );
			DR.ClearRes();
			DR.DevOp( "window", '', 0 );
			return 3.0;

		case 3:
			Check( DR.GetRes("window")==1, "client window open" );
			Check( Comp.curFrobber==R, "control: session stays while in range" );
			// Walk away.
			Check( TeleFar(R,Comp.Location,1700), "remote moved out of range (dist " $ VSize(R.Location-Comp.Location) $ ")" );
			return 1.0;

		case 4:
			if ( Wait(Comp.curFrobber==None, 25) )
				return 1.0;
			Check( Comp.curFrobber==None, "server released the computer after the user left range (user=" $ Comp.curFrobber $ ")" );
			DR.ClearRes();
			DR.DevOp( "window", '', 0 );
			return 1.0;

		case 5:
			if ( Wait(DR.GetRes("window")!=-99, 15) )
				return 1.0;
			Check( DR.GetRes("window")==0, "client window closed (" $ DR.GetRes("window") $ ")" );
			return 2.0;

		case 6:
			if ( Wait(!Comp.bOn && !Comp.bAnimating, 20) )
				return 1.0;
			Check( !Comp.bOn, "computer is off" );
			TeleNear( H, Comp.Location );
			return 1.0;
		case 7:
			Comp.Frob( H, None );
			return 1.0;

		case 8:
			if ( Wait(Comp.bOn && Comp.curFrobber==H, 25) )
				return 1.0;
			Check( Comp.curFrobber==H && Comp.bOn, "second remote client can use the computer afterwards (user=" $ Comp.curFrobber $ " health=" $ H.Health $ " dist=" $ VSize(H.Location-Comp.Location) $ ")" );
			return -1;
	}
	return -1;
}

defaultproperties
{
	MinPlayers=3
	DriverClass=Class'HXFixTestDevDriver'
	TimeoutSeconds=150.000000
}
