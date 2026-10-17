//=============================================================================
// HXFixSaveWorld.
//
// Co-op save of the shared world state (the single "Continue" slot), kept in
// HXFixSave.ini next to the player records of HXFixSavePlayers.
//
// Save()  stores the map name, mission number, every game flag, goals, notes,
//         nanokeys, data vault images and the team skill point total.
// Load()  puts flags, goals, keys, images and skill points back into HXSteve.
//         It must run before HXGameInfo.InitGame spawns the mission script,
//         because mission scripts read flags as soon as they exist.
// Notes   come back separately (RestoreNotes), once the game info is set up.
//
// Lines are "|" separated, the free text field is always last.
//   Flag: <type b/y/i/f/n/v/r>|<name>|<expiration>|<value>
//   Goal: <name>|<primary 0/1>|<completed 0/1>|<text>
//   Note: <tag>|<user note 0/1>|<text>
//   Key:  <id>|<description>
// Newlines in text are escaped like HXFixNoteStore does.
//=============================================================================
class HXFixSaveWorld extends Object
	config(HXFixSave);

const MaxFlags = 2048;
const MaxGoals = 128;
const MaxNotes = 256;
const MaxKeys  = 128;
const MaxImages = 63;

var config string SavedMap;          // Empty: no saved game.
var config int    Mission;
var config int    SkillPointsTotal;
var config string Portal;
var config int    NumFlags;
var config string Flag[2048];
var config int    NumGoals;
var config string Goal[128];
var config int    NumNotes;
var config string NoteLine[256];
var config int    NumKeys;
var config string Key[128];
var config string Image[63];

// ----------------------------------------------------------------------------
// Text helpers.
// ----------------------------------------------------------------------------

static function string Part( string S, int N )
{
	local int i;

	while ( N>0 )
	{
		i = InStr( S, "|" );
		if ( i<0 )
			return "";
		S = Mid( S, i+1 );
		N--;
	}
	i = InStr( S, "|" );
	if ( i>=0 )
		return Left( S, i );
	return S;
}

// Everything after the first N separators.
static function string Rest( string S, int N )
{
	local int i;

	while ( N>0 )
	{
		i = InStr( S, "|" );
		if ( i<0 )
			return "";
		S = Mid( S, i+1 );
		N--;
	}
	return S;
}

static function bool HasSave()
{
	return Default.SavedMap!="";
}

static function string MapName()
{
	return Default.SavedMap;
}

static function AddFlag( string S )
{
	if ( Default.NumFlags>=MaxFlags )
	{
		Log( "HXFixSaveWorld: flag table full, dropping" @ S, 'HXFixSave' );
		return;
	}
	Default.Flag[Default.NumFlags] = S;
	Default.NumFlags++;
}

// ----------------------------------------------------------------------------
// Save.
// ----------------------------------------------------------------------------

