//=============================================================================
// HXFixTestConDriver.
//
// Client side probes for the conversation tests. The server asks with
// ClientProbe(), the client answers through ServerProbeResult().
//=============================================================================
class HXFixTestConDriver extends HXFixTestDriver;

var string ProbeKind;     // Server: last answer.
var int    ProbeValue;
var int    ProbeCount;    // Server: number of answers received.

replication
{
	reliable if ( Role==ROLE_Authority )
		ClientProbe, ClientCall;
	reliable if ( Role<ROLE_Authority )
		ServerProbeResult;
}

// Counts something on this client.
//   msg <text>     console/message lines containing text
//   credits        credits of the local pawn
//   startup        1 if the startup message was shown by HXFixGameReplicationInfo
//   conwin         1 if a third person conversation window exists
//   hudstartup     1 if the HUD's startup display holds text
simulated function ClientProbe( string Kind, string Arg )
{
	local HXPlayerPawn Pawn;
	local HXFixGameReplicationInfo GRI;
	local Console Con;
	local int i, Num;

	Pawn = HXPlayerPawn(Owner);
	if ( Pawn==None )
	{
		ServerProbeResult( Kind, -999 );
		return;
	}

	if ( Kind=="msg" )
	{
		Con = Pawn.Player.Console;
		if ( Con!=None )
			for ( i=0; i<ArrayCount(Con.MsgText); i++ )
				if ( Con.MsgText[i]!="" && InStr(Con.MsgText[i],Arg)>=0 )
					Num++;
	}
	else if ( Kind=="credits" )
		Num = Pawn.ClientCredits;
	else if ( Kind=="startup" )
	{
		foreach AllActors( class'HXFixGameReplicationInfo', GRI )
			if ( GRI.bStartupShown )
				Num = 1;
	}
	else if ( Kind=="conwin" )
	{
		if ( Pawn.conWinThird!=None && Pawn.conWinThird.IsVisible() )
			Num = 1;
	}
	else if ( Kind=="note" )
	{
		if ( Pawn.FirstNote!=None )
			Num = 1;
	}
	Log( "HXFixTest: client probe" @ Kind @ Arg @ "=" @ Num, 'HXFixTest' );
	ServerProbeResult( Kind, Num );
}

// Calls a server function as this client (real RPC).
//   advance   ServerPlayNextConPlayEvent
//   choice    ServerPlayConPlayChoice(0)
simulated function ClientCall( string Kind )
{
	local HXPlayerPawn Pawn;

	Pawn = HXPlayerPawn(Owner);
	if ( Pawn==None )
		return;
	Log( "HXFixTest: client call" @ Kind, 'HXFixTest' );
	if ( Kind=="advance" )
		Pawn.ServerPlayNextConPlayEvent();
	else if ( Kind=="choice" )
		Pawn.ServerPlayConPlayChoice( 0 );
}

function ServerProbeResult( string Kind, int Value )
{
	ProbeKind = Kind;
	ProbeValue = Value;
	ProbeCount++;
	Log( "HXFixTest: client report from" @ Owner $ ": probe" @ Kind @ "=" @ Value, 'HXFixTest' );
}

defaultproperties
{
}
