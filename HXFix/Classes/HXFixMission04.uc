//=============================================================================
// HXFixMission04.
//
// - HX only started the hotel raid once the Paul conversation was played, but
//   it started that conversation without a player, which fails for third
//   person conversations (and for any other reason it can't start). Start it
//   with the player nearest to Paul and, if it still hasn't played after a
//   while, mark it played so the raid happens like in the stock game.
// - 04_NYC_FREECLINIC: unhide the UNATCO troops after the Paul conversation.
//=============================================================================
class HXFixMission04 extends HXMission04;

var float RaidWaitStart;
var float RaidWaitTime;

function FirstFrame()
{
	Super.FirstFrame();

	if ( LocalURL=="04_NYC_FREECLINIC" && GetBoolFlag('TalkedToPaulAfterMessage_Played') )
		PawnsEnterWorld( UNATCOTroopClass );
}

function Timer()
{
	local Actor Paul;
	local Pawn P;
	local HXPlayerPawn Candidate, Target;
	local float Dist, BestDist;

	Super.Timer();

	if ( LocalURL!="04_NYC_HOTEL" || GetBoolFlag('M04RaidTeleportDone') || GetBoolFlag('TalkedToPaulAfterMessage_Played')
	  || !GetBoolFlag('ApartmentEntered') || !GetBoolFlag('NSFSignalSent') )
	{
		RaidWaitStart = 0;
		return;
	}

	if ( RaidWaitStart==0 )
		RaidWaitStart = Level.TimeSeconds;

	// Try the conversation with a real player.
	if ( PaulDentonClass!=None && Game.ConPlay==None )
	{
		foreach AllActors( PaulDentonClass, Paul )
		{
			for ( P=Level.PawnList; P!=None; P=P.NextPawn )
			{
				Candidate = HXPlayerPawn(P);
				if ( Candidate==None || Candidate.bDeleteMe || Candidate.Health<=0 )
					continue;
				Dist = VSize( Candidate.Location - Paul.Location );
				if ( Target==None || Dist<BestDist )
				{
					Target   = Candidate;
					BestDist = Dist;
				}
			}
			if ( Target!=None )
				Game.StartConversationByName( Target, 'TalkedToPaulAfterMessage', Paul, false, false );
			break;
		}
	}

	// Don't let the raid depend on that conversation forever.
	if ( Level.TimeSeconds-RaidWaitStart>RaidWaitTime && Game.ConPlay==None )
	{
		Log( "HXFix: Paul conversation did not play, starting the raid anyway", 'HXFix' );
		SetBoolFlag( 'TalkedToPaulAfterMessage_Played', true, true, 5 );
	}
}

defaultproperties
{
	RaidWaitTime=25
}
