//=============================================================================
// HXFixTestExit.
//
// Test helper: spawned when the URL has ?HXFixTestExit=<seconds>. Quits the
// server cleanly so automated boot tests get a complete log.
//=============================================================================
class HXFixTestExit extends Info;

function Timer()
{
	Log( "HXFixTestExit: shutting down", 'HXFix' );
	ConsoleCommand( "exit" );
}
