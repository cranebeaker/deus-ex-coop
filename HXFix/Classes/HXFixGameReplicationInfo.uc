//=============================================================================
// HXFixGameReplicationInfo.
//
// HXGameReplicationInfo.PostNetBeginPlay had a stray ';' after the
// StartupMessage check, so it always left the loop and the startup message
// was never shown on clients. Also retry a few seconds, as the player's HUD
// may not exist yet when the GRI arrives.
//=============================================================================
class HXFixGameReplicationInfo extends HXGameReplicationInfo;

var bool bStartupShown;
var int StartupTries;

simulated function PostNetBeginPlay()
{
	// Skip HXGameReplicationInfo's broken version.
	Super(GameReplicationInfo).PostNetBeginPlay();

	TryShowStartupMessage();
}

simulated function Timer()
{
	Super.Timer();

	if ( !bStartupShown && StartupTries<150 )
		TryShowStartupMessage();
}

simulated function TryShowStartupMessage()
{
	local HXRootWindow RootWindow;
	local HXPlayerPawn Player;
	local DeusExLevelInfo DeusExLevelInfo;
	local int i;

	if ( Level.NetMode!=NM_Client || !bShowStartupMessage || bStartupShown )
		return;

	StartupTries++;

	Player = HXPlayerPawn(GetPlayerPawn());
	if ( Player==None )
		return;
	RootWindow = HXRootWindow(Player.RootWindow);
	if ( RootWindow==None || RootWindow.HUD==None || RootWindow.HUD.StartDisplay==None )
		return;

	bStartupShown = True;

	foreach AllActors( Class'DeusExLevelInfo', DeusExLevelInfo )
	{
		if ( DeusExLevelInfo.StartupMessage[0]=="" )
			break;

		RootWindow.HUD.StartDisplay.Message = "";
		for ( i=0; i<ArrayCount(DeusExLevelInfo.StartupMessage); i++ )
			RootWindow.HUD.StartDisplay.AddMessage( DeusExLevelInfo.StartupMessage[i] );
		RootWindow.HUD.StartDisplay.StartMessage();
		break;
	}
}
