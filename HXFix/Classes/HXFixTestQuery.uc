//=============================================================================
// HXFixTestQuery.
//
// Driven together with an outside script that hammers the UDP query port
// with \players\ \info\ \status\ and starts a second client at about 45s.
// Meanwhile this test makes the first client leave and waits for the new one.
// The host must stay alive and NumPlayers must match the real player count.
// Also the listen spectator count: a Spectator that logs in is counted by
// HXGameInfo.Login but was never uncounted by Logout on listen servers.
// (HX can't really host spectators, so the Login/Logout pair is simulated.)
//=============================================================================
class HXFixTestQuery extends HXFixTestBase;

var int Phase, Waited;

function PostBeginPlay()
{
	TimeoutSeconds = 170.0;
	Super.PostBeginPlay();
}

function int PlayerPawns()
{
	local Pawn P;
	local int Num;

	for ( P=Level.PawnList; P!=None; P=P.NextPawn )
		if ( HXPlayerPawn(P)!=None && !P.bDeleteMe && PlayerPawn(P).Player!=None )
			Num++;
	return Num;
}

function SimulateSpectator()
{
	local Spectator Spec;
	local int Before;

	Before = Game.NumSpectators;
	Spec = Spawn( class'Spectator' );
	if ( !Check(Spec!=None, "spectator pawn spawned") )
		return;
	Game.NumSpectators++; // What HXGameInfo.Login does.
	Game.Logout( Spec );
	Check( Game.NumSpectators==Before, "listen server spectator logout uncounts it (" $ Before $ " -> " $ Game.NumSpectators $ ")" );
	if ( Spec!=None )
		Spec.Destroy();
}

function float RunStep( int StepNum )
{
	Waited++;
	switch ( Phase )
	{
		case 0:
			SimulateSpectator();
			Check( Game.NumPlayers==PlayerPawns(), "NumPlayers" @ Game.NumPlayers @ "matches player pawns" @ PlayerPawns() );
			ClientCmd( Remote(), "disconnect" );
			Phase = 1;
			Waited = 0;
			return 1.0;

		case 1:
			if ( Remote()==None )
			{
				Note( "client left after" @ Waited @ "s, NumPlayers" @ Game.NumPlayers @ "pawns" @ PlayerPawns() );
				Phase = 2;
				Waited = 0;
			}
			else if ( Waited>30 )
			{
				Check( False, "client did not leave" );
				return -1;
			}
			return 1.0;

		case 2:
			if ( Remote()!=None )
			{
				Note( "new client joined after" @ Waited @ "s" );
				Phase = 3;
				Waited = 0;
			}
			else if ( Waited>100 )
			{
				Check( False, "no new client joined" );
				return -1;
			}
			return 1.0;

		case 3:
			if ( Waited<8 )
				return 1.0;
			Check( Game.NumPlayers==PlayerPawns(), "NumPlayers" @ Game.NumPlayers @ "matches player pawns" @ PlayerPawns() $ " after leave and join" );
			Check( True, "server still running after the query storm" );
			return -1;
	}
	return -1;
}
