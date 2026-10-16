//=============================================================================
// HXFixGameInfo.
//
// Community fixes on top of HX 0.9.89.4.
//=============================================================================
class HXFixGameInfo extends HXGameInfo;

// Fix modules (HXFixMutatorBase subclasses). Missing classes are skipped.
var string FixMutatorClasses[8];
var HXFixMutatorBase FixMutators[8];

// Deferred forced conversations.
var HXPlayerPawn DeferPlayer[4];
var Actor DeferActor[4];
var EInvokeMethod DeferMethod[4];
var Conversation DeferCon[4];
var byte bDeferAvoid[4];
var int NumDeferred;
var float DeferStartTime;
var bool bRetryingDeferred;
var float FixTickTime;

// Test helper (?HXFixTestDL=DL_a,DL_b): start datalinks after 3 seconds.
var string TestDataLinks;
var bool bTestDataLinksDone;

// Live test class named in the URL, carried over server travels.
var string LiveTestName;
var string TestNetEmu; // ?HXFixNetEmu=, see HXFixTestBase.
var float MinSwitchCountdown; // ?HXFixSwitchCountdown=, see ProcessServerTravel.

// Replicate all bool flags up to this many (table holds 256).
var int FlagReplicationBudget;

event InitGame( String Options, out String Error )
{
	local float TestExitTime;
	local HXFixTestExit TestExit;

	Super.InitGame( Options, Error );

	if ( MissionScript!=None )
		Log( "HXFix: MissionScript is" @ MissionScript.Class, 'HXFix' );

	SpawnFixMutators();

	RestoreNotes();

	// Test helper: add a note, then travel to the given map.
	if ( ParseOption(Options,"HXFixTestTravel")!="" && ParseOption(Options,"HXFixTestExit")=="" )
	{
		AddNote( "HXFix test note"$Chr(10)$"code 0451", False, True, 'HXFixTestNote' );
		Level.ServerTravel( ParseOption(Options,"HXFixTestTravel")$"?Game=HXFix.HXFixGameInfo?HXFixTestExit=5", True );
		return;
	}

	TestDataLinks = ParseOption( Options, "HXFixTest" $ "DL" );

	// Live test harness: ?HXFixTest=<HXFixTestBase subclass in HXFix>.
	TestNetEmu = ParseOption( Options, "HXFixNetEmu" );
	MinSwitchCountdown = 5.0;
	if ( ParseOption(Options,"HXFixSwitchCountdown")!="" )
		MinSwitchCountdown = float( ParseOption(Options,"HXFixSwitchCountdown") );
	SpawnLiveTest( ParseOption(Options,"HXFixTest") );

	TestExitTime = float(ParseOption(Options,"HXFixTestExit"));
	if ( TestExitTime>0 )
	{
		TestExit = Spawn( class'HXFixTestExit' );
		if ( TestExit!=None )
			TestExit.SetTimer( TestExitTime, False );
	}
}

// ---------------------------------------------------------------------
// Fix modules.
// ---------------------------------------------------------------------

function SpawnLiveTest( string TestName )
{
	local class<HXFixTestBase> TestClass;

	LiveTestName = TestName;
	if ( TestName=="" )
		return;

	TestClass = class<HXFixTestBase>( DynamicLoadObject("HXFix."$TestName, class'Class', True) );
	if ( TestClass==None )
	{
		Log( "HXFixTest: FAIL unknown test class" @ TestName, 'HXFixTest' );
		Log( "HXFixTest: DONE" @ TestName @ "pass=0 fail=1", 'HXFixTest' );
		ConsoleCommand( "exit" );
		return;
	}
	Spawn( TestClass );
}

function SpawnFixMutators()
{
	local class<HXFixMutatorBase> ModuleClass;
	local int i;

	for ( i=0; i<ArrayCount(FixMutatorClasses); i++ )
	{
		if ( FixMutatorClasses[i]=="" )
			continue;

		ModuleClass = class<HXFixMutatorBase>( DynamicLoadObject(FixMutatorClasses[i], class'Class', True) );
		if ( ModuleClass==None )
			continue;

		FixMutators[i] = Spawn( ModuleClass );
		if ( FixMutators[i]!=None )
		{
			HXBaseMutator.AddMutator( FixMutators[i] );
			Log( "HXFix: module" @ FixMutators[i].Class, 'HXFix' );
		}
	}
}

