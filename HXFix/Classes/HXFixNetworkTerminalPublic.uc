//=============================================================================
// HXFixNetworkTerminalPublic.
//
// HXNetworkTerminalPublic which also reports a detected hack to the server.
//=============================================================================
class HXFixNetworkTerminalPublic extends HXNetworkTerminalPublic;

function HackDetected( optional bool bDamageOnly )
{
	class'HXFixDeviceUtil'.static.ClientHackDetected( CompOwner, bDamageOnly );
	Super.HackDetected( bDamageOnly );
}
