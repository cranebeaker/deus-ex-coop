//=============================================================================
// HXFixNameNotifier.
//
// Tells the owning client to store a server assigned name in its URL,
// so the next map travel reconnects with the same unique name.
//=============================================================================
class HXFixNameNotifier extends Info;

var string NewName;

replication
{
	reliable if ( Role==ROLE_Authority && bNetOwner )
		NewName;
}

simulated function Tick( float DeltaTime )
{
	if ( Role==ROLE_Authority || NewName=="" || PlayerPawn(Owner)==None )
		return;

	// Session only: don't overwrite the player's saved name.
	PlayerPawn(Owner).UpdateURL( "Name", NewName, False );
	Disable( 'Tick' );
}

defaultproperties
{
	RemoteRole=ROLE_SimulatedProxy
	bAlwaysRelevant=True
	LifeSpan=30.000000
}
