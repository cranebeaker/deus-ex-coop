//=============================================================================
// HXFixTestWeaponDriver.
//
// Client side probes for the weapon tests. The server calls ClientXxx on the
// owning client, the client reports back through ServerXxx into variables the
// test reads. Seq/MSeq count replies so the test can tell a fresh answer.
//=============================================================================
class HXFixTestWeaponDriver extends HXFixTestDriver;

// Last weapon report.
var int   Seq;
var bool  bFound;
var int   RReloadCount;
var float RRecoil;
var bool  bRScope;
var float RBaseAccuracy;
var int   RAccurateRange;
var float RReloadTime;
var class<Ammo> RAmmoName;

// Last mod / inventory screen / key report.
var int   MSeq;
var bool  bModFound;
var bool  bCanUpgrade;
var bool  bScreenUp;
var bool  bBtnFound;
var bool  bKeyHas;
var string KeyLabel;
var class<Ammo> RSelectedAmmo;

replication
{
	reliable if ( Role==ROLE_Authority )
		ClientProbeWeapon, ClientProbeMod, ClientOpenInventory, ClientSelectWeapon, ClientPickAmmo, ClientProbeKey, ClientChangeAmmo;
	reliable if ( Role<ROLE_Authority )
		ServerWeaponReport, ServerModReport, ServerScreenReport, ServerKeyReport;
}

simulated function HXWeapon FindWeapon( class<HXWeapon> WC )
{
	local Inventory Inv;
	local int Count;

	for ( Inv=Pawn(Owner).Inventory; Inv!=None && Count<256; Inv=Inv.Inventory )
	{
		Count++;
		if ( Inv.Class==WC )
			return HXWeapon(Inv);
	}
	return None;
}

simulated function ClientProbeWeapon( class<HXWeapon> WC )
{
	local HXWeapon W;

	W = FindWeapon( WC );
	if ( W==None )
		ServerWeaponReport( False, 0, 0, False, 0, 0, 0, None );
	else
		ServerWeaponReport( True, W.ReloadCount, W.recoilStrength, W.bHasScope, W.BaseAccuracy, W.AccurateRange, W.ReloadTime, W.AmmoName );
}

function ServerWeaponReport( bool bF, int Reload, float Recoil, bool bScope, float Acc, int Range, float RTime, class<Ammo> Ammo )
{
	bFound = bF; RReloadCount = Reload; RRecoil = Recoil; bRScope = bScope; RBaseAccuracy = Acc;
	RAccurateRange = Range; RReloadTime = RTime; RAmmoName = Ammo;
	Seq++;
	Log( "HXFixTest: client weapon report found=" $ bF $ " reload=" $ Reload $ " recoil=" $ Recoil $ " scope=" $ bScope $ " acc=" $ Acc $ " range=" $ Range $ " rtime=" $ RTime $ " ammo=" $ Ammo, 'HXFixTest' );
}

// What the inventory screen does when a mod is dropped on a weapon.
simulated function ClientProbeMod( class<HXWeaponMod> MC, class<HXWeapon> WC, bool bApply )
{
	local Inventory Inv;
	local HXWeaponMod Mod;
	local HXWeapon W;
	local int Count;

	W = FindWeapon( WC );
	for ( Inv=Pawn(Owner).Inventory; Inv!=None && Count<256; Inv=Inv.Inventory )
	{
		Count++;
		if ( Inv.Class==MC )
		{
			Mod = HXWeaponMod(Inv);
			break;
		}
	}
	if ( Mod==None || W==None )
	{
		ServerModReport( False, False );
		return;
	}
	if ( Mod.CanUpgradeWeapon(W) )
	{
		ServerModReport( True, True );
		if ( bApply )
		{
			Mod.ApplyMod( W );
			Mod.DestroyMod();
		}
	}
	else
		ServerModReport( True, False );
}

