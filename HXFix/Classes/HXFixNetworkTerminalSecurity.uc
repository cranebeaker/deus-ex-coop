//=============================================================================
// HXFixNetworkTerminalSecurity.
//
// HXNetworkTerminalSecurity which also reports a detected hack to the server.
//=============================================================================
class HXFixNetworkTerminalSecurity extends HXNetworkTerminalSecurity;

function HackDetected( optional bool bDamageOnly )
{
	class'HXFixDeviceUtil'.static.ClientHackDetected( CompOwner, bDamageOnly );
	Super.HackDetected( bDamageOnly );
}