function bool RestartPlayer( Pawn PlayerToRestart )
{
	local int i;

	if ( !Super.RestartPlayer(PlayerToRestart) )
		return False;

	for ( i=0; i<ArrayCount(FixMutators); i++ )
		if ( FixMutators[i]!=None )
			FixMutators[i].NotifyRestartPlayer( PlayerToRestart );
	return True;
}

function Logout( Pawn Exiting )
{
	local int i;

	for ( i=0; i<ArrayCount(FixMutators); i++ )
		if ( FixMutators[i]!=None )
			FixMutators[i].NotifyLogout( Exiting );

	// HXGameInfo.Login counts spectators on listen and dedicated servers, but
	// Logout only uncounts them on dedicated ones.
	if ( Exiting!=None && Exiting.IsA('Spectator') && Level.NetMode==NM_ListenServer )
		NumSpectators--;

	Super.Logout( Exiting );
}

// ---------------------------------------------------------------------
// ModifyMissionScriptClass()
//
// Swap in HXFix subclasses after the HX mutator chain picked its script.
// ---------------------------------------------------------------------

function ModifyMissionScriptClass( out Class<MissionScript> MissionScriptClass, Name LevelName )
{
	Super.ModifyMissionScriptClass( MissionScriptClass, LevelName );

	if ( MissionScriptClass==None )
		return;

	switch ( MissionScriptClass.Name )
	{
		case 'HXMission02':      MissionScriptClass = Class'HXFixMission02'; break;
		case 'HXMission03':      MissionScriptClass = Class'HXFixMission03'; break;
		case 'HXMission04':      MissionScriptClass = Class'HXFixMission04'; break;
		case 'HXMission05':      MissionScriptClass = Class'HXFixMission05'; break;
		case 'HXMission09':      MissionScriptClass = Class'HXFixMission09'; break;
		case 'HXMission10':      MissionScriptClass = Class'HXFixMission10'; break;
		case 'HXMission15':      MissionScriptClass = Class'HXFixMission15'; break;
		case 'HXMissionEndgame': MissionScriptClass = Class'HXFixMissionEndgame'; break;
	}
}

// ---------------------------------------------------------------------
// StartConversation()
//
// Copy of HXGameInfo.StartConversation with two changes: it spawns
// HXFixConPlay, and a forced conversation is deferred (DeferConversation)
// instead of interrupting a running third-person conversation, which marked
// that conversation as played.
// ---------------------------------------------------------------------

