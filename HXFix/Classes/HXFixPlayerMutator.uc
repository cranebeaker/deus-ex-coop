//=============================================================================
// HXFixPlayerMutator.
//
// Player pawn fixes.
//
// The pawn overrides live in HXFix<Name>Player, one subclass per stock HX
// player class (they all have to extend the stock class to keep its look), and
// call into HXFixPlayerLogic. This module maps every login class to its HXFix
// counterpart and does the parts which need game wide knowledge:
//
//  - listen host NotifyUp, which can't happen before the viewport exists
//  - respawn equipment farming (suicide / dropped equipment)
//  - carried decoration of a disconnecting player
//=============================================================================
class HXFixPlayerMutator extends HXFixMutatorBase;

// Seconds after the last starting equipment before a suicide gets new one.
var float SuicideCooldown;

const MaxSlots = 32;
var Pawn  SlotPawn[32];
var float SlotLastGrant[32];
var byte  bSlotSuicided[32];

// ----------------------------------------------------------------------------
// Class mapping.
// ----------------------------------------------------------------------------

// Stock HX class for the given login class.
function class<PlayerPawn> StockClass( class<PlayerPawn> C )
{
	if ( C!=None && Left(string(C.Name),5)~="HXFix" )
		return class<PlayerPawn>( DynamicLoadObject("HX.HX"$Mid(string(C.Name),5), class'Class', True) );
	return C;
}

// HXFix subclass of a stock HX class, or the class itself if there is none.
function class<PlayerPawn> FixClass( class<PlayerPawn> C )
{
	local class<PlayerPawn> Fix;

	if ( C==None || Left(string(C.Name),5)~="HXFix" )
		return C;

	Fix = class<PlayerPawn>( DynamicLoadObject("HXFix.HXFix"$Mid(string(C.Name),2), class'Class', True) );
	if ( Fix!=None && ClassIsChildOf(Fix,C) )
		return Fix;
	return C;
}

// ----------------------------------------------------------------------------
// ModifyLogin()
//
// Applies the class rules of HXGameInfo.ModifyLogin on the stock class and
// swaps in the HXFix subclass afterwards. HXGameInfo's own rules can't be left
// to run afterwards, they compare class identity and would revert the swap.
// ----------------------------------------------------------------------------

function ModifyLogin( out class<PlayerPawn> SpawnClass, out string Portal, out string Options, out byte bSuperRelevant )
{
	local class<PlayerPawn> Base;

	Base = StockClass( SpawnClass );

	if ( Base==None )
	{
		Base = Game.DefaultPlayerClass;
	}
	else if ( Game.bJCDentonMode && !Game.IsJCDentonPlayerClass(Base) )
	{
		switch ( int(float(class'HXActor'.static.Strihash(Base.Name)&0x7fffffff)/float(0x7fffffff)*5.0) )
		{
			case 0:  Base = class'HXJCDentonPlayer' ; break;
			case 1:  Base = class'HXJCDenton2Player'; break;
			case 2:  Base = class'HXJCDenton3Player'; break;
			case 3:  Base = class'HXJCDenton4Player'; break;
			default: Base = class'HXJCDenton5Player'; break;
		}
	}
	else if ( !ClassIsChildOf(Base,class'HXStockPlayerPawn') )
	{
		Base = Game.DefaultPlayerClass;
	}

	SpawnClass = FixClass( StockClass(Base) );
	bSuperRelevant = 1;

	Super.ModifyLogin( SpawnClass, Portal, Options, bSuperRelevant );
}

// ----------------------------------------------------------------------------
// Slots.
// ----------------------------------------------------------------------------

function int FindSlot( Pawn P )
{
	local int i, Free;

	Free = -1;
	for ( i=0; i<MaxSlots; i++ )
	{
		if ( SlotPawn[i]==P )
			return i;
		if ( Free<0 && (SlotPawn[i]==None || SlotPawn[i].bDeleteMe) )
			Free = i;
	}
	if ( Free>=0 )
	{
		SlotPawn[Free]      = P;
		SlotLastGrant[Free] = -1000000.0;
		bSlotSuicided[Free] = 0;
	}
	return Free;
}

