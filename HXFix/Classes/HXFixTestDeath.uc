//=============================================================================
// HXFixTestDeath.
//
// Gibbed players leave a carcass with their items, partly used charged
// pickups survive, and respawning does not hand out free starting gear while
// the corpse still holds items / right after a suicide.
//=============================================================================
class HXFixTestDeath extends HXFixTestBase;

var HXPlayerPawn R;
var HXBallisticArmor Armor;
var int ArmorCharge;
var int StartItems;

function int CountItems( Pawn P )
{
	local Inventory Inv;
	local int N;

	for ( Inv=P.Inventory; Inv!=None && N<200; Inv=Inv.Inventory )
		if ( Inv.bDisplayableInv )
			N++;
	return N;
}

function HXCarcass FindCorpse( Pawn P )
{
	local HXCarcass C;

	foreach AllActors( class'HXCarcass', C )
		if ( C.bPlayerCarcass && !C.bDeleteMe && C.CarcassName==P.Name )
			return C;
	return None;
}

function int CorpseItems( Pawn P )
{
	local HXCarcass C;
	local Inventory Inv;
	local int N;

	C = FindCorpse( P );
	if ( C==None )
		return -1;
	for ( Inv=C.Inventory; Inv!=None && N<200; Inv=Inv.Inventory )
		N++;
	return N;
}

function DestroyCorpses( Pawn P )
{
	local HXCarcass C;

	foreach AllActors( class'HXCarcass', C )
		if ( C.bPlayerCarcass && C.CarcassName==P.Name )
			C.Destroy();
}

function Kill( int NewHealth, name Type )
{
	R.Health = NewHealth;
	R.Died( None, Type, R.Location );
}

function float RunStep( int StepNum )
{
	local HXCarcass C;
	local Inventory Inv;
	local bool bFound;

	switch ( StepNum )
	{
		case 0:
			R = Remote();
			if ( !Check(R!=None, "remote present") )
				return -1;
			StartItems = CountItems( R );
			Note( "remote starts with" @ StartItems @ "items" );
			Check( StartItems>0, "remote has starting items" );
			Armor = Spawn( class'HXBallisticArmor' );
			Armor.GiveTo( R );
			ArmorCharge = Armor.Default.Charge / 3;
			Armor.Charge = ArmorCharge;
			Check( Armor.Owner==R, "armor given" );
			StartItems = CountItems( R );
			return 1.0;

		case 1:
			Kill( -150, 'Exploded' );
			return 2.0;

		case 2:
			C = FindCorpse( R );
			if ( Check(C!=None, "gibbed player left a carcass") )
			{
				Check( CorpseItems(R)>=StartItems-1, "carcass holds the items (" $ CorpseItems(R) $ " of " $ StartItems $ ")" );
				for ( Inv=C.Inventory; Inv!=None; Inv=Inv.Inventory )
					if ( HXBallisticArmor(Inv)!=None )
					{
						bFound = True;
						Check( Inv.Charge==ArmorCharge, "partly used armor kept its charge (" $ Inv.Charge $ " of " $ ArmorCharge $ ")" );
					}
				Check( bFound, "armor on the carcass" );
			}
			return 3.0;

		case 3:
			// The click to respawn is gated by bFrozen (random), call it directly.
			R.ServerReStartPlayer();
			Check( R.Health>0, "respawned (health" @ R.Health $ ")" );
			Check( CountItems(R)==0, "no free starting items while the corpse holds items (has" @ CountItems(R) $ ")" );
			// Legit case: empty corpse gets gear.
			DestroyCorpses( R );
			R.RemoveAllInventory();
			return 1.0;

		case 4:
			Kill( 0, 'Shot' );
			return 2.0;

		case 5:
			Check( CorpseItems(R)<=0, "second corpse is empty (" $ CorpseItems(R) $ ")" );
			return 3.0;

		case 6:
			R.ServerReStartPlayer();
			Check( CountItems(R)>0, "empty corpse: respawn gives starting gear (has" @ CountItems(R) $ ")" );
			// Suicide farming.
			DestroyCorpses( R );
			R.RemoveAllInventory();
			ClientCmd( R, "Suicide" );
			return 2.0;

		case 7:
			Check( R.Health<=0, "suicided" );
			return 3.0;

		case 8:
			R.ServerReStartPlayer();
			Check( CountItems(R)==0, "suicide respawn right after gear gives nothing (has" @ CountItems(R) $ ")" );
			return -1;
	}
	return -1;
}

defaultproperties
{
	TimeoutSeconds=120.000000
}
