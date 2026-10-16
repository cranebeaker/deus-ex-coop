//=============================================================================
// HXFixWeaponsMutator.
//
// Weapon fixes:
// - spawns HXFixWeaponSync helpers so remote clients know scope/clip/recoil/
//   accuracy/range/reload mods and can select ammo in the inventory screen.
// - adds nanokey IDs to the replicated key list so client datalink NK_ checks
//   (which look up key IDs, not descriptions) work.
//=============================================================================
class HXFixWeaponsMutator extends HXFixMutatorBase;

var float ScanTimer;

const SCAN_INTERVAL = 0.5;

function Tick( float DeltaTime )
{
	Super.Tick( DeltaTime );

	ScanTimer += DeltaTime;
	if ( ScanTimer<SCAN_INTERVAL )
		return;
	ScanTimer = 0.0;

	SyncWeapons();
	SyncKeyIDs();
}

function NotifyPostLogin( PlayerPawn NewPlayer )
{
	SyncWeapons();
}

function NotifyRestartPlayer( Pawn Player )
{
	SyncWeapons();
}

function SyncWeapons()
{
	local HXPlayerPawn P;
	local HXFixWeaponSync Sync;
	local Inventory Inv;
	local HXWeapon W;
	local bool bFound;
	local int Count;

	foreach AllActors( class'HXPlayerPawn', P )
	{
		if ( P.bDeleteMe )
			continue;

		for ( Inv=P.Inventory; Inv!=None && Count<256; Inv=Inv.Inventory )
		{
			Count++;
			W = HXWeapon(Inv);
			if ( W==None )
				continue;

			bFound = False;
			foreach AllActors( class'HXFixWeaponSync', Sync )
				if ( Sync.Weapon==W && !Sync.bDeleteMe )
				{
					bFound = True;
					break;
				}

			if ( !bFound )
			{
				Sync = Spawn( class'HXFixWeaponSync', P );
				if ( Sync!=None )
					Sync.Weapon = W;
			}
		}
	}
}

// Datalinks test "NK_<KeyID>" on the client via NanoKeyReplicationInfo, which
// only stores key descriptions. Add the IDs too (and drop IDs of removed keys).
// Stock HasNanoKey does not work on clients, so swap in HXFixNanoKeyInfo.
function SyncKeyIDs()
{
	local HXGameInfo G;
	local HXNanoKeyInfo Key;
	local HXFixNanoKeyInfo Info;
	local int Count, i;
	local string Slot;

	G = HXGameInfo(Level.Game);
	if ( G==None || G.NanoKeyReplicationInfo==None || G.Steve==None )
		return;

	Info = HXFixNanoKeyInfo(G.NanoKeyReplicationInfo);
	if ( Info==None )
		Info = SwapKeyInfo( G );
	if ( Info==None )
		return;

	// Blank IDs of keys the team no longer holds. Description slots are
	// handled by stock HX; older builds put IDs there too, so drop those.
	for ( i=0; i<Info.KeyIDCount; i++ )
	{
		if ( Info.KeyIDs[i]!="" && !TeamHasKeyID( G, Info.KeyIDs[i] ) )
			Info.KeyIDs[i] = "";
	}
	for ( i=0; i<Info.NanoKeyCount; i++ )
	{
		Slot = Info.SlotAt( i );
		if ( Slot!="" && !TeamHasDescription( G, Slot ) )
			Info.SetPropertyText( "NanoKey" $ i, "" );
	}

	Count = 0;
	for ( Key=G.Steve.KeyList; Key!=None && Count<256; Key=Key.NextKey )
	{
		Count++;
		Info.AddKeyID( string(Key.KeyID) );
	}
}

function bool TeamHasKeyID( HXGameInfo G, string KeyID )
{
	local HXNanoKeyInfo Key;
	local int Count;

	for ( Key=G.Steve.KeyList; Key!=None && Count<256; Key=Key.NextKey )
	{
		Count++;
		if ( KeyID~=string(Key.KeyID) )
			return True;
	}
	return False;
}

function bool TeamHasDescription( HXGameInfo G, string Desc )
{
	local HXNanoKeyInfo Key;
	local int Count;

	for ( Key=G.Steve.KeyList; Key!=None && Count<256; Key=Key.NextKey )
	{
		Count++;
		if ( Desc~=Key.Description )
			return True;
	}
	return False;
}

function HXFixNanoKeyInfo SwapKeyInfo( HXGameInfo G )
{
	local HXFixNanoKeyInfo Info;
	local HXPlayerPawn P;
	local HXNanoKeyReplicationInfo Old;
	local int i;

	Old = G.NanoKeyReplicationInfo;
	Info = Spawn( class'HXFixNanoKeyInfo' );
	if ( Info==None )
		return None;
	for ( i=0; i<Old.NanoKeyCount; i++ )
		Info.AddNanoKey( Old.GetPropertyText( "NanoKey" $ i ) );
	G.NanoKeyReplicationInfo = Info;
	foreach AllActors( class'HXPlayerPawn', P )
		if ( P.NanoKeyReplicationInfo==Old )
			P.NanoKeyReplicationInfo = Info;
	Old.Destroy();
	return Info;
}