function bool StartConversation(
	HXPlayerPawn PassedInPlayer,
	Actor invokeActor, 
	EInvokeMethod invokeMethod, 
	optional Conversation con,
	optional bool bAvoidState,
	optional bool bForcePlay
	)
{
//	local HXRootWindow root;
//	root = HXRootWindow(rootWindow);

	//Log( "=========================================================================", 'DevConPlay' );
	//Log( Self $ ".StartConversation( " $ PassedInPlayer $ ", " $ invokeActor $ ", " $ invokeMethod $ ", " $ con $ ", " $ bAvoidState $ ", " $ bForcePlay $ " ) called.", 'DevConPlay' );
	//Log( "=========================================================================", 'DevConPlay' );

	// First check to see the actor has any conversations or if for some
	// other reason we're unable to start a conversation (typically if 
	// we're alread in a conversation or there's a UI screen visible)

//	if ((!bForcePlay) && ((invokeActor.conListItems == None) || (!CanStartConversation())))
//		return False;

	// Make sure the other actor can converse
//	if ((!bForcePlay) && ((ScriptedPawn(invokeActor) != None) && (!ScriptedPawn(invokeActor).CanConverse())))
//		return False;

	if ((!bForcePlay) && ((invokeActor.conListItems == None) || (!CanGameStartConversation())))
		return False;

	//Log( "Passed: if ((!bForcePlay) && ((invokeActor.conListItems == None) || (!CanGameStartConversation())))", 'DevConPlay' );

	// see if passed in player is ok
	if ( PassedInPlayer != None && !CanPlayerStartConversation( PassedInPlayer ) )
		return False;

	//Log( "Passed: if ( PassedInPlayer != None && !CanPlayerStartConversation( PassedInPlayer ) )", 'DevConPlay' );

	// !!!!  TODO CanPlayerStartConversation !!!! 

	// Make sure the other actor can converse
	if ((!bForcePlay) && ((ScriptedPawn(invokeActor) != None) && (!ScriptedPawn(invokeActor).CanConverse())))
		return False;

	//Log( "Passed: if ((!bForcePlay) && ((ScriptedPawn(invokeActor) != None) && (!ScriptedPawn(invokeActor).CanConverse())))", 'DevConPlay' );

	// If we have a conversation passed in, use it.  Otherwise check to see
	// if the passed in actor actually has a valid conversation that can be
	// started.

	if ( con == None )
		con = GetActiveConversation( PassedInPlayer, invokeActor, invokeMethod );

	//Log( "con = " $ con, 'DevConPlay' );

	// If we have a conversation, put the actor into "Conversation Mode".
	// Otherwise just return false.
	//
	// TODO: Scan through the conversation and put *ALL* actors involved
	//       in the conversation into the "Conversation" state??

	if ( con != None )
	{
		// Check to see if this conversation is already playing.  If so,
		// then don't start it again.  This prevents a multi-bark conversation
		// from being abused.
		if ((conPlay != None) && (conPlay.con == con))
			return False;

		// Now check to see if there's a conversation playing that is owned
		// by the InvokeActor *and* the player has a speaking part *and*
		// it's a first-person convo, in which case we want to abort here.
		if (((conPlay != None) && (conPlay.invokeActor == invokeActor)) && 
		    (conPlay.con.bFirstPerson) &&
//			(conPlay.con.IsSpeakingActor(Self)))
				(IsSpeakingActorByBindName(conPlay.con, BindName)))
			return False;

		// Check if the person we're trying to start the conversation 
		// with is a Foe and this is a Third-Person conversation.  
		// If so, ABORT!
//		if ((!bForcePlay) && ((!con.bFirstPerson) && (ScriptedPawn(invokeActor) != None) && (ScriptedPawn(invokeActor).GetPawnAllianceType(Self) == ALLIANCE_Hostile)))
//			return False;

		if ( PassedInPlayer != None )
		{
			//if ((!bForcePlay) && ((!con.bFirstPerson) && (ScriptedPawn(invokeActor) != None) && (ScriptedPawn(invokeActor).GetPawnAllianceType(Self) == ALLIANCE_Hostile)))
			if ((!bForcePlay) && ((!con.bFirstPerson) && (ScriptedPawn(invokeActor) != None) && (ScriptedPawn(invokeActor).GetPawnAllianceType( PassedInPlayer ) == ALLIANCE_Hostile)))
				return False;
		}
		else
		{
			//if ((!bForcePlay) && ((!con.bFirstPerson) && (ScriptedPawn(invokeActor) != None) && (ScriptedPawn(invokeActor).GetPawnAllianceType(Self) == ALLIANCE_Hostile)))
			if ((!bForcePlay) && ((!con.bFirstPerson) && (ScriptedPawn(invokeActor) != None) && (ScriptedPawn(invokeActor).GetAllianceType( 'Player' ) == ALLIANCE_Hostile)))
				return False;
		}

		// If the player is involved in this conversation, make sure the 
		// scriptedpawn even WANTS to converse with the player.
		//
		// I have put a hack in here, if "con.bCanBeInterrupted" 
		// (which is no longer used as intended) is set, then don't 
		// call the ScriptedPawn::CanConverseWithPlayer() function

//		if ((!bForcePlay) && ((con.IsSpeakingActor(Self)) && (!con.bCanBeInterrupted) && (ScriptedPawn(invokeActor) != None) && (!ScriptedPawn(invokeActor).CanConverseWithPlayer(Self))))
//			return False;

		if ( PassedInPlayer != None )
		{
			if ((!bForcePlay) && ((con.IsSpeakingActor(Self)) && (!con.bCanBeInterrupted) && (ScriptedPawn(invokeActor) != None) && (!ScriptedPawn(invokeActor).CanConverseWithPlayer(PassedInPlayer))))
				return False;
		}
		else
		{
			if ((!bForcePlay) && ((con.IsSpeakingActor(Self)) && (!con.bCanBeInterrupted) && (ScriptedPawn(invokeActor) != None) && (!HXScriptedPawn(invokeActor).CanConverseWithPlayer2())))
				return False;
		}

		// Hack alert!  If this is a Bark conversation (as denoted by the 
		// conversation name, since we don't have a field in ConEdit), 
		// then force this conversation to be first-person
		if (Left(con.conName, Len(con.conOwnerName) + 5) == (con.conOwnerName $ "_Bark"))
			con.bFirstPerson = True;

		// Make sure the player isn't ducking.  If the player can't rise
		// to start a third-person conversation (blocked by geometry) then 
		// immediately abort the conversation, as this can create all 
		// sorts of complications (such as the player standing through
		// geometry!!)

//		if ((!con.bFirstPerson) && (ResetBasedPawnSize() == False))
//			return False;

		if ( !con.bFirstPerson )
		{
			if ( PassedInPlayer == None )
			{
				Log( "No PassedInPlayer for 3rd person conversation... aborting..", 'DevConPlay' );
				return false;
			}
			else if ( !PassedInPlayer.ResetBasedPawnSize() )
			{
				Log( "Failed to ResetBasedPawnSize() for " $ PassedInPlayer $ ".. aborting..", 'DevConPlay' );
				return false;
			}

			//Log( "con is not a firstperson con.. aborting.." );
			//return false;
		}

		// If ConPlay exists, end the current conversation playing
		if (conPlay != None)
		{
			// HXFix: a forced conversation must not interrupt (and mark as played) a
			// third-person conversation of another player. Defer it until that one ended.
			if ( bForcePlay && conPlay.con!=None && !conPlay.con.bFirstPerson && !conPlay.GetForcePlay() && DeferConversation(PassedInPlayer,invokeActor,invokeMethod,con,bAvoidState) )
				return True;

			// If we're already playing a third-person conversation, don't interrupt with
			// another *radius* induced conversation (frobbing is okay, though).
			if ((conPlay.con != None) && (conPlay.con.bFirstPerson) && (invokeMethod == IM_Radius))
				return False;

			conPlay.InterruptConversation();
			conPlay.TerminateConversation();
		}

		// If this is a first-person conversation _and_ a DataLink is already
		// playing, then abort.  We don't want to give the user any more 
		// distractions while a DL is playing, since they're pretty important.
		if ( dataLinkPlay != None )
		{
			if (con.bFirstPerson)
				return False;
			else
				dataLinkPlay.AbortAndSaveHistory();
		}

		// Found an active conversation, so start it
		conPlay = Spawn(class'HXFixConPlay');
		conPlay.SetStartActor(invokeActor);
		conPlay.SetConversation(con);
		conPlay.SetForcePlay(bForcePlay);

		if ( PassedInPlayer != None )
		{
			conPlay.SetInitialRadius(VSize(PassedInPlayer.Location - invokeActor.Location));
		}
		else
		{
			// hopefully this is huge enough
			conPlay.SetInitialRadius( 512.0 );
		}

		// If this conversation was invoked with IM_Named, then save away
		// the current radius so we don't abort until we get outside 
		// of this radius + 100.
		if (invokeMethod == IM_Frob)
		{
			conPlay.SetOriginalRadius(con.radiusDistance);
			con.radiusDistance = VSize(invokeActor.Location - PassedInPlayer.Location);
		}
		else if (invokeMethod == IM_Named)
		{
			conPlay.SetOriginalRadius(con.radiusDistance);

			if ( PassedInPlayer != None )
				con.radiusDistance = VSize(invokeActor.Location - PassedInPlayer.Location);
			else
			{
				Log( "WARNING! No PassedInPlayer for IM_Named Convo, setting con.radiusDistance to 512.0" );
				con.radiusDistance = 512.0;
			}
		}

		// If the invoking actor is a ScriptedPawn, then force this person 
		// into the conversation state
		if ((!bForcePlay) && (ScriptedPawn(invokeActor) != None ))
			ScriptedPawn(invokeActor).EnterConversationState(con.bFirstPerson, bAvoidState);

		// Do the same if this is a HXDecoration
		if ((!bForcePlay) && (HXDecoration(invokeActor) != None ))
			HXDecoration(invokeActor).EnterConversationState(con.bFirstPerson, bAvoidState);

		// If this is a third-person convo, we're pretty much going to 
		// pause the game.  If this is a first-person convo, then just 
		// keep on going..
		//
		// If this is a third-person convo *AND* 'bForcePlay' == True, 
		// then use first-person mode, as we're playing an intro/endgame
		// sequence and we can't have the player in the convo state (bad bad bad!)

		if ((!con.bFirstPerson) && (!bForcePlay))
		{
			PassedInPlayer.GotoState('Conversation');
		}
		else
		{
			if (!ConPlay.StartCoopConversation(InvokeActor, bForcePlay))
			{
				AbortConversation(True);
			}
		}

		//Log( "==============================  True  ==================================" );
		return True;
	}
	else
	{
		//Log( "==============================  False  =================================" );
		return False;
	}
}

