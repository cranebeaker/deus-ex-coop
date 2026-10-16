//=============================================================================
// HXFixTestWeaponMods.
//
// Server applies every mod type to a pistol held by a remote client; the
// client's own copy must show the same stats (HXFixWeaponSync). Then the
// second scope must not be applicable from the client's inventory path, and
// the helper must go away when the weapon is dropped.
// Control: the client's AmmoName is stock state.
//=============================================================================
class HXFixTestWeaponMods extends HXFixTestBase;

var HXPlayerPawn R;
var HXFixTestWeaponDriver D;
var HXWeapon W;
var int LastSeq;

function ServerApply( class<HXWeaponMod> MC )
{
	local HXWeaponMod M;

	M = Spawn( MC, , , R.Location );
	if ( M.CanUpgradeWeapon(W) )
		M.ApplyMod( W );
	else
		Check( False, "server can apply" @ MC );
	M.Destroy();
}

function int CountSyncs()
{
	local HXFixWeaponSync S;
	local int Num;

	foreach AllActors( class'HXFixWeaponSync', S )
		if ( S.Weapon==W && !S.bDeleteMe )
			Num++;
	return Num;
}

function float RunStep( int StepNum )
{
	local HXWeaponModScope Scope;
	local Inventory Inv;
	local int Num;

	switch ( StepNum )
	{
		case 0:
			R = Remote();
			if ( !Check(R!=None, "remote client present") )
				return -1;
			D = HXFixTestWeaponDriver( DriverFor(R) );
			if ( !Check(D!=None, "weapon driver present") )
				return -1;
			Inv = Spawn( class'HXWeaponPistol', , , R.Location ).SpawnCopy( R );
			W = HXWeapon( Inv );
			if ( !Check(W!=None && W.Owner==R, "pistol given to remote") )
				return -1;
			Note( "pistol: reload=" $ W.ReloadCount $ " recoil=" $ W.recoilStrength $ " acc=" $ W.BaseAccuracy $ " range=" $ W.AccurateRange $ " rtime=" $ W.ReloadTime $ " scope=" $ W.bHasScope $ " canScope=" $ W.bCanHaveScope );
			return 3.0;

		case 1:
			// Baseline: client copy equals server copy.
			LastSeq = D.Seq;
			D.ClientProbeWeapon( W.Class );
			return 1.5;

		case 2:
			Check( D.Seq>LastSeq && D.bFound, "client has the pistol" );
			Check( D.RReloadCount==W.ReloadCount, "baseline reload count" @ D.RReloadCount @ W.ReloadCount );
			Num = CountSyncs();
			Check( Num==1, "exactly one sync helper for pistol (" $ Num $ ")" );
			ServerApply( class'HXWeaponModClip' );
			ServerApply( class'HXWeaponModRecoil' );
			ServerApply( class'HXWeaponModAccuracy' );
			ServerApply( class'HXWeaponModRange' );
			ServerApply( class'HXWeaponModReload' );
			ServerApply( class'HXWeaponModScope' );
			Note( "after mods: reload=" $ W.ReloadCount $ " recoil=" $ W.recoilStrength $ " acc=" $ W.BaseAccuracy $ " range=" $ W.AccurateRange $ " rtime=" $ W.ReloadTime $ " scope=" $ W.bHasScope );
			return 3.0;

		case 3:
			LastSeq = D.Seq;
			D.ClientProbeWeapon( W.Class );
			return 1.5;

		case 4:
			Check( D.Seq>LastSeq && D.bFound, "client report arrived" );
			Check( W.ReloadCount>W.Default.ReloadCount, "server clip mod applied" );
			Check( D.RReloadCount==W.ReloadCount, "client ReloadCount" @ D.RReloadCount @ "server" @ W.ReloadCount );
			Check( Abs(D.RRecoil-W.recoilStrength)<0.001 && W.recoilStrength!=W.Default.recoilStrength, "client recoilStrength" @ D.RRecoil @ "server" @ W.recoilStrength );
			Check( D.bRScope==W.bHasScope && W.bHasScope, "client bHasScope" @ D.bRScope );
			Check( Abs(D.RBaseAccuracy-W.BaseAccuracy)<0.001 && W.BaseAccuracy!=W.Default.BaseAccuracy, "client BaseAccuracy" @ D.RBaseAccuracy @ "server" @ W.BaseAccuracy );
			Check( D.RAccurateRange==W.AccurateRange && W.AccurateRange!=W.Default.AccurateRange, "client AccurateRange" @ D.RAccurateRange @ "server" @ W.AccurateRange );
			Check( Abs(D.RReloadTime-W.ReloadTime)<0.001 && W.ReloadTime!=W.Default.ReloadTime, "client ReloadTime" @ D.RReloadTime @ "server" @ W.ReloadTime );
			Check( D.RAmmoName==W.AmmoName, "control: client AmmoName" @ D.RAmmoName @ "server" @ W.AmmoName );

			// Second scope from the client's inventory path.
			Scope = Spawn( class'HXWeaponModScope', , , R.Location );
			Scope.SpawnCopy( R );
			return 2.0;

		case 5:
			D.ClientProbeMod( class'HXWeaponModScope', W.Class, True );
			return 2.0;

		case 6:
			Check( D.bModFound, "client holds the second scope mod" );
			Check( !D.bCanUpgrade, "client refuses second scope (CanUpgradeWeapon false)" );
			foreach AllActors( class'HXWeaponModScope', Scope )
				if ( Scope.Owner==R )
					Num++;
			Check( Num==1, "second scope mod not destroyed (" $ Num $ " in inventory)" );

			// Drop: helper must vanish.
			R.DeleteInventory( W );
			return 2.0;

		case 7:
			Num = CountSyncs();
			Check( Num==0, "sync helper cleaned up after weapon removed (" $ Num $ ")" );
			W.Destroy();
			return -1;
	}
	return -1;
}

defaultproperties
{
	DriverClass=Class'HXFixTestWeaponDriver'
	TimeoutSeconds=330.000000
}