static function bool Save( HXFixGameInfo G )
{
	local HXSteve Steve;
	local HXFlagBase FB;
	local HXGoal Gl;
	local HXNanoKeyInfo K;
	local DeusExNote N;
	local int It, i;
	local name FN;
	local vector V;
	local rotator R;
	local int Counts[7];

	if ( G==None || G.Steve==None || G.Steve.FlagBase==None )
		return False;
	Steve = G.Steve;
	FB    = Steve.FlagBase;

	Default.SavedMap         = string( G.Level.Outer.Name );
	Default.SkillPointsTotal = Steve.SkillPointsTotal;
	Default.Portal           = Steve.Portal;
	if ( G.DeusExLevelInfo!=None )
		Default.Mission = G.DeusExLevelInfo.MissionNumber;

	// ---- Flags, one iterator per type. ----
	for ( i=0; i<MaxFlags; i++ )
		Default.Flag[i] = "";
	Default.NumFlags = 0;

	It = FB.CreateIterator( FLAG_Bool );
	while ( FB.GetNextFlagName( It, FN ) )
	{
		AddFlag( "b|" $ FN $ "|" $ FB.GetExpiration(FN,FLAG_Bool) $ "|" $ int(FB.GetBool(FN)) );
		Counts[0]++;
	}
	FB.DestroyIterator( It );

	It = FB.CreateIterator( FLAG_Byte );
	while ( FB.GetNextFlagName( It, FN ) )
	{
		AddFlag( "y|" $ FN $ "|" $ FB.GetExpiration(FN,FLAG_Byte) $ "|" $ FB.GetByte(FN) );
		Counts[1]++;
	}
	FB.DestroyIterator( It );

	It = FB.CreateIterator( FLAG_Int );
	while ( FB.GetNextFlagName( It, FN ) )
	{
		AddFlag( "i|" $ FN $ "|" $ FB.GetExpiration(FN,FLAG_Int) $ "|" $ FB.GetInt(FN) );
		Counts[2]++;
	}
	FB.DestroyIterator( It );

	It = FB.CreateIterator( FLAG_Float );
	while ( FB.GetNextFlagName( It, FN ) )
	{
		AddFlag( "f|" $ FN $ "|" $ FB.GetExpiration(FN,FLAG_Float) $ "|" $ FB.GetFloat(FN) );
		Counts[3]++;
	}
	FB.DestroyIterator( It );

	It = FB.CreateIterator( FLAG_Name );
	while ( FB.GetNextFlagName( It, FN ) )
	{
		AddFlag( "n|" $ FN $ "|" $ FB.GetExpiration(FN,FLAG_Name) $ "|" $ FB.GetName(FN) );
		Counts[4]++;
	}
	FB.DestroyIterator( It );

	It = FB.CreateIterator( FLAG_Vector );
	while ( FB.GetNextFlagName( It, FN ) )
	{
		V = FB.GetVector( FN );
		AddFlag( "v|" $ FN $ "|" $ FB.GetExpiration(FN,FLAG_Vector) $ "|" $ V.X $ "|" $ V.Y $ "|" $ V.Z );
		Counts[5]++;
	}
	FB.DestroyIterator( It );

	It = FB.CreateIterator( FLAG_Rotator );
	while ( FB.GetNextFlagName( It, FN ) )
	{
		R = FB.GetRotator( FN );
		AddFlag( "r|" $ FN $ "|" $ FB.GetExpiration(FN,FLAG_Rotator) $ "|" $ R.Pitch $ "|" $ R.Yaw $ "|" $ R.Roll );
		Counts[6]++;
	}
	FB.DestroyIterator( It );

	// ---- Goals, newest first like the list. ----
	for ( i=0; i<MaxGoals; i++ )
		Default.Goal[i] = "";
	Default.NumGoals = 0;
	for ( Gl=Steve.FirstGoal; Gl!=None && Default.NumGoals<MaxGoals; Gl=Gl.Next )
	{
		Default.Goal[Default.NumGoals] = Gl.GoalName $ "|" $ int(Gl.bPrimaryGoal) $ "|" $ int(Gl.bCompleted) $ "|" $ class'HXFixNoteStore'.static.Escape( Gl.Text );
		Default.NumGoals++;
	}

	// ---- Notes, newest first. ----
	for ( i=0; i<MaxNotes; i++ )
		Default.NoteLine[i] = "";
	Default.NumNotes = 0;
	for ( N=G.FirstNote; N!=None && Default.NumNotes<MaxNotes; N=N.Next )
	{
		Default.NoteLine[Default.NumNotes] = string(N.TextTag) $ "|" $ int(N.bUserNote) $ "|" $ class'HXFixNoteStore'.static.Escape( N.Text );
		Default.NumNotes++;
	}

	// ---- Nanokeys, newest first. ----
	for ( i=0; i<MaxKeys; i++ )
		Default.Key[i] = "";
	Default.NumKeys = 0;
	for ( K=Steve.KeyList; K!=None && Default.NumKeys<MaxKeys; K=K.NextKey )
	{
		Default.Key[Default.NumKeys] = K.KeyID $ "|" $ class'HXFixNoteStore'.static.Escape( K.Description );
		Default.NumKeys++;
	}

	// ---- Data vault images. ----
	for ( i=0; i<MaxImages; i++ )
		Default.Image[i] = class'HXFixSavePlayers'.static.ClassStr( Steve.DataVaultImages[i] );

	StaticSaveConfig();
	Log( "HXFixSaveWorld: saved" @ Default.SavedMap @ "mission" @ Default.Mission @ "flags" @ Default.NumFlags
		@ "(b" $ Counts[0] @ "y" $ Counts[1] @ "i" $ Counts[2] @ "f" $ Counts[3] @ "n" $ Counts[4] @ "v" $ Counts[5] @ "r" $ Counts[6] $ ")"
		@ "goals" @ Default.NumGoals @ "notes" @ Default.NumNotes @ "keys" @ Default.NumKeys, 'HXFixSave' );
	return True;
}

// ----------------------------------------------------------------------------
// Load. Steve is the level's HXSteve, G.Steve is not set yet at this point.
// ----------------------------------------------------------------------------

