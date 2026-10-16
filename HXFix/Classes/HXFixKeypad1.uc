//=============================================================================
// HXFixKeypad1.
//
// HXKeypad1 which works for several players:
//  - HackAction no longer refuses everybody while the listen host has the
//    keypad window open (keypadwindow is only set on the host's own copy).
//  - Two players entering the code together toggled the lock twice (or ran
//    the event twice), cancelling each other out.
//=============================================================================
class HXFixKeypad1 extends HXKeypad1;

var float FixLastToggle;
var float FixLastEvent;
var float FixLastUntrigger;

const FixDebounce = 2.0;


function HackAction( Actor Hacker, bool bHacked )
{
	local HXPlayerPawn User;

	User = HXPlayerPawn(Hacker);
	if ( User==None )
		return;

	// Only the player who has the window open on this very copy is blocked.
	if ( keypadwindow!=None && Viewport(User.Player)!=None )
		return;

	User.HXActivateKeypadWindow( Self, bHacked );
}

function ToggleLocks( DeusExPlayer Player )
{
	if ( FixLastToggle>0 && Level.TimeSeconds-FixLastToggle<FixDebounce )
		return;
	FixLastToggle = Level.TimeSeconds;
	Super.ToggleLocks( Player );
}

function RunEvents( DeusExPlayer Player, bool bSuccess )
{
	if ( bSuccess )
	{
		if ( FixLastEvent>0 && Level.TimeSeconds-FixLastEvent<FixDebounce )
			return;
		FixLastEvent = Level.TimeSeconds;
	}
	Super.RunEvents( Player, bSuccess );
}

function RunUntriggers( DeusExPlayer Player )
{
	if ( FixLastUntrigger>0 && Level.TimeSeconds-FixLastUntrigger<FixDebounce )
		return;
	FixLastUntrigger = Level.TimeSeconds;
	Super.RunUntriggers( Player );
}
