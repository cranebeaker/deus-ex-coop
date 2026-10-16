//=============================================================================
// HXFixTestConAuth2.
//
// Host is in a third person conversation. The remote client's advance / choice
// RPCs must be ignored, the host's own must work (control).
//=============================================================================
class HXFixTestConAuth2 extends HXFixTestConBase;

var HXPlayerPawn H, R;
var HXScriptedPawn Paul;
var ConEvent Before;
var int Ticks;
var bool bChoiceTested;

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
			H.SetLocation( Paul.Location + vect(0,100,50) );
			return 2.5;

		case 1:
			Game.StartConversationByName( H, 'MeetPaul', Paul, false, false );
			return 2.0;

		case 2:
			if ( !Check(Game.ConPlay!=None && Game.ConPlay.Player==H, "control: host in MeetPaul") )
				return -1;
			Before = Game.ConPlay.CurrentEvent;
			CDriver(R).ClientCall( "advance" );
			return 1.0;

		case 3:
			Check( Game.ConPlay!=None && Game.ConPlay.CurrentEvent==Before, "remote's advance RPC ignored (" $ ConState() $ ")" );
			CDriver(H).ClientCall( "advance" );
			return 1.0;

		case 4:
			Check( Game.ConPlay==None || Game.ConPlay.CurrentEvent!=Before, "control: host's advance RPC works" );
			return 0.5;

		default:
			// Walk to the first choice using the host's RPCs.
			if ( !bChoiceTested && Game.ConPlay!=None && Ticks++<80 )
			{
				if ( Game.ConPlay.IsInState('WaitForInput') && ConEventChoice(Game.ConPlay.CurrentEvent)!=None )
				{
					bChoiceTested = True;
					Before = Game.ConPlay.CurrentEvent;
					CDriver(R).ClientCall( "choice" );
					return 1.5;
				}
				if ( Game.ConPlay.IsInState('WaitForInput') )
					Game.ConPlay.PlayNextEvent();
				else
					CDriver(H).ClientCall( "advance" );
				return 0.7;
			}
			if ( bChoiceTested && Before!=None )
			{
				Check( Game.ConPlay!=None && Game.ConPlay.CurrentEvent==Before, "remote's choice RPC ignored" );
				CDriver(H).ClientCall( "choice" );
				Before = None;
				return 1.5;
			}
			if ( bChoiceTested )
				Check( Game.ConPlay==None || ConEventChoice(Game.ConPlay.CurrentEvent)==None, "control: host's choice RPC works" );
			else
				Note( "no choice event reached" );
	}
	return -1;
}

defaultproperties
{
	TimeoutSeconds=240.000000
}
