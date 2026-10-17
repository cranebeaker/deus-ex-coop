//=============================================================================
// HXFixSavePlayers.
//
// Co-op save of the per player state, kept in HXFixSave.ini and matched by
// the exact player name (HXFix makes names unique with _N suffixes).
//
// SaveAll()       captures every connected player.
// RestorePlayer() replaces a player's state with the record of the same name.
// Clear()         deletes all records.
//
// Storage is a flat list of short text lines, "<player index>,<kind>,<fields>":
//   C core stats    S skill          A augmentation
//   M ammo item     P pickup/other   W weapon (with applied mods and ammo type)
// Kept: health per part, bio energy, credits, skill points, skill levels,
// augmentations, inventory with counts/charges, weapons, ammo, belt slots.
// Skipped: the team wide nanokey ring and nanokeys, items in hand, pinned
// belt slots, active aug state. Unknown classes are skipped with a log line.
//=============================================================================
class HXFixSavePlayers extends Object
	config(HXFixSave);

const MaxPlayers = 16;
const MaxLines   = 1200;

var config int    NumPlayers;
var config string PlayerName[16];
var config int    NumLines;
var config string Line[1200];

// ----------------------------------------------------------------------------
// Text helpers.
// ----------------------------------------------------------------------------

static function string Field( string S, int Index )
{
	local int i;

	while ( Index>0 )
	{
		i = InStr( S, "," );
		if ( i<0 )
			return "";
		S = Mid( S, i+1 );
		Index--;
	}
	i = InStr( S, "," );
	if ( i>=0 )
		S = Left( S, i );
	return S;
}

static function string ClassStr( Class<Object> C )
{
	if ( C==None )
		return "";
	return string(C.Outer.Name) $ "." $ string(C.Name);
}

static function Class<Object> LoadClassStr( string S )
{
	if ( S=="" )
		return None;
	return Class<Object>( DynamicLoadObject( S, class'Class', True ) );
}

static function AddLine( int P, string S )
{
	if ( Default.NumLines>=MaxLines )
	{
		Log( "HXFixSavePlayers: line table full, dropping" @ S, 'HXFixSave' );
		return;
	}
	Default.Line[Default.NumLines] = P $ "," $ S;
	Default.NumLines++;
}

// Removes the record of player index P and renumbers the ones after it.
static function DropPlayer( int P )
{
	local int i, n, Idx;
	local string S;

	for ( i=0; i<Default.NumLines; i++ )
	{
		S   = Default.Line[i];
		Idx = int( Field(S,0) );
		if ( Idx==P )
			continue;
		if ( Idx>P )
			S = (Idx-1) $ Mid( S, InStr(S,",") );
		Default.Line[n] = S;
		n++;
	}
	for ( i=n; i<Default.NumLines; i++ )
		Default.Line[i] = "";
	Default.NumLines = n;

	for ( i=P; i<Default.NumPlayers-1; i++ )
		Default.PlayerName[i] = Default.PlayerName[i+1];
	Default.PlayerName[Default.NumPlayers-1] = "";
	Default.NumPlayers--;
}

static function int FindPlayer( string Name )
{
	local int i;

	for ( i=0; i<Default.NumPlayers; i++ )
		if ( Default.PlayerName[i]==Name )
			return i;
	return -1;
}

static function string NameOf( HXPlayerPawn P )
{
	if ( P.PlayerReplicationInfo!=None )
		return P.PlayerReplicationInfo.PlayerName;
	return "";
}

// ----------------------------------------------------------------------------
// Capture.
// ----------------------------------------------------------------------------

static function SaveAll( LevelInfo L )
{
	local Pawn Pwn;
	local HXPlayerPawn P;
	local int Num;

	if ( L==None )
		return;

	for ( Pwn=L.PawnList; Pwn!=None; Pwn=Pwn.NextPawn )
	{
		P = HXPlayerPawn( Pwn );
		if ( P==None || P.bDeleteMe || P.Player==None || P.Health<=0 )
			continue;
		if ( CapturePlayer(P) )
			Num++;
	}
	StaticSaveConfig();
	Log( "HXFixSavePlayers: saved" @ Num @ "players," @ Default.NumLines @ "lines", 'HXFixSave' );
}

