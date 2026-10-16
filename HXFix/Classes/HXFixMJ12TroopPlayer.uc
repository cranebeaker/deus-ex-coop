//=============================================================================
// HXFixMJ12TroopPlayer.
//
// HXMJ12TroopPlayer with the HXFix player fixes, see HXFixPlayerMutator.
// All HXFix*Player classes are identical apart from their parent class.
//=============================================================================
class HXFixMJ12TroopPlayer extends HXMJ12TroopPlayer;

// NotifyUp() was accepted already.
var bool bFixNotifiedUp;

// Client side stand in for the bioelectric cell, see HXFixPlayerLogic.CellProxy().
var HXBioelectricCell FixCellProxy;

replication
{
	reliable if ( Role<ROLE_Authority )
		HXFixUseCell;
}

// Once per player, and only once there is a connection: PostPostBeginPlay also
// calls this on listen servers for pawns which don't have one yet.
function NotifyUp()
{
	if ( bFixNotifiedUp || Player==None )
		return;
	bFixNotifiedUp = True;
	Super.NotifyUp();
}

// Never run the client half for a remote player on a listen server.
function ClientStartCinematicCamera( float TimeOffset, Vector StartLocation, Rotator StartViewRotation )
{
	if ( Role==ROLE_Authority && Level.NetMode==NM_ListenServer && Viewport(Player)==None )
		return;
	Super.ClientStartCinematicCamera( TimeOffset, StartLocation, StartViewRotation );
}

// Only the player in a conversation controls it.
function ServerPlayNextConPlayEvent()
{
	if ( class'HXFixPlayerLogic'.static.MayControlConPlay(Self) )
		Super.ServerPlayNextConPlayEvent();
}

function ServerPlayConPlayChoice( int Index )
{
	if ( class'HXFixPlayerLogic'.static.MayControlConPlay(Self) )
		Super.ServerPlayConPlayChoice( Index );
}

// Gibbed players leave a carcass with their items too, partly used charged
// pickups are kept.
function Carcass SpawnCarcass()
{
	local HXFixCarcassStash Stash;
	local Carcass Result;
	local int OldHealth;

	Stash     = class'HXFixPlayerLogic'.static.PrepareCarcass( Self );
	OldHealth = Health;
	if ( Health<-80 )
		Health = -80;
	Result    = Super.SpawnCarcass();
	Health    = OldHealth;
	class'HXFixPlayerLogic'.static.FinishCarcass( Stash );
	return Result;
}

// HXGameInfo.IsAugmentedPlayerClass() compares class identity.
function IncreaseNanoVirusInfection()
{
	if ( class'HXFixPlayerLogic'.static.IsAugmentedClass(Class) )
		return;
	Super.IncreaseNanoVirusInfection();
}

// Name rules of the login.
exec function SetName( coerce string InName )
{
	InName = class'HXFixPlayerLogic'.static.SanitizeName( InName );
	if ( InName=="" )
	{
		ClientMessage( "Invalid name." );
		return;
	}
	Super.SetName( InName );
}

function ChangeName( coerce string S )
{
	S = class'HXFixPlayerLogic'.static.SanitizeName( S );
	if ( S=="" )
		return;
	Super.ChangeName( S );
}

// The augmentation screen's "Use Cell" button calls Activate() on the cell it
// finds on the client, which does nothing there. Hand it a stand in which asks
// the server to use the real cell.
function Inventory FindInventoryType( class DesiredClass )
{
	local Inventory Found;

	Found = Super.FindInventoryType( DesiredClass );
	if ( Role<ROLE_Authority && DesiredClass==class'HXBioelectricCell' )
		return class'HXFixPlayerLogic'.static.CellProxy( Self, Found, FixCellProxy );
	return Found;
}

// Close the inventory and other screens with the local player, see
// HXFixPlayerLogic.CloseScreens.
simulated event Destroyed()
{
	class'HXFixPlayerLogic'.static.CloseScreens( Self );
	Super.Destroyed();
}

exec function HXFixUseCell()
{
	class'HXFixPlayerLogic'.static.UseCell( Self );
}
