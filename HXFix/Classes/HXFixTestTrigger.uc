//=============================================================================
// HXFixTestTrigger.
//
// Two players standing in a player proximity trigger count as one: it fires
// once and untriggers only when the last one left. Map: 01_NYC_UNATCOHQ.
//=============================================================================
class HXFixTestTrigger extends HXFixTestDevBase;

var HXPlayerPawn H, R;
var HXTrigger Trig;
var HXFixTestCounter Cnt;
var Vector Base, Dir, Spot;

function float RunStep( int StepNum )
{
	switch ( StepNum )
	{
		case 0:
			H = Host();
			H.ReducedDamageType = 'All';
			R = Remote();
			if ( R!=None )
				R.ReducedDamageType = 'All';
			if ( !Check(H!=None && R!=None, "host and remote present") )
				return -1;
			if ( !Check(FindOpen(H,400,250,Base,Dir), "open spot found" @ Base) )
				return -1;
			TeleNear( H, Base );
			TeleNear( R, Base, 4 );
			Spot = Base + Dir*400;
			Trig = Spawn( class'HXFixTrigger',,, Spot );
			Cnt  = Spawn( class'HXFixTestCounter' );
			if ( !Check(Trig!=None && Cnt!=None, "trigger and counter spawned") )
				return -1;
			Trig.TriggerType = TT_PlayerProximity;
			Trig.Event = 'FixCnt';
			Cnt.Tag = 'FixCnt';
			Trig.RepeatTriggerTime = 0;
			Trig.Message = "";
			Trig.bInitiallyActive = True;
			Trig.SetCollision( True, False, False );
			Trig.SetCollisionSize( 100, 80 );
			Note( "trigger class" @ Trig.Class.Name @ "at" @ Spot );
			// Control: one player.
			H.SetLocation( Spot );
			return 1.5;

		case 1:
			Check( Cnt.Triggers==1, "control: one player entering fires once (" $ Cnt.Triggers $ ")" );
			H.SetLocation( Base );
			return 1.5;

		case 2:
			Check( Cnt.UnTriggers==1, "control: one player leaving untriggers (" $ Cnt.UnTriggers $ ")" );
			Cnt.Triggers = 0;
			Cnt.UnTriggers = 0;
			H.SetLocation( Spot );
			// Toward Base: that side is known to be open.
			if ( !R.SetLocation(Spot - Dir*50) )
				R.SetLocation( Spot - Dir*80 );
			return 1.5;

		case 3:
			if ( !Check(VSize(R.Location-Spot)<100, "remote inside the trigger (" $ VSize(R.Location-Spot) $ ")") )
				return -1;
			Check( Cnt.Triggers==1, "two players entering fire once (" $ Cnt.Triggers $ ")" );
			H.SetLocation( Base );
			Note( "touching right after H left:" @ Trig.Touching[0] @ Trig.Touching[1] @ Trig.Touching[2] @ "R at" @ VSize(R.Location-Spot) @ "active=" $ HXFixTrigger(Trig).FixActiveToucher );
			return 1.5;

		case 4:
			Note( "touching" @ Trig.Touching[0] @ Trig.Touching[1] @ Trig.Touching[2] @ "R at" @ VSize(R.Location-Spot) @ "active=" $ HXFixTrigger(Trig).FixActiveToucher );
			Check( Cnt.UnTriggers==0, "first player leaving does not untrigger (" $ Cnt.UnTriggers $ ")" );
			R.SetLocation( Base - Dir*200 );
			return 1.5;

		case 5:
			Check( Cnt.UnTriggers==1, "last player leaving untriggers once (" $ Cnt.UnTriggers $ ")" );
			Check( Cnt.Triggers==1, "still triggered only once (" $ Cnt.Triggers $ ")" );
			return -1;
	}
	return -1;
}

defaultproperties
{
	TimeoutSeconds=60.000000
}