function bool DeferConversation( HXPlayerPawn PassedInPlayer, Actor InvokeActor, EInvokeMethod InvokeMethod, Conversation Con, bool bAvoidState )
{
	local int i;

	if ( bRetryingDeferred )
		return False;

	for ( i=0; i<NumDeferred; i++ )
		if ( DeferActor[i]==InvokeActor && DeferCon[i]==Con )
			return True;

	if ( NumDeferred>=ArrayCount(DeferActor) )
		return False;

	if ( NumDeferred==0 )
		DeferStartTime = Level.TimeSeconds;

	DeferPlayer[NumDeferred] = PassedInPlayer;
	DeferActor[NumDeferred]  = InvokeActor;
	DeferMethod[NumDeferred] = InvokeMethod;
	DeferCon[NumDeferred]    = Con;
	bDeferAvoid[NumDeferred] = byte(bAvoidState);
	NumDeferred++;

	Log( "HXFix: deferring forced conversation" @ Con @ "of" @ InvokeActor @ "until" @ ConPlay.Con @ "ended", 'HXFix' );
	return True;
}

function ProcessDeferredConversations()
{
	local HXPlayerPawn P;
	local Actor A;
	local EInvokeMethod M;
	local Conversation C;
	local bool bA;
	local int i;

	if ( NumDeferred<=0 )
		return;

	if ( ConPlay!=None )
	{
		// Don't wait forever on a stuck conversation.
		if ( Level.TimeSeconds-DeferStartTime>90.0 )
		{
			Log( "HXFix: aborting stuck conversation to play deferred ones", 'HXFix' );
			AbortConversation( True );
		}
		if ( ConPlay!=None )
			return;
	}

	// CanPlayerStartConversation() refuses a start within a second of the last
	// conversation's end, which would silently drop the deferred one.
	if ( LastConEndTime+1.0>Level.TimeSeconds )
		return;

	P = DeferPlayer[0];
	A = DeferActor[0];
	M = DeferMethod[0];
	C = DeferCon[0];
	bA = bDeferAvoid[0]!=0;
	for ( i=1; i<NumDeferred; i++ )
	{
		DeferPlayer[i-1] = DeferPlayer[i];
		DeferActor[i-1]  = DeferActor[i];
		DeferMethod[i-1] = DeferMethod[i];
		DeferCon[i-1]    = DeferCon[i];
		bDeferAvoid[i-1] = bDeferAvoid[i];
	}
	NumDeferred--;

	if ( A==None || A.bDeleteMe || (P!=None && P.bDeleteMe) )
		return;

	Log( "HXFix: playing deferred conversation" @ C @ "of" @ A, 'HXFix' );
	bRetryingDeferred = True;
	StartConversation( P, A, M, C, bA, True );
	bRetryingDeferred = False;
}

