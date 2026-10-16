//=============================================================================
// HXFixTestDeco.
//
// A decoration carried by a client which disconnects must be released and
// become solid again.
//=============================================================================
class HXFixTestDeco extends HXFixTestBase;

var HXPlayerPawn R;
var Decoration Deco;
var int Ticks;

function float RunStep( int StepNum )
{
	local Decoration D;

	switch ( StepNum )
	{
		case 0:
			R = Remote();
			if ( !Check(R!=None, "remote present") )
				return -1;
			foreach AllActors( class'Decoration', D )
				if ( !D.bDeleteMe && D.bPushable && D.bMovable && R.CanBeLifted(D) && D.Mass<=20 )
				{
					Deco = D;
					break;
				}
			if ( !Check(Deco!=None, "found a liftable decoration") )
				return -1;
			Note( "deco" @ Deco @ "mass" @ Deco.Mass @ "at" @ Deco.Location );
			R.SetLocation( Deco.Location + vect(0,80,40) );
			R.CarriedDecoration = Deco;
			R.PutCarriedDecorationInHand();
			return 1.0;

		case 1:
			Check( R.CarriedDecoration==Deco && Deco.Base==R && !Deco.bCollideActors, "remote carries the decoration (base=" $ Deco.Base $ " collide=" $ Deco.bCollideActors $ ")" );
			ClientCmd( R, "disconnect" );
			return 5.0;

		case 2:
			Check( Remote()==None, "remote client gone" );
			Check( Deco.Base!=R, "decoration no longer based on the leaver" );
			Check( Deco.bCollideActors && Deco.bBlockActors, "decoration is solid again (collide=" $ Deco.bCollideActors $ " block=" $ Deco.bBlockActors $ ")" );
			Check( Deco.bCollideWorld, "decoration collides with the world again" );
			Check( Deco.Physics==PHYS_Falling || Deco.Physics==PHYS_None, "decoration physics ok (" $ Deco.Physics $ ")" );
			return -1;
	}
	return -1;
}

defaultproperties
{
	MinPlayers=2
	TimeoutSeconds=90.000000
}
