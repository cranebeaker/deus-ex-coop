//=============================================================================
// HXFixDeviceUtil.
//
// Shared helpers for the HXFix device subclasses, which can't share a base
// class because they extend different HX classes.
//=============================================================================
class HXFixDeviceUtil extends Object;

// ----------------------------------------------------------------------------
// IsLivePlayer()
// ----------------------------------------------------------------------------

static function bool IsLivePlayer( Actor Other )
{
	local HXPlayerPawn P;

	P = HXPlayerPawn(Other);
	return P!=None && !P.bDeleteMe && P.bIsPlayer && P.Health>0;
}

// ----------------------------------------------------------------------------
// HasTransitionPath()
//
// HXMapExit with bPlayTransition never travels if there is no
// InterpolationPoint with Position 1 on CameraPathTag.
// ----------------------------------------------------------------------------

static function bool HasTransitionPath( Actor Context, name PathTag )
{
	local InterpolationPoint IP;

	foreach Context.AllActors( class'InterpolationPoint', IP, PathTag )
		if ( IP.Position==1 )
			return true;
	return false;
}

// ----------------------------------------------------------------------------
// ClientHackDetected()
//
// Called on the client by the fixed terminals. Forwards the hack lockout to
// the server copy of the computer (which the client owns while using it).
// ----------------------------------------------------------------------------

static function ClientHackDetected( HXComputers Comp, bool bDamageOnly )
{
	if ( Comp==None )
		return;

	if ( HXFixComputerPersonal(Comp)!=None )
		HXFixComputerPersonal(Comp).ServerHackDetected();
	else if ( HXFixComputerPublic(Comp)!=None )
		HXFixComputerPublic(Comp).ServerHackDetected();
	else if ( HXFixComputerSecurity(Comp)!=None )
		HXFixComputerSecurity(Comp).ServerHackDetected();
	else if ( HXFixATM(Comp)!=None )
		HXFixATM(Comp).ServerHackDetected();
}

// ----------------------------------------------------------------------------
// ApplyHackLockout()
//
// Server side. The caller is the client that owns the computer. The lockout
// is accepted while that player is using the computer, or for a few seconds
// after the session closed, as the close request (player channel) can
// overtake this call (computer channel).
// ----------------------------------------------------------------------------

static function ApplyHackLockout( HXComputers Comp, HXPlayerPawn LastUser, float LastCloseTime )
{
	if ( Comp==None || Comp.Level.NetMode==NM_Client )
		return;

	if ( Comp.curFrobber!=None )
	{
		if ( Comp.curFrobber!=Comp.Owner )
			return;
	}
	else
	{
		if ( LastUser==None || LastUser!=Comp.Owner || Comp.Level.TimeSeconds-LastCloseTime>5.0 )
			return;
	}

	Comp.LockoutTime = Comp.Level.TimeSeconds;
	Comp.bLockedOut  = True;
	Log( "HXFix: hack lockout on" @ Comp @ "by" @ Comp.Owner, 'HXFix' );

	// The session already closed without seeing the lockout, so no alarm yet.
	if ( Comp.curFrobber==None && !Comp.bOn && Comp.lastAlarmTime==0 )
		Comp.BeginAlarm();
}

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
