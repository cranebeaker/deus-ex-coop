//=============================================================================
// HXFixNetworkTerminalPersonal.
//
// HXNetworkTerminalPersonal which also reports a detected hack to the server.
//=============================================================================
class HXFixNetworkTerminalPersonal extends HXNetworkTerminalPersonal;

function HackDetected( optional bool bDamageOnly )
{
	class'HXFixDeviceUtil'.static.ClientHackDetected( CompOwner, bDamageOnly );
	Super.HackDetected( bDamageOnly );
}
