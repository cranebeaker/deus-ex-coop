//=============================================================================
// HXFixTestDeadDup.
//
// Two clients ask for the same name, every player gets a distinct item, one
// client is dead when the server travels. After travel: names unique and
// unchanged, nobody swapped inventory, the dead player is alive with gear.
// Needs -Clients 2.
//=============================================================================
class HXFixTestDeadDup extends HXFixTestTravelBase;

var HXPlayerPawn A, B;
var string NameA, NameB, NameH;
var bool bKill;

function PostBeginPlay()
{
	MinPlayers = 3;
	Super.PostBeginPlay();
}

function Inventory GiveItem( Pawn P, class<Inventory> C )
{
	local Inventory I;

	I = Spawn( C,,, P.Location );
	if ( I==None || !Check(I!=None, "spawned" @ C) )
		return None;
	I.GiveTo( P );
	return I;
}

function bool Owns( Pawn P, name ClassName )
{
	local Inventory I;

	for ( I=P.Inventory; I!=None; I=I.Inventory )
		if ( I.Class.Name==ClassName )
			return True;
	return False;
}

function HXPlayerPawn FindByName( string S )
{
	local Pawn P;

	for ( P=Level.PawnList; P!=None; P=P.NextPawn )
		if ( HXPlayerPawn(P)!=None && PlayerPawn(P).Player!=None && P.PlayerReplicationInfo!=None && P.PlayerReplicationInfo.PlayerName==S )
			return HXPlayerPawn(P);
	return None;
}

function float RunStep( int StepNum )
{
	if ( Stage()==0 )
		return Stage0( StepNum );
	return Stage1( StepNum );
}

function float Stage0( int StepNum )
{
	switch ( StepNum )
	{
		case 0:
			A = Remote( 0 );
			B = Remote( 1 );
			if ( !Check(A!=None && B!=None, "two remote clients") )
				return -1;
			ClientCmd( A, "Name Dup" );
			return 1.0;

		case 1:
			ClientCmd( B, "Name Dup" );
			return 6.0;

		case 2:
			NameA = A.PlayerReplicationInfo.PlayerName;
			NameB = B.PlayerReplicationInfo.PlayerName;
			NameH = Host().PlayerReplicationInfo.PlayerName;
			Note( "names:" @ NameA @ NameB @ NameH );
			Check( NameA!=NameB, "duplicate name made unique" );
			Check( NameA=="Dup" && NameB!="Dup" && Left(NameB,3)=="Dup", "first keeps Dup, second gets suffix:" @ NameB );
			GiveItem( A, class'HXLockpick' );
			GiveItem( B, class'HXMultitool' );
			GiveItem( Host(), class'HXWeaponCombatKnife' );
			Check( Owns(A,'HXLockpick') && Owns(B,'HXMultitool') && Owns(Host(),'HXWeaponCombatKnife'), "items given" );
			return 2.0;

		case 3:
			if ( bKill )
				B.TakeDamage( 10000, None, B.Location, vect(0,0,0), 'Shot' );
			return 3.0;

		case 4:
			Check( !bKill || B.Health<=0, "client B dead before travel (health" @ B.Health $ ")" );
			Note( "B state" @ B.GetStateName() );
			return TravelTo( "01_NYC_UNATCOHQ" );
	}
	return -1;
}

function float Stage1( int StepNum )
{
	local HXFixTestProbeDriver D;
	local HXPlayerPawn PA, PB, PH;

	switch ( StepNum )
	{
		case 0:
			PA = FindByName( "Dup" );
			PB = FindByName( "Dup_2" );
			PH = Host();
			Note( "names after travel:" @ PA @ PB @ PH.PlayerReplicationInfo.PlayerName );
			if ( !Check(PA!=None && PB!=None, "both Dup and Dup_2 present after travel") )
				return -1;
			Check( PA!=PB, "distinct pawns" );
			Check( PA.Health>0, "A alive: " $ PA.Health );
			Check( PB.Health>0, "B (dead at travel?) alive: " $ PB.Health );
			Check( PH.Health>0, "host alive: " $ PH.Health );
			Check( Owns(PA,'HXLockpick') && !Owns(PA,'HXMultitool'), "A has own item only" );
			Check( !Owns(PB,'HXLockpick') && !Owns(PB,'HXWeaponCombatKnife'), "B has no foreign items (own item lost with corpse if dead:" @ bKill $ ")" );
			Check( Owns(PH,'HXWeaponCombatKnife') && !Owns(PH,'HXLockpick') && !Owns(PH,'HXMultitool'), "host has own item only" );
			Check( Owns(PB,'HXWeaponPistol') || Owns(PB,'HXMedKit'), "B (dead) has starting gear" );
			Probe( PA );
			Probe( PB );
			return 3.0;

		case 1:
			PA = FindByName( "Dup" );
			PB = FindByName( "Dup_2" );
			D = HXFixTestProbeDriver( DriverFor(PA) );
			Check( D.ProbeSeq>0 && InStr(D.ProbeInv,"HXLockpick")>=0 && InStr(D.ProbeInv,"HXMultitool")<0, "client A sees own inventory:" @ D.ProbeInv );
			Check( D.ProbeName=="Dup", "client A name" @ D.ProbeName );
			D = HXFixTestProbeDriver( DriverFor(PB) );
			Check( D.ProbeSeq>0 && (bKill || InStr(D.ProbeInv,"HXMultitool")>=0) && InStr(D.ProbeInv,"HXLockpick")<0 && InStr(D.ProbeInv,"HXWeaponPistol")>=0, "client B sees sane inventory:" @ D.ProbeInv );
			Check( D.ProbeHealth>0, "client B sees health" @ D.ProbeHealth );
			Check( D.ProbeName=="Dup_2", "client B name" @ D.ProbeName );
			return -1;
	}
	return -1;
}

defaultproperties
{
	bKill=True
}
