//=============================================================================
// HXFixTestProbeDriver.
//
// Driver with client side probes: the client reports its own view of notes,
// inventory and health to the server (stored in the Probe* vars).
//=============================================================================
class HXFixTestProbeDriver extends HXFixTestDriver;

var int ProbeSeq;       // Server: number of probe reports received.
var int ProbeNotes;     // Server: notes in the client's datavault.
var string ProbeNoteText; // Server: all note texts, '|' separated.
var string ProbeInv;    // Server: client inventory class names, ',' separated.
var int ProbeHealth;
var string ProbeName;
var string ProbeState;  // Client local state name.
var string ProbeMap;

replication
{
	reliable if ( Role==ROLE_Authority )
		ClientProbe, ClientPrepTravel;
	reliable if ( Role<ROLE_Authority )
		ServerProbe;
}

simulated function ClientProbe()
{
	local HXPlayerPawn P;
	local DeusExNote N;
	local Inventory Inv;
	local int Num;
	local string Texts, InvList;

	P = HXPlayerPawn( Owner );
	if ( P==None )
		return;

	for ( N=P.FirstNote; N!=None && Num<64; N=N.Next )
	{
		Texts = Texts $ N.Text $ "|";
		Num++;
	}
	for ( Inv=P.Inventory; Inv!=None; Inv=Inv.Inventory )
		InvList = InvList $ Inv.Class.Name $ ",";

	ServerProbe( Num, Texts, InvList, P.Health, P.PlayerReplicationInfo.PlayerName, string(P.GetStateName()), string(Level.Outer.Name) );
}

simulated function ClientPrepTravel()
{
	local Actor A;
	local int Num;

	// Owned helper actors (PRIs, color themes, ...) keep a pointer to the pawn
	// that gets exported and freed on travel.
	foreach AllActors( class'Actor', A )
		if ( A.Owner!=None && (A.IsA('PlayerReplicationInfo') || A.IsA('ColorTheme')) )
		{
			A.SetOwner( None );
			Num++;
		}
	Log( "HXFixTest: client cleared owner of" @ Num @ "actors", 'HXFixTest' );
}

function ServerProbe( int NumNotes, string Texts, string InvList, int Health, string PlayerName, string StateName, string MapName )
{
	ProbeNotes    = NumNotes;
	ProbeNoteText = Texts;
	ProbeInv      = InvList;
	ProbeHealth   = Health;
	ProbeName     = PlayerName;
	ProbeState    = StateName;
	ProbeMap      = MapName;
	ProbeSeq++;
	Log( "HXFixTest: client probe from" @ Owner @ "map=" $ MapName @ "notes=" $ NumNotes @ "health=" $ Health @ "name=" $ PlayerName @ "state=" $ StateName @ "inv=" $ InvList @ "texts=" $ Texts, 'HXFixTest' );
}
