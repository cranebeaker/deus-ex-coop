//=============================================================================
// HXFixTestMuscle.
//
// Remote client toggles the Microfibral Muscle aug through its hotkey; the
// aug must end up active on the server (HX's SpecialActivation bug).
// Speed aug is the control: stock HX activates it fine.
//=============================================================================
class HXFixTestMuscle extends HXFixTestBase;

var HXPlayerPawn R;
var Augmentation Aug, Control;

// ToggleAugmentation takes the slot (F3 = 0), not the hotkey number.
function string ToggleCmd( Augmentation A )
{
	return "ToggleAugmentation" @ (A.HotKeyNum-3);
}

function float RunStep( int StepNum )
{
	switch ( StepNum )
	{
		case 0:
			R = Remote();
			if ( !Check(R!=None, "remote client present") )
				return -1;
			R.Energy = R.EnergyMax;
			Control = HXAugmentationManager(R.AugmentationSystem).GivePlayerAugmentation( class'HXAugSpeed' );
			Aug = HXAugmentationManager(R.AugmentationSystem).GivePlayerAugmentation( class'HXAugMuscle' );
			if ( !Check(Aug!=None && Aug.bHasIt && Control!=None, "muscle + speed augs granted") )
				return -1;
			Note( "muscle hotkey" @ Aug.HotKeyNum @ "speed hotkey" @ Control.HotKeyNum );
			return 2.0;

		case 1:
			ClientCmd( R, ToggleCmd(Control) );
			ClientCmd( R, ToggleCmd(Aug) );
			return 3.0;

		case 2:
			if ( !Check(Control.bIsActive, "control: speed aug active after client hotkey") )
				return -1;
			Check( Aug.bIsActive && Aug.IsInState('Active'), "muscle active after client hotkey (bIsActive=" $ Aug.bIsActive $ " state=" $ Aug.GetStateName() $ ")" );
			Check( R.AugMuscleClassLevel==Aug.CurrentLevel, "AugMuscleClassLevel set for bump code" );
			ClientCmd( R, ToggleCmd(Aug) );
			return 3.0;

		case 3:
			Check( !Aug.bIsActive, "muscle deactivates on second toggle" );
			Check( R.AugMuscleClassLevel==-1, "AugMuscleClassLevel reset on deactivate" );
			return -1;
	}
	return -1;
}
