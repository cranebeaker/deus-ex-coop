//=============================================================================
// HXFixTrigger.
//
// HXTrigger where several players standing in a player proximity trigger
// count as one. The original triggered once per player, so two players
// entering a trigger that toggles a mover opened and closed it again, and
// the first player leaving closed it on the other one.
//=============================================================================
class HXFixTrigger extends HXTrigger;

var Actor FixActiveToucher;


function bool FixDedup()
{
	return TriggerType==TT_PlayerProximity && RepeatTriggerTime<=0 && Message=="" && Event!='';
}

function bool FixIsTouching( Actor A )
{
	local int i;

	if ( A==None || A.bDeleteMe )
		return false;
	for ( i=0; i<4; i++ )
		if ( Touching[i]==A )
			return true;
	return false;
}

function Touch( Actor Other )
{
	if ( FixDedup() && IsRelevant(Other) )
	{
		// Somebody else already triggered us and is still inside.
		if ( FixActiveToucher!=None && FixActiveToucher!=Other && FixIsTouching(FixActiveToucher) && IsRelevant(FixActiveToucher) )
			return;
		FixActiveToucher = Other;
	}
	Super.Touch( Other );
}

function UnTouch( Actor Other )
{
	local int i;

	if ( FixDedup() && IsRelevant(Other) )
	{
		if ( Other!=FixActiveToucher )
			return;

		// Hand over to somebody still inside instead of untriggering.
		for ( i=0; i<4; i++ )
			if ( Touching[i]!=None && Touching[i]!=Other && !Touching[i].bDeleteMe && IsRelevant(Touching[i]) )
			{
				FixActiveToucher = Touching[i];
				return;
			}
		FixActiveToucher = None;
	}
	Super.UnTouch( Other );
}
