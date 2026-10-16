//=============================================================================
// HXFixTestProbe.
//
// Dumps the device actors of the loaded map to the log (map discovery).
//=============================================================================
class HXFixTestProbe extends HXFixTestBase;

function float RunStep( int StepNum )
{
	local Actor A;

	foreach AllActors( class'Actor', A )
	{
		if ( HXComputers(A)!=None || HXSecurityCamera(A)!=None || HXKeypad(A)!=None || HXMapExit(A)!=None
			|| HXMedicalBot(A)!=None || HXRepairBot(A)!=None || HXInterpolateTrigger(A)!=None
			|| HXFixComputerSecurity(A)!=None || HXFixATM(A)!=None )
			Log( "HXFixTest: PROBE" @ A.Class.Name @ A.Name @ "tag=" $ A.Tag @ "ev=" $ A.Event @ "loc=" $ A.Location @ "rot=" $ A.Rotation, 'HXFixTest' );
		if ( HXComputerSecurity(A)!=None )
			Log( "HXFixTest: PROBE   views" @ HXComputerSecurity(A).Views[0].cameraTag @ HXComputerSecurity(A).Views[1].cameraTag @ HXComputerSecurity(A).Views[2].cameraTag, 'HXFixTest' );
	}
	Check( True, "probe done" );
	return -1;
}

defaultproperties
{
	MinPlayers=1
	TimeoutSeconds=60.000000
}
