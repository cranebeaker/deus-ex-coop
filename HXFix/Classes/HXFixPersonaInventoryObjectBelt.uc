//=============================================================================
// HXFixPersonaInventoryObjectBelt.
//
// Stock DestroyWindow() always calls hudBelt.AssignWinInv(None). When the game
// exits with the inventory screen open, or after a client dropped back to
// Entry (host quit) with it open, hudBelt belongs to a HUD that is already
// gone and the call crashed the game. Only call it while hudBelt is still the
// belt of the current HUD.
//=============================================================================
class HXFixPersonaInventoryObjectBelt extends HXPersonaInventoryObjectBelt;

event DestroyWindow()
{
	local HXRootWindow Root;

	Root = HXRootWindow( GetRootWindow() );
	if ( GetPlayerPawn()==None || Root==None || HXDeusExHUD(Root.hud)==None || HXDeusExHUD(Root.hud).hxbelt!=hudBelt )
		hudBelt = None;
	if ( hudBelt!=None )
		hudBelt.AssignWinInv( None );
	hudBelt = None;
	Super(HXWindow).DestroyWindow();
}
