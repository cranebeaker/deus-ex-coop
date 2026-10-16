//=============================================================================
// HXFixTestConBase.
//
// Shared helpers of the conversation tests.
//=============================================================================
class HXFixTestConBase extends HXFixTestBase;

var int PendingTries;

function HXFixTestConDriver CDriver( Pawn P )
{
	return HXFixTestConDriver(DriverFor(P));
}

function HXScriptedPawn FindNPC( string InBindName )
{
	local HXScriptedPawn S;

	foreach AllActors( class'HXScriptedPawn', S )
		if ( S.BindName~=InBindName )
			return S;
	return None;
}

function Probe( Pawn P, string Kind, string Arg )
{
	local HXFixTestConDriver D;

	D = CDriver( P );
	if ( D==None )
	{
		Check( False, "no con driver for" @ P );
		return;
	}
	D.ProbeValue = -1000;
	D.ClientProbe( Kind, Arg );
}

// Value of the last probe answer, -1000 if none yet.
function int ProbeValue( Pawn P )
{
	local HXFixTestConDriver D;

	D = CDriver( P );
	if ( D==None )
		return -1000;
	return D.ProbeValue;
}

// True (and the current step is repeated by Again()) while the probe answer is missing.
function bool Pending( Pawn P )
{
	if ( ProbeValue(P)!=-1000 )
	{
		PendingTries = 0;
		return False;
	}
	if ( PendingTries++>30 )
	{
		PendingTries = 0;
		Check( False, "no probe answer from" @ P );
		return False;
	}
	return True;
}

// Repeat the current step later.
function float Again( optional float Delay )
{
	Step--;
	if ( Delay<=0 )
		Delay = 1.0;
	return Delay;
}

function string ConState()
{
	if ( Game.ConPlay==None )
		return "none";
	return string(Game.ConPlay.GetStateName());
}

// Plays through a running conversation: skips waits, picks the first choice.
function AdvanceCon()
{
	if ( Game.ConPlay==None )
		return;
	if ( Game.ConPlay.IsInState('WaitForInput') )
	{
		if ( ConEventChoice(Game.ConPlay.CurrentEvent)!=None )
			Game.ConPlay.PlayChoiceByIndex( 0 );
		else
			Game.ConPlay.PlayNextEvent();
	}
	else
		Game.ConPlay.SkipCurrent();
}

defaultproperties
{
	DriverClass=Class'HXFixTestConDriver'
}
