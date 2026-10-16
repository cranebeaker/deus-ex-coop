//=============================================================================
// HXFixTestChangeAmmo.
//
// Remote client cycles ammo with the SwitchAmmo key and with the inventory
// screen's Change Ammo button. Both must change the server weapon's ammo.
//=============================================================================
class HXFixTestChangeAmmo extends HXFixTestBase;

var HXPlayerPawn R;
var HXFixTestWeaponDriver D;
var HXWeapon W;
var class<Ammo> Before;

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
			if ( !Check(W.NumAmmoTypesAvailable()>=2, "weapon has two ammo types (" $ W.NumAmmoTypesAvailable() $ ")") )
				return -1;
			R.PutInHand( W );
			return 3.0;

		case 1:
			Check( R.InHand==W, "assault gun in hand" );
			Before = W.AmmoName;
			ClientCmd( R, "SwitchAmmo" );
			return 3.0;

		case 2:
			Check( W.AmmoName!=Before, "SwitchAmmo key changed server ammo (" $ Before $ " -> " $ W.AmmoName $ ")" );
			D.ClientOpenInventory();
			return 2.0;

		case 3:
			D.ClientSelectWeapon( W.Class );
			return 3.0;

		case 4:
			Check( D.bScreenUp, "client inventory screen is up" );
			Before = W.AmmoName;
			D.ClientChangeAmmo();
			return 3.0;

		case 5:
			Check( D.bBtnFound, "Change Ammo button found" );
			Check( W.AmmoName!=Before, "Change Ammo button changed server ammo (" $ Before $ " -> " $ W.AmmoName $ ")" );
			Check( D.RSelectedAmmo==W.AmmoName, "screen shows the server's ammo (" $ D.RSelectedAmmo $ ")" );
			Before = W.AmmoName;
			D.ClientChangeAmmo();
			return 3.0;

		case 6:
			Check( W.AmmoName!=Before, "second press changed server ammo again (" $ Before $ " -> " $ W.AmmoName $ ")" );
			Check( D.RSelectedAmmo==W.AmmoName, "screen still matches the server (" $ D.RSelectedAmmo $ ")" );
			return -1;
	}
	return -1;
}

defaultproperties
{
	DriverClass=Class'HXFixTestWeaponDriver'
	TimeoutSeconds=330.000000
}
