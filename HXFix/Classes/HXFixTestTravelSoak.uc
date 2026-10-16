//=============================================================================
// HXFixTestTravelSoak.
//
// 2 clients + host travel through the maps of Maps[]. Every player gets a
// distinct item on the first map; on every arrival all three must be alive,
// have their item and the starting gear. A forced conversation is started
// right before a few of the travels (ConvStages), so travel with a running
// conversation is covered. Use -Clients 2 and a long -Timeout.
//=============================================================================
class HXFixTestTravelSoak extends HXFixTestTravelBase;

var string Maps[16];
var int NumMaps;
var string ConvStages;   // e.g. "|2|5|8|"
var float WaitOnMap;

function PostBeginPlay()
{
	MinPlayers = 3;
	TimeoutSeconds = 120.0;
	Super.PostBeginPlay();
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

function GiveItem( Pawn P, class<Inventory> C )
{
	local Inventory I;

	I = Spawn( C,,, P.Location );
	if ( I!=None )
		I.GiveTo( P );
}

function bool StartConversation()
{
	local ScriptedPawn SP;
	local HXPlayerPawn H;

	H = Host();
	foreach AllActors( class'ScriptedPawn', SP )
	{
		if ( SP.conListItems==None || SP.bHidden || SP.Health<=0 || VSize(SP.Location-H.Location)>2500 )
			continue;
		if ( Game.StartConversation(H, SP, IM_Frob, None, False, False) )
		{
			Note( "started conversation with" @ SP @ "con" @ Game.ConPlay.Con );
			return True;
		}
	}
	return False;
}

function float RunStep( int StepNum )
{
	local HXPlayerPawn T1, T2, H;
	local int S, Convs;
	local bool bAll;

	S = Stage();
	T1 = FindByName( "Tester1" );
	T2 = FindByName( "Tester2" );
	H  = Host();

	switch ( StepNum )
	{
		case 0:
			Note( "map" @ S @ Level.Outer.Name );
			if ( S==0 )
			{
				if ( !Check(T1!=None && T2!=None && H!=None, "Tester1, Tester2 and the host are in") )
					return -1;
				GiveItem( T1, class'HXLockpick' );
				GiveItem( T2, class'HXMultitool' );
				GiveItem( H, class'HXWeaponCombatKnife' );
			}
			else
			{
				bAll = Check( T1!=None && T2!=None && H!=None, "map" @ S @ "all 3 players present" );
				if ( !bAll )
					return -1;
				Check( T1.Health>0 && T2.Health>0 && H.Health>0, "map" @ S @ "all alive" );
				Check( Owns(T1,'HXLockpick') && !Owns(T1,'HXMultitool') && Owns(T1,'HXNanoKeyRing'), "map" @ S @ "Tester1 inventory" );
				Check( Owns(T2,'HXMultitool') && !Owns(T2,'HXLockpick') && Owns(T2,'HXNanoKeyRing'), "map" @ S @ "Tester2 inventory" );
				Check( Owns(H,'HXWeaponCombatKnife') && !Owns(H,'HXLockpick') && !Owns(H,'HXMultitool'), "map" @ S @ "host inventory" );
			}
			return WaitOnMap;

		case 1:
			if ( InStr(ConvStages,"|"$S$"|")>=0 )
			{
				if ( StartConversation() )
					SetCounter( 'HXFixT_Convs', GetCounter('HXFixT_Convs')+1 );
				else
					Note( "no conversation available on this map" );
			}
			return 4.0;

		case 2:
			if ( S+1>=NumMaps )
			{
				Convs = GetCounter( 'HXFixT_Convs' );
				Check( Convs>0, "travelled with a running conversation" @ Convs @ "times" );
				Note( "ConPlay at the end:" @ Game.ConPlay );
				return -1;
			}
			return TravelTo( Maps[S+1] );
	}
	return -1;
}

defaultproperties
{
	NumMaps=13
	WaitOnMap=7.0
	ConvStages="|1|2|3|6|"
	Maps(0)="01_NYC_UNATCOIsland"
	Maps(1)="01_NYC_UNATCOHQ"
	Maps(2)="02_NYC_BatteryPark"
	Maps(3)="02_NYC_Street"
	Maps(4)="02_NYC_Bar"
	Maps(5)="03_NYC_UNATCOIsland"
	Maps(6)="03_NYC_UNATCOHQ"
	Maps(7)="03_NYC_BrooklynBridgeStation"
	Maps(8)="04_NYC_UNATCOIsland"
	Maps(9)="04_NYC_Street"
	Maps(10)="05_NYC_UNATCOIsland"
	Maps(11)="05_NYC_UNATCOHQ"
	Maps(12)="02_NYC_BatteryPark"
}
