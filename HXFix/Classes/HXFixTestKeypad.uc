//=============================================================================
// HXFixTestKeypad.
//
// Keypad with the listen host's window open must still work for a remote
// client, and both players entering the code on a bToggleLock keypad must
// toggle the lock once. Map: 01_NYC_UNATCOHQ.
//=============================================================================
class HXFixTestKeypad extends HXFixTestBase;

var HXPlayerPawn H, R;
var HXFixTestDevDriver DH, DR;
var HXKeypad Pad, StockPad;
var HXMover Door;
var bool bLockedBefore;
var int Tries;

function bool Wait( bool bCond, int Max )
{
	if ( bCond )
	{
		Tries = 0;
		return false;
	}
	if ( Tries++<Max )
	{
		Step--;
		return true;
	}
	Tries = 0;
	return false;
}

function Actor SpawnNear( class<Actor> C, Vector Where )
{
	local Vector Off;
	local Rotator Rt;
	local Actor A;
	local int i;

	for ( i=0; i<32 && A==None; i++ )
	{
		Rt.Yaw = (i%8)*8192;
		Off = (Vect(60,0,0) >> Rt) + Vect(0,0,1)*(i/8*50-50);
		A = Spawn( C,,, Where+Off );
	}
	return A;
}

function float RunStep( int StepNum )
{
	switch ( StepNum )
	{
		case 0:
			H = Host();
			R = Remote();
			if ( !Check(H!=None && R!=None, "host and remote present") )
				return -1;
			DH = HXFixTestDevDriver( DriverFor(H) );
			DR = HXFixTestDevDriver( DriverFor(R) );
			if ( !Check(DH!=None && DR!=None, "drivers present") )
				return -1;
			foreach AllActors( class'HXMover', Door, 'alexcloset' )
				break;
			if ( !Check(Door!=None, "mover alexcloset found") )
				return -1;
			Note( "mover" @ Door.Class.Name @ "locked=" $ Door.bLocked );
			foreach AllActors( class'HXKeypad', Pad )
				if ( Pad.Event=='alexcloset' )
					break;
			if ( !Check(Pad!=None && HXFixKeypad2(Pad)!=None, "map keypad for alexcloset found (" $ Pad $ ")") )
				return -1;
			Pad.Tag = 'TestPad';
			Pad.bToggleLock = True;
			H.SetLocation( Pad.Location + Vect(0,60,20) );
			R.SetLocation( Pad.Location + Vect(40,60,20) );
			DH.ClearRes();
			DR.ClearRes();
			Pad.HackAction( H, False );
			return 2.0;

		case 1:
			Pad.HackAction( R, False );
			return 2.0;

		case 2:
			DH.DevOp( "padcheck", 'TestPad', 0 );
			DR.DevOp( "padcheck", 'TestPad', 0 );
			return 1.0;

		case 3:
			if ( Wait(DH.GetRes("padwindow")!=-99 && DR.GetRes("padwindow")!=-99, 15) )
				return 1.0;
			Check( Pad.keypadwindow!=None, "control: host window open on the server keypad copy (" $ Pad.keypadwindow $ ")" );
			Check( DH.GetRes("padwindow")==1, "host window open on fixed keypad" );
			Check( DR.GetRes("padwindow")==1, "remote client window opens although the host has it open" );
			return 0.5;

		case 4:
			// Both enter the code.
			bLockedBefore = Door.bLocked;
			DH.DevOp( "padcode", 'TestPad', 0 );
			DR.DevOp( "padcode", 'TestPad', 0 );
			return 1.0;

		case 5:
			if ( Wait(DR.GetRes("padcode")==1 && DH.GetRes("padcode")==1, 15) )
				return 1.0;
			return 1.5;

		case 6:
			return 0.5;

		case 7:
			Check( Door.bLocked!=bLockedBefore, "two players entering the code toggle the lock once (before=" $ bLockedBefore $ " now=" $ Door.bLocked $ ")" );
			return 3.0;

		case 8:
			// A later entry works again.
			DH.DevOp( "padcode", 'TestPad', 0 );
			return 2.0;

		case 9:
			Check( Door.bLocked==bLockedBefore, "a later code entry toggles again (now=" $ Door.bLocked $ ")" );
			return -1;
	}
	return -1;
}

defaultproperties
{
	DriverClass=Class'HXFixTestDevDriver'
	TimeoutSeconds=150.000000
}
