//=============================================================================
// HXFixTestDLQueue.
//
// 1. Two datalinks started back to back: the second is queued, still accepted,
//    and both triggers fire their Event when their datalink finished.
// 2. A datalink started during a third person conversation is held back and
//    plays (and fires its Event) once the conversation ended.
//=============================================================================
class HXFixTestDLQueue extends HXFixTestConBase;

var HXPlayerPawn H, R;
var HXScriptedPawn Paul;
var HXFixTestDLTrigger TrigA, TrigB, TrigC;
var HXFixTestEventSink SinkA, SinkB, SinkC;
var int Ticks;

function HXFixTestDLTrigger MakeTrigger( name DL, name Evt )
{
	local HXFixTestDLTrigger T;

	T = Spawn( class'HXFixTestDLTrigger' );
	T.DatalinkTag = DL;
	T.Event = Evt;
	return T;
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
			SinkA = Spawn( class'HXFixTestEventSink',,'HXFixEvtA' );
			SinkB = Spawn( class'HXFixTestEventSink',,'HXFixEvtB' );
			SinkC = Spawn( class'HXFixTestEventSink',,'HXFixEvtC' );
			TrigA = MakeTrigger( 'DL_StartGame', 'HXFixEvtA' );
			TrigB = MakeTrigger( 'DL_Hermann', 'HXFixEvtB' );
			TrigC = MakeTrigger( 'DL_Top', 'HXFixEvtC' );
			return 1.0;

		case 1:
			Check( TrigA.Fire(H), "first datalink accepted" );
			Check( Game.DataLinkPlay!=None, "datalink runner exists" );
			Check( TrigB.Fire(H), "second datalink accepted although queued behind the first" );
			return 1.0;

		case 2:
			if ( (SinkA.Count==0 || SinkB.Count==0) && Ticks++<150 )
				return Again();
			Ticks = 0;
			Check( TrigA.Finished==1 && SinkA.Count==1, "first trigger event fired once (finished=" $ TrigA.Finished $ " sink=" $ SinkA.Count $ ")" );
			Check( TrigB.Finished==1 && SinkB.Count==1, "queued datalink trigger event fired once (finished=" $ TrigB.Finished $ " sink=" $ SinkB.Count $ ")" );
			return 6.0;

		case 3:
			Check( Game.DataLinkPlay==None, "datalink runner cleaned up (" $ Game.DataLinkPlay $ ")" );
			H.SetLocation( Paul.Location + vect(0,100,50) );
			return 2.0;

		case 4:
			Game.StartConversationByName( H, 'MeetPaul', Paul, false, false );
			return 2.0;

		case 5:
			if ( !Check(Game.ConPlay!=None, "control: conversation running") )
				return -1;
			Check( TrigC.Fire(H), "datalink accepted while a conversation runs" );
			return 3.0;

		case 6:
			Check( SinkC.Count==0 && Game.ConPlay!=None, "datalink held back by the conversation" );
			Game.AbortConversation( True );
			return 1.0;

		default:
			if ( SinkC.Count==0 && Ticks++<100 )
				return Again();
			Check( TrigC.Finished==1 && SinkC.Count==1, "held back datalink played after the conversation and fired its Event (finished=" $ TrigC.Finished $ " sink=" $ SinkC.Count $ ")" );
			return -1;
	}
	return -1;
}

defaultproperties
{
	TimeoutSeconds=400.000000
}