static function bool CapturePlayer( HXPlayerPawn P )
{
	local string Name;
	local int Idx, Count;
	local Skill Sk;
	local Augmentation Aug;
	local Inventory Inv;
	local HXWeapon W;
	local string Belt;

	Name = NameOf( P );
	if ( Name=="" )
		return false;

	// Replace an older record of this name, keep records of absent players.
	Idx = FindPlayer( Name );
	if ( Idx>=0 )
		DropPlayer( Idx );
	if ( Default.NumPlayers>=MaxPlayers )
	{
		Log( "HXFixSavePlayers: player table full, not saving" @ Name, 'HXFixSave' );
		return false;
	}
	Idx = Default.NumPlayers;
	Default.NumPlayers++;
	Default.PlayerName[Idx] = Name;

	AddLine( Idx, "C," $ P.Health $ "," $ P.HealthHead $ "," $ P.HealthTorso $ "," $ P.HealthLegLeft $ "," $ P.HealthLegRight
		$ "," $ P.HealthArmLeft $ "," $ P.HealthArmRight $ "," $ P.Energy $ "," $ P.EnergyMax $ "," $ P.Credits
		$ "," $ P.SkillPointsAvail $ "," $ P.SkillPointsTotal );

	if ( P.SkillSystem!=None )
		for ( Sk=P.SkillSystem.FirstSkill; Sk!=None && Count<64; Sk=Sk.Next )
		{
			Count++;
			AddLine( Idx, "S," $ ClassStr(Sk.Class) $ "," $ Sk.CurrentLevel );
		}

	Count = 0;
	if ( P.AugmentationSystem!=None )
		for ( Aug=P.AugmentationSystem.FirstAug; Aug!=None && Count<64; Aug=Aug.Next )
		{
			Count++;
			if ( Aug.bHasIt )
				AddLine( Idx, "A," $ ClassStr(Aug.Class) $ "," $ Aug.CurrentLevel $ "," $ Aug.HotKeyNum );
		}

	Count = 0;
	for ( Inv=P.Inventory; Inv!=None && Count<512; Inv=Inv.Inventory )
	{
		Count++;
		if ( Inv.bDeleteMe || HXNanoKey(Inv)!=None || HXNanoKeyRing(Inv)!=None )
			continue;
		if ( !Inv.bDisplayableInv && Ammo(Inv)==None )
			continue;

		Belt = string( P.FindInBelt(Inv) );
		W = HXWeapon( Inv );
		if ( W!=None )
		{
			AddLine( Idx, "W," $ ClassStr(W.Class) $ "," $ Belt $ "," $ ClassStr(W.AmmoName) $ "," $ W.ClipCount
				$ "," $ W.ReloadCount $ "," $ W.AccurateRange $ "," $ W.BaseAccuracy $ "," $ W.ReloadTime $ "," $ W.recoilStrength
				$ "," $ W.ModBaseAccuracy $ "," $ W.ModReloadCount $ "," $ W.ModAccurateRange $ "," $ W.ModReloadTime $ "," $ W.ModRecoilStrength
				$ "," $ int(W.bHasScope) $ "," $ int(W.bHasLaser) $ "," $ int(W.bHasSilencer) );
		}
		else if ( Ammo(Inv)!=None )
			AddLine( Idx, "M," $ ClassStr(Inv.Class) $ "," $ Belt $ "," $ Ammo(Inv).AmmoAmount );
		else if ( DeusExPickup(Inv)!=None )
			AddLine( Idx, "P," $ ClassStr(Inv.Class) $ "," $ Belt $ "," $ DeusExPickup(Inv).NumCopies $ "," $ Inv.Charge );
		else
			Log( "HXFixSavePlayers: skipping unsupported item" @ Inv.Class, 'HXFixSave' );
	}
	return true;
}

// ----------------------------------------------------------------------------
// Restore.
// ----------------------------------------------------------------------------

