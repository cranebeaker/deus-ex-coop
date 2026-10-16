//=============================================================================
// HXFixComputerSecurity.
//
// HXComputerSecurity with the hack lockout applied on the server (HXFixDevicesMutator).
//=============================================================================
class HXFixComputerSecurity extends HXComputerSecurity;

var HXPlayerPawn FixLastUser;
var float FixLastCloseTime;

replication
{
	// client to server
	reliable if ( Role<ROLE_Authority )
		ServerHackDetected;
}


// Remember who closed the session, see HXFixDeviceUtil.ApplyHackLockout().
function CloseOut()
{
	if ( curFrobber!=None )
	{
		FixLastUser      = curFrobber;
		FixLastCloseTime = Level.TimeSeconds;
	}
	Super.CloseOut();
}

// Warn the client when the session is dropped for distance, so its window
// closes through CloseOut() instead of staying open on a dead session.
function Tick( float DeltaTime )
{
	if ( bOn && IsInState('On') && curFrobber!=None && VSize(curFrobber.Location-Location)>1500 )
	{
		FixLastUser      = curFrobber;
		FixLastCloseTime = Level.TimeSeconds;
		curFrobber.HXCloseThisComputer( Self );
	}
	Super.Tick( DeltaTime );
}

function ServerHackDetected()
{
	class'HXFixDeviceUtil'.static.ApplyHackLockout( Self, FixLastUser, FixLastCloseTime );
}

// HX cameras are HXSecurityCamera (not SecurityCamera) and doors can be any
// Mover, so the original never gave remote clients ownership (relevance) of
// the cameras they watch. When releasing, only touch what this user owns.
function SetControlledObjectOwners( DeusExPlayer PlayerWhoOwns )
{
	local int i;
	local name ObjectTag;
	local HXSecurityCamera Camera;
	local HXAutoTurret Turret;
	local Mover Door;
	local Actor User;

	User = curFrobber;
	if ( User==None )
		User = FixLastUser;

	for ( i=0; i<ArrayCount(Views); i++ )
	{
		ObjectTag = Views[i].cameraTag;
		if ( ObjectTag!='' )
			foreach AllActors( class'HXSecurityCamera', Camera, ObjectTag )
				if ( PlayerWhoOwns!=None || Camera.Owner==None || Camera.Owner==User )
					Camera.SetOwner( PlayerWhoOwns );

		ObjectTag = Views[i].turretTag;
		if ( ObjectTag!='' )
			foreach AllActors( class'HXAutoTurret', Turret, ObjectTag )
				if ( PlayerWhoOwns!=None || Turret.Owner==None || Turret.Owner==User )
					Turret.SetOwner( PlayerWhoOwns );

		ObjectTag = Views[i].doorTag;
		if ( ObjectTag!='' )
			foreach AllActors( class'Mover', Door, ObjectTag )
				if ( PlayerWhoOwns!=None || Door.Owner==None || Door.Owner==User )
					Door.SetOwner( PlayerWhoOwns );
	}
}

defaultproperties
{
	TerminalType=Class'HXFixNetworkTerminalSecurity'
}
