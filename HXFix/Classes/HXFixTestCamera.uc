//=============================================================================
// HXFixTestCamera.
//
// A security camera must notice whichever player it can see, whatever their
// order in the pawn list, and must respect its view angle.
// Map: 01_NYC_UNATCOHQ.
//=============================================================================
class HXFixTestCamera extends HXFixTestDevBase;

var HXPlayerPawn H, R;
var HXSecurityCamera Cam;
var Vector Base;
var Vector Dir;

function bool MakeCam( class<HXSecurityCamera> C )
{
	local Rotator Rt;

	if ( Cam!=None )
		Cam.Destroy();
	Rt = Rotator(Dir);
	Cam = HXSecurityCamera( SpawnNear(C,Base) );
	if ( Cam!=None )
	{
		Cam.SetRotation( Rt );
		Cam.SetLocation( Base );
	}
	else
		Note( "camera spawn failed at" @ Base );
	if ( Cam==None )
		return false;
	Cam.bActive = True;
	Cam.bNoAlarm = False;
	Cam.bSwing = False;
	Cam.CameraFOV = 4096;
	Cam.CameraRange = 1500;
	Cam.origRot = Rt;
	Cam.DesiredRotation = Rt;
	Cam.bStasis = False;
	Cam.triggerDelay = 0;
	return true;
}

function Diag( string Tag )
{
	local Vector HL, HN;
	local Actor Hit;

	Hit = Cam.Trace( HL, HN, R.Location, Cam.Location, True );
	Note( Tag $ ": cam" @ Cam.Location @ Cam.Rotation @ "active=" $ Cam.bActive @ "R" @ R.Location @ "hp" @ R.Health @ "traceR=" $ Hit @ "H" @ H.Location @ "hp" @ H.Health @ "FOV" @ Cam.CameraFOV @ "range" @ Cam.CameraRange @ "target=" $ Cam.curTarget @ "seen=" $ Cam.bPlayerSeen @ "ignoreR=" $ R.bIgnore @ "detR=" $ R.bDetectable );
}

function PlaceBoth( HXPlayerPawn InView, HXPlayerPawn Behind )
{
	InView.SetLocation( Base + Dir*400 );
	Behind.SetLocation( Base - Dir*400 );
	InView.bIgnore = False;
	Behind.bIgnore = False;
}

function float RunStep( int StepNum )
{
	switch ( StepNum )
	{
		case 0:
			H = Host();
			H.ReducedDamageType = 'All';
			R = Remote();
			if ( R!=None )
				R.ReducedDamageType = 'All';
			if ( !Check(H!=None && R!=None, "host and remote present") )
				return -1;
			if ( !Check(FindOpen(H,450,450,Base,Dir), "open spot for camera found at" @ Base) )
				return -1;
			// Control: only the in-view player counts (the other one is ignored).
			if ( !Check(MakeCam(class'HXFixSecurityCamera'), "fix camera spawned") )
				return -1;
			PlaceBoth( R, H );
			H.bIgnore = True;
			return 1.5;

		case 1:
			Diag( "control" );
			Check( Cam.bEventTriggered, "control: camera sees the in-view player (alarm=" $ Cam.bEventTriggered $ ")" );
			H.bIgnore = False;
			MakeCam( class'HXFixSecurityCamera' );
			PlaceBoth( R, H );
			return 1.5;

		case 2:
			Check( Cam.bEventTriggered, "fix camera: remote in view, host behind it -> alarm" );
			Check( Cam.alarmInstigator==R, "alarm instigator is the in-view remote (" $ Cam.alarmInstigator $ ")" );
			MakeCam( class'HXFixSecurityCamera' );
			PlaceBoth( H, R );
			return 1.5;

		case 3:
			Check( Cam.bEventTriggered, "fix camera: host in view, remote behind it -> alarm" );
			Check( Cam.alarmInstigator==H, "alarm instigator is the in-view host (" $ Cam.alarmInstigator $ ")" );
			MakeCam( class'HXFixSecurityCamera' );
			H.SetLocation( Base - Dir*400 );
			R.SetLocation( Base - Dir*250 );
			return 1.5;

		case 4:
			Check( !Cam.bEventTriggered, "fix camera: nobody in its view angle -> no alarm" );
			return -1;
	}
	return -1;
}

defaultproperties
{
	TimeoutSeconds=90.000000
}
