//=============================================================================
// HXFixTestConKilled.
//
// The host dies in a third person conversation with Paul: the conversation
// is aborted (not marked played), Paul can be talked to again by the remote
// player, and datalinks still play afterwards.
//=============================================================================
class HXFixTestConKilled extends HXFixTestConBase;

var HXPlayerPawn H, R;
var HXScriptedPawn Paul;
var HXFixTestDLTrigger Trig;
var HXFixTestEventSink Sink;
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
			H.SetLocation( Paul.Location + vect(0,100,50) );
			return 2.0;

		case 1:
			Game.StartConversationByName( H, 'MeetPaul', Paul, false, false );
			return 2.0;

		case 2:
			if ( !Check(Game.ConPlay!=None && Game.ConPlay.Player==H, "control: host in MeetPaul") )
				return -1;
			Check( Paul.bInConversation, "control: Paul is in conversation" );
			Check( Paul.CanConverse(), "control: Paul can converse before" );
			H.TakeDamage( 9999, None, H.Location, vect(0,0,0), 'Fell' );
			return 3.0;

		case 3:
			Check( H.Health<=0, "host is dead" );
			Check( Game.ConPlay==None, "conversation aborted by the death (state" @ ConState() $ ")" );
			Check( !Game.Steve.FlagBase.GetBool('MeetPaul_Played'), "MeetPaul not marked as played" );
			Check( !Paul.bInConversation, "Paul is free again" );
			// Datalinks must still work.
			Sink = Spawn( class'HXFixTestEventSink',,'HXFixKillEvt' );
			Trig = Spawn( class'HXFixTestDLTrigger' );
			Trig.DatalinkTag = 'DL_StartGame';
			Trig.Event = 'HXFixKillEvt';
			Check( Trig.Fire(R), "datalink DL_StartGame accepted after the death" );
			return 1.0;

		case 4:
			Check( Game.DataLinkPlay!=None, "datalink is playing" );
			R.SetLocation( Paul.Location + vect(0,100,50) );
			return 2.0;

		case 5:
			if ( !Paul.CanConverse() && Ticks++<30 )
			{
				if ( Ticks%5==1 )
					Note( "waiting for Paul to calm down, state" @ Paul.GetStateName() );
				return Again();
			}
			Ticks = 0;
			Check( Paul.CanConverse(), "Paul can converse again (state" @ Paul.GetStateName() $ ")" );
			Note( "Paul state" @ Paul.GetStateName() @ "R state" @ R.GetStateName() @ "phys" @ R.Physics @ "canGame" @ Game.CanGameStartConversation() @ "canPlayer" @ Game.CanPlayerStartConversation(R) @ "canConverse" @ Paul.CanConverse() @ "dist" @ VSize(R.Location-Paul.Location) );
			Note( "start ->" @ Game.StartConversationByName( R, 'MeetPaul', Paul, false, false ) );
			return 2.0;

		case 6:
			if ( !Check(Game.ConPlay!=None && Game.ConPlay.Player==R, "Paul talkable again: MeetPaul runs with the remote (" $ ConState() $ ")") )
				return -1;
			return 1.0;

		default:
			if ( Game.ConPlay!=None && Ticks<80 )
			{
				Ticks++;
				AdvanceCon();
				return 0.7;
			}
			if ( Sink.Count==0 && Ticks<200 )
			{
				Ticks++;
				return 1.0;
			}
	}
	Check( Game.ConPlay==None, "conversation finished" );
	Check( Trig.Finished==1 && Sink.Count==1, "datalink trigger event fired once after the death (finished=" $ Trig.Finished $ " sink=" $ Sink.Count $ ")" );
	Check( Game.Steve.FlagBase.GetBool('MeetPaul_Played'), "MeetPaul played now" );
	return -1;
}

defaultproperties
{
	TimeoutSeconds=240.000000
}
