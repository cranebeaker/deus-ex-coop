//=============================================================================
// HXFixMutatorBase.
//
// Base for HXFix fix modules. HXFixGameInfo spawns every class listed in its
// FixMutatorClasses (missing ones are skipped) and forwards these hooks to
// each of them. Being HXMutators, modules also get the HX replacement hooks
// (CheckActorClassReplacement, CheckInventoryClassReplacement, ModifyLogin).
//
// Note: depending on chain order a module may see either the stock class
// (e.g. ComputerSecurity) or the HX class (HXComputerSecurity), so match both.
//=============================================================================
class HXFixMutatorBase extends HXMutator;

// After HXGameInfo.PostLogin, for every joining player (listen host included).
function NotifyPostLogin( PlayerPawn NewPlayer );

// Before HXGameInfo.Killed (player is not in Dying state yet).
function NotifyKilled( Pawn Killer, Pawn Other, name DamageType );

// After HXGameInfo.RestartPlayer succeeded.
function NotifyRestartPlayer( Pawn Player );

// Before HXGameInfo.Logout.
function NotifyLogout( Pawn Exiting );

// Before HXGameInfo.ProcessServerTravel.
function NotifyServerTravel( string URL, bool bItems );
