//=============================================================================
// HXFixDevicesMutator.
//
// Swaps the HX device classes for their HXFix subclasses, see the individual
// classes for the fixes. The HX tail mutator maps stock classes to HX
// classes before this module sees them, the stock classes are matched too in
// case the order ever changes.
//=============================================================================
class HXFixDevicesMutator extends HXFixMutatorBase;

// Interpolation paths (trigger Events) started so far on this map.
var name Paths[32];
var int NumPaths;

// ----------------------------------------------------------------------------
// PostBeginPlay()
// ----------------------------------------------------------------------------

function PostBeginPlay()
{
	Super.PostBeginPlay();

	// The level actors are all set up a moment from now.
	SetTimer( 1.0, False );
}

// ----------------------------------------------------------------------------
// Timer()
//
// 00_TrainingFinal's map exit is bNoDelete, the HX mutators can't give it the
// no-items behaviour they intended, so players took their training items
// into mission 1. Fix the exits there, and give any stock MapExit nobody
// replaced a fixed successor.
// ----------------------------------------------------------------------------

function Timer()
{
	local MapExit Old;
	local HXMapExit Exit, Rep;
	local bool bHasSuccessor;

	if ( Level.Outer.Name=='00_TrainingFinal' )
	{
		foreach AllActors( class'HXMapExit', Exit )
			if ( Exit.bItems )
			{
				Exit.bItems = False;
				Log( "HXFix:" @ Exit @ "no longer carries items", 'HXFix' );
			}
	}

	foreach AllActors( class'MapExit', Old )
	{
		if ( Old.Class!=class'MapExit' )
			continue;

		bHasSuccessor = False;
		foreach AllActors( class'HXMapExit', Exit )
			if ( VSize(Exit.Location-Old.Location)<8 )
				bHasSuccessor = True;
		if ( bHasSuccessor )
			continue;

		Rep = Spawn( class'HXFixMapExit', None, Old.Tag, Old.Location, Old.Rotation );
		if ( Rep==None )
		{
			Log( "HXFix: couldn't replace" @ Old, 'HXFix' );
			continue;
		}
		DuckCallSucceeds( Rep, Old );
		Rep.SetCollisionSize( Old.CollisionRadius, Old.CollisionHeight );
		Rep.SetCollision( Old.bCollideActors, Old.bBlockActors, Old.bBlockPlayers );
		Log( "HXFix: replaced" @ Old @ "with" @ Rep @ "DestMap=" $ Rep.DestMap, 'HXFix' );

		// Can't be destroyed, make it inert.
		Old.SetCollision( False, False, False );
		Old.Tag = 'HXFixDisabledExit';
	}
}

// ----------------------------------------------------------------------------
// RecordPath()
// ----------------------------------------------------------------------------

function RecordPath( name PathEvent )
{
	local int i;

	for ( i=0; i<NumPaths; i++ )
		if ( Paths[i]==PathEvent )
			return;
	if ( NumPaths<ArrayCount(Paths) )
		Paths[NumPaths++] = PathEvent;
}

// ----------------------------------------------------------------------------
// CheckActorClassReplacement()
// ----------------------------------------------------------------------------

function bool CheckActorClassReplacement( out Class<Actor> ActorClass )
{
	switch ( ActorClass )
	{
		case class'ComputerPersonal':     case class'HXComputerPersonal':     ActorClass = class'HXFixComputerPersonal';     break;
		case class'ComputerPublic':       case class'HXComputerPublic':       ActorClass = class'HXFixComputerPublic';       break;
		case class'ComputerSecurity':     case class'HXComputerSecurity':     ActorClass = class'HXFixComputerSecurity';     break;
		case class'ATM':                  case class'HXATM':                  ActorClass = class'HXFixATM';                  break;
		case class'SecurityCamera':       case class'HXSecurityCamera':       ActorClass = class'HXFixSecurityCamera';       break;
		case class'MapExit':              case class'HXMapExit':              ActorClass = class'HXFixMapExit';              break;
		case class'HXMapExitNoItems':                                         ActorClass = class'HXFixMapExitNoItems';       break;
		case class'Keypad1':              case class'HXKeypad1':              ActorClass = class'HXFixKeypad1';              break;
		case class'Keypad2':              case class'HXKeypad2':              ActorClass = class'HXFixKeypad2';              break;
		case class'Keypad3':              case class'HXKeypad3':              ActorClass = class'HXFixKeypad3';              break;
		case class'MedicalBot':           case class'HXMedicalBot':           ActorClass = class'HXFixMedicalBot';           break;
		case class'RepairBot':            case class'HXRepairBot':            ActorClass = class'HXFixRepairBot';            break;
		case class'Trigger':              case class'HXTrigger':              ActorClass = class'HXFixTrigger';              break;
		case class'InterpolateTrigger':   case class'HXInterpolateTrigger':   ActorClass = class'HXFixInterpolateTrigger';   break;
	}

	return true;
}

// ----------------------------------------------------------------------------
// NotifyPostLogin()
// ----------------------------------------------------------------------------

function NotifyPostLogin( PlayerPawn NewPlayer )
{
	local HXFixInterpolateResender Resender;

	// The listen host is in the game from the start, nothing to catch up.
	if ( NumPaths==0 || HXPlayerPawn(NewPlayer)==None || NewPlayer.Player==None || Viewport(NewPlayer.Player)!=None )
		return;

	Resender = Spawn( class'HXFixInterpolateResender', NewPlayer );
	if ( Resender!=None )
		Resender.Begin( HXPlayerPawn(NewPlayer), Self );
}
