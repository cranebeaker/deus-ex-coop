//=============================================================================
// HXFixPersonaScreenInventory.
//
// - Change Ammo on a client: stock calls CycleAmmo on the server and then
//   shows the client's AmmoName, which is never replicated, so the screen
//   lagged behind and HXFixWeaponSync could send that stale pick back. Pick
//   the next ammo here from the replicated AmmoType and send exactly that.
// - Uses HXFixPersonaInventoryObjectBelt, whose DestroyWindow no longer
//   crashes the game when it exits with this screen open.
// - Closes itself once its player is gone (client dropped back to Entry when
//   the host quit) if its Tick runs there.
//=============================================================================
class HXFixPersonaScreenInventory extends HXPersonaScreenInventory;

function Tick( float DeltaTime )
{
	if ( Player==None || Player.bDeleteMe || Player!=GetPlayerPawn() )
	{
		bTickEnabled = False;
		if ( HXRootWindow(GetRootWindow())!=None )
			HXRootWindow(GetRootWindow()).ClearWindowStackNoUnPauseGame();
		return;
	}
	Super.Tick( DeltaTime );
}

function CreateObjectBelt()
{
	invBelt = HXPersonaInventoryObjectBelt( NewChild(Class'HXFixPersonaInventoryObjectBelt') );
	invBelt.SetWindowAlignments( HALIGN_Right, VALIGN_Bottom, 0, 0 );
	invBelt.SetInventoryWindow( Self );
}

function WeaponChangeAmmo()
{
	local HXWeapon W;
	local HXFixWeaponSync Sync, S;
	local class<Ammo> Current, Next;
	local int i, Start;

	W = HXWeapon( selectedItem.GetClientObject() );
	if ( W!=None && Player.Role<ROLE_Authority )
		foreach Player.AllActors( class'HXFixWeaponSync', S )
			if ( S.Weapon==W )
			{
				Sync = S;
				break;
			}
	if ( Sync==None )
	{
		Super.WeaponChangeAmmo();
		return;
	}

	// Our last pick if the server has not confirmed it yet, else the server's.
	Current = W.AmmoName;
	if ( Sync.PendingAmmo!=None )
		Current = Sync.PendingAmmo;
	else if ( W.AmmoType!=None )
		Current = W.AmmoType.Class;

	Start = 0;
	for ( i=0; i<ArrayCount(W.AmmoNames); i++ )
		if ( W.AmmoNames[i]==Current )
			Start = i;
	for ( i=1; i<ArrayCount(W.AmmoNames); i++ )
	{
		Next = W.AmmoNames[(Start+i)%ArrayCount(W.AmmoNames)];
		if ( Next!=None && Next!=Current && Player.FindInventoryType(Next)!=None )
			break;
		Next = None;
	}
	if ( Next==None )
		return;

	Sync.LastSelectedAmmo   = Next;
	Sync.bTrackingSelection = True;
	Sync.PendingAmmo        = Next;
	Sync.PendingTime        = Player.Level.TimeSeconds;
	Sync.ServerLoadAmmo( W, Next );
	W.AmmoName = Next;

	W.UpdateAmmoInfo( winInfo, class<HXAmmo>(Next) );
	winInfo.SetLoaded( Next );
}
