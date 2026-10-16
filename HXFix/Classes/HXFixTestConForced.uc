//=============================================================================
// HXFixTestConForced.
//
// A forced conversation started while the host is in a third person
// conversation is deferred: the first one keeps running and is not marked
// played, the forced one plays afterwards.
//=============================================================================
class HXFixTestConForced extends HXFixTestConBase;

var HXPlayerPawn H, R;
var HXScriptedPawn Paul, Filben;
var int Ticks;
var bool bFilbenSeen;

function float RunStep( int StepNum )
{
	switch ( StepNum )
	{
		case 0:
			H = Host();
			R = Remote();
			Paul = FindNPC( "PaulDenton" );
			Filben = FindNPC( "HarleyFilben" );
			if ( !Check(H!=None && R!=None && Paul!=None && Filben!=None, "host, remote, Paul and Filben present") )
				return -1;
			H.SetLocation( Paul.Location + vect(0,100,50) );
			R.SetLocation( Filben.Location + vect(0,100,50) );
			return 2.0;

		case 1:
			Game.StartConversationByName( H, 'MeetPaul', Paul, false, false );
			return 2.0;

		case 2:
			if ( !Check(Game.ConPlay!=None && Game.ConPlay.Player==H && Game.ConPlay.Con.ConName=='MeetPaul', "control: host in MeetPaul") )
				return -1;
			Note( "forced start returned" @ Game.StartConversationByName(R,'MeetFilben',Filben,false,true) );
			return 1.0;

		case 3:
			Check( Game.ConPlay!=None && Game.ConPlay.Player==H && Game.ConPlay.Con.ConName=='MeetPaul', "MeetPaul still runs for the host after the forced start" );
			Check( !Game.Steve.FlagBase.GetBool('MeetPaul_Played'), "MeetPaul not marked played by the forced conversation" );
			Check( !Game.Steve.FlagBase.GetBool('MeetPaul_Interrupted'), "MeetPaul not marked interrupted" );
			Check( Game.NumDeferred==1, "forced conversation deferred (NumDeferred=" $ Game.NumDeferred $ ")" );
			return 0.5;

		default:
			if ( Game.ConPlay!=None && Game.ConPlay.Con!=None )
			{
				if ( Game.ConPlay.Con.ConName=='MeetFilben' )
					bFilbenSeen = True;
				else
					Check( Game.ConPlay.Player==H, "only the host runs MeetPaul" );
			}
			if ( (Game.ConPlay!=None || Game.NumDeferred>0 || !bFilbenSeen) && Ticks<120 )
			{
				Ticks++;
				if ( Ticks%10==0 )
					Note( "state" @ ConState() @ "deferred" @ Game.NumDeferred @ "filben" @ bFilbenSeen );
				AdvanceCon();
				return 0.7;
			}
	}
	Check( Game.Steve.FlagBase.GetBool('MeetPaul_Played'), "MeetPaul played to its end" );
	Check( bFilbenSeen, "deferred MeetFilben played afterwards" );
	Check( Game.ConPlay==None && Game.NumDeferred==0, "everything finished" );
	return -1;
}

defaultproperties
{
	TimeoutSeconds=240.000000
}