// ---------------------------------------------------------------------
// Tick()
//
// - Plays deferred forced conversations.
// - Safety net: a datalink held back by a conversation is only resumed by
//   EndConversation(). If ConPlay got cleared without it, resume here.
// ---------------------------------------------------------------------

function Tick( float DeltaTime )
{
	local HXFixDataLinkDryRunner Runner;

	Super.Tick( DeltaTime );

	FixTickTime += DeltaTime;
	if ( FixTickTime<0.5 )
		return;
	FixTickTime = 0;

	ProcessDeferredConversations();

	if ( TestDataLinks!="" && !bTestDataLinksDone && Level.TimeSeconds>3.0 )
	{
		bTestDataLinksDone = True;
		Log( "HXFix: test datalink 1 =>" @ StartDataLinkTransmission( Left(TestDataLinks,InStr(TestDataLinks,",")) ), 'HXFix' );
		Log( "HXFix: test datalink 2 =>" @ StartDataLinkTransmission( Mid(TestDataLinks,InStr(TestDataLinks,",")+1) ), 'HXFix' );
	}

	Runner = HXFixDataLinkDryRunner(DataLinkPlay);
	if ( Runner!=None && Runner.bWaitingForConPlay && ConPlay==None )
	{
		Log( "HXFix: resuming stalled datalinks", 'HXFix' );
		Runner.bWaitingForConPlay = False;
		ResumeDataLinks();
	}
}

