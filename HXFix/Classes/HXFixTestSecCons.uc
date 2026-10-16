//=============================================================================
// HXFixTestSecCons.
//
// Remote client uses a security console: cameras it controls must become
// owned by it (relevance), it can toggle a camera through the console RPC,
// and a hack detected on the client locks the console out and sounds the
// alarm on the server. Map: 01_NYC_UNATCOHQ (cameras only, console spawned).
//=============================================================================
class HXFixTestSecCons extends HXFixTestBase;

var HXPlayerPawn R;
var HXFixTestDevDriver D;
var HXSecurityCamera Cam;
var HXFixComputerSecurity Comp;
var bool bWasActive;
var int Tries;

// Returns true (and repeats this step in a second) while bCond is false.
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

	for ( i=0; i<8 && A==None; i++ )
	{
		Rt.Yaw = i*8192;
		Off = Vect(80,0,0) >> Rt;
		A = Spawn( C,,, Where+Off );
	}
	return A;
}

function float RunStep( int StepNum )
{
	switch ( StepNum )
	{
		case 0:
			R = Remote();
			if ( !Check(R!=None, "remote client present") )
				return -1;
			D = HXFixTestDevDriver( DriverFor(R) );
			if ( !Check(D!=None, "dev driver present") )
				return -1;
			foreach AllActors( class'HXSecurityCamera', Cam, 'UN_lobbycam01' )
				break;
			if ( !Check(Cam!=None, "camera UN_lobbycam01 found") )
				return -1;
			Note( "camera is" @ Cam.Class.Name @ "at" @ Cam.Location );

			// Client far away from the camera, console beside the client.
			R.SetLocation( Vect(250,-96,320) );
			Comp = HXFixComputerSecurity( SpawnNear(class'HXFixComputerSecurity', Vect(250,-96,320)) );
			if ( !Check(Comp!=None, "console spawned") )
				return -1;
			Comp.Views[0].titleString = "Lobby";
			Comp.Views[0].cameraTag   = 'UN_lobbycam01';
			Comp.Views[1].cameraTag   = 'UN_conferencecam01';
			Comp.bLockedOut = False;
			Cam.bActive = True;
			Check( Cam.Owner==None, "control: camera has no owner before the console is used" );
			return 3.0;

		case 1:
			Comp.Frob( R, None );
			return 1.0;

		case 2:
			if ( Wait(Comp.bOn && Comp.curFrobber==R, 20) )
				return 1.0;
			Check( Comp.curFrobber==R, "console in use by remote client" );
			Check( Cam.Owner==R, "camera owned by the using client (owner=" $ Cam.Owner $ ")" );
			D.ClearRes();
			D.DevOp( "window", '', 0 );
			D.DevOp( "camprobe", 'UN_lobbycam01', 0 );
			return 1.0;

		case 3:
			if ( Wait(D.GetRes("window")!=-99 && D.GetRes("camfound")!=-99, 20) )
				return 1.0;
			Check( D.GetRes("window")==1, "client has the console window open" );
			Check( D.GetRes("camfound")==1, "camera relevant to client while console open" );
			bWasActive = Cam.bActive;
			D.DevOp( "camtoggle", 'UN_lobbycam01', 0 );
			return 1.0;

		case 4:
			if ( Wait(Cam.bActive!=bWasActive, 15) )
				return 1.0;
			Check( D.GetRes("toggled")==1, "client toggled camera through console RPC" );
			Check( Cam.bActive!=bWasActive, "camera state changed on server (was" @ bWasActive $ " now" @ Cam.bActive $ ")" );
			D.DevOp( "hack", '', 0 );
			return 1.0;

		case 5:
			if ( Wait(Comp.bLockedOut && Comp.curFrobber==None, 20) )
				return 1.0;
			Check( D.GetRes("hacked")==1, "client ran HackDetected" );
			Check( Comp.bLockedOut, "server: console locked out after client hack" );
			Check( Comp.lastAlarmTime!=0, "server: alarm sounding after client hack" );
			Check( Comp.curFrobber==None, "console released after hack" );
			Check( Cam.Owner==None, "camera owner released (owner=" $ Cam.Owner $ ")" );

			return -1;
	}
	return -1;
}

defaultproperties
{
	DriverClass=Class'HXFixTestDevDriver'
	TimeoutSeconds=150.000000
}