// ----------------------------------------------------------------------------
// NotifyPostLogin()
//
// HXPlayerPawn.PostPostBeginPlay calls NotifyUp for every spawned pawn on a
// listen server, before the pawn has any connection, which started cinematics
// for the host on behalf of joining players and ran the mission scripts twice.
// The HXFix pawns ignore NotifyUp without a connection, remote clients still
// request it themselves, so only the host has to be notified here.
// ----------------------------------------------------------------------------

function NotifyPostLogin( PlayerPawn NewPlayer )
{
	if ( Level.NetMode==NM_ListenServer && HXPlayerPawn(NewPlayer)!=None && Viewport(NewPlayer.Player)!=None )
		HXPlayerPawn(NewPlayer).NotifyUp();
}

// ----------------------------------------------------------------------------
// NotifyKilled()
// ----------------------------------------------------------------------------

function NotifyKilled( Pawn Killer, Pawn Other, name DamageType )
{
	local int Slot;

	if ( HXPlayerPawn(Other)==None )
		return;

	Slot = FindSlot( Other );
	if ( Slot>=0 )
		bSlotSuicided[Slot] = byte( DamageType=='Suicided' );
}

// ----------------------------------------------------------------------------
// NotifyRestartPlayer()
//
// HXGameInfo.RestartPlayer hands out the starting equipment on every respawn,
// so dying (or suiciding) repeatedly produced unlimited items. No starting
// equipment as long as the player's carcass still holds items, and a suicide
// only gets new equipment after SuicideCooldown seconds.
// ----------------------------------------------------------------------------

function NotifyRestartPlayer( Pawn P )
{
	local HXPlayerPawn Human;
	local int Slot;
	local bool bStrip;

	Human = HXPlayerPawn(P);
	if ( Human==None )
		return;

	Slot = FindSlot( P );
	if ( Slot<0 )
		return;

	if ( CarcassHoldsItems(P) )
	{
		bStrip = True;
		Human.ClientMessage( "Your equipment is still on your body." );
	}
	else if ( bSlotSuicided[Slot]!=0 && Level.TimeSeconds-SlotLastGrant[Slot]<SuicideCooldown )
	{
		bStrip = True;
		Human.ClientMessage( "No new equipment so soon after a suicide." );
	}
	bSlotSuicided[Slot] = 0;

	if ( !bStrip )
	{
		SlotLastGrant[Slot] = Level.TimeSeconds;
		return;
	}

	Log( "HXFix: no starting equipment for" @ P, 'HXFix' );
	Human.RemoveAllInventory();
	Human.SetInHandPending( None );
	Human.SetInHand( None );
}

function bool CarcassHoldsItems( Pawn P )
{
	local HXCarcass Carcass;

	foreach AllActors( class'HXCarcass', Carcass )
		if ( Carcass.bPlayerCarcass && !Carcass.bDeleteMe && Carcass.CarcassName==P.Name && Carcass.Inventory!=None )
			return True;
	return False;
}

// ----------------------------------------------------------------------------
// NotifyLogout()
//
// A decoration carried by the leaving player had its collision switched off
// and HXPlayerPawn.Destroyed never switched it back on, so it stayed in the map
// as an intangible ghost. Do what DropDecoration does before it gets released.
// ----------------------------------------------------------------------------

function NotifyLogout( Pawn Exiting )
{
	local HXPlayerPawn Human;
	local Decoration Deco;
	local Vector DropLocation;
	local int Slot;

	Slot = FindSlot( Exiting );
	if ( Slot>=0 )
		SlotPawn[Slot] = None;

	Human = HXPlayerPawn(Exiting);
	if ( Human==None || Human.CarriedDecoration==None )
		return;

	Deco = Human.CarriedDecoration;
	Log( "HXFix: releasing" @ Deco @ "carried by" @ Exiting, 'HXFix' );

	Deco.SetBase( None );
	DropLocation = Human.Location + (Deco.CollisionRadius+Human.CollisionRadius+4) * Vector(Human.Rotation);
	DropLocation.Z += Human.BaseEyeHeight;
	if ( !FastTrace(DropLocation,Human.Location) || !Deco.SetLocation(DropLocation) )
		Deco.SetLocation( Human.Location + vect(0,0,1)*(Human.CollisionHeight+Deco.CollisionHeight) );
	Deco.SetCollision( True, True, True );
	Deco.bCollideWorld = True;
	Deco.Velocity = vect(0,0,0);
	Deco.SetPhysics( PHYS_Falling );
}

defaultproperties
{
	SuicideCooldown=120.0
}
