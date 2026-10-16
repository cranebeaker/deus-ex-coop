//=============================================================================
// HXFixTestWeaponAmmo.
//
// Remote client opens the real inventory screen, selects an assault gun and
// presses another ammo button. The server weapon must then load that ammo;
// opening the screen and selecting the weapon alone must not change anything.
//=============================================================================
class HXFixTestWeaponAmmo extends HXFixTestBase;

var HXPlayerPawn R;
var HXFixTestWeaponDriver D;
var HXWeapon W;
var class<Ammo> First, Other;

function float RunStep( int StepNum )
{
	local Inventory Inv;
	local int i;

	switch ( StepNum )
	{
		case 0:
			R = Remote();
			if ( !Check(R!=None, "remote client present") )
				return -1;
			D = HXFixTestWeaponDriver( DriverFor(R) );
			if ( !Check(D!=None, "weapon driver present") )
				return -1;
			Inv = Spawn( class'HXWeaponAssaultGun', , , R.Location ).SpawnCopy( R );
			W = HXWeapon( Inv );
			if ( !Check(W!=None && W.Owner==R, "assault gun given to remote") )
				return -1;
			for ( i=0; i<3; i++ )
				if ( W.AmmoNames[i]!=None )
				{
					Inv = Spawn( W.AmmoNames[i], , , R.Location );
					Ammo(Inv).AmmoAmount = 30;
					Inv.SpawnCopy( R );
				}
			First = W.AmmoName;
			for ( i=0; i<3; i++ )
				if ( W.AmmoNames[i]!=None && W.AmmoNames[i]!=First )
				{
					Other = W.AmmoNames[i];
					break;
				}
			Note( "ammo first=" $ First $ " other=" $ Other );
			if ( !Check(First!=None && Other!=None, "weapon has two ammo types") )
				return -1;
			return 3.0;

		case 1:
			D.ClientOpenInventory();
			return 2.0;

		case 2:
			Check( D.bScreenUp, "client inventory screen is up" );
			D.ClientSelectWeapon( W.Class );
			return 3.0;

		case 3:
			Check( D.bScreenUp && D.RSelectedAmmo!=None, "screen shows a selected ammo (" $ D.RSelectedAmmo $ ")" );
			Check( W.AmmoName==First, "opening screen + selecting weapon does not change server ammo (" $ W.AmmoName $ ")" );
			D.ClientPickAmmo( Other );
			return 3.0;

		case 4:
			Check( D.bBtnFound, "ammo button for other ammo found" );
			Check( W.AmmoName==Other, "server weapon ammo changed to " $ Other $ " (now " $ W.AmmoName $ ")" );
			D.ClientPickAmmo( First );
			return 3.0;

		case 5:
			Check( W.AmmoName==First, "server weapon ammo changed back to " $ First $ " (now " $ W.AmmoName $ ")" );
			return -1;
	}
	return -1;
}

defaultproperties
{
	DriverClass=Class'HXFixTestWeaponDriver'
	TimeoutSeconds=330.000000
}
