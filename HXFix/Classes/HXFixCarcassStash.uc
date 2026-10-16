//=============================================================================
// HXFixCarcassStash.
//
// Temporary storage of the charge of partly used charged pickups while a
// player carcass is being spawned. See HXFixPlayerLogic.PrepareCarcass().
//=============================================================================
class HXFixCarcassStash extends Info;

var Inventory Items[32];
var int       Charges[32];
var int       Num;

defaultproperties
{
	bHidden=True
	RemoteRole=ROLE_None
}
