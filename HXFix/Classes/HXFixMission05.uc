//=============================================================================
// HXFixMission05.
//
// HXMissionScript.IsGoalCompleted ignored its argument and always checked
// 'PowerElevator', so respawning players never got their equipment back.
//=============================================================================
class HXFixMission05 extends HXMission05;

function bool IsGoalCompleted( Name GoalName )
{
	return Game.IsGoalCompleted( GoalName );
}

event Trigger( Actor Other, Pawn EventInstigator )
{
	if ( Other==None )
		return;
	Super.Trigger( Other, EventInstigator );
}
