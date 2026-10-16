//=============================================================================
// HXFixCellProxy.
//
// Client side stand in for the player's bioelectric cell: using it asks the
// server to use the real one. See HXFixPlayerLogic.CellProxy().
//=============================================================================
class HXFixCellProxy extends HXBioelectricCell;

function Activate()
{
	if ( Owner!=None )
		Owner.ConsoleCommand( "HXFixUseCell" );
}

function ActivateOn( Actor FrobTarget )
{
	Activate();
}

defaultproperties
{
	bHidden=True
	bCollideActors=False
	bBlockActors=False
	bBlockPlayers=False
	RemoteRole=ROLE_None
	Physics=PHYS_None
	LifeSpan=0.000000
}
