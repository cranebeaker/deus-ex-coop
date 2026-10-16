//=============================================================================
// HXFixTestNotes.
//
// Stage 0 (map A): a note exists before the client joins (late join), another
//   is added live; a fresh campaign must not show notes of earlier runs.
// Stage 1 (map B): both notes arrived on the client, add a third.
// Stage 2 (map C): all three there.
//=============================================================================
class HXFixTestNotes extends HXFixTestTravelBase;

var HXFixTestProbeDriver D;
var int Seq;

function PostBeginPlay()
{
	Super.PostBeginPlay();
	if ( Stage()==0 )
		Game.AddNote( "late note A", False, False, 'HXFixTNA' );
}

function int HostNotes()
{
	local DeusExNote N;
	local int Num;

	for ( N=Game.FirstNote; N!=None; N=N.Next )
		Num++;
	return Num;
}

function bool Has( string Needle )
{
	return InStr( D.ProbeNoteText, Needle )>=0;
}

function float RunStep( int StepNum )
{
	switch ( StepNum )
	{
		case 0:
			Check( Remote()!=None, "remote client present" );
			Check( HostNotes()==ExpectedBefore(), "server note count" @ HostNotes() @ "expected" @ ExpectedBefore() );
			D = Probe( Remote() );
			Seq = D.ProbeSeq;
			return 2.0;

		case 1:
			Check( D.ProbeSeq>Seq, "client probe answered" );
			Check( D.ProbeNotes==ExpectedBefore(), "client note count" @ D.ProbeNotes @ "expected" @ ExpectedBefore() @ "map" @ D.ProbeMap );
			if ( Stage()>=1 )
				Check( Has("late note A") && Has("note B"), "notes from earlier maps survived travel" );
			if ( Stage()>=2 )
				Check( Has("note C"), "note C survived travel" );
			if ( Stage()==0 )
				Check( Has("late note A"), "late joiner got existing note" );
			switch ( Stage() )
			{
				case 0: Game.AddNote( "note B", False, False, 'HXFixTNB' ); break;
				case 1: Game.AddNote( "note C", True, False, 'HXFixTNC' ); break;
			}
			if ( Stage()>=2 )
				return -1;
			return 2.0;

		case 2:
			Seq = D.ProbeSeq;
			D.ClientProbe();
			return 2.0;

		case 3:
			Check( D.ProbeSeq>Seq && D.ProbeNotes==ExpectedBefore()+1, "live note reached client:" @ D.ProbeNotes );
			if ( Stage()==0 )
				return TravelTo( "01_NYC_UNATCOHQ" );
			return TravelTo( "02_NYC_BatteryPark" );
	}
	return -1;
}

// Notes expected when a stage starts.
function int ExpectedBefore()
{
	switch ( Stage() )
	{
		case 0: return 1;
		case 1: return 2;
	}
	return 3;
}
