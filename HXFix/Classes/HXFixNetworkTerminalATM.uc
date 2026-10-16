//=============================================================================
// HXFixNetworkTerminalATM.
//
// HXNetworkTerminalATM which also reports a detected hack to the server.
//=============================================================================
class HXFixNetworkTerminalATM extends HXNetworkTerminalATM;

function HackDetected( optional bool bDamageOnly )
{
	class'HXFixDeviceUtil'.static.ClientHackDetected( CompOwner, bDamageOnly );
	Super.HackDetected( bDamageOnly );
}
