//=============================================================================
// HXFixMission02.
//
// HX counted *unconscious* street terrorists towards TenderloinSlaughter,
// so non lethal players got the slaughter reactions and lethal ones didn't.
//=============================================================================
class HXFixMission02 extends HXMission02;

function Timer()
{
	local bool bCheckSlaughter;
	local Actor Actor;
	local HXCarcass Carcass;
	local int Count;

	// Mirror the condition under which HXMission02 opens the street this tick.
	if ( LocalURL=="02_NYC_STREET" && !GetBoolFlag('StreetOpened') )
	{
		bCheckSlaughter = True;
		if ( TerroristClass!=None )
			foreach AllActors( TerroristClass, Actor, 'StreetTerrorist' )
				bCheckSlaughter = False;
	}

	Super.Timer();

	if ( !bCheckSlaughter || !GetBoolFlag('StreetOpened') )
		return;

	// there are 5 terrorists total
	// if player killed 3 or more, call it a slaughter
	if ( TerroristCarcassClass!=None )
	{
		foreach AllActors( TerroristCarcassClass, Actor, 'StreetTerrorist' )
		{
			Carcass = HXCarcass(Actor);
			if ( Carcass!=None && Carcass.KillerBindName=="JCDenton" && InStr(Carcass.ItemName,"Unconscious")==-1 )
				Count++;
		}
	}

	SetBoolFlag( 'TenderloinSlaughter', Count>=3, True, 6 );
}
