//=============================================================================
// HXFixTestRaid.
//
// 04_NYC_Hotel: ApartmentEntered + NSFSignalSent set, nobody near Paul. The
// raid must start anyway (HXFixMission04 fallback marks Paul's conversation
// as played, HXMission04 then does the raid teleport).
//=============================================================================
class HXFixTestRaid extends HXFixTestConBase;

var int Ticks;

function float RunStep( int StepNum )
{
	switch ( StepNum )
	{
		case 0:
			Check( Remote()!=None && Host()!=None, "host and remote present" );
			Check( HXFixMission04(Game.MissionScript)!=None, "mission script is HXFixMission04 (" $ Game.MissionScript $ ")" );
			Check( !Game.Steve.FlagBase.GetBool('M04RaidTeleportDone'), "control: raid not started yet" );
			Check( !Game.Steve.FlagBase.GetBool('TalkedToPaulAfterMessage_Played'), "control: Paul conversation not played yet" );
			Game.Steve.FlagBase.SetBool( 'ApartmentEntered', True );
			Game.Steve.FlagBase.SetBool( 'NSFSignalSent', True );
			return 5.0;

		default:
			if ( !Game.Steve.FlagBase.GetBool('M04RaidTeleportDone') && Ticks++<80 )
			{
				if ( Ticks%10==0 )
					Note( "waiting, ConPlay" @ ConState() @ "played" @ Game.Steve.FlagBase.GetBool('TalkedToPaulAfterMessage_Played') );
				return Again( 1.0 );
			}
	}
	Check( Game.Steve.FlagBase.GetBool('TalkedToPaulAfterMessage_Played'), "Paul conversation marked as played" );
	Check( Game.Steve.FlagBase.GetBool('M04RaidTeleportDone'), "raid started (M04RaidTeleportDone)" );
	return -1;
}

defaultproperties
{
	TimeoutSeconds=200.000000
}
