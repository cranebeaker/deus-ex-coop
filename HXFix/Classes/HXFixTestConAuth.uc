//=============================================================================
// HXFixTestConAuth.
//
// Only the player in a conversation may advance it through the server RPCs.
// The host talks to Paul; the remote client's ServerPlayNextConPlayEvent /
// ServerPlayConPlayChoice must be ignored, the host's own call advances it.
//=============================================================================
class HXFixTestConAuth extends HXFixTestBase;

var HXPlayerPawn H, R;
var HXScriptedPawn Paul;
var ConEvent E0;
var int Ticks;
var bool bForce; // Forced (cinematic style) conversation: anybody may skip it.

function HXScriptedPawn FindNPC( string InBindName )
{
	local HXScriptedPawn S;

	foreach AllActors( class'HXScriptedPawn', S )
		if ( S.BindName~=InBindName )
			return S;
	return None;
}

function float RunStep( int StepNum )
{
	switch ( StepNum )
	{
		case 0:
			H = Host();
			R = Remote();
			Paul = FindNPC( "PaulDenton" );
			if ( !Check(H!=None && R!=None && Paul!=None, "host, remote and Paul present") )
				return -1;
			if ( !bForce )
				H.SetLocation( Paul.Location + vect(0,100,50) );
			return 2.0;

		case 1:
			if ( bForce )
				Check( Game.StartCinematicByName('MeetPaul',Paul), "cinematic started" );
			else
				Game.StartConversationByName( H, 'MeetPaul', Paul, false, false );
			return 1.0;

		case 2:
			if ( bForce )
			{
				if ( !Check(Game.ConPlay!=None, "cinematic conversation running") )
					return -1;
				Note( "player" @ Game.ConPlay.Player @ "force" @ Game.ConPlay.GetForcePlay() );
				Check( class'HXFixPlayerLogic'.static.MayControlConPlay(R), "remote client may skip a cinematic" );
				Check( class'HXFixPlayerLogic'.static.MayControlConPlay(H), "host may skip a cinematic" );
				// And through the real RPC.
				CDriver(R).ClientProbe( "connext", "" );
				return -1;
			}
			if ( !Check(Game.ConPlay!=None && Game.ConPlay.Player==H, "control: host is in MeetPaul") )
				return -1;
			return 0.3;

		default:
			// Wait until the conversation waits for input.
			if ( E0==None )
			{
				if ( Game.ConPlay==None )
				{
					Check( False, "conversation ended before waiting for input" );
					return -1;
				}
				if ( !Game.ConPlay.IsInState('WaitForInput') )
				{
					if ( ++Ticks>150 )
					{
						Check( False, "never reached WaitForInput" );
						return -1;
					}
					Game.ConPlay.SkipCurrent();
					return 0.5;
				}
				E0 = Game.ConPlay.CurrentEvent;
				Note( "waiting for input at" @ E0 @ "state" @ Game.ConPlay.GetStateName() @ "player" @ Game.ConPlay.Player @ "force" @ Game.ConPlay.GetForcePlay() @ "mayR" @ class'HXFixPlayerLogic'.static.MayControlConPlay(R) );
				if ( ConEventChoice(E0)!=None )
					CDriver(R).ClientProbe( "conchoice", "0" );
				else
					CDriver(R).ClientProbe( "connext", "" );
				return 1.5;
			}
			// Remote attempt done.
			if ( StepNum<1000 )
			{
				if ( bForce )
				{
					Check( Game.ConPlay==None || Game.ConPlay.CurrentEvent!=E0, "remote client may skip a forced conversation" );
					return -1;
				}
				if ( !Check(Game.ConPlay!=None && Game.ConPlay.Con!=None && Game.ConPlay.CurrentEvent==E0, "remote client could not advance the host's conversation") )
					return -1;
				// Host's own RPC works.
				if ( ConEventChoice(E0)!=None )
					CDriver(H).ClientProbe( "conchoice", "0" );
				else
					CDriver(H).ClientProbe( "connext", "" );
				Step = 1000;
				return 1.5;
			}
			Check( Game.ConPlay==None || Game.ConPlay.CurrentEvent!=E0, "control: host's own call advances the conversation" );
			return -1;
	}
	return -1;
}

function HXFixTestPlayerDriver CDriver( Pawn P )
{
	return HXFixTestPlayerDriver( DriverFor(P) );
}

defaultproperties
{
	DriverClass=Class'HXFixTestPlayerDriver'
	TimeoutSeconds=120.000000
}
