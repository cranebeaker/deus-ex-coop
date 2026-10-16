//=============================================================================
// HXFixWeaponSync.
//
// One per player-held HXWeapon. Owned by the player (owner relevant only).
// Replicates the weapon stats stock DeusExWeapon does not replicate and
// applies them to the client's copy of the weapon. Also provides a server
// RPC for the inventory screen's ammo selection, which otherwise only calls a
// non-simulated function on the client's copy of the weapon.
//=============================================================================
class HXFixWeaponSync extends Info;

var HXWeapon Weapon;

var bool  bSyncHasScope;
var int   SyncReloadCount;
var float SyncRecoilStrength;
var float SyncBaseAccuracy;
var int   SyncAccurateRange;
var float SyncReloadTime;

// Client only: ammo selection tracking for the inventory screen.
var class<Ammo> LastSelectedAmmo;
var bool bTrackingSelection;

// Client only: last Change Ammo pick, until the server's AmmoType catches up.
var class<Ammo> PendingAmmo;
var float PendingTime;

replication
{
	reliable if ( Role==ROLE_Authority && bNetOwner )
		Weapon, bSyncHasScope, SyncReloadCount, SyncRecoilStrength, SyncBaseAccuracy, SyncAccurateRange, SyncReloadTime;

	reliable if ( Role<ROLE_Authority )
		ServerLoadAmmo;
}

// Server: true while helper is still valid.
function bool IsValid()
{
	return Weapon!=None && !Weapon.bDeleteMe && Owner!=None && !Owner.bDeleteMe && Weapon.Owner==Owner;
}

function ServerLoadAmmo( HXWeapon W, class<Ammo> NewAmmo )
{
	if ( W==None || NewAmmo==None || W!=Weapon || W.Owner!=Owner )
		return;
	W.LoadAmmoClass( NewAmmo );
}

simulated function Tick( float DeltaTime )
{
	if ( Role==ROLE_Authority )
	{
		if ( !IsValid() )
		{
			Destroy();
			return;
		}
		// Assigning equal values does not cause replication traffic.
		bSyncHasScope      = Weapon.bHasScope;
		SyncReloadCount    = Weapon.ReloadCount;
		SyncRecoilStrength = Weapon.recoilStrength;
		SyncBaseAccuracy   = Weapon.BaseAccuracy;
		SyncAccurateRange  = Weapon.AccurateRange;
		SyncReloadTime     = Weapon.ReloadTime;
		return;
	}

	if ( Weapon==None )
		return;

	Weapon.bHasScope      = bSyncHasScope;
	Weapon.ReloadCount    = SyncReloadCount;
	Weapon.recoilStrength = SyncRecoilStrength;
	Weapon.BaseAccuracy   = SyncBaseAccuracy;
	Weapon.AccurateRange  = SyncAccurateRange;
	Weapon.ReloadTime     = SyncReloadTime;

	// AmmoName is not replicated, AmmoType is: keep the loaded ammo shown in
	// the inventory screen right after ammo changes made on the server.
	if ( PendingAmmo!=None && (Level.TimeSeconds-PendingTime>1.5 || (Weapon.AmmoType!=None && Weapon.AmmoType.Class==PendingAmmo)) )
		PendingAmmo = None;
	if ( PendingAmmo==None && Weapon.AmmoType!=None && Weapon.AmmoName!=Weapon.AmmoType.Class )
		Weapon.AmmoName = Weapon.AmmoType.Class;

	if ( PlayerPawn(Owner)!=None && Viewport(PlayerPawn(Owner).Player)!=None )
		TrackAmmoSelection();
}

// Client: forward the inventory screen's ammo selection to the server.
simulated function TrackAmmoSelection()
{
	local HXPlayerPawn P;
	local HXPersonaScreenInventory Screen;
	local class<Ammo> Selected;

	P = HXPlayerPawn(Owner);
	if ( P!=None && HXRootWindow(P.rootWindow)!=None )
		Screen = HXPersonaScreenInventory( HXRootWindow(P.rootWindow).GetTopWindow() );

	if ( Screen==None || Screen.selectedItem==None || Screen.winInfo==None
		|| HXWeapon(Screen.selectedItem.GetClientObject())!=Weapon )
	{
		bTrackingSelection = False;
		return;
	}

	Selected = Screen.winInfo.GetSelectedAmmo();
	if ( Selected==None )
		return;

	if ( !bTrackingSelection )
	{
		// First sight of this weapon being selected: remember, do not send.
		bTrackingSelection = True;
		LastSelectedAmmo   = Selected;
		return;
	}

	if ( Selected!=LastSelectedAmmo )
	{
		LastSelectedAmmo = Selected;
		PendingAmmo      = Selected;
		PendingTime      = Level.TimeSeconds;
		ServerLoadAmmo( Weapon, Selected );
	}
}

defaultproperties
{
	RemoteRole=ROLE_SimulatedProxy
	NetUpdateFrequency=5.000000
}
