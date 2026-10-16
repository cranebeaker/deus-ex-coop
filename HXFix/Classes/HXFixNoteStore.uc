//=============================================================================
// HXFixNoteStore.
//
// Server side datavault notes, kept in HXFix.ini across map changes and
// server restarts. HX itself dropped all notes on every travel.
//=============================================================================
class HXFixNoteStore extends Object
	config(HXFix);

const MaxNotes = 256;

var config int    NumNotes;
var config string Text[256];
var config string Tag[256];
var config byte   bUserNote[256];

static function string Escape( string S )
{
	class'HXActor'.static.ReplaceText( S, Chr(13), "{CR}" );
	class'HXActor'.static.ReplaceText( S, Chr(10), "{LF}" );
	return S;
}

static function string Unescape( string S )
{
	class'HXActor'.static.ReplaceText( S, "{CR}", Chr(13) );
	class'HXActor'.static.ReplaceText( S, "{LF}", Chr(10) );
	return S;
}

// Stores the list newest first, the same order HXGameInfo keeps it in.
static function Save( DeusExNote FirstNote )
{
	local DeusExNote Note;
	local int i;

	for ( Note=FirstNote; Note!=None && i<MaxNotes; Note=Note.Next )
	{
		Default.Text[i]      = Escape( Note.Text );
		Default.Tag[i]       = string(Note.TextTag);
		Default.bUserNote[i] = byte(Note.bUserNote);
		i++;
	}
	Default.NumNotes = i;
	StaticSaveConfig();
}

static function int Count()
{
	return Default.NumNotes;
}

static function string GetText( int i )
{
	return Unescape( Default.Text[i] );
}

static function string GetTag( int i )
{
	return Default.Tag[i];
}

static function bool GetUserNote( int i )
{
	return Default.bUserNote[i]!=0;
}

static function Clear()
{
	Default.NumNotes = 0;
	StaticSaveConfig();
}
