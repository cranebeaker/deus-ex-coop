//=============================================================================
// HXFixDataLinkDryRunner.
//
// - Remembers the trigger of every datalink, including queued ones, and
//   notifies the right trigger when that datalink finishes (stock kept a
//   single trigger, so queued datalinks never fired their Event).
// - bWaitingForConPlay marks a datalink that was held back by a running
//   conversation, so HXFixGameInfo can resume it if the conversation ended
//   without calling EndConversation.
// - Has no Player, so resolve one for the persona events.
//=============================================================================
class HXFixDataLinkDryRunner extends HXDataLinkDryRunner;

var Conversation TriggerCons[16];
var HXDataLinkTrigger Triggers[16];

var bool bWaitingForConPlay;

function RegisterTrigger( Conversation InCon, HXDataLinkTrigger InTrigger )
{
	local int i;

	if ( InCon==None || InTrigger==None )
		return;

	for ( i=0; i<ArrayCount(Triggers); i++ )
		if ( Triggers[i]==InTrigger && TriggerCons[i]==InCon )
			return;
	for ( i=0; i<ArrayCount(Triggers); i++ )
	{
		if ( Triggers[i]==None )
		{
			TriggerCons[i] = InCon;
			Triggers[i]    = InTrigger;
			return;
		}
	}
}

function UnregisterTrigger( Conversation InCon, HXDataLinkTrigger InTrigger )
{
	local int i;

	for ( i=0; i<ArrayCount(Triggers); i++ )
	{
		if ( TriggerCons[i]==InCon && Triggers[i]==InTrigger )
		{
			TriggerCons[i] = None;
			Triggers[i]    = None;
		}
	}
}

// True if InCon waits in the queue (not the one currently started).
function bool IsQueued( Conversation InCon )
{
	local int i;

	for ( i=0; i<ArrayCount(dataLinkQueue); i++ )
		if ( dataLinkQueue[i]==InCon )
			return True;
	return False;
}

function bool IsCurrent( Conversation InCon )
{
	return InCon!=None && (InCon==startCon || InCon==con);
}

function Bool StartDryConversation( HXGameInfo NewInfo )
{
	bWaitingForConPlay = NewInfo!=None && NewInfo.ConPlay!=None;
	return Super.StartDryConversation( NewInfo );
}

function NotifyDatalinkTrigger()
{
	local int i;
	local Conversation Finished;
	local HXDataLinkTrigger Trigger;

	Finished = startCon;
	if ( Finished==None )
		Finished = con;

	for ( i=0; i<ArrayCount(Triggers); i++ )
	{
		if ( Triggers[i]!=None && TriggerCons[i]==Finished )
		{
			Trigger        = Triggers[i];
			Triggers[i]    = None;
			TriggerCons[i] = None;
			Trigger.DatalinkFinished();
		}
	}
}

// ---------------------------------------------------------------------
// There is no Player in the dry run, use one of the players around.
// ---------------------------------------------------------------------

function HXPlayerPawn ResolvePlayer()
{
	local Pawn P;
	local HXPlayerPawn Candidate;
	local int i;

	for ( i=0; i<ArrayCount(Triggers); i++ )
		if ( Triggers[i]!=None && TriggerCons[i]==startCon && Triggers[i].Player!=None && Triggers[i].Player.Health>0 )
			return Triggers[i].Player;

	for ( P=Level.PawnList; P!=None; P=P.NextPawn )
	{
		Candidate = HXPlayerPawn(P);
		if ( Candidate!=None && !Candidate.bDeleteMe && Candidate.Health>0 )
			return Candidate;
	}
	return None;
}

function EEventAction SetupEventAddCredits( ConEventAddCredits Event, out String NextLabel )
{
	local HXPlayerPawn Target;

	Target = ResolvePlayer();
	if ( Target!=None )
		Target.Credits = Max( Target.Credits + Event.CreditsToAdd, 0 );

	NextLabel = "";
	return EA_NextEvent;
}

function EEventAction SetupEventCheckPersona( ConEventCheckPersona Event, out String NextLabel )
{
	local EEventAction Action;

	player = ResolvePlayer();
	if ( player==None )
	{
		NextLabel = "";
		return EA_NextEvent;
	}
	Action = Super.SetupEventCheckPersona( Event, NextLabel );
	player = None;
	return Action;
}
