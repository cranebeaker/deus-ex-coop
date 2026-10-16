//=============================================================================
// HXFixTestCounter.
//
// Test helper which counts Trigger/UnTrigger calls.
//=============================================================================
class HXFixTestCounter extends Actor;

var int Triggers, UnTriggers;

function Trigger( Actor Other, Pawn EventInstigator )
{
	Triggers++;
}

function UnTrigger( Actor Other, Pawn EventInstigator )
{
	UnTriggers++;
}

defaultproperties
{
	bHidden=True
	RemoteRole=ROLE_None
}