static function bool RestorePlayer( HXPlayerPawn P )
{
	local int Idx, i, Count;
	local string S, Kind;
	local Class<Object> C;
	local Inventory Items[64];
	local int Belts[64];
	local int NumItems;
	local Inventory Inv;
	local HXWeapon W;
	local Skill Sk;
	local Augmentation Aug;
	local HXAugmentationManager AM;

	if ( P==None || P.bDeleteMe || P.Level.NetMode==NM_Client )
		return false;
	Idx = FindPlayer( NameOf(P) );
	if ( Idx<0 )
		return false;

	// ---- Wipe the default loadout (the nanokey ring stays). ----
	P.RemoveAllInventory();
	P._ClearBelt( true );
	P.SetInHandPending( None );
	P.SetInHand( None );

	AM = HXAugmentationManager( P.AugmentationSystem );
	if ( AM!=None )
		WipeAugs( AM );
	if ( P.SkillSystem!=None )
		for ( Sk=P.SkillSystem.FirstSkill; Sk!=None && Count<64; Sk=Sk.Next )
		{
			Count++;
			Sk.CurrentLevel = 0;
		}

	// ---- Apply lines. Ammo first so weapons find their ammo. ----
	for ( i=0; i<Default.NumLines; i++ )
	{
		S = Default.Line[i];
		if ( int(Field(S,0))!=Idx )
			continue;
		Kind = Field( S, 1 );

		if ( Kind=="C" )
			RestoreCore( P, S );
		else if ( Kind=="S" )
		{
			C = LoadClassStr( Field(S,2) );
			Sk = None;
			if ( C!=None && P.SkillSystem!=None )
				Sk = P.SkillSystem.GetSkillFromClass( Class<Skill>(C) );
			if ( Sk!=None )
				Sk.CurrentLevel = int( Field(S,3) );
			else
				Log( "HXFixSavePlayers: unknown skill" @ Field(S,2), 'HXFixSave' );
		}
		else if ( Kind=="A" )
		{
			C = LoadClassStr( Field(S,2) );
			Aug = None;
			if ( C!=None && AM!=None )
				Aug = AM.GivePlayerAugmentation( Class<Augmentation>(C) );
			if ( Aug!=None )
			{
				Aug.CurrentLevel = int( Field(S,3) );
				Aug.HotKeyNum    = int( Field(S,4) );
			}
			else
				Log( "HXFixSavePlayers: could not restore aug" @ Field(S,2), 'HXFixSave' );
		}
		else if ( Kind=="M" )
		{
			Inv = GiveAmmo( P, S );
			if ( Inv!=None && NumItems<64 )
			{
				Items[NumItems]  = Inv;
				Belts[NumItems] = int( Field(S,3) );
				NumItems++;
			}
		}
	}
	for ( i=0; i<Default.NumLines; i++ )
	{
		S = Default.Line[i];
		if ( int(Field(S,0))!=Idx )
			continue;
		Kind = Field( S, 1 );
		Inv  = None;
		if ( Kind=="P" )
			Inv = GivePickup( P, S );
		else if ( Kind=="W" )
			Inv = GiveWeapon( P, S );
		else
			continue;
		if ( Inv!=None && NumItems<64 )
		{
			Items[NumItems]  = Inv;
			Belts[NumItems] = int( Field(S,3) );
			NumItems++;
		}
	}

	// ---- Belt: exactly the saved slots. ----
	P._ClearBelt( true );
	for ( i=0; i<NumItems; i++ )
		if ( Belts[i]>=0 && Items[i]!=None && !Items[i].bDeleteMe )
			P._AddObjectToBelt( Items[i], Belts[i], true );

	// Weapons were added without switching; make sure the player has something ready.
	if ( P.Weapon==None )
		P.SwitchToBestWeapon();

	if ( AM!=None )
		AM.RefreshAugDisplay();
	Log( "HXFixSavePlayers: restored" @ NameOf(P) @ "with" @ NumItems @ "items", 'HXFixSave' );
	return true;
}

static function RestoreCore( HXPlayerPawn P, string S )
{
	P.Health         = int( Field(S,2) );
	P.HealthHead     = int( Field(S,3) );
	P.HealthTorso    = int( Field(S,4) );
	P.HealthLegLeft  = int( Field(S,5) );
	P.HealthLegRight = int( Field(S,6) );
	P.HealthArmLeft  = int( Field(S,7) );
	P.HealthArmRight = int( Field(S,8) );
	P.Energy         = float( Field(S,9) );
	P.EnergyMax      = float( Field(S,10) );
	P.Credits        = int( Field(S,11) );
	P.SkillPointsAvail = int( Field(S,12) );
	P.SkillPointsTotal = int( Field(S,13) );
	P.ClientCredits  = P.Credits;
	P.UpdateClientCredits( P.Credits );
}

