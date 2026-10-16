//=============================================================================
// HXFixInterpolateResender.
//
// HXInterpolateTrigger only tells the clients present at that moment to run
// the path, so players joining later saw the actors (helicopters, platforms)
// at their start positions. A while after the player entered the game, this
// replays every already fired path on that client.
//=============================================================================
class HXFixInterpolateResender extends Info;

var HXPlayerPawn Target;
var HXFixDevicesMutator Source;
var int Tries;

function Begin( HXPlayerPawn NewTarget, HXFixDevicesMutator NewSource )
{
	Target = NewTarget;
	Source = NewSource;
	SetTimer( 8.0, True );
}

function Timer()
{
	local int i, Num;

	Tries++;
	if ( Target==None || Target.bDeleteMe || Source==None || Tries>3 )
	{
		Destroy();
		return;
	}

	// Wait for the client to be in game.
	if ( Target.Player==None || Target.Health<=0 )
		return;

	for ( i=0; i<Source.NumPaths; i++ )
	{
		Target.SendActorOnPath( Source.Paths[i] );
		Num++;
	}

	Log( "HXFix: resent" @ Num @ "interpolation paths to" @ Target, 'HXFix' );
	Destroy();
}
