//=============================================================================
// HXFixMapExitNoItems.
//
// HXMapExitNoItems which only reacts to living players touching it (the original
// moved the whole server when any NPC, projectile or item touched it) and
// which can't soft lock when its transition camera path is missing.
//=============================================================================
class HXFixMapExitNoItems extends HXMapExitNoItems;

// Safety net: if the transition never reaches its end, travel anyway.
var float FixTransitionTimeout;


function Touch( Actor Other )
{
	if ( class'HXFixDeviceUtil'.static.IsLivePlayer(Other) )
		LoadMap( Other );
}

function LoadMap( Actor Other )
{
	if ( bFired )
		return;

	// Without a path starting at Position 1 the interpolation dummy never
	// moves and nobody ever travels.
	if ( bPlayTransition && !class'HXFixDeviceUtil'.static.HasTransitionPath(Self,CameraPathTag) )
	{
		Log( "HXFix:" @ Self @ "has no transition path for tag" @ CameraPathTag @ "- travelling directly", 'HXFix' );
		bPlayTransition = False;
	}

	Super.LoadMap( Other );

	if ( bPlayTransition && bFired )
		SetTimer( FixTransitionTimeout, False );
}

function Timer()
{
	local string NextURL;

	NextURL = DestMap;
	if ( InStr(NextURL,"/")==-1 && InStr(NextURL,"#")==-1 )
		NextURL = NextURL $ "#";

	Log( "HXFix:" @ Self @ "transition timed out - travelling", 'HXFix' );
	Level.ServerTravel( NextURL, bItems );
}

defaultproperties
{
	FixTransitionTimeout=90.0
}
