//=============================================================================
// HXFixDataLinkManager.
//
// The stock dry runner queued a datalink behind a running one but still
// reported failure, so HXDataLinkTrigger never remembered it had started the
// transmission and its Event never fired. Report success for queued
// datalinks and hand the trigger to HXFixDataLinkDryRunner, which notifies
// the matching trigger when that very datalink finishes.
//=============================================================================
class HXFixDataLinkManager extends HXDataLinkManager
	transient;

function bool StartDataLinkDryRunner( string DataLinkName, optional HXDataLinkTrigger DatalinkTrigger )
{
	local Conversation ActiveDataLink;
	local HXFixDataLinkDryRunner Runner;
	local bool bSpawned, bWasQueued, bWasCurrent;

	if ( Level.bPlayersOnly )
		return false;

	ActiveDataLink = GetActiveDataLink( DataLinkName );
	if ( ActiveDataLink==None )
		return false;

	if ( Game.DataLinkPlay==None )
	{
		Runner = Game.Spawn( class'HXFixDataLinkDryRunner' );
		Game.DataLinkPlay = Runner;
		bSpawned = true;
	}
	else
	{
		Runner = HXFixDataLinkDryRunner(Game.DataLinkPlay);
		if ( Runner==None )
			return Super.StartDataLinkDryRunner( DataLinkName, DatalinkTrigger );
	}

	bWasQueued  = Runner.IsQueued( ActiveDataLink );
	bWasCurrent = Runner.IsCurrent( ActiveDataLink );

	// Already playing or waiting in the queue: nothing to do (like stock).
	if ( bWasQueued || bWasCurrent )
		return false;

	Runner.RegisterTrigger( ActiveDataLink, DatalinkTrigger );

	if ( Runner.SetConversation(ActiveDataLink) )
	{
		if ( Runner.StartDryConversation(Game) )
			return true;

		Runner.UnregisterTrigger( ActiveDataLink, DatalinkTrigger );
		if ( bSpawned )
		{
			Runner.Destroy();
			Game.DataLinkPlay = None;
		}
		return false;
	}

	// Not started: freshly queued behind a running datalink (or the queue was full).
	if ( Runner.IsQueued(ActiveDataLink) )
	{
		Log( "HXFix: queued datalink" @ DataLinkName, 'HXFix' );
		return true;
	}

	Runner.UnregisterTrigger( ActiveDataLink, DatalinkTrigger );
	if ( bSpawned )
	{
		Runner.Destroy();
		Game.DataLinkPlay = None;
	}
	return false;
}
