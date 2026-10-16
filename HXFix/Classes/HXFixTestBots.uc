//=============================================================================
// HXFixTestBots.
//
// Med bot and repair bot must not stay "in use" after a session ends early:
// closed while the arm is still rising, closed normally, user walking away.
// After each the other player must be able to use the bot.
// Map: 01_NYC_UNATCOHQ.
//=============================================================================
class HXFixTestBots extends HXFixTestDevBase;

var HXPlayerPawn H, R;
var HXScriptedPawn Bot;

function float RunStep( int StepNum )
{
	local int Idx, Sub;
	local string N;
	local HXMedicalBot MB;
	local HXRepairBot RB;

	Idx = StepNum/20;
	Sub = StepNum%20;

	if ( Idx>1 )
		return -1;
	if ( Idx==0 )
		N = "medbot";
	else
		N = "repairbot";

	switch ( Sub )
	{
		case 0:
			H = Host();
			R = Remote();
			if ( !Check(H!=None && R!=None, N $ ": host and remote present") )
				return -1;
			Bot = None;
			if ( Idx==0 )
			{
				foreach AllActors( class'HXMedicalBot', MB )
					break;
				Bot = MB;
			}
			else
			{
				foreach AllActors( class'HXRepairBot', RB )
					break;
				Bot = RB;
			}
			if ( !Check(Bot!=None, N $ ": bot found (" $ Bot $ ")") )
				return -1;
			Check( TeleNear(H,Bot.Location) && TeleNear(R,Bot.Location,4), N $ ": players moved next to the bot" );
			return 2.0;

		case 1:
			// Interrupt while the arm is rising.
			Bot.Frob( R, None );
			Bot.CloseOut();
			Note( N $ ": closed right after frob, user=" $ Bot.curFrobber $ " animating=" $ Bot.bAnimating $ " on=" $ Bot.bOn $ " state=" $ Bot.GetStateName() );
			return 1.0;

		case 2:
			if ( Wait(Bot.curFrobber==None && !Bot.bAnimating, 25) )
				return 1.0;
			Check( Bot.curFrobber==None, N $ ": released after close during raise (user=" $ Bot.curFrobber $ " state=" $ Bot.GetStateName() $ " on=" $ Bot.bOn $ ")" );
			Check( !Bot.bAnimating, N $ ": not stuck animating" );
			return 2.0;

		case 3:
			Bot.Frob( H, None );
			return 1.0;

		case 4:
			if ( Wait(Bot.curFrobber==H && Bot.bOn, 25) )
				return 1.0;
			Check( Bot.curFrobber==H && Bot.bOn, N $ ": other player can use it afterwards (user=" $ Bot.curFrobber $ " on=" $ Bot.bOn $ ")" );
			// Normal close.
			Bot.CloseOut();
			return 1.0;

		case 5:
			if ( Wait(Bot.curFrobber==None && !Bot.bOn && !Bot.bAnimating, 25) )
				return 1.0;
			Check( Bot.curFrobber==None && !Bot.bOn, N $ ": released after normal close (user=" $ Bot.curFrobber $ " on=" $ Bot.bOn $ ")" );
			Bot.Frob( R, None );
			return 1.0;

		case 6:
			if ( Wait(Bot.curFrobber==R && Bot.bOn, 25) )
				return 1.0;
			Check( Bot.curFrobber==R && Bot.bOn, N $ ": remote client can use it (user=" $ Bot.curFrobber $ ")" );
			// Walk away.
			Check( TeleFar(R,Bot.Location,1700), N $ ": remote moved out of range (dist " $ VSize(R.Location-Bot.Location) $ ")" );
			return 1.0;

		case 7:
			if ( Wait(Bot.curFrobber==None && !Bot.bOn && !Bot.bAnimating, 25) )
				return 1.0;
			Check( Bot.curFrobber==None && !Bot.bOn, N $ ": released when the user walks away (user=" $ Bot.curFrobber $ " on=" $ Bot.bOn $ ")" );
			TeleNear( R, Bot.Location, 4 );
			Bot.Frob( H, None );
			return 1.0;

		case 8:
			if ( Wait(Bot.curFrobber==H && Bot.bOn, 25) )
				return 1.0;
			Check( Bot.curFrobber==H, N $ ": usable again after walk away" );
			Bot.CloseOut();
			Step = (Idx+1)*20;
			return 3.0;
	}
	return -1;
}

defaultproperties
{
	TimeoutSeconds=180.000000
}
