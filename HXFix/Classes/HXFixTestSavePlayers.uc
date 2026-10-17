//=============================================================================
// HXFixTestSavePlayers.
//
// Gives the host and a remote client distinct state, SaveAll()s, wipes the
// state, RestorePlayer()s both and checks everything came back (server side
// and what the client sees). A restore for an unknown name must return false
// and change nothing.
//=============================================================================
class HXFixTestSavePlayers extends HXFixTestBase;

var HXPlayerPawn Pl[2];
var HXFixTestSavePlayersDriver D;
var int ExpCredits[2], ExpHead[2], ExpTorso[2], ExpLegL[2], ExpHealth[2], ExpAmmo[2], ExpCopies[2], ExpReload[2], ExpBelt[2], ExpHotKey[2];
var float ExpEnergy[2];
var int ExpScope[2], ExpLaser[2];
var int LastSeq;

function ApplyMod( HXPlayerPawn P, HXWeapon W, class<HXWeaponMod> MC )
{
	local HXWeaponMod M;

	M = Spawn( MC, , , P.Location );
	if ( M.CanUpgradeWeapon(W) )
		M.ApplyMod( W );
	else
		Check( False, "can apply" @ MC );
	M.Destroy();
}

function Inventory Give( HXPlayerPawn P, class<Inventory> C )
{
	local Inventory Inv;

	Inv = P.FindInventoryType( C );
	if ( Inv==None )
	{
		Inv = Spawn( C, P );
		Inv.bHeldItem = True;
		Inv.GiveTo( P );
	}
	return Inv;
}

function HXWeapon Pistol( HXPlayerPawn P )
{
	return HXWeapon( P.FindInventoryType(class'HXWeaponPistol') );
}

function int Count( HXPlayerPawn P, class<Inventory> C )
{
	local Inventory Inv;
	local int Num, Safety;

	for ( Inv=P.Inventory; Inv!=None && Safety<512; Inv=Inv.Inventory )
	{
		Safety++;
		if ( Inv.Class==C )
			Num++;
	}
	return Num;
}

function int Copies( HXPlayerPawn P )
{
	local Inventory Inv;

	Inv = P.FindInventoryType( class'HXMedKit' );
	if ( Inv==None )
		return -1;
	return DeusExPickup(Inv).NumCopies;
}

function int AmmoCount( HXPlayerPawn P )
{
	local Inventory Inv;

	Inv = P.FindInventoryType( class'HXAmmo10mm' );
	if ( Inv==None )
		return -1;
	return Ammo(Inv).AmmoAmount;
}

function Setup( int i, int Credits, int AmmoAmt, int NumCopies, class<HXWeaponMod> MC, bool bLaser, int Head, int Torso, int Hp, float Energy )
{
	local HXPlayerPawn P;
	local HXWeapon W;
	local Augmentation Aug;
	local Skill Sk;

	P = Pl[i];
	P.Credits = Credits;
	P.ClientCredits = Credits;
	P.UpdateClientCredits( Credits );

	W = HXWeapon( Give(P, class'HXWeaponPistol') );
	ApplyMod( P, W, MC );
	if ( bLaser )
		ApplyMod( P, W, class'HXWeaponModLaser' );
	else
		ApplyMod( P, W, class'HXWeaponModScope' );
	Ammo(Give(P, class'HXAmmo10mm')).AmmoAmount = AmmoAmt;
	DeusExPickup(Give(P, class'HXMedKit')).NumCopies = NumCopies;
	P._AddObjectToBelt( W, 7 - i, true );

	Aug = HXAugmentationManager(P.AugmentationSystem).GivePlayerAugmentation( class'HXAugSpeed' );
	if ( Aug!=None && Aug.bHasIt )
	{
		Aug.CurrentLevel = 1;
		ExpHotKey[i] = Aug.HotKeyNum;
	}
	else
		Check( False, "speed aug granted to player" @ i );

	Sk = P.SkillSystem.GetSkillFromClass( class'HXSkillWeaponPistol' );
	Sk.CurrentLevel = 2 - i;

	P.HealthHead  = Head;
	P.HealthTorso = Torso;
	P.HealthLegLeft = 33 + i;
	P.Health = Hp;
	P.Energy = Energy;

	ExpCredits[i] = Credits; ExpAmmo[i] = AmmoAmt; ExpCopies[i] = NumCopies;
	ExpHead[i] = Head; ExpTorso[i] = Torso; ExpLegL[i] = 33 + i; ExpHealth[i] = Hp; ExpEnergy[i] = Energy;
	ExpReload[i] = W.ReloadCount;
	ExpScope[i] = int(W.bHasScope); ExpLaser[i] = int(W.bHasLaser);
	ExpBelt[i] = P.FindInBelt( W );
	Note( "player" @ i @ P.PlayerReplicationInfo.PlayerName @ "set up: reload=" $ W.ReloadCount @ "scope=" $ W.bHasScope @ "laser=" $ W.bHasLaser @ "belt=" $ ExpBelt[i] @ "hotkey=" $ ExpHotKey[i] );
}

