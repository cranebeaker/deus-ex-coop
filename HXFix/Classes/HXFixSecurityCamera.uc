//=============================================================================
// HXFixSecurityCamera.
//
// HXSecurityCamera which considers every player instead of the first one in
// range. The original returned the first player within range and line of
// sight, then only checked that one against the field of view, so a second
// player standing in front of the camera was ignored whenever the first one
// was out of view.
//=============================================================================
class HXFixSecurityCamera extends HXSecurityCamera;


function bool FixInFOV( Actor Target )
{
	local Rotator Rot;
	local float Yaw, Pitch;

	Rot = Rotator( Target.Location - Location );
	Rot.Roll = 0;
	Yaw   = (Abs(Rotation.Yaw   - Rot.Yaw))   % 65536;
	Pitch = (Abs(Rotation.Pitch - Rot.Pitch)) % 65536;

	if ( Yaw>32767 )
		Yaw -= 65536;
	if ( Pitch>32767 )
		Pitch -= 65536;

	return Abs(Yaw)<CameraFOV && Abs(Pitch)<CameraFOV;
}

// Returns the closest player this camera can currently see.
function Actor AcquireMultiplayerTarget()
{
	local Pawn CurPawn;
	local HXPlayerPawn Player, Best;
	local float Dist, BestDist;
	local Actor Hit;
	local Vector HitLocation, HitNormal;

	curTarget = None;

	for ( CurPawn=Level.PawnList; CurPawn!=None; CurPawn=CurPawn.NextPawn )
	{
		Player = HXPlayerPawn(CurPawn);
		if ( Player==None || Player.bDeleteMe || Player.Health<=0 || !Player.bDetectable || Player.bIgnore )
			continue;

		Dist = VSize( Player.Location-Location );
		if ( Dist>=CameraRange )
			continue;

		// Radar transparency hides the player.
		if ( Player.AugmentationSystem!=None && Player.AugmentationSystem.GetAugLevelValue(class'HXAugRadarTrans')!=-1.0 )
			continue;

		Hit = Trace( HitLocation, HitNormal, Player.Location, Location, True );
		if ( Hit!=Player )
			continue;

		if ( !FixInFOV(Player) )
			continue;

		if ( Best==None || Dist<BestDist )
		{
			Best     = Player;
			BestDist = Dist;
		}
	}

	curTarget = Best;
	return curTarget;
}
