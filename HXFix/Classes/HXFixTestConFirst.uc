//=============================================================================
// HXFixTestConFirst.
//
// First person conversations have no Player. Run the credits / persona /
// transfer events of a first person conversation (Paul's bark) through
// HXFixConPlay and check the nearest player is used.
//=============================================================================
class HXFixTestConFirst extends HXFixTestConBase;

var HXPlayerPawn H, R;
var HXScriptedPawn Paul;
var HXFixConPlay CP;
var int HCredits, RCredits, KitBefore;

function int Copies( Pawn P )
{
	local Inventory Inv;
	local int Num;

	for ( Inv=P.Inventory; Inv!=None; Inv=Inv.Inventory )
		if ( Inv.Class==class'HXMedKit' )
			Num += HXPickup(Inv).NumCopies;
	return Num;
}

function float RunStep( int StepNum )
{
	local ConEventAddCredits Add;
	local ConEventCheckPersona Persona;
	local ConEventTransferObject Transfer;
	local ConListItem Item;
	local Conversation FP;
	local string Label;
	local Inventory Kit;
	local HXPickup Med;

	switch ( StepNum )
	{
		case 0:
			H = Host();
			R = Remote();
			Paul = FindNPC( "PaulDenton" );
			if ( !Check(H!=None && R!=None && Paul!=None, "host, remote and Paul present") )
				return -1;
			R.SetLocation( Paul.Location + vect(0,100,50) );
			return 2.0;

		case 1:
			for ( Item=ConListItem(Paul.ConListItems); Item!=None; Item=Item.Next )
				if ( Item.Con.bFirstPerson )
				{
					FP = Item.Con;
					break;
				}
			if ( !Check(FP!=None, "Paul has a first person conversation (" $ FP $ ")") )
				return -1;
			CP = Spawn( class'HXFixConPlay' );
			CP.SetStartActor( Paul );
			CP.SetConversation( FP );
			Check( CP.Player==None, "control: first person ConPlay has no Player" );

			HCredits = H.Credits;
			RCredits = R.Credits;
			Add = new class'ConEventAddCredits';
			Add.CreditsToAdd = 250;
			CP.SetupEventAddCredits( Add, Label );
			Check( R.Credits==RCredits+250, "credits landed on the nearest player (" $ RCredits $ " -> " $ R.Credits $ ")" );
			Check( H.Credits==HCredits, "credits not given to the far player" );
			Check( CP.Player==None, "Player reset after the event" );

			Persona = new class'ConEventCheckPersona';
			Persona.PersonaType = EP_Credits;
			Persona.Condition = EC_GreaterEqual;
			Persona.Value = RCredits + 250;
			Persona.JumpLabel = "Rich";
			Check( CP.SetupEventCheckPersona(Persona,Label)==EA_JumpToLabel && Label=="Rich", "persona check sees the nearest player's credits (label" @ Label $ ")" );
			Persona.Value = RCredits + 251;
			Check( CP.SetupEventCheckPersona(Persona,Label)==EA_NextEvent, "persona check fails above the credits" );

			// Player -> NPC transfer.
			Kit = Spawn( class'HXMedKit' );
			Kit.GiveTo( R );
			KitBefore = Copies( R );
			Check( KitBefore>0, "control: remote holds medkits (" $ KitBefore $ ")" );
			Transfer = new class'ConEventTransferObject';
			Transfer.GiveObject = class'HXMedKit';
			Transfer.ObjectName = "MedKit";
			Transfer.FromActor = H;
			Transfer.ToActor = Paul;
			Transfer.TransferCount = 1;
			CP.SetupEventTransferObject( Transfer, Label );
			Check( Copies(R)==KitBefore-1, "a medkit left the nearest player (" $ KitBefore $ " -> " $ Copies(R) $ ")" );
			Check( Copies(Paul)==1, "Paul received the medkit (" $ Copies(Paul) $ ")" );
			return 2.0;

		case 2:
			Probe( R, "credits", "" );
			return 2.0;

		case 3:
			if ( Pending(R) )
				return Again();
			Check( ProbeValue(R)==R.Credits, "credits replicated to the client (" $ ProbeValue(R) $ ")" );
			CP.Destroy();
			return -1;
	}
	return -1;
}

defaultproperties
{
	TimeoutSeconds=120.000000
}