function Wipe( HXPlayerPawn P )
{
	P.RemoveAllInventory();
	P._ClearBelt( true );
	class'HXFixSavePlayers'.static.WipeAugs( HXAugmentationManager(P.AugmentationSystem) );
	P.SkillSystem.GetSkillFromClass( class'HXSkillWeaponPistol' ).CurrentLevel = 0;
	P.Credits = 1;
	P.ClientCredits = 1;
	P.UpdateClientCredits( 1 );
	P.RestoreAllHealth();
	P.Energy = 10;
	// Something that must not survive the restore.
	Give( P, class'HXBioelectricCell' );
}

function VerifyServer( int i )
{
	local HXPlayerPawn P;
	local HXWeapon W;
	local Augmentation Aug;
	local string Tag;

	P = Pl[i];
	Tag = "player" @ i;
	Check( P.Credits==ExpCredits[i], Tag @ "credits" @ P.Credits @ "expected" @ ExpCredits[i] );
	Check( P.HealthHead==ExpHead[i] && P.HealthTorso==ExpTorso[i] && P.HealthLegLeft==ExpLegL[i] && P.Health==ExpHealth[i],
		Tag @ "health" @ P.HealthHead @ P.HealthTorso @ P.HealthLegLeft @ P.Health );
	Check( Abs(P.Energy-ExpEnergy[i])<0.5, Tag @ "bio energy" @ P.Energy @ "expected" @ ExpEnergy[i] );
	Check( P.SkillSystem.GetSkillFromClass(class'HXSkillWeaponPistol').CurrentLevel==2-i, Tag @ "pistol skill" );

	Aug = HXAugmentationManager(P.AugmentationSystem).FindAugmentation( class'HXAugSpeed' );
	Check( Aug!=None && Aug.bHasIt && Aug.CurrentLevel==1 && Aug.HotKeyNum==ExpHotKey[i], Tag @ "speed aug level 2 and hotkey" );

	Check( Count(P, class'HXWeaponPistol')==1, Tag @ "exactly one pistol (" $ Count(P, class'HXWeaponPistol') $ ")" );
	W = Pistol( P );
	Check( W!=None && W.ReloadCount==ExpReload[i] && int(W.bHasScope)==ExpScope[i] && int(W.bHasLaser)==ExpLaser[i], Tag @ "pistol mods" );
	Check( W!=None && W.AmmoType!=None && W.AmmoType==P.FindInventoryType(class'HXAmmo10mm') && W.AmmoName==class'HXAmmo10mm', Tag @ "pistol linked to its ammo item" );
	Check( Count(P, class'HXAmmo10mm')==1 && AmmoCount(P)==ExpAmmo[i], Tag @ "10mm ammo" @ AmmoCount(P) @ "expected" @ ExpAmmo[i] );
	Check( Count(P, class'HXMedKit')==1 && Copies(P)==ExpCopies[i], Tag @ "medkits" @ Copies(P) @ "expected" @ ExpCopies[i] );
	Check( Count(P, class'HXBioelectricCell')==0, Tag @ "stray bioelectric cell is gone" );
	Check( W!=None && P.FindInBelt(W)==ExpBelt[i], Tag @ "pistol belt slot" @ P.FindInBelt(W) @ "expected" @ ExpBelt[i] );
}