// Takes every installed aug away again, the way a fresh character has none.
static function WipeAugs( HXAugmentationManager AM )
{
	local Augmentation Aug;
	local int Count;

	for ( Aug=AM.FirstAug; Aug!=None && Count<64; Aug=Aug.Next )
	{
		Count++;
		if ( Aug.bHasIt )
		{
			if ( Aug.bIsActive && !Aug.bAlwaysActive )
				Aug.Deactivate();
			Aug.bIsActive = false;
			Aug.GotoState( 'Inactive' );
			Aug.bHasIt = false;
			Aug.bBoosted = false;
			Aug.HotKeyNum = 0;
			if ( AM.AugLocs[Aug.AugmentationLocation].AugCount>0 )
				AM.AugLocs[Aug.AugmentationLocation].AugCount--;
		}
		Aug.CurrentLevel = 0;
	}
}

static function Inventory GiveAmmo( HXPlayerPawn P, string S )
{
	local Class<Object> C;
	local Ammo A;

	C = LoadClassStr( Field(S,2) );
	if ( Class<Ammo>(C)==None )
	{
		Log( "HXFixSavePlayers: unknown ammo" @ Field(S,2), 'HXFixSave' );
		return None;
	}
	A = Ammo( P.FindInventoryType(Class<Ammo>(C)) );
	if ( A==None )
	{
		A = P.Spawn( Class<Ammo>(C), P );
		if ( A==None )
			return None;
		A.GiveTo( P );
	}
	A.AmmoAmount = int( Field(S,4) );
	return A;
}

static function Inventory GivePickup( HXPlayerPawn P, string S )
{
	local Class<Object> C;
	local Inventory Inv;

	C = LoadClassStr( Field(S,2) );
	if ( Class<DeusExPickup>(C)==None )
	{
		Log( "HXFixSavePlayers: unknown item" @ Field(S,2), 'HXFixSave' );
		return None;
	}
	Inv = P.Spawn( Class<Inventory>(C), P );
	if ( Inv==None )
		return None;
	DeusExPickup(Inv).NumCopies = int( Field(S,4) );
	Inv.Charge = int( Field(S,5) );
	Inv.bHeldItem = true;
	Inv.GiveTo( P );
	return Inv;
}

static function Inventory GiveWeapon( HXPlayerPawn P, string S )
{
	local Class<Object> C;
	local HXWeapon W;

	C = LoadClassStr( Field(S,2) );
	if ( Class<HXWeapon>(C)==None )
	{
		Log( "HXFixSavePlayers: unknown weapon" @ Field(S,2), 'HXFixSave' );
		return None;
	}
	W = P.Spawn( Class<HXWeapon>(C), P );
	if ( W==None )
		return None;

	if ( Field(S,4)!="" )
		W.AmmoName = Class<Ammo>( LoadClassStr(Field(S,4)) );
	W.ClipCount        = int( Field(S,5) );
	W.ReloadCount      = int( Field(S,6) );
	W.AccurateRange    = int( Field(S,7) );
	W.BaseAccuracy     = float( Field(S,8) );
	W.ReloadTime       = float( Field(S,9) );
	W.recoilStrength   = float( Field(S,10) );
	W.ModBaseAccuracy  = float( Field(S,11) );
	W.ModReloadCount   = float( Field(S,12) );
	W.ModAccurateRange = float( Field(S,13) );
	W.ModReloadTime    = float( Field(S,14) );
	W.ModRecoilStrength = float( Field(S,15) );
	W.bHasScope        = int( Field(S,16) )!=0;
	W.bHasLaser        = int( Field(S,17) )!=0;
	W.bHasSilencer     = int( Field(S,18) )!=0;

	// The ammo item is already in the inventory, so no PickupAmmoCount gets added.
	W.AmmoType = None;
	if ( W.AmmoName!=None )
		W.AmmoType = Ammo( P.FindInventoryType(W.AmmoName) );
	W.bHeldItem = true;
	W.Instigator = P;
	W.GiveTo( P );
	W.TravelPostAccept();
	return W;
}

static function Clear()
{
	local int i;

	for ( i=0; i<MaxLines; i++ )
		Default.Line[i] = "";
	for ( i=0; i<MaxPlayers; i++ )
		Default.PlayerName[i] = "";
	Default.NumLines   = 0;
	Default.NumPlayers = 0;
	StaticSaveConfig();
}

static function int Count()
{
	return Default.NumPlayers;
}