function ServerModReport( bool bMod, bool bCan )
{
	bModFound = bMod; bCanUpgrade = bCan;
	MSeq++;
	Log( "HXFixTest: client mod report modFound=" $ bMod $ " canUpgrade=" $ bCan, 'HXFixTest' );
}

simulated function HXPersonaScreenInventory GetScreen()
{
	local HXPlayerPawn P;

	P = HXPlayerPawn(Owner);
	if ( P!=None && HXRootWindow(P.rootWindow)!=None )
		return HXPersonaScreenInventory( HXRootWindow(P.rootWindow).GetTopWindow() );
	return None;
}

simulated function ClientOpenInventory()
{
	HXPlayerPawn(Owner).ShowInventoryWindow();
	ServerScreenReport( GetScreen()!=None, None, False );
}

simulated function ClientSelectWeapon( class<HXWeapon> WC )
{
	local HXPersonaScreenInventory Screen;
	local HXWeapon W;

	Screen = GetScreen();
	W = FindWeapon( WC );
	if ( Screen==None || W==None )
	{
		ServerScreenReport( Screen!=None, None, False );
		return;
	}
	Screen.SelectInventoryItem( W );
	ServerScreenReport( True, Screen.winInfo.GetSelectedAmmo(), False );
}

// Press the ammo button for AmmoClass like a click would.
simulated function ClientPickAmmo( class<Ammo> AmmoClass )
{
	local HXPersonaScreenInventory Screen;
	local Window Win;

	Screen = GetScreen();
	if ( Screen==None || Screen.winInfo==None )
	{
		ServerScreenReport( False, None, False );
		return;
	}
	Win = Screen.winInfo.WinTileAmmo.GetTopChild();
	while ( Win!=None )
	{
		if ( PersonaAmmoDetailButton(Win)!=None && PersonaAmmoDetailButton(Win).GetAmmo()==AmmoClass )
			break;
		Win = Win.GetLowerSibling();
	}
	bBtnFound = Win!=None;
	if ( Win!=None )
		Screen.ButtonActivated( Win );
	ServerScreenReport( True, Screen.winInfo.GetSelectedAmmo(), bBtnFound );
}

// Press the inventory screen's Change Ammo button.
simulated function ClientChangeAmmo()
{
	local HXPersonaScreenInventory Screen;

	Screen = GetScreen();
	bBtnFound = Screen!=None && Screen.BtnChangeAmmo!=None;
	if ( bBtnFound )
		Screen.ButtonActivated( Screen.BtnChangeAmmo );
	ServerScreenReport( Screen!=None, Screen.winInfo.GetSelectedAmmo(), bBtnFound );
}

function ServerScreenReport( bool bUp, class<Ammo> Selected, bool bBtn )
{
	bScreenUp = bUp; RSelectedAmmo = Selected; bBtnFound = bBtn;
	MSeq++;
	Log( "HXFixTest: client screen report up=" $ bUp $ " btnFound=" $ bBtnFound $ " selected=" $ Selected, 'HXFixTest' );
}

// What a client datalink does for NK_<Name>: reports the branch taken.
simulated function ClientProbeKey( string ObjectName )
{
	local HXClientDataLinkPlay Play;
	local ConEventCheckObject Event;
	local string NextLabel;

	Play = Spawn( class'HXClientDataLinkPlay' );
	Play.Player = DeusExPlayer(Owner);
	Event = new(None) class'ConEventCheckObject';
	Event.ObjectName = ObjectName;
	Event.FailLabel = "FAILED";
	Play.SetupEventCheckObject( Event, NextLabel );
	ServerKeyReport( ObjectName, NextLabel=="", NextLabel );
	Play.Destroy();
}

function ServerKeyReport( string ObjectName, bool bHas, string Label )
{
	bKeyHas = bHas; KeyLabel = Label;
	MSeq++;
	Log( "HXFixTest: client key report " $ ObjectName $ " has=" $ bHas $ " label=" $ Label, 'HXFixTest' );
}
