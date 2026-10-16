//=============================================================================
// HXFixTestBase.
//
// Base for live tests: ?HXFixTest=<ClassName> on the listen server URL.
// Waits until MinPlayers players (listen host + remote clients) have their
// HXFixTestDriver up, then calls RunStep(0), RunStep(1), ... RunStep returns
// the delay in seconds before the next step, or a negative value when done.
// Results go to the log as "HXFixTest: PASS/FAIL ...", ending with
// "HXFixTest: DONE pass=N fail=M", after which the host exits.
// ?HXFixNetEmu=PktLag=150,PktLoss=5 runs those engine net emulation commands
// on the host and every client first, to get internet like conditions.
//=============================================================================
class HXFixTestBase extends Info;

var int MinPlayers;
var class<HXFixTestDriver> DriverClass; // Subclass to add client side probes.
var float TimeoutSeconds;

var int Step, Passes, Fails;
var bool bStarted, bDone;
var float Elapsed, NextStepTime;
var HXFixGameInfo Game;

function PostBeginPlay()
{
	Super.PostBeginPlay();
	Game = HXFixGameInfo(Level.Game);
	SetTimer( 0.25, True );
	Log( "HXFixTest: test" @ Class.Name @ "loaded on" @ Level.Outer.Name, 'HXFixTest' );
}

// ---------------------------------------------------------------------
// To override.
// ---------------------------------------------------------------------

function float RunStep( int StepNum )
{
	return -1;
}

// ---------------------------------------------------------------------
// Helpers.
// ---------------------------------------------------------------------

function HXFixTestDriver DriverFor( Pawn P )
{
	local HXFixTestDriver D;

	foreach AllActors( class'HXFixTestDriver', D )
		if ( D.Owner==P )
			return D;
	return None;
}

function HXPlayerPawn PlayerAt( int Index, bool bRemote )
{
	local Pawn P;
	local int i;

	for ( P=Level.PawnList; P!=None; P=P.NextPawn )
	{
		if ( HXPlayerPawn(P)==None || PlayerPawn(P).Player==None || P.bDeleteMe )
			continue;
		if ( bRemote==(Viewport(PlayerPawn(P).Player)==None) )
		{
			if ( i==Index )
				return HXPlayerPawn(P);
			i++;
		}
	}
	return None;
}

// First remote client / the listen host.
function HXPlayerPawn Remote( optional int Index ) { return PlayerAt( Index, True ); }
function HXPlayerPawn Host() { return PlayerAt( 0, False ); }

function ClientCmd( Pawn P, string Cmd )
{
	local HXFixTestDriver D;

	D = DriverFor( P );
	if ( D==None )
	{
		Check( False, "no driver for" @ P @ "to run '" $ Cmd $ "'" );
		return;
	}
	D.ClientExec( Cmd );
}

function bool Check( bool bOk, string What )
{
	if ( bOk )
	{
		Passes++;
		Log( "HXFixTest: PASS" @ What, 'HXFixTest' );
	}
	else
	{
		Fails++;
		Log( "HXFixTest: FAIL" @ What, 'HXFixTest' );
	}
	return bOk;
}

function Note( string Msg )
{
	Log( "HXFixTest: NOTE" @ Msg, 'HXFixTest' );
}

// ---------------------------------------------------------------------
// Driver.
// ---------------------------------------------------------------------

function int ReadyPlayers()
{
	local Pawn P;
	local HXFixTestDriver D;
	local int Num;

	for ( P=Level.PawnList; P!=None; P=P.NextPawn )
	{
		if ( HXPlayerPawn(P)==None || PlayerPawn(P).Player==None )
			continue;
		D = DriverFor( P );
		if ( D==None )
		{
			D = Spawn( DriverClass, P );
			continue;
		}
		// The listen host's driver is local, no handshake needed.
		if ( D.bServerReady || Viewport(PlayerPawn(P).Player)!=None )
			Num++;
	}
	return Num;
}

function Timer()
{
	local float Delay;

	if ( bDone )
		return;

	Elapsed += 0.25;
	if ( Elapsed>TimeoutSeconds )
	{
		Check( False, "timeout after" @ int(TimeoutSeconds) $ "s at step" @ Step @ "(started=" $ bStarted $ ")" );
		Finish();
		return;
	}

	if ( !bStarted )
	{
		if ( ReadyPlayers()<MinPlayers )
			return;
		bStarted = True;
		Note( "starting with" @ MinPlayers @ "players" );
		ApplyNetEmu();
		NextStepTime = Elapsed + 2.0;
		return;
	}

	if ( Elapsed<NextStepTime )
		return;

	Delay = RunStep( Step++ );
	if ( Delay<0 )
		Finish();
	else
		NextStepTime = Elapsed + Delay;
}

function ApplyNetEmu()
{
	local string Cmds, Cmd;
	local Pawn P;
	local int i;

	if ( Game==None )
		return;
	Cmds = Game.TestNetEmu;
	while ( Cmds!="" )
	{
		i = InStr( Cmds, "," );
		if ( i<0 )
		{
			Cmd  = Cmds;
			Cmds = "";
		}
		else
		{
			Cmd  = Left( Cmds, i );
			Cmds = Mid( Cmds, i+1 );
		}
		Note( "net emulation:" @ Cmd @ "-> host" @ ConsoleCommand(Cmd) );
		for ( P=Level.PawnList; P!=None; P=P.NextPawn )
			if ( HXPlayerPawn(P)!=None && PlayerPawn(P).Player!=None && Viewport(PlayerPawn(P).Player)==None )
				ClientCmd( P, Cmd );
	}
}

function Finish()
{
	bDone = True;
	Log( "HXFixTest: DONE" @ Class.Name @ "pass=" $ Passes @ "fail=" $ Fails, 'HXFixTest' );
	SetTimer( 0, False );
	ConsoleCommand( "exit" );
}

defaultproperties
{
	MinPlayers=2
	DriverClass=Class'HXFixTestDriver'
	TimeoutSeconds=150.000000
}
