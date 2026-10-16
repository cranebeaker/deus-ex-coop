//=============================================================================
// HXFixTestConTravel.
//
// The host starts a conversation and the server changes map right away, as
// when a conversation ends in a level change. Every client must arrive on the
// next map (HXFixTestInvTravel2 checks). Run it with ?HXFixNetEmu packet loss.
//=============================================================================
class HXFixTestConTravel extends HXFixTestBase;

function float RunStep( int StepNum )
{
	local ScriptedPawn SP;
	local HXPlayerPawn H;
	local bool bStarted;

	switch ( StepNum )
	{
		case 0:
			H = Host();
			if ( !Check(H!=None && Remote()!=None, "host and remote client present") )
				return -1;
			foreach AllActors( class'ScriptedPawn', SP )
			{
				if ( SP.conListItems==None || SP.bHidden || SP.Health<=0 )
					continue;
				if ( Game.StartConversation(H, SP, IM_Frob, None, False, False) )
				{
					bStarted = True;
					break;
				}
			}
			Check( bStarted, "conversation started" );
			return 0.5;

		case 1:
			Note( "travelling during the conversation" );
			bDone = True;
			SetTimer( 0, False );
			Level.ServerTravel( "01_NYC_UNATCOHQ?Game=HXFix.HXFixGameInfo?HXFixTest=HXFixTestInvTravel2", False );
			return 999; // No Finish(): that exits the host.
	}
	return -1;
}

defaultproperties
{
	TimeoutSeconds=200.000000
}
