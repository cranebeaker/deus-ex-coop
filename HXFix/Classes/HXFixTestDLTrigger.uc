//=============================================================================
// HXFixTestDLTrigger.
//
// Datalink trigger which can be fired from test code.
//=============================================================================
class HXFixTestDLTrigger extends HXDataLinkTrigger;

var int Finished;

function DatalinkFinished()
{
	Finished++;
	Log( "HXFixTest: datalink trigger" @ DatalinkTag @ "finished, event" @ Event, 'HXFixTest' );
	Super.DatalinkFinished();
}

function bool Fire( HXPlayerPawn InPlayer )
{
	// Like a player walking into the trigger (the Trigger() path never fires the Event).
	bInitiallyActive = True;
	Touch( InPlayer );
	return bStartedViaTouch;
}

defaultproperties
{
}