// ---------------------------------------------------------------------
// InitFlagReplicationInfo()
//
// HXFlagReplicationInfo has a fixed table (16x16 = 256 flags). The stock
// code pushes every bool flag of the campaign into it, which overflows
// ("NO EMPTY FLAG SLOT") late in the campaign and then drops flags
// silently. Clients only read flags for datalink conditions (FlagRefs and
// the _Played flag), so once there are too many flags replicate only the
// true ones that are relevant for this mission's datalinks.
// ---------------------------------------------------------------------

function string BuildRelevantFlagList()
{
	local ConListItem Item;
	local ConFlagRef Ref;
	local Conversation Con;
	local string List, ConBindClass;
	local int MissionNumber;

	if ( ConListItems==None && DeusExLevelInfo!=None )
	{
		MissionNumber = DeusExLevelInfo.MissionNumber;
		if ( MissionNumber>=0 && MissionNumber<=9 )
			ConBindClass = "DeusExConText.ConList_Mission0" $ MissionNumber;
		else if ( MissionNumber>=10 && MissionNumber<=99 )
			ConBindClass = "DeusExConText.ConList_Mission" $ MissionNumber;
		if ( ConBindClass!="" )
			class'HXActor'.Static.BindConversationList( ConBindClass, Self );
	}

	List = "|";
	for ( Item=ConListItem(ConListItems); Item!=None; Item=Item.Next )
	{
		Con = Item.Con;
		if ( Con==None || !( Con.bDataLinkCon || Left(string(Con.ConName),3)~="DL_" ) )
			continue;

		if ( Con.bDisplayOnce )
			List = List $ Con.ConName $ "_Played|";
		for ( Ref=Con.FlagRefList; Ref!=None; Ref=Ref.NextFlagRef )
			List = List $ Ref.FlagName $ "|";
	}
	return List;
}

function InitFlagReplicationInfo()
{
	local int FlagIterator, Total, Sent;
	local Name FlagName;
	local string Relevant;

	if ( FlagReplicationInfo==None || Steve==None || Steve.FlagBase==None )
		return;

	FlagIterator = Steve.FlagBase.CreateIterator();
	while ( Steve.FlagBase.GetNextFlagName( FlagIterator, FlagName ) )
		if ( Steve.FlagBase.CheckFlag( FlagName, FLAG_Bool ) )
			Total++;
	Steve.FlagBase.DestroyIterator( FlagIterator );

	if ( Total<=FlagReplicationBudget )
	{
		Log( "HXFix: replicating all" @ Total @ "bool flags", 'HXFix' );
		Super.InitFlagReplicationInfo();
		return;
	}

	Relevant = BuildRelevantFlagList();
	if ( Relevant=="|" )
	{
		Super.InitFlagReplicationInfo();
		return;
	}

	FlagIterator = Steve.FlagBase.CreateIterator();
	while ( Steve.FlagBase.GetNextFlagName( FlagIterator, FlagName ) )
	{
		if ( Steve.FlagBase.CheckFlag( FlagName, FLAG_Bool ) && Steve.FlagBase.GetBool( FlagName ) && InStr( Relevant, "|"$FlagName$"|" )>=0 )
		{
			FlagReplicationInfo.SetBoolFlag( FlagName, True );
			Sent++;
		}
	}
	Steve.FlagBase.DestroyIterator( FlagIterator );
	Log( "HXFix: too many bool flags (" $ Total $ "), replicating only" @ Sent @ "of" @ Len(Relevant) @ "chars of datalink relevant flag names", 'HXFix' );
}

// ---------------------------------------------------------------------
// Notes.
//
// HX wipes FirstNote on travel and Steve doesn't carry notes, so door
// codes vanished on every map change and late joiners never got any.
// Steve's flags travel with the campaign, so a missing HXFixNotesValid
// flag means a fresh campaign and the stored notes are stale.
// ---------------------------------------------------------------------

