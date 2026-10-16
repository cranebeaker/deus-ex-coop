//=============================================================================
// HXFixMission10.
//
// HX dropped the '!' on MS_CommandosUnhidden, so the Chateau commando
// ambush after Everett's infolink never happened (and once the flag was set
// by us, the inverted check made HX unhide them again on every tick).
//=============================================================================
class HXFixMission10 extends HXMission10;

function Timer()
{
	local bool bUnhidden, bChateau;

	bChateau = LocalURL=="10_PARIS_CHATEAU";
	if ( bChateau )
	{
		// Keep HX's inverted check from firing.
		bUnhidden = GetBoolFlag( 'MS_CommandosUnhidden' );
		if ( bUnhidden )
			SetBoolFlag( 'MS_CommandosUnhidden', False, True, 11 );
	}

	Super.Timer();

	if ( !bChateau )
		return;

	if ( !bUnhidden && GetBoolFlag('everettsignal') )
	{
		bUnhidden = True;
		PawnsEnterWorld( MJ12CommandoClass );
	}
	if ( bUnhidden )
		SetBoolFlag( 'MS_CommandosUnhidden', True, True, 11 );
}
