//=============================================================================
// HXFixMedicalBot.
//
// HXMedicalBot which can't get stuck "in use". If the session is closed while the
// raise animation still runs, or the bot leaves its On/Off states mid
// animation, curFrobber and bAnimating stayed set forever.
//=============================================================================
class HXFixMedicalBot extends HXMedicalBot;

var bool bFixCloseRequested;


// Closed while still raising the arm: the On state code can't be aborted
// cleanly, so remember it and lower the arm as soon as it is up.
function CloseOut()
{
	if ( curFrobber!=None && !bOn && bAnimating )
	{
		bFixCloseRequested = True;
		return;
	}
	Super.CloseOut();
}

function TryInvoke()
{
	if ( bFixCloseRequested )
	{
		bFixCloseRequested = False;
		curFrobber = None;
		GotoState( 'Off' );
		return;
	}
	Super.TryInvoke();
}

simulated event Tick( float DeltaTime )
{
	Super.Tick( DeltaTime );

	if ( Role!=ROLE_Authority || curFrobber==None )
		return;

	// Off state without anything running: nothing will ever release the bot.
	if ( IsInState('Off') && !bOn )
	{
		Log( "HXFix: releasing stuck" @ Self, 'HXFix' );
		bAnimating = False;
		bFixCloseRequested = False;
		curFrobber = None;
		FollowOrders();
	}
	// Left On/Off (damage, EMP...) mid session.
	else if ( !IsInState('On') && !IsInState('Off') )
	{
		Log( "HXFix: releasing" @ Self @ "which left its use states", 'HXFix' );
		bOn = False;
		bAnimating = False;
		bFixCloseRequested = False;
		curFrobber = None;
	}
}