function RestoreNotes()
{
	local DeusExNote Note;
	local string Tag;
	local int i;

	if ( Steve==None || Steve.FlagBase==None )
		return;

	if ( !Steve.FlagBase.GetBool('HXFixNotesValid') )
	{
		class'HXFixNoteStore'.static.Clear();
		Steve.FlagBase.SetBool( 'HXFixNotesValid', True, True, 0 );
		return;
	}

	FirstNote = None;
	LastNote  = None;
	for ( i=0; i<class'HXFixNoteStore'.static.Count(); i++ )
	{
		Note = new(None,'',RF_Transient) Class'DeusExNote';
		Note.Text = class'HXFixNoteStore'.static.GetText( i );
		Note.SetUserNote( class'HXFixNoteStore'.static.GetUserNote(i) );
		Tag = class'HXFixNoteStore'.static.GetTag( i );
		if ( Tag!="" && Tag!="None" )
			Note.SetTextTag( StringToName(Tag) );

		// Stored newest first, so append.
		if ( LastNote==None )
			FirstNote = Note;
		else
			LastNote.Next = Note;
		LastNote = Note;
	}
	Log( "HXFix: restored" @ i @ "notes", 'HXFix' );
}

function ProcessServerTravel( string URL, bool bItems )
{
	local int i;
	local Pawn P;
	local HXCarcass Carcass;
	local Inventory Inv, NextInv;

	// A pawn travelling while dead crashed a client in garbage collection
	// (dangling PlayerReplicationInfo owner), respawn dead players first.
	for ( P=Level.PawnList; P!=None; P=P.NextPawn )
		if ( HXPlayerPawn(P)!=None && P.Health<=0 && !P.bDeleteMe && PlayerPawn(P).Player!=None )
		{
			Log( "HXFix: respawning dead" @ P @ "before travel", 'HXFix' );
			// The corpse stays behind: drop its items, so the respawn isn't
			// treated as equipment farming and the player gets starting gear.
			foreach AllActors( class'HXCarcass', Carcass )
				if ( Carcass.bPlayerCarcass && !Carcass.bDeleteMe && Carcass.CarcassName==P.Name )
					for ( Inv=Carcass.Inventory; Inv!=None; Inv=NextInv )
					{
						NextInv = Inv.Inventory;
						Carcass.DeleteInventory( Inv );
						Inv.Destroy();
					}
			PlayerPawn(P).ServerReStartPlayer();
		}

	for ( i=0; i<ArrayCount(FixMutators); i++ )
		if ( FixMutators[i]!=None )
			FixMutators[i].NotifyServerTravel( URL, bItems );

	if ( bItems )
		class'HXFixNoteStore'.static.Save( FirstNote );
	else
		class'HXFixNoteStore'.static.Clear();

	Super.ProcessServerTravel( URL, bItems );

	// ClientTravel is one reliable RPC queued behind everything else on the
	// player's channel (a conversation that just started sends a burst), and
	// the level switch tears the old connections down after 2 s. With lag and
	// packet loss the clients were stranded on the old map. Leave more time.
	if ( Level.NetMode==NM_ListenServer || Level.NetMode==NM_DedicatedServer )
		Level.NextSwitchCountdown = FMax( Level.NextSwitchCountdown, MinSwitchCountdown );
}

event PostLogin( PlayerPawn NewPlayer )
{
	local DeusExNote Note, Notes[256];
	local int i, Num;

	Super.PostLogin( NewPlayer );

	if ( HXPlayerPawn(NewPlayer)==None )
		return;

	// Remote clients, and the listen host for its inventory screen.
	if ( Level.NetMode!=NM_Standalone )
		Spawn( class'HXFixClientCleanup', NewPlayer );

	// ClientAddNote prepends, so send oldest first.
	for ( Note=FirstNote; Note!=None && Num<256; Note=Note.Next )
		Notes[Num++] = Note;
	for ( i=Num-1; i>=0; i-- )
		HXPlayerPawn(NewPlayer).ClientAddNote( Notes[i].Text, Notes[i].bUserNote, Notes[i].TextTag );

	for ( i=0; i<ArrayCount(FixMutators); i++ )
		if ( FixMutators[i]!=None )
			FixMutators[i].NotifyPostLogin( NewPlayer );
}

// ---------------------------------------------------------------------
// Killed()
//
// HXPlayerPawn.Died only terminates its own conPlay, which HX never sets
// (it uses Game.ConPlay). A player killed mid conversation left the
// conversation orphaned: the NPC stayed untalkable and every queued
// datalink stalled for the rest of the map. Abort it here instead,
// without marking it played so the story conversation can be replayed.
// ---------------------------------------------------------------------

