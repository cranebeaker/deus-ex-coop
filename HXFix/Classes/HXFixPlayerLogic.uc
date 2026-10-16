//=============================================================================
// HXFixPlayerLogic.
//
// Shared logic of the HXFix player pawn subclasses (HXFix<Name>Player, one per
// stock HX player class, see HXFixPlayerMutator). Pawn classes can't share a
// common base here, because every stock class already extends HXGMTrenchPlayer
// or HXMPJumpsuitPlayer, so their overrides are one liners calling in here.
//=============================================================================
class HXFixPlayerLogic extends Object;

const MaxNameLength = 20; // Same as HXGameInfo.Login.

// ----------------------------------------------------------------------------
// SanitizeName()
//
// Applies the same rules as HXGameInfo.Login: 20 characters at most, no
// internal Steve names. Also drops control characters and characters which
// would break URL options. Returns "" if the name must be rejected.
// ----------------------------------------------------------------------------

static function string SanitizeName( string S )
{
	local string Result, Ch;
	local int i, Code;

	if ( InStr(Caps(S),"__INTERNAL_STEVE_")!=-1 )
		return "";

	for ( i=0; i<Len(S); i++ )
	{
		Ch   = Mid( S, i, 1 );
		Code = Asc( Ch );
		if ( Code<32 || Code==127 || Ch=="?" || Ch=="\"" || Ch=="\\" )
			continue;
		Result = Result $ Ch;
	}

	Result = Left( Result, MaxNameLength );

	// Trim trailing space.
	while ( Len(Result)>0 && Right(Result,1)==" " )
		Result = Left( Result, Len(Result)-1 );

	if ( InStr(Caps(Result),"__INTERNAL_STEVE_")!=-1 )
		return "";
	return Result;
}

// ----------------------------------------------------------------------------
// MayControlConPlay()
//
// Server side conversation input is only accepted from the player who is in
// the conversation. Unowned conversations (first person ones) and cinematics
// (bForcePlay) can be skipped by anybody.
// ----------------------------------------------------------------------------

static function bool MayControlConPlay( HXPlayerPawn P )
{
	local HXGameInfo Game;

	Game = HXGameInfo(P.Level.Game);
	if ( Game==None || Game.ConPlay==None )
		return False;

	if ( Game.ConPlay.Player==None || Game.ConPlay.Player==P )
		return True;

	return Game.ConPlay.GetForcePlay();
}

// ----------------------------------------------------------------------------
// IsAugmentedClass()
//
// HXGameInfo.IsAugmentedPlayerClass() compares class identity, which the HXFix
// subclasses don't have. Used for the nano virus immunity.
// ----------------------------------------------------------------------------

static function bool IsAugmentedClass( Class<Object> C )
{
	return ClassIsChildOf( C, class'HXJCDentonPlayer'  )
		|| ClassIsChildOf( C, class'HXJCDenton2Player' )
		|| ClassIsChildOf( C, class'HXJCDenton3Player' )
		|| ClassIsChildOf( C, class'HXJCDenton4Player' )
		|| ClassIsChildOf( C, class'HXJCDenton5Player' )
		|| ClassIsChildOf( C, class'HXPaulDentonPlayer'  )
		|| ClassIsChildOf( C, class'HXPaulDenton2Player' )
		|| ClassIsChildOf( C, class'HXPaulDenton3Player' )
		|| ClassIsChildOf( C, class'HXPaulDenton4Player' )
		|| ClassIsChildOf( C, class'HXPaulDenton5Player' )
		|| ClassIsChildOf( C, class'HXWaltonSimonsPlayer' );
}

// ----------------------------------------------------------------------------
// PrepareCarcass() / FinishCarcass()
//
// HXPlayerPawn.SpawnCarcass() destroys partly used charged pickups. Make them
// look fully charged for the duration of the call and restore their charge
// afterwards, so they end up on the carcass like everything else.
// ----------------------------------------------------------------------------

static function HXFixCarcassStash PrepareCarcass( HXPlayerPawn P )
{
	local HXFixCarcassStash Stash;
	local Inventory Item;
	local int Count;

	Stash = P.Spawn( class'HXFixCarcassStash' );
	if ( Stash==None )
		return None;

	for ( Item=P.Inventory; Item!=None && Count<512; Item=Item.Inventory )
	{
		Count++;
		if ( HXChargedPickup(Item)!=None && Item.Charge!=Item.Default.Charge && Stash.Num<ArrayCount(Stash.Items) )
		{
			Stash.Items[Stash.Num]   = Item;
			Stash.Charges[Stash.Num] = Item.Charge;
			Stash.Num++;
			Item.Charge = Item.Default.Charge;
		}
	}
	return Stash;
}

static function FinishCarcass( HXFixCarcassStash Stash )
{
	local int i;

	if ( Stash==None )
		return;

	for ( i=0; i<Stash.Num; i++ )
		if ( Stash.Items[i]!=None && !Stash.Items[i].bDeleteMe )
			Stash.Items[i].Charge = Stash.Charges[i];
	Stash.Destroy();
}

// ----------------------------------------------------------------------------
// CellProxy() / UseCell()
//
// HXPersonaScreenAugmentations.UseCell() calls Activate() on the bioelectric
// cell it finds in the client's inventory. Activate() isn't replicated, so for
// remote clients the button did nothing. On clients FindInventoryType() hands
// out a local HXFixCellProxy instead, whose Activate() runs the HXFixUseCell
// exec on the pawn, a server function which uses the real cell.
// ----------------------------------------------------------------------------

static function Inventory CellProxy( HXPlayerPawn P, Inventory Real, out HXBioelectricCell Proxy )
{
	if ( Real==None )
		return None;

	if ( Proxy==None || Proxy.bDeleteMe )
		Proxy = P.Spawn( class'HXFixCellProxy', P );
	if ( Proxy==None )
		return Real;

	Proxy.NumCopies = HXBioelectricCell(Real).NumCopies;
	return Proxy;
}

// A client which drops back to Entry (host quit, connection lost) keeps the
// old player's inventory screen around, and the game crashed on exit in
// HXPersonaInventoryObjectBelt.DestroyWindow. HXPlayerPawn.Destroyed had this
// commented out because of regressions, so only the local client player does it.
static function CloseScreens( HXPlayerPawn P )
{
	local HXRootWindow Root;

	if ( P.Role!=ROLE_AutonomousProxy )
		return;
	Root = HXRootWindow( P.rootWindow );
	if ( Root!=None && Root.winCount>0 )
		Root.ClearWindowStackNoUnPauseGame();
}

static function UseCell( HXPlayerPawn P )
{
	local Inventory Cell;

	if ( P.Role<ROLE_Authority || P.Health<=0 )
		return;

	Cell = P.FindInventoryType( class'HXBioelectricCell' );
	if ( Cell!=None )
		Cell.Activate();
}
