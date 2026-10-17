//=============================================================================
// HXFixTestSavePlayersDriver.
//
// Client side probe for HXFixTestSavePlayers: reports what the client's own
// copy of its inventory looks like after a restore.
//=============================================================================
class HXFixTestSavePlayersDriver extends HXFixTestDriver;

var int   Seq;
var bool  bWeapon;
var int   RReload;
var bool  bRScope;
var bool  bRLaser;
var int   RBelt;
var int   RAmmo;
var int   RCopies;
var int   RCredits;

replication
{
	reliable if ( Role==ROLE_Authority )
		ClientProbeInv;
	reliable if ( Role<ROLE_Authority )
		ServerInvReport;
}

simulated function ClientProbeInv( class<Inventory> WC, class<Inventory> AC, class<Inventory> PC )
{
	local Inventory Inv, W, A, Pk;
	local int Count;
	local HXPlayerPawn P;
	local HXWeapon HW;

	P = HXPlayerPawn( Owner );
	for ( Inv=P.Inventory; Inv!=None && Count<256; Inv=Inv.Inventory )
	{
		Count++;
		if ( Inv.Class==WC )
			W = Inv;
		else if ( Inv.Class==AC )
			A = Inv;
		else if ( Inv.Class==PC )
			Pk = Inv;
	}
	HW = HXWeapon( W );
	if ( HW!=None )
		ServerInvReport( True, HW.ReloadCount, HW.bHasScope, HW.bHasLaser, P.FindInBelt(W), AmmoOf(A), CopiesOf(Pk), P.ClientCredits );
	else
		ServerInvReport( False, 0, False, False, -1, AmmoOf(A), CopiesOf(Pk), P.ClientCredits );
}

simulated function int AmmoOf( Inventory A )
{
	if ( Ammo(A)!=None )
		return Ammo(A).AmmoAmount;
	return -1;
}

simulated function int CopiesOf( Inventory Pk )
{
	if ( DeusExPickup(Pk)!=None )
		return DeusExPickup(Pk).NumCopies;
	return -1;
}

function ServerInvReport( bool bW, int Reload, bool bScope, bool bLaser, int Belt, int AmmoAmt, int Copies, int Credits )
{
	bWeapon = bW; RReload = Reload; bRScope = bScope; bRLaser = bLaser; RBelt = Belt;
	RAmmo = AmmoAmt; RCopies = Copies; RCredits = Credits;
	Seq++;
	Log( "HXFixTest: client inv report weapon=" $ bW $ " reload=" $ Reload $ " scope=" $ bScope $ " laser=" $ bLaser $ " belt=" $ Belt
		$ " ammo=" $ AmmoAmt $ " copies=" $ Copies $ " credits=" $ Credits, 'HXFixTest' );
}