function Killed( Pawn Killer, Pawn Other, name DamageType )
{
	local int i;

	for ( i=0; i<ArrayCount(FixMutators); i++ )
		if ( FixMutators[i]!=None )
			FixMutators[i].NotifyKilled( Killer, Other, DamageType );

	if ( ConPlay!=None && Other!=None && ConPlay.Player==Other )
	{
		Log( "HXFix: aborting conversation of killed player" @ Other, 'HXFix' );
		AbortConversation( True );
	}

	Super.Killed( Killer, Other, DamageType );
}

// ---------------------------------------------------------------------
// AcceptInventory()
//
// A player who is dead when the map changes arrives with 0 health and
// their gear stranded in the corpse on the old map. Respawn them properly.
// ---------------------------------------------------------------------

event AcceptInventory( Pawn PlayerPawn )
{
	local HXPlayerPawn Human;

	Super.AcceptInventory( PlayerPawn );

	Human = HXPlayerPawn(PlayerPawn);
	if ( Human==None || Human.Health>0 )
		return;

	Log( "HXFix: respawning" @ Human @ "who travelled dead", 'HXFix' );
	Human.RestoreAllHealth();
	Human.Energy = Human.Default.Energy;
	Human.GiveInitialInventory();
	AddDefaultInventory( Human );
}

// ---------------------------------------------------------------------
// ChangeName()
//
// Travel inventory is keyed by player name, so two players sharing a
// name can lose or swap their gear on map change. Force unique names
// and push the new name into the client's URL, so it sticks on travel.
// ---------------------------------------------------------------------

function ChangeName( Pawn Other, coerce string S, bool bNameChange )
{
	local string UniqueName;
	local HXFixNameNotifier Notifier;

	if ( S=="" || Other==None || Other.PlayerReplicationInfo==None )
	{
		Super.ChangeName( Other, S, bNameChange );
		return;
	}

	UniqueName = MakeUniqueName( Other, S );
	Super.ChangeName( Other, UniqueName, bNameChange );

	if ( UniqueName!=S && PlayerPawn(Other)!=None && Level.NetMode!=NM_Standalone )
	{
		Notifier = Spawn( Class'HXFixNameNotifier', Other );
		if ( Notifier!=None )
			Notifier.NewName = UniqueName;
		Other.ClientMessage( "Name '"$S$"' is already taken, you are now '"$UniqueName$"'." );
	}
}

function bool IsNameTaken( Pawn Other, string S )
{
	local Pawn P;

	for ( P=Level.PawnList; P!=None; P=P.NextPawn )
		if ( P!=Other && P.bIsPlayer && !P.bDeleteMe && P.PlayerReplicationInfo!=None && P.PlayerReplicationInfo.PlayerName~=S )
			return True;
	return False;
}

// "Name_2" -> "Name", so renames don't stack into "Name_2_2".
function string StripNameSuffix( string S )
{
	local int i;

	for ( i=Len(S)-1; i>0; i-- )
	{
		if ( Mid(S,i,1)=="_" )
			return Left( S, i );
		if ( Asc(Mid(S,i,1))<48 || Asc(Mid(S,i,1))>57 )
			return S;
	}
	return S;
}

function string MakeUniqueName( Pawn Other, string S )
{
	local int i;
	local string Candidate;

	if ( !IsNameTaken(Other,S) )
		return S;

	S = StripNameSuffix( S );
	for ( i=2; i<100; i++ )
	{
		Candidate = Left(S,17)$"_"$i;
		if ( !IsNameTaken(Other,Candidate) )
			return Candidate;
	}
	return S;
}

defaultproperties
{
	FlagReplicationBudget=180
	DataLinkManagerClass=class'HXFix.HXFixDataLinkManager'
	GameReplicationInfoClass=class'HXFix.HXFixGameReplicationInfo'
	FixMutatorClasses(0)="HXFix.HXFixAugsMutator"
	FixMutatorClasses(1)="HXFix.HXFixPlayerMutator"
	FixMutatorClasses(2)="HXFix.HXFixDevicesMutator"
	FixMutatorClasses(3)="HXFix.HXFixWeaponsMutator"
	FixMutatorClasses(4)="HXFix.HXFixConvoMutator"
}
