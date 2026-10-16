//=============================================================================
// HXFixInterpolateTrigger.
//
// HXInterpolateTrigger which reports fired paths to HXFixDevicesMutator, so
// players joining later can be sent them. Triggers with bTriggerOnceOnly
// destroy themselves after firing, hence the mutator keeps the record.
//=============================================================================
class HXFixInterpolateTrigger extends HXInterpolateTrigger;

function bool SendActorOnPath()
{
	local bool bResult;
	local HXFixDevicesMutator Devices;

	bResult = Super.SendActorOnPath();
	if ( bResult )
	{
		foreach AllActors( class'HXFixDevicesMutator', Devices )
		{
			Devices.RecordPath( Event );
			break;
		}
	}
	return bResult;
}
