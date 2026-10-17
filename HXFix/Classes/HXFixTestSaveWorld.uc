//=============================================================================
// HXFixTestSaveWorld.
//
// Run twice (see tools/live_suite.txt):
//  A) normal start: autosave must happen after arrival; set distinctive flags
//     of every type, a goal, a note, a nanokey, credits; save with the
//     CoopSave console command and check the stored lines.
//  B) same map with ?HXFixLoad=1: all of it must be back (flags with their
//     expiration, goal text and completion, note, key, skill points, player
//     credits) and a fresh client must have joined and got the note.
//=============================================================================
class HXFixTestSaveWorld extends HXFixTestBase;

var HXFixTestProbeDriver D;
var int Seq;
var bool bCleared;

function string GoalAText()
{
	return "Goal A text" $ Chr(10) $ "second line";
}

function bool SavedHas( string Needle )
{
	local int i;

	for ( i=0; i<class'HXFixSaveWorld'.Default.NumFlags; i++ )
		if ( InStr( class'HXFixSaveWorld'.Default.Flag[i], Needle )>=0 )
			return True;
	return False;
}

function Setup()
{
	local HXFlagBase FB;
	local HXGoal Goal;
	local vector V;
	local rotator R;

	FB = Game.Steve.FlagBase;
	V.X = 1.5; V.Y = -2.0; V.Z = 300.25;
	R.Pitch = 100; R.Yaw = 20000; R.Roll = -300;
	FB.SetBool( 'HXFixTSBool', True, True, 0 );
	FB.SetBool( 'HXFixTSBoolExp', True, True, 99 );
	FB.SetByte( 'HXFixTSByte', 77, True, 0 );
	FB.SetInt( 'HXFixTSInt', 123456, True, 0 );
	FB.SetFloat( 'HXFixTSFloat', 2.5, True, 0 );
	FB.SetName( 'HXFixTSName', 'HXFixTSValue', True, 0 );
	FB.SetVector( 'HXFixTSVec', V, True, 0 );
	FB.SetRotator( 'HXFixTSRot', R, True, 0 );

	Game.AddGoal( 'HXFixTSGoalA', True, GoalAText() );
	Game.AddGoal( 'HXFixTSGoalB', False, "Goal B text" );
	Game.GoalCompleted( 'HXFixTSGoalB' );
	Goal = Game.FindGoal( 'HXFixTSGoalB' );
	Check( Goal!=None && Goal.bCompleted, "goal B completed before save" );

	Game.AddNote( "save world note"$Chr(10)$"code 7788", True, False, 'HXFixTSNote' );
	Game.GiveKey( 'HXFixTSKey', "Test key", True );
	Game.Steve.SkillPointsTotal += 7;

	Host().Credits   = 4242;
	Remote().Credits = 3131;
}

function VerifyWorld( string Tag )
{
	local HXFlagBase FB;
	local HXGoal Goal;
	local vector V;
	local rotator R;

	FB = Game.Steve.FlagBase;
	V = FB.GetVector( 'HXFixTSVec' );
	R = FB.GetRotator( 'HXFixTSRot' );
	Check( FB.GetBool('HXFixTSBool'), Tag @ "bool flag" );
	Check( FB.GetBool('HXFixTSBoolExp') && FB.GetExpiration('HXFixTSBoolExp',FLAG_Bool)==99, Tag @ "bool flag expiration" @ FB.GetExpiration('HXFixTSBoolExp',FLAG_Bool) );
	Check( FB.GetByte('HXFixTSByte')==77, Tag @ "byte flag" @ FB.GetByte('HXFixTSByte') );
	Check( FB.GetInt('HXFixTSInt')==123456, Tag @ "int flag" @ FB.GetInt('HXFixTSInt') );
	Check( Abs(FB.GetFloat('HXFixTSFloat')-2.5)<0.001, Tag @ "float flag" @ FB.GetFloat('HXFixTSFloat') );
	Check( FB.GetName('HXFixTSName')=='HXFixTSValue', Tag @ "name flag" @ FB.GetName('HXFixTSName') );
	Check( Abs(V.X-1.5)<0.01 && Abs(V.Y+2.0)<0.01 && Abs(V.Z-300.25)<0.01, Tag @ "vector flag" @ V );
	Check( R.Pitch==100 && R.Yaw==20000 && R.Roll==-300, Tag @ "rotator flag" @ R.Pitch @ R.Yaw @ R.Roll );
	Goal = Game.FindGoal( 'HXFixTSGoalA' );
	Check( Goal!=None && Goal.bPrimaryGoal && !Goal.bCompleted && Goal.Text==GoalAText(), Tag @ "goal A" );
	Goal = Game.FindGoal( 'HXFixTSGoalB' );
	Check( Goal!=None && !Goal.bPrimaryGoal && Goal.bCompleted && Goal.Text=="Goal B text", Tag @ "goal B (completed)" );
	Check( Game.Steve.FirstGoal!=None && Game.Steve.FirstGoal.GoalName=='HXFixTSGoalB', Tag @ "goal order newest first" );
	Check( Game.HasKey('HXFixTSKey'), Tag @ "nanokey" );
}

