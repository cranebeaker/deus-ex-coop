//=============================================================================
// HXFixTestSaveWorldFresh.
//
// Normal start (no ?HXFixLoad) after HXFixTestSaveWorld: a save exists in the
// ini, but nothing of it may be restored.
//=============================================================================
class HXFixTestSaveWorldFresh extends HXFixTestBase;

function float RunStep( int StepNum )
{
	local HXFlagBase FB;

	FB = Game.Steve.FlagBase;
	Check( class'HXFixSaveWorld'.static.HasSave(), "a saved game exists in the ini" );
	Check( !Game.bLoadedGame, "not loaded" );
	Check( !FB.GetBool('HXFixTSBool') && FB.GetInt('HXFixTSInt')==0, "saved flags not restored" );
	Check( Game.FindGoal('HXFixTSGoalA')==None && Game.Steve.FirstGoal==None, "no saved goals" );
	Check( Game.FirstNote==None, "no saved notes" );
	Check( !Game.HasKey('HXFixTSKey'), "no saved key" );
	Check( Game.RestoredNames=="", "no player restore ran" );
	return -1;
}

defaultproperties
{
	MinPlayers=1
}
