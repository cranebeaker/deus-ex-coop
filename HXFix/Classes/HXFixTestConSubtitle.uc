//=============================================================================
// HXFixTestConSubtitle.
//
// Host talks to Paul (third person) far from the remote client: the client
// must receive the lines as messages (HXFixConPlay.SetupEventSpeechPost).
// Control: the remote must not have such lines before the conversation.
//=============================================================================
class HXFixTestConSubtitle extends HXFixTestConBase;

var HXPlayerPawn H, R;
var HXScriptedPawn Paul;
var int Ticks;

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
			Probe( R, "msg", "Paul Denton:" );
			return 1.0;

		case 1:
			if ( Pending(R) )
				return Again();
			Check( ProbeValue(R)==0, "control: remote has no Paul lines before the conversation (" $ ProbeValue(R) $ ")" );
			H.SetLocation( Paul.Location + vect(0,100,50) );
			return 1.5;

		case 2:
			Note( "distance host-Paul" @ VSize(H.Location-Paul.Location) @ "remote-Paul" @ VSize(R.Location-Paul.Location) );
			Check( VSize(R.Location-Paul.Location)>1200, "remote is far from Paul" );
			Note( "StartConversationByName ->" @ Game.StartConversationByName(H,'MeetPaul',Paul,false,false) @ "(Paul may already have started it by radius)" );
			return 1.5;

		case 3:
			if ( !Check(Game.ConPlay!=None && Game.ConPlay.Player==H, "ConPlay runs with the host as player") )
				return -1;
			return 0.5;

		default:
			if ( Game.ConPlay!=None && Ticks<60 )
			{
				Ticks++;
				if ( Ticks%5==0 )
					Note( "conplay state" @ ConState() @ "event" @ Game.ConPlay.CurrentEvent );
				AdvanceCon();
				return 0.7;
			}
			if ( Ticks>=0 )
			{
				Ticks = -1;
				Probe( R, "msg", "Paul Denton:" );
				return 1.0;
			}
			if ( Pending(R) )
				return Again();
	}
	Check( ProbeValue(R)>0, "remote received Paul's lines as messages (" $ ProbeValue(R) $ ")" );
	return -1;
}

defaultproperties
{
	TimeoutSeconds=240.000000
}
