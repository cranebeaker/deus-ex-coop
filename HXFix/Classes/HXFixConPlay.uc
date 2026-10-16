//=============================================================================
// HXFixConPlay.
//
// First-person conversations have no Player (HXConPlay only sets it for
// third-person ones), so the stock credits / persona events accessed None
// and player->NPC item transfers lost their source. Resolve the player
// nearest to the speaking actor for the duration of those events.
//=============================================================================
class HXFixConPlay extends HXConPlay;

function HXPlayerPawn ResolvePlayer()
{
	local HXScriptedPawn ScriptedPawn;
	local HXPlayerPawn Best, Candidate;
	local Actor Ref;
	local Pawn P;
	local float Dist, BestDist;

	ScriptedPawn = HXScriptedPawn(StartActor);
	if ( ScriptedPawn==None )
		ScriptedPawn = HXScriptedPawn(InvokeActor);
	if ( ScriptedPawn!=None )
	{
		Best = ScriptedPawn.GetNearestPlayer();
		if ( Best!=None && !Best.bDeleteMe && Best.Health>0 )
			return Best;
		Best = None;
	}

	Ref = StartActor;
	if ( Ref==None )
		Ref = InvokeActor;

	for ( P=Level.PawnList; P!=None; P=P.NextPawn )
	{
		Candidate = HXPlayerPawn(P);
		if ( Candidate==None || Candidate.bDeleteMe || Candidate.Health<=0 )
			continue;
		if ( Ref!=None )
			Dist = VSize( Candidate.Location - Ref.Location );
		if ( Best==None || Dist<BestDist )
		{
			Best     = Candidate;
			BestDist = Dist;
		}
	}
	return Best;
}

function EEventAction SetupEventAddCredits( ConEventAddCredits Event, out String NextLabel )
{
	local EEventAction Action;

	if ( Player!=None )
		return Super.SetupEventAddCredits( Event, NextLabel );

	Player = ResolvePlayer();
	if ( Player==None )
	{
		NextLabel = "";
		return EA_NextEvent;
	}
	Action = Super.SetupEventAddCredits( Event, NextLabel );
	Player = None;
	return Action;
}

function EEventAction SetupEventCheckPersona( ConEventCheckPersona Event, out String NextLabel )
{
	local EEventAction Action;

	if ( Player!=None )
		return Super.SetupEventCheckPersona( Event, NextLabel );

	Player = ResolvePlayer();
	if ( Player==None )
	{
		NextLabel = "";
		return EA_NextEvent;
	}
	Action = Super.SetupEventCheckPersona( Event, NextLabel );
	Player = None;
	return Action;
}

function EEventAction SetupEventTransferObject( ConEventTransferObject Event, out String NextLabel )
{
	local EEventAction Action;

	if ( Player!=None )
		return Super.SetupEventTransferObject( Event, NextLabel );

	// Player->NPC transfers in first-person conversations.
	Player = ResolvePlayer();
	Action = Super.SetupEventTransferObject( Event, NextLabel );
	Player = None;
	return Action;
}

// ----------------------------------------------------------------------
// SetupEventSpeechPost()
//
// HX only shows a third-person conversation to its player and, as barks,
// to players within radius of the speaker. Everyone else on the map got
// nothing, so co-op partners missed the story. Send them the line as a
// message so the whole team follows the conversation.
// ----------------------------------------------------------------------

function EEventAction SetupEventSpeechPost( ConEventSpeech Event, out String NextLabel )
{
	local EEventAction Result;
	local Actor Speaker;
	local Pawn P;
	local string Speech, Line;

	Result = Super.SetupEventSpeechPost( Event, NextLabel );

	if ( Con==None || Con.bFirstPerson || Event==None || Event.ConSpeech==None )
		return Result;

	Speech = Event.ConSpeech.Speech;
	if ( Speech=="" )
		return Result;

	if ( Event.SpeakerName~=Game.BindName )
		Speaker = Player;
	else
		Speaker = Event.Speaker;

	Line = Game.GetDisplayName( Speaker ) $ ": " $ Speech;
	if ( Player!=None && Player.PlayerReplicationInfo!=None )
		Line = "[" $ Player.PlayerReplicationInfo.PlayerName $ "] " $ Line;

	for ( P=Level.PawnList; P!=None; P=P.NextPawn )
	{
		if ( HXPlayerPawn(P)==None || P==Player || P.bDeleteMe )
			continue;
		// Players near the speaker already see it as a bark.
		if ( Speaker!=None && CheckRadius(P,Speaker) )
			continue;
		P.ClientMessage( Line );
	}

	return Result;
}

// ----------------------------------------------------------------------
// PostTerminateConversation()
//
// HXGameInfo.CanPlayerStartConversation() refuses any start within a second
// of the last conversation's end. A forced conversation which HXFixGameInfo
// deferred until now would be dropped by that, so lift the guard for it.
// ----------------------------------------------------------------------

function PostTerminateConversation()
{
	Super.PostTerminateConversation();

	if ( HXFixGameInfo(Game)!=None && HXFixGameInfo(Game).NumDeferred>0 )
		Game.LastConEndTime = Level.TimeSeconds - 2.0;
}
