//=============================================================================
// HXFixTestDevDriver.
//
// Client side probes/actions for the device tests: acts like the UI would
// (computer window, security console, keypad window) and reports back.
//=============================================================================
class HXFixTestDevDriver extends HXFixTestDriver;

var string ResKey[24];
var int    ResVal[24];
var int    NumRes;

replication
{
	reliable if ( Role==ROLE_Authority )
		DevOp;
	reliable if ( Role<ROLE_Authority )
		ServerRes;
}

function ServerRes( string Key, int Val )
{
	local int i;

	for ( i=0; i<NumRes; i++ )
		if ( ResKey[i]==Key )
		{
			ResVal[i] = Val;
			return;
		}
	if ( NumRes<ArrayCount(ResKey) )
	{
		ResKey[NumRes] = Key;
		ResVal[NumRes] = Val;
		NumRes++;
	}
	Log( "HXFixTest: client result" @ Key $ "=" $ Val, 'HXFixTest' );
}

// Server side: -99 when the client has not reported Key.
function int GetRes( string Key )
{
	local int i;

	for ( i=0; i<NumRes; i++ )
		if ( ResKey[i]==Key )
			return ResVal[i];
	return -99;
}

function ClearRes()
{
	NumRes = 0;
}

simulated function int B( bool bVal )
{
	if ( bVal )
		return 1;
	return 0;
}

// Runs on the owning client.
simulated function DevOp( string Op, name N, int I )
{
	local HXPlayerPawn P;
	local HXSecurityCamera Cam;
	local HXComputers Comp;
	local HXKeypad Pad;
	local Actor Act;
	local int Num;

	P = HXPlayerPawn(Owner);
	if ( P==None )
		return;
	Log( "HXFixTest: client op" @ Op @ N @ I, 'HXFixTest' );

	switch ( Op )
	{
		case "camprobe":
			foreach AllActors( class'HXSecurityCamera', Cam, N )
			{
				Num++;
				ServerRes( "camfound", 1 );
				ServerRes( "camactive", B(Cam.bActive) );
			}
			if ( Num==0 )
				ServerRes( "camfound", 0 );
			break;

		case "camtoggle":
			foreach AllActors( class'HXSecurityCamera', Cam, N )
			{
				Comp = P.HXActiveComputer;
				P.HXToggleCameraState( Cam, Comp );
				ServerRes( "toggled", 1 );
				break;
			}
			break;

		case "window":
			Comp = P.HXActiveComputer;
			ServerRes( "window", B(Comp!=None && Comp.termwindow!=None) );
			break;

		case "hack":
			Comp = P.HXActiveComputer;
			if ( Comp!=None && Comp.termwindow!=None )
			{
				Comp.termwindow.HackDetected();
				ServerRes( "hacked", 1 );
			}
			else
				ServerRes( "hacked", 0 );
			break;

		case "close":
			Comp = P.HXActiveComputer;
			if ( Comp!=None && Comp.termwindow!=None )
				Comp.termwindow.CloseScreen( "EXIT" );
			break;

		case "pathprobe":
			// Reports whether the actor tagged N runs an interpolation path on this client.
			foreach AllActors( class'Actor', Act, N )
				if ( InterpolationPoint(Act)==None )
				{
					ServerRes( "pathfound", 1 );
					ServerRes( "pathinterp", B(Act.bInterpolating) );
					ServerRes( "pathphys", Act.Physics );
					ServerRes( "pathx", int(Act.Location.X) );
					ServerRes( "pathy", int(Act.Location.Y) );
					ServerRes( "pathz", int(Act.Location.Z) );
					break;
				}
			if ( Act==None )
				ServerRes( "pathfound", 0 );
			break;

		case "padcheck":
			foreach AllActors( class'HXKeypad', Pad, N )
			{
				ServerRes( "padwindow", B(Pad.keypadwindow!=None) );
				break;
			}
			break;

		case "padopen":
			// I=1: hacked.
			foreach AllActors( class'HXKeypad', Pad, N )
			{
				Pad.ActivateKeypadWindow( P, I!=0 );
				ServerRes( "padwindow", B(Pad.keypadwindow!=None) );
				break;
			}
			break;

		case "padcode":
			// Enter the code the way the keypad window does on success.
			foreach AllActors( class'HXKeypad', Pad, N )
			{
				P.HXKeypadToggleLocks( Pad );
				P.HXKeypadRunEvents( Pad, True );
				P.HXKeypadRunUntriggers( Pad );
				ServerRes( "padcode", 1 );
				break;
			}
			break;
	}
}

defaultproperties
{
}
