//=============================================================================
// HXFixTestSoak.
//
// Test helper mutator: ?Mutator=HXFix.HXFixTestSoak
// Once at least MinPlayers are in, travels to the next map in Maps every
// Interval seconds (with items), to stress travel export/prune on a
// listen server. Logs each step under the 'HXFixSoak' tag.
//=============================================================================
class HXFixTestSoak extends HXMutator;

var float Interval;
var int MinPlayers;
var string Maps[8];
var float Elapsed;

function PostBeginPlay()
{
	Super.PostBeginPlay();
	SetTimer( 1.0, True );
	Log( "HXFixSoak: started on" @ Level.Outer.Name, 'HXFixSoak' );
}

function Timer()
{
	local Pawn P;
	local int i, Num, Next;
	local string Here;

	for ( P=Level.PawnList; P!=None; P=P.NextPawn )
		if ( HXPlayerPawn(P)!=None && PlayerPawn(P).Player!=None )
			Num++;

	if ( Num<MinPlayers )
	{
		Elapsed = 0;
		return;
	}

	Elapsed += 1.0;
	if ( Elapsed<Interval )
		return;

	Here = string(Level.Outer.Name);
	for ( i=0; i<ArrayCount(Maps); i++ )
		if ( Maps[i]~=Here )
			Next = i+1;
	if ( Next>=ArrayCount(Maps) || Maps[Next]=="" )
		Next = 0;

	for ( P=Level.PawnList; P!=None; P=P.NextPawn )
		if ( HXPlayerPawn(P)!=None )
			Log( "HXFixSoak: player" @ PlayerPawn(P).PlayerReplicationInfo.PlayerName @ "health" @ P.Health @ "state" @ P.GetStateName(), 'HXFixSoak' );

	Log( "HXFixSoak: travel" @ Here @ "->" @ Maps[Next] @ "with" @ Num @ "players", 'HXFixSoak' );
	SetTimer( 0, False );
	Level.ServerTravel( Maps[Next]$"?Game=HXFix.HXFixGameInfo?Mutator=HXFix.HXFixTestSoak", True );
}

defaultproperties
{
	Interval=20.000000
	MinPlayers=2
	Maps(0)="01_NYC_UNATCOIsland"
	Maps(1)="01_NYC_UNATCOHQ"
	Maps(2)="02_NYC_BatteryPark"
	Maps(3)="02_NYC_Street"
	Maps(4)="02_NYC_Bar"
	Maps(5)="03_NYC_UNATCOIsland"
	Maps(6)="03_NYC_UNATCOHQ"
}
