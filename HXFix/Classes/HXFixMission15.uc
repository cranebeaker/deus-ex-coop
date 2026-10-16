//=============================================================================
// HXFixMission15.
//
// See HXFixMission05: IsGoalCompleted ignored its argument.
//=============================================================================
class HXFixMission15 extends HXMission15;

function bool IsGoalCompleted( Name GoalName )
{
	return Game.IsGoalCompleted( GoalName );
}
