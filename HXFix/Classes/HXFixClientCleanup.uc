//=============================================================================
// HXFixClientCleanup.
//
// One per player, owned by the player's pawn, runs on that client. On map
// change the client exports its pawn and frees it, while PlayerReplicationInfos
// and UI ColorTheme actors of the old level still point at it through Owner.
// The garbage collection that follows then crashes the client in TestReach
// (seen in roughly every third travel with 3 players). Nothing uses those
// Owner pointers, so keep them cleared.
// Also makes the inventory screen HXFixPersonaScreenInventory, on clients and
// for the listen host (the host's instance only does that part).
//=============================================================================
class HXFixClientCleanup extends Info;

function PostBeginPlay()
{
	Super.PostBeginPlay();
	if ( Level.NetMode==NM_ListenServer )
		SetTimer( 0.5, True );
}

simulated function PostNetBeginPlay()
{
	if ( Level.NetMode==NM_Client )
		SetTimer( 0.5, True );
}

simulated function Timer()
{
	local PlayerReplicationInfo PRI;
	local ColorTheme Theme;

	if ( Level.NetMode!=NM_Client )
	{
		// Server side copy: only the listen host's own one has work to do.
		if ( PlayerPawn(Owner)==None || NetConnection(PlayerPawn(Owner).Player)!=None )
			SetTimer( 0, False );
		else
			UseFixInventoryScreen();
		return;
	}

	foreach AllActors( class'PlayerReplicationInfo', PRI )
		if ( PRI.Owner!=None )
			PRI.SetOwner( None );
	foreach AllActors( class'ColorTheme', Theme )
		if ( Theme.Owner!=None )
			Theme.SetOwner( None );
	UseFixInventoryScreen();
}

// See HXFixPersonaScreenInventory.
simulated function UseFixInventoryScreen()
{
	local PlayerPawn P;
	local HXRootWindow Root;

	P = PlayerPawn(Owner);
	if ( P==None || Viewport(P.Player)==None )
		return;
	Root = HXRootWindow( DeusExPlayer(P).rootWindow );
	if ( Root==None || Root.ShowInventoryWindowClass==class'HXFixPersonaScreenInventory' )
		return;
	Root.ShowInventoryWindowClass = class'HXFixPersonaScreenInventory';
	Root.DataVaultFunctions[0].WinClass = class'HXFixPersonaScreenInventory';
}

defaultproperties
{
	RemoteRole=ROLE_SimulatedProxy
	bAlwaysRelevant=True
	bHidden=True
}
