//=============================================================================
// HXFixAugsMutator.
//
// Microfibral Muscle could never be activated: HXAugMuscle.SpecialActivation()
// has no "return True", so HXAugmentation.Activate() always aborts after
// SpecialActivation() has run.
//
// Swapping in a subclass would break everything that compares exact classes
// (HXAugmentationManager.FindAugmentation/GetClassLevel/GetAugLevelValue,
// HXAugmentationCannister.GetAugmentation which matches Class.Name, the hard
// coded manager class in HXPlayerPawn.InitializeSubSystems). So the original
// HXAugMuscle object is kept and the activation is completed from outside.
//
// The failed Activate() leaves a fingerprint: SpecialActivation() already ran
// and set HXPlayerPawn.AugMuscleClassLevel = CurrentLevel while the aug is
// still inactive. Deactivate() resets it to -1, so no other code path leaves
// an inactive muscle aug with AugMuscleClassLevel == CurrentLevel. The server
// polls for that state and performs the rest of HXAugmentation.Activate().
//=============================================================================
class HXFixAugsMutator extends HXFixMutatorBase;

var Pawn KnownPlayers[32]; // Players whose AugMuscleClassLevel was initialized.

// ----------------------------------------------------------------------------
// Tick()
// ----------------------------------------------------------------------------

function Tick( float DeltaTime )
{
	local Pawn P;
	local HXPlayerPawn Player;
	local HXAugMuscle Aug;

	Super.Tick( DeltaTime );

	for ( P=Level.PawnList; P!=None; P=P.NextPawn )
	{
		Player = HXPlayerPawn(P);
		if ( Player==None || Player.bDeleteMe || Player.AugmentationSystem==None )
			continue;

		Aug = HXAugMuscle(Player.AugmentationSystem.FindAugmentation( class'HXAugMuscle' ));
		if ( Aug==None )
			continue;

		// First sight of this player: AugMuscleClassLevel is not a travel
		// variable, so bring it in sync with the aug instead of interpreting it.
		if ( !IsKnown(Player) )
		{
			if ( Aug.bIsActive )
				Player.AugMuscleClassLevel = Aug.CurrentLevel;
			else
				Player.AugMuscleClassLevel = -1;
			continue;
		}

		if ( Aug.bHasIt && !Aug.bIsActive && !Aug.bAlwaysActive && Aug.IsInState('Inactive') && Player.AugMuscleClassLevel==Aug.CurrentLevel )
			CompleteActivation( Player, Aug );
	}
}

// ----------------------------------------------------------------------------
// IsKnown()
//
// Returns whether P was seen before. Registers P otherwise.
// ----------------------------------------------------------------------------

function bool IsKnown( Pawn P )
{
	local int i, Free;

	Free = -1;
	for ( i=0; i<ArrayCount(KnownPlayers); i++ )
	{
		if ( KnownPlayers[i]==P )
			return true;
		if ( Free==-1 && (KnownPlayers[i]==None || KnownPlayers[i].bDeleteMe) )
			Free = i;
	}

	if ( Free!=-1 )
		KnownPlayers[Free] = P;
	return false;
}

// ----------------------------------------------------------------------------
// CompleteActivation()
//
// The part of HXAugmentation.Activate() following SpecialActivation().
// ----------------------------------------------------------------------------

function CompleteActivation( HXPlayerPawn Player, HXAugMuscle Aug )
{
	Player.ClientMessage( Aug.Sprintf(Aug.AugActivated,Aug.AugmentationName), 'StatusLine' );

	if ( Aug.ActivateSound!=None )
		Player.PlaySound( Aug.ActivateSound, SLOT_None );

	// Needs to be before bIsActive is set, otherwise NumAugsActive counts incorrectly.
	if ( Player.AugmentationSystem.NumAugsActive()==0 )
		Player.AmbientSound = Aug.LoopSound;

	Aug.bIsActive = true;

	if ( Player.bHUDShowAllAugs )
		Player.UpdateAugmentationDisplayStatus( Aug );
	else
		Player.AddAugmentationDisplay( Aug );

	Aug.GotoState( 'Active' );
}

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

defaultproperties
{
}
