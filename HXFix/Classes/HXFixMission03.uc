//=============================================================================
// HXFixMission03.
//
// HX also required the boss (Elrey) to be dead before setting
// JugHeadGangDefeated at the Brooklyn Bridge Station. Stock only looks at
// the ThugMale2 gang members, so do the same.
//=============================================================================
class HXFixMission03 extends HXMission03;

function Timer()
{
	local Actor Thug;
	local bool bAlive;

	Super.Timer();

	if ( LocalURL=="03_NYC_BROOKLYNBRIDGESTATION" && ThugMale2Class!=None && !GetBoolFlag('JugHeadGangDefeated') )
	{
		foreach AllActors( ThugMale2Class, Thug, 'ThugMale2' )
		{
			bAlive = True;
			break;
		}
		if ( !bAlive )
			SetBoolFlag( 'JugHeadGangDefeated', True, True, 4 );
	}
}
