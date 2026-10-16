//=============================================================================
// HXFixTestMission.
//
// Mission script fixes, by map (start the test on the map):
//   02_NYC_Street                  M02 TenderloinSlaughter (kills); the
//                                  HXFixTestMission02Knock subclass knocks out
//   03_NYC_BrooklynBridgeStation   M03 JugHeadGangDefeated without Elrey dead
//   05_NYC_UNATCOIsland / 15_Area51_Entrance  IsGoalCompleted honours its argument
//   09_NYC_Ship                    M09 explosion odds
//   10_Paris_Chateau               M10 commandos after everettsignal
//=============================================================================
class HXFixTestMission extends HXFixTestBase;

var bool bKnock;
var HXMissionScript Scr;
var string MapName;

function PostBeginPlay()
{
	// Wait for the client too: finishing and exiting while a client is still
	// joining hangs the exiting host or the loading client (race, flaky).
	Super.PostBeginPlay();
	MapName = Caps( string(Level.Outer.Name) );
}

function bool Flag( Name N )
{
	return Game.Steve.FlagBase.GetBool( N );
}

function float RunStep( int StepNum )
{
	Scr = Game.MissionScript;
	if ( StepNum==0 )
		Note( "map" @ MapName @ "script" @ Scr.Class );

	switch ( MapName )
	{
		case "02_NYC_STREET": return M02( StepNum );
		case "03_NYC_BROOKLYNBRIDGESTATION": return M03( StepNum );
		case "05_NYC_UNATCOISLAND":
		case "15_AREA51_ENTRANCE": return Goals( StepNum );
		case "09_NYC_SHIP": return M09( StepNum );
		case "10_PARIS_CHATEAU": return M10( StepNum );
	}
	Check( False, "no test for map" @ MapName );
	return -1;
}

// ---------------------------------------------------------------------
function float M02( int StepNum )
{
	local HXScriptedPawn T;
	local HXCarcass C;
	local int Num;

	switch ( StepNum )
	{
		case 0:
			Check( Scr.IsA('HXFixMission02'), "HXFixMission02 loaded" );
			foreach AllActors( class'HXScriptedPawn', T, 'StreetTerrorist' )
				Num++;
			Check( Num>=3, "street terrorists present:" @ Num );
			Check( !Flag('StreetOpened') && !Flag('TenderloinSlaughter'), "flags clear at start" );
			foreach AllActors( class'HXScriptedPawn', T, 'StreetTerrorist' )
			{
				if ( bKnock )
					T.TakeDamage( 10000, Host(), T.Location, vect(0,0,0), 'KnockedOut' );
				else
					T.TakeDamage( 10000, Host(), T.Location, vect(0,0,0), 'Shot' );
			}
			return 6.0;

		case 1:
			Num = 0;
			foreach AllActors( class'HXScriptedPawn', T, 'StreetTerrorist' )
				Num++;
			Note( "terrorists left" @ Num );
			foreach AllActors( class'HXCarcass', C, 'StreetTerrorist' )
				Note( "carcass" @ C @ "name" @ C.ItemName @ "killer" @ C.KillerBindName );
			Check( Flag('StreetOpened'), "StreetOpened set once the street is clear" );
			if ( bKnock )
				Check( !Flag('TenderloinSlaughter'), "knockouts are not a slaughter" );
			else
				Check( Flag('TenderloinSlaughter'), "kills are a slaughter" );
			return -1;
	}
	return -1;
}

// ---------------------------------------------------------------------
function float M03( int StepNum )
{
	local Actor A;
	local int Num;

	switch ( StepNum )
	{
		case 0:
			Check( Scr.IsA('HXFixMission03'), "HXFixMission03 loaded" );
			Check( !Flag('JugHeadGangDefeated'), "gang alive at start" );
			foreach AllActors( class'Actor', A, 'ThugMale2' )
				if ( ScriptedPawn(A)!=None )
				{
					Num++;
					A.Destroy();
				}
			Note( "removed" @ Num @ "ThugMale2 gang members" );
			Check( Num>0, "gang members found" );
			return 5.0;

		case 1:
			Check( Flag('JugHeadGangDefeated'), "JugHeadGangDefeated set (boss may live)" );
			return -1;
	}
	return -1;
}

// ---------------------------------------------------------------------
function float Goals( int StepNum )
{
	local bool bA, bB;

	Game.AddGoal( 'HXFixTGoalA', True, "goal a" );
	Game.AddGoal( 'HXFixTGoalB', True, "goal b" );
	Game.GoalCompleted( 'HXFixTGoalA' );
	bA = Scr.IsGoalCompleted( 'HXFixTGoalA' );
	bB = Scr.IsGoalCompleted( 'HXFixTGoalB' );
	Check( Scr.IsA('HXFixMission05') || Scr.IsA('HXFixMission15'), "HXFix goal script loaded:" @ Scr.Class );
	Check( bA, "IsGoalCompleted(done goal) true" );
	Check( !bB, "IsGoalCompleted(open goal) false" );
	return -1;
}

// ---------------------------------------------------------------------
function float M09( int StepNum )
{
	local HXFixMission09 S;
	local int i, Calls, Passed;

	S = HXFixMission09( Scr );
	if ( !Check(S!=None, "HXFixMission09 loaded") )
		return -1;
	Calls = S.NumCalls;
	Passed = S.NumPassed;
	for ( i=0; i<2000; i++ )
		S.ShipExplosionEffects( False );
	Note( "below deck: passed" @ (S.NumPassed-Passed) @ "of" @ (S.NumCalls-Calls) );
	Check( S.NumPassed-Passed>120 && S.NumPassed-Passed<290, "below deck pre-gate rate ~11%" );
	Calls = S.NumCalls;
	Passed = S.NumPassed;
	for ( i=0; i<2000; i++ )
		S.ShipExplosionEffects( True );
	Note( "deck: passed" @ (S.NumPassed-Passed) @ "of" @ (S.NumCalls-Calls) );
	Check( S.NumPassed-Passed>900 && S.NumPassed-Passed<1100, "deck pre-gate rate 50% (x0.66 inside = stock 33%)" );
	return -1;
}

// ---------------------------------------------------------------------
function int VisibleCommandos()
{
	local HXScriptedPawn P;
	local int Num;

	foreach AllActors( class'HXScriptedPawn', P )
		if ( InStr(string(P.Class.Name),"MJ12Commando")>=0 && !P.bHidden )
			Num++;
	return Num;
}

function float M10( int StepNum )
{
	local HXScriptedPawn P;
	local int Num;

	switch ( StepNum )
	{
		case 0:
			Check( Scr.IsA('HXFixMission10'), "HXFixMission10 loaded" );
			foreach AllActors( class'HXScriptedPawn', P )
				if ( InStr(string(P.Class.Name),"MJ12Commando")>=0 )
					Num++;
			Check( Num>0, "commandos exist:" @ Num );
			Check( VisibleCommandos()==0 && !Flag('MS_CommandosUnhidden'), "commandos hidden before the signal (" $ VisibleCommandos() $ ")" );
			return 3.0;

		case 1:
			Check( VisibleCommandos()==0, "still hidden without everettsignal" );
			Game.Steve.FlagBase.SetBool( 'everettsignal', True, True, 0 );
			return 4.0;

		case 2:
			Check( VisibleCommandos()>0, "commandos unhidden after everettsignal (" $ VisibleCommandos() $ ")" );
			Check( Flag('MS_CommandosUnhidden'), "MS_CommandosUnhidden stays set" );
			return -1;
	}
	return -1;
}