function float RunStep( int StepNum )
{
	switch ( StepNum )
	{
		case 0:
			Check( Host()!=None && Remote()!=None, "host and remote client present" );
			if ( Game.bLoadedGame )
			{
				Check( True, "game was loaded" );
				VerifyWorld( "loaded:" );
				Check( Game.Steve.SkillPointsTotal>=7, "skill points total" @ Game.Steve.SkillPointsTotal );
				Check( Game.FirstNote!=None && InStr(Game.FirstNote.Text,"code 7788")>=0 && Game.FirstNote.bUserNote, "note restored" );
				Check( Game.FirstNote!=None && Game.FirstNote.TextTag=='HXFixTSNote', "note tag restored" );
				Check( Host().Credits==4242, "host credits restored" @ Host().Credits );
				Check( Remote().Credits==3131, "client credits restored" @ Remote().Credits );
				Check( InStr(Game.RestoredNames,"|"$Host().PlayerReplicationInfo.PlayerName$"|")>=0, "host restore ran" );
				D = HXFixTestProbeDriver( DriverFor(Remote()) );
				Seq = D.ProbeSeq;
				D.ClientProbe();
				return 3.0;
			}
			Check( Game.bAutoSaveDone, "autosave scheduled on arrival" );
			// Only meaningful if the autosave has not run yet.
			bCleared = Game.SaveCount<1;
			if ( bCleared )
				class'HXFixSaveWorld'.static.Clear();
			return 1.0;

		case 1:
			if ( Game.bLoadedGame )
			{
				Check( D.ProbeSeq>Seq && D.ProbeNotes==1 && InStr(D.ProbeNoteText,"code 7788")>=0, "fresh client got the note" @ D.ProbeNotes );
				Check( Game.Steve.FlagBase.GetBool('HXFixTSBool'), "still loaded after a few seconds" );
				return -1;
			}
			// Wait for the autosave (10 s after the first login).
			if ( Game.SaveCount<1 && Elapsed<60 )
			{
				Step--;
				return 2.0;
			}
			Check( Game.SaveCount>=1, "autosave ran" );
			if ( bCleared )
				Check( class'HXFixSaveWorld'.static.HasSave() && class'HXFixSaveWorld'.static.MapName()~="01_NYC_UNATCOIsland", "autosave stored the map" );
			Setup();
			return 1.0;

		case 2:
			Host().ConsoleCommand( "CoopSave" );
			return 2.0;

		case 3:
			Check( Game.SaveCount>=2, "CoopSave console command saved (count" @ Game.SaveCount $ ")" );
			Check( SavedHas("b|HXFixTSBoolExp|99|1"), "ini has bool flag with expiration" );
			Check( SavedHas("y|HXFixTSByte|0|77"), "ini has byte flag" );
			Check( SavedHas("i|HXFixTSInt|0|123456"), "ini has int flag" );
			Check( SavedHas("f|HXFixTSFloat|0|2.5"), "ini has float flag" );
			Check( SavedHas("n|HXFixTSName|0|HXFixTSValue"), "ini has name flag" );
			Check( SavedHas("v|HXFixTSVec|0|1.5"), "ini has vector flag" );
			Check( SavedHas("r|HXFixTSRot|0|100|20000|-300"), "ini has rotator flag" );
			Check( class'HXFixSaveWorld'.Default.NumGoals>=2 && InStr(class'HXFixSaveWorld'.Default.Goal[0],"HXFixTSGoalB|0|1|Goal B text")==0, "ini has goals" );
			Check( class'HXFixSaveWorld'.Default.NumNotes==1 && InStr(class'HXFixSaveWorld'.Default.NoteLine[0],"HXFixTSNote|1|")==0, "ini has the note" );
			Check( class'HXFixSaveWorld'.Default.NumKeys>=1 && InStr(class'HXFixSaveWorld'.Default.Key[0],"HXFixTSKey|Test key")==0, "ini has the key" );
			Check( class'HXFixSavePlayers'.static.Count()==2, "player records saved" @ class'HXFixSavePlayers'.static.Count() );
			VerifyWorld( "before exit:" );
			return -1;
	}
	return -1;
}

defaultproperties
{
	DriverClass=Class'HXFixTestProbeDriver'
}
