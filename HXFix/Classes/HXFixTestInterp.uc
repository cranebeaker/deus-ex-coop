//=============================================================================
// HXFixTestInterp.
//
// A player joining after an interpolation path (the UNATCO island helicopter)
// was fired must get it replayed. Run with two clients: the test starts with
// host + first client, fires the path, then waits for the second client to
// join late. Map: 01_NYC_UNATCOIsland.
//=============================================================================
class HXFixTestInterp extends HXFixTestDevBase;

var HXPlayerPawn H, Late;
var HXInterpolateTrigger Trig;
var HXFixTestDevDriver DL;
var bool bLateAlreadyThere;
var Actor Heli;
var Vector StartLoc;
var float BeforeDist;

function float ClientDist()
{
	local Vector V;

	V.X = DL.GetRes("pathx");
	V.Y = DL.GetRes("pathy");
	V.Z = DL.GetRes("pathz");
	return VSize( V-Heli.Location );
}

function float RunStep( int StepNum )
{
	local HXFixDevicesMutator Dev;

	switch ( StepNum )
	{
		case 0:
			H = Host();
			if ( !Check(H!=None && Remote()!=None, "host and first client present") )
				return -1;
			foreach AllActors( class'HXInterpolateTrigger', Trig )
				if ( Trig.Event=='UN_BlackHeli' )
					break;
			if ( !Check(Trig!=None, "heli trigger found (" $ Trig $ ")") )
				return -1;
			foreach AllActors( class'Actor', Heli, 'UN_BlackHeli' )
				if ( InterpolationPoint(Heli)==None )
					break;
			if ( !Check(Heli!=None, "helicopter found (" $ Heli $ ")") )
				return -1;
			StartLoc = Heli.Location;
			bLateAlreadyThere = Remote(1)!=None;
			Note( "second client already in game: " $ bLateAlreadyThere );
			Trig.Trigger( H, H );
			foreach AllActors( class'HXFixDevicesMutator', Dev )
				break;
			Check( Dev!=None && Dev.NumPaths>=1, "fired path was recorded for late joiners (" $ Dev.NumPaths $ ")" );
			return 1.0;

		case 1:
			// Wait for the late joiner.
			Late = Remote(1);
			if ( Late==None || Late.Health<=0 )
			{
				if ( Tries++<150 )
				{
					Step--;
					return 1.0;
				}
				Check( False, "second client never joined" );
				return -1;
			}
			Tries = 0;
			DL = HXFixTestDevDriver( DriverFor(Late) );
			if ( DL==None )
				DL = Spawn( class'HXFixTestDevDriver', Late );
			return 1.0;

		case 2:
			if ( Wait(DL.bServerReady, 40) )
				return 1.0;
			Check( DL.bServerReady, "late client driver up" );
			Check( !bLateAlreadyThere, "control: the second client joined after the path fired" );
			DL.ClearRes();
			// The resender waits ~8s after the join; probe until the path runs on the late client.
			DL.DevOp( "pathprobe", 'UN_BlackHeli', 0 );
			return 3.0;

		case 3:
			if ( Wait(DL.GetRes("pathfound")!=-99 && DL.GetRes("pathz")!=-99, 20) )
				return 1.0;
			Check( DL.GetRes("pathfound")==1, "late client knows the helicopter" );
			Note( "late client right after join: interpolating=" $ DL.GetRes("pathinterp") $ " physics=" $ DL.GetRes("pathphys") $ " distance to server heli=" $ ClientDist() $ " (moved from start: " $ VSize(Heli.Location-StartLoc) $ ")" );
			BeforeDist = ClientDist();
			// The resender replays after ~8s.
			return 14.0;

		case 4:
			DL.ClearRes();
			DL.DevOp( "pathprobe", 'UN_BlackHeli', 0 );
			return 1.0;

		case 5:
			if ( Wait(DL.GetRes("pathz")!=-99, 20) )
				return 1.0;
			Note( "late client after replay: interpolating=" $ DL.GetRes("pathinterp") $ " distance to server heli=" $ ClientDist() $ " server heli moved " $ VSize(Heli.Location-StartLoc) );
			Check( DL.GetRes("pathinterp")==1, "path runs on the late client (interpolating=" $ DL.GetRes("pathinterp") $ ")" );
			Check( ClientDist()<800, "late client's helicopter is where the server's is (off by " $ ClientDist() $ ", before replay " $ BeforeDist $ ")" );
			return -1;
	}
	return -1;
}

defaultproperties
{
	DriverClass=Class'HXFixTestDevDriver'
	TimeoutSeconds=240.000000
}
