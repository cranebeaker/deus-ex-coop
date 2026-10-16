//=============================================================================
// HXFixTestDriver.
//
// Live test helper, one per player, owned by that player. Lets a server side
// test make a real client run console commands (exec functions), so the
// normal client->server RPC paths get exercised end to end.
//=============================================================================
class HXFixTestDriver extends Info;

var bool bServerReady;   // Server: client reported in.
var bool bSentReady;     // Client: already reported.
var int Reports;         // Server: ServerReport calls so far.

replication
{
	reliable if ( Role==ROLE_Authority )
		ClientExec;
	reliable if ( Role<ROLE_Authority )
		ServerReady, ServerReport;
}

simulated function Tick( float DeltaTime )
{
	// Only the owning client's local pawn has a Player.
	if ( Role==ROLE_Authority || bSentReady || PlayerPawn(Owner)==None || PlayerPawn(Owner).Player==None )
		return;

	bSentReady = True;
	Log( "HXFixTest: client driver up for" @ Owner, 'HXFixTest' );
	ServerReady();
}

function ServerReady()
{
	bServerReady = True;
}

// Runs on the owning client (locally for the listen host).
simulated function ClientExec( string Cmd )
{
	local string Result;

	if ( PlayerPawn(Owner)==None )
		return;

	Log( "HXFixTest: client exec '" $ Cmd $ "' on" @ Owner, 'HXFixTest' );
	Result = PlayerPawn(Owner).ConsoleCommand( Cmd );
	if ( Result!="" )
		ServerReport( Cmd $ " -> " $ Result );
}

// Lets client side test code send observations to the server log.
function ServerReport( string Msg )
{
	Reports++;
	Log( "HXFixTest: client report from" @ Owner $ ":" @ Msg, 'HXFixTest' );
}

defaultproperties
{
	RemoteRole=ROLE_SimulatedProxy
	bAlwaysRelevant=True
	bHidden=True
}