function float RunStep( int StepNum )
{
	local int i;
	local string OldName;

	switch ( StepNum )
	{
		case 0:
			Pl[0] = Host();
			Pl[1] = Remote();
			if ( !Check(Pl[0]!=None && Pl[1]!=None, "host and remote client present") )
				return -1;
			D = HXFixTestSavePlayersDriver( DriverFor(Pl[1]) );
			if ( !Check(D!=None, "driver present") )
				return -1;
			class'HXFixSavePlayers'.static.Clear();
			Check( class'HXFixSavePlayers'.static.Count()==0, "save starts empty" );
			Setup( 0, 1234, 37, 3, class'HXWeaponModClip', False, 40, 55, 77, 44 );
			Setup( 1,  777, 23, 5, class'HXWeaponModRecoil', True, 61, 72, 88, 66 );
			return 2.0;

		case 1:
			class'HXFixSavePlayers'.static.SaveAll( Level );
			Check( class'HXFixSavePlayers'.static.Count()==2, "SaveAll stored 2 players (" $ class'HXFixSavePlayers'.static.Count() $ ")" );
			for ( i=0; i<2; i++ )
				Wipe( Pl[i] );
			Check( Pistol(Pl[0])==None && Pistol(Pl[1])==None && Pl[0].Credits==1, "state wiped" );
			return 2.0;

		case 2:
			Check( class'HXFixSavePlayers'.static.RestorePlayer(Pl[0]), "RestorePlayer host" );
			Check( class'HXFixSavePlayers'.static.RestorePlayer(Pl[1]), "RestorePlayer client" );
			VerifyServer( 0 );
			VerifyServer( 1 );
			return 3.0;

		case 3:
			LastSeq = D.Seq;
			D.ClientProbeInv( class'HXWeaponPistol', class'HXAmmo10mm', class'HXMedKit' );
			return 3.0;

		case 4:
			Check( D.Seq>LastSeq && D.bWeapon, "client reported its pistol" );
			Check( D.RReload==ExpReload[1] && int(D.bRScope)==ExpScope[1] && int(D.bRLaser)==ExpLaser[1], "client pistol mods" @ D.RReload );
			Check( D.RBelt==ExpBelt[1], "client belt slot" @ D.RBelt @ "expected" @ ExpBelt[1] );
			Check( D.RAmmo==ExpAmmo[1] && D.RCopies==ExpCopies[1], "client ammo" @ D.RAmmo @ "medkits" @ D.RCopies );
			Check( D.RCredits==ExpCredits[1], "client credits" @ D.RCredits );

			// Unknown name: false and nothing changes.
			OldName = Pl[0].PlayerReplicationInfo.PlayerName;
			Pl[0].PlayerReplicationInfo.PlayerName = "NoSuchPlayerXyz";
			Pl[0].Credits = 4242;
			Check( !class'HXFixSavePlayers'.static.RestorePlayer(Pl[0]), "unknown name returns false" );
			Check( Pl[0].Credits==4242 && Count(Pl[0], class'HXWeaponPistol')==1 && Copies(Pl[0])==ExpCopies[0], "unknown name changed nothing" );
			Pl[0].PlayerReplicationInfo.PlayerName = OldName;

			class'HXFixSavePlayers'.static.Clear();
			Check( class'HXFixSavePlayers'.static.Count()==0 && !class'HXFixSavePlayers'.static.RestorePlayer(Pl[0]), "Clear removes all records" );
			return -1;
	}
	return -1;
}

defaultproperties
{
	DriverClass=Class'HXFixTestSavePlayersDriver'
	TimeoutSeconds=300.000000
}
