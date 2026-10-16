//=============================================================================
// HXFixTestTravelBase.
//
// Base for live tests spanning map changes. The test object dies with the
// map, so the stage and the failure count live in Steve's flags (they travel
// with the campaign). RunStep numbers restart on every map: subclasses switch
// on Stage() first. TravelTo() respawns the test on the next map.
//=============================================================================
class HXFixTestTravelBase extends HXFixTestBase;

// Int flags did not survive travel in testing, bool flags do: counters are
// stored as a run of bool flags <Name>_1 .. <Name>_N.
var bool bPrepTravel;
var string PendingURL;
var float PendingTime;

function int GetCounter( Name N )
{
	local int i;

	if ( Game==None || Game.Steve==None )
		return 0;
	while ( i<250 && Game.Steve.FlagBase.GetBool( class'HXActor'.static.StringToName(string(N)$"_"$(i+1)) ) )
		i++;
	return i;
}

function SetCounter( Name N, int V )
{
	Game.Steve.FlagBase.SetBool( class'HXActor'.static.StringToName(string(N)$"_"$V), True, True, 0 );
}

function int Stage()
{
	return GetCounter( 'HXFixT_Stage' );
}

function SetStage( int N )
{
	SetCounter( 'HXFixT_Stage', N );
}

function bool Check( bool bOk, string What )
{
	if ( !bOk )
		SetCounter( 'HXFixT_Fails', GetCounter('HXFixT_Fails')+1 );
	else
		SetCounter( 'HXFixT_Passes', GetCounter('HXFixT_Passes')+1 );
	return Super.Check( bOk, What );
}

function Finish()
{
	// Counts of earlier maps (this map's are already included in the flags).
	Passes = GetCounter( 'HXFixT_Passes' );
	Fails  = GetCounter( 'HXFixT_Fails' );
	Super.Finish();
}

// Next stage on the given map. Returns a delay for RunStep.
function float TravelTo( string MapName, optional bool bItems )
{
	local HXFixTestProbeDriver D;

	SetStage( Stage()+1 );
	Note( "travel to" @ MapName @ "stage" @ Stage() );
	PendingURL = MapName $ "?Game=HXFix.HXFixGameInfo?HXFixTest=" $ Class.Name;
	if ( bPrepTravel )
	{
		foreach AllActors( class'HXFixTestProbeDriver', D )
			D.ClientPrepTravel();
		PendingTime = Elapsed + 1.0;
	}
	else
		PendingTime = Elapsed;
	return 100.0;
}

function Timer()
{
	Super.Timer();
	if ( PendingURL!="" && Elapsed>=PendingTime )
	{
		Level.ServerTravel( PendingURL, True );
		PendingURL = "";
	}
}

function HXFixTestProbeDriver Probe( Pawn P )
{
	local HXFixTestProbeDriver D;

	D = HXFixTestProbeDriver( DriverFor(P) );
	if ( D!=None )
		D.ClientProbe();
	return D;
}

defaultproperties
{
	bPrepTravel=False
	DriverClass=Class'HXFixTestProbeDriver'
}
