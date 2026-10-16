//=============================================================================
// HXFixTestEventSink.
//
// Counts the events sent to its tag.
//=============================================================================
class HXFixTestEventSink extends Actor;

var int Count;

function Trigger( Actor Other, Pawn EventInstigator )
{
	Count++;
	Log( "HXFixTest: sink" @ Tag @ "triggered, count" @ Count, 'HXFixTest' );
}

defaultproperties
{
	bHidden=True
}