static function bool Load( HXFixGameInfo G, HXSteve Steve )
{
	local HXFlagBase FB;
	local HXGoal Gl, Last;
	local string S, T;
	local int i, Exp;
	local name FN;
	local vector V;
	local rotator R;
	local class<DataVaultImage> Img;

	if ( G==None || Steve==None || Steve.FlagBase==None || Default.SavedMap=="" )
		return False;
	FB = Steve.FlagBase;

	// ---- Flags. ----
	FB.DeleteAllFlags();
	for ( i=0; i<Default.NumFlags; i++ )
	{
		S   = Default.Flag[i];
		T   = Part( S, 0 );
		FN  = class'HXActor'.static.StringToName( Part(S,1) );
		Exp = int( Part(S,2) );
		switch ( T )
		{
			case "b": FB.SetBool( FN, Part(S,3)=="1", True, Exp ); break;
			case "y": FB.SetByte( FN, byte(Part(S,3)), True, Exp ); break;
			case "i": FB.SetInt( FN, int(Part(S,3)), True, Exp ); break;
			case "f": FB.SetFloat( FN, float(Part(S,3)), True, Exp ); break;
			case "n": FB.SetName( FN, class'HXActor'.static.StringToName(Part(S,3)), True, Exp ); break;
			case "v":
				V.X = float( Part(S,3) );
				V.Y = float( Part(S,4) );
				V.Z = float( Part(S,5) );
				FB.SetVector( FN, V, True, Exp );
				break;
			case "r":
				R.Pitch = int( Part(S,3) );
				R.Yaw   = int( Part(S,4) );
				R.Roll  = int( Part(S,5) );
				FB.SetRotator( FN, R, True, Exp );
				break;
		}
	}

	// ---- Goals (stored newest first, so append). ----
	Steve.FirstGoal = None;
	for ( i=0; i<Default.NumGoals; i++ )
	{
		S  = Default.Goal[i];
		Gl = new(G) class'HXGoal';
		Gl.GoalName     = class'HXActor'.static.StringToName( Part(S,0) );
		Gl.bPrimaryGoal = Part(S,1)=="1";
		Gl.bCompleted   = Part(S,2)=="1";
		Gl.Text         = class'HXFixNoteStore'.static.Unescape( Rest(S,3) );
		if ( Last==None )
			Steve.FirstGoal = Gl;
		else
			Last.Next = Gl;
		Last = Gl;
	}

	// ---- Keys: GiveKey prepends, so oldest first. ----
	Steve.KeyList = None;
	for ( i=Default.NumKeys-1; i>=0; i-- )
	{
		S = Default.Key[i];
		G.GiveKey( class'HXActor'.static.StringToName(Part(S,0)), class'HXFixNoteStore'.static.Unescape(Rest(S,1)), True );
	}

	// ---- Images and skill points. ----
	for ( i=0; i<MaxImages; i++ )
	{
		Img = class<DataVaultImage>( class'HXFixSavePlayers'.static.LoadClassStr(Default.Image[i]) );
		Steve.DataVaultImages[i] = Img;
	}
	Steve.SkillPointsTotal = Default.SkillPointsTotal;
	if ( Default.Portal!="" )
		Steve.Portal = Default.Portal;

	Log( "HXFixSaveWorld: loaded" @ Default.SavedMap @ "flags" @ Default.NumFlags @ "goals" @ Default.NumGoals @ "keys" @ Default.NumKeys, 'HXFixSave' );
	return True;
}

// Rebuilds the note list of the game (newest first, same order HXGameInfo keeps).
static function int RestoreNotes( HXFixGameInfo G )
{
	local DeusExNote Note;
	local string S, Tag;
	local int i;

	G.FirstNote = None;
	G.LastNote  = None;
	for ( i=0; i<Default.NumNotes; i++ )
	{
		S    = Default.NoteLine[i];
		Note = new(None,'',RF_Transient) Class'DeusExNote';
		Note.Text = class'HXFixNoteStore'.static.Unescape( Rest(S,2) );
		Note.SetUserNote( Part(S,1)=="1" );
		Tag = Part( S, 0 );
		if ( Tag!="" && Tag!="None" )
			Note.SetTextTag( class'HXActor'.static.StringToName(Tag) );
		if ( G.LastNote==None )
			G.FirstNote = Note;
		else
			G.LastNote.Next = Note;
		G.LastNote = Note;
	}
	return i;
}

static function Clear()
{
	local int i;

	for ( i=0; i<MaxFlags; i++ )
		Default.Flag[i] = "";
	for ( i=0; i<MaxGoals; i++ )
		Default.Goal[i] = "";
	for ( i=0; i<MaxNotes; i++ )
		Default.NoteLine[i] = "";
	for ( i=0; i<MaxKeys; i++ )
		Default.Key[i] = "";
	for ( i=0; i<MaxImages; i++ )
		Default.Image[i] = "";
	Default.NumFlags = 0;
	Default.NumGoals = 0;
	Default.NumNotes = 0;
	Default.NumKeys  = 0;
	Default.SavedMap = "";
	StaticSaveConfig();
}
