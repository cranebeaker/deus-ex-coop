//=============================================================================
// HXFixComputerPublic.
//
// HXComputerPublic with the hack lockout applied on the server (HXFixDevicesMutator).
//=============================================================================
class HXFixComputerPublic extends HXComputerPublic;

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

defaultproperties
{
	TerminalType=Class'HXFixNetworkTerminalPublic'
}
