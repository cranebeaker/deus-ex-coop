//=============================================================================
// HXFixNanoKeyInfo.
//
// Stock HasNanoKey() looks the slots up with GetPropertyText/Sprintf, which
// return empty strings on a remote client, so every client side datalink
// "NK_" check failed. This one reads the slots directly. Also reuses blanked
// slots so keys added and removed repeatedly cannot exhaust the 128 slots.
// Key IDs (for datalink NK_ checks) live in their own KeyIDs list: the key
// ring screen prints every NanoKey slot, so IDs there showed each key twice.
//=============================================================================
class HXFixNanoKeyInfo extends HXNanoKeyReplicationInfo;

const KEY_ID_MAX = 64;

var string KeyIDs[64];
var int KeyIDCount;

replication
{
	reliable if ( Role==ROLE_Authority )
		KeyIDs, KeyIDCount;
}

simulated function string SlotAt( int Index )
{
	switch ( Index )
	{
		case 0: return NanoKey0;
		case 1: return NanoKey1;
		case 2: return NanoKey2;
		case 3: return NanoKey3;
		case 4: return NanoKey4;
		case 5: return NanoKey5;
		case 6: return NanoKey6;
		case 7: return NanoKey7;
		case 8: return NanoKey8;
		case 9: return NanoKey9;
		case 10: return NanoKey10;
		case 11: return NanoKey11;
		case 12: return NanoKey12;
		case 13: return NanoKey13;
		case 14: return NanoKey14;
		case 15: return NanoKey15;
		case 16: return NanoKey16;
		case 17: return NanoKey17;
		case 18: return NanoKey18;
		case 19: return NanoKey19;
		case 20: return NanoKey20;
		case 21: return NanoKey21;
		case 22: return NanoKey22;
		case 23: return NanoKey23;
		case 24: return NanoKey24;
		case 25: return NanoKey25;
		case 26: return NanoKey26;
		case 27: return NanoKey27;
		case 28: return NanoKey28;
		case 29: return NanoKey29;
		case 30: return NanoKey30;
		case 31: return NanoKey31;
		case 32: return NanoKey32;
		case 33: return NanoKey33;
		case 34: return NanoKey34;
		case 35: return NanoKey35;
		case 36: return NanoKey36;
		case 37: return NanoKey37;
		case 38: return NanoKey38;
		case 39: return NanoKey39;
		case 40: return NanoKey40;
		case 41: return NanoKey41;
		case 42: return NanoKey42;
		case 43: return NanoKey43;
		case 44: return NanoKey44;
		case 45: return NanoKey45;
		case 46: return NanoKey46;
		case 47: return NanoKey47;
		case 48: return NanoKey48;
		case 49: return NanoKey49;
		case 50: return NanoKey50;
		case 51: return NanoKey51;
		case 52: return NanoKey52;
		case 53: return NanoKey53;
		case 54: return NanoKey54;
		case 55: return NanoKey55;
		case 56: return NanoKey56;
		case 57: return NanoKey57;
		case 58: return NanoKey58;
		case 59: return NanoKey59;
		case 60: return NanoKey60;
		case 61: return NanoKey61;
		case 62: return NanoKey62;
		case 63: return NanoKey63;
		case 64: return NanoKey64;
		case 65: return NanoKey65;
		case 66: return NanoKey66;
		case 67: return NanoKey67;
		case 68: return NanoKey68;
		case 69: return NanoKey69;
		case 70: return NanoKey70;
		case 71: return NanoKey71;
		case 72: return NanoKey72;
		case 73: return NanoKey73;
		case 74: return NanoKey74;
		case 75: return NanoKey75;
		case 76: return NanoKey76;
		case 77: return NanoKey77;
		case 78: return NanoKey78;
		case 79: return NanoKey79;
		case 80: return NanoKey80;
		case 81: return NanoKey81;
		case 82: return NanoKey82;
		case 83: return NanoKey83;
		case 84: return NanoKey84;
		case 85: return NanoKey85;
		case 86: return NanoKey86;
		case 87: return NanoKey87;
		case 88: return NanoKey88;
		case 89: return NanoKey89;
		case 90: return NanoKey90;
		case 91: return NanoKey91;
		case 92: return NanoKey92;
		case 93: return NanoKey93;
		case 94: return NanoKey94;
		case 95: return NanoKey95;
		case 96: return NanoKey96;
		case 97: return NanoKey97;
		case 98: return NanoKey98;
		case 99: return NanoKey99;
		case 100: return NanoKey100;
		case 101: return NanoKey101;
		case 102: return NanoKey102;
		case 103: return NanoKey103;
		case 104: return NanoKey104;
		case 105: return NanoKey105;
		case 106: return NanoKey106;
		case 107: return NanoKey107;
		case 108: return NanoKey108;
		case 109: return NanoKey109;
		case 110: return NanoKey110;
		case 111: return NanoKey111;
		case 112: return NanoKey112;
		case 113: return NanoKey113;
		case 114: return NanoKey114;
		case 115: return NanoKey115;
		case 116: return NanoKey116;
		case 117: return NanoKey117;
		case 118: return NanoKey118;
		case 119: return NanoKey119;
		case 120: return NanoKey120;
		case 121: return NanoKey121;
		case 122: return NanoKey122;
		case 123: return NanoKey123;
		case 124: return NanoKey124;
		case 125: return NanoKey125;
		case 126: return NanoKey126;
		case 127: return NanoKey127;
	}
	return "";
}

simulated function bool HasNanoKey( string Key )
{
	local int i;

	if ( Key=="" )
		return False;

	for ( i=0; i<KeyIDCount && i<KEY_ID_MAX; i++ )
		if ( KeyIDs[i]~=Key )
			return True;
	for ( i=0; i<NanoKeyCount && i<NANO_KEY_MAX_COUNT; i++ )
		if ( SlotAt(i)~=Key )
			return True;
	return False;
}

simulated function bool HasKeyID( string KeyID )
{
	local int i;

	for ( i=0; i<KeyIDCount && i<KEY_ID_MAX; i++ )
		if ( KeyIDs[i]~=KeyID )
			return True;
	return False;
}

// Server: reuse a blanked ID slot before growing.
function AddKeyID( string KeyID )
{
	local int i;

	if ( KeyID=="" || HasKeyID(KeyID) )
		return;
	for ( i=0; i<KeyIDCount; i++ )
		if ( KeyIDs[i]=="" )
		{
			KeyIDs[i] = KeyID;
			return;
		}
	if ( KeyIDCount>=KEY_ID_MAX )
	{
		Log( "HXFix: no room for key ID replication: " $ KeyID );
		return;
	}
	KeyIDs[KeyIDCount++] = KeyID;
}

// Server: reuse a blanked slot before growing.
function AddNanoKey( string Key )
{
	local int i;

	if ( Key=="" )
		return;
	for ( i=0; i<NanoKeyCount; i++ )
		if ( SlotAt(i)=="" )
		{
			SetPropertyText( "NanoKey" $ i, Key );
			return;
		}
	if ( NanoKeyCount>(NANO_KEY_MAX_COUNT-2) )
	{
		Log( "HXFix: no room for NanoKey replication: " $ Key );
		return;
	}
	SetPropertyText( "NanoKey" $ NanoKeyCount, Key );
	NanoKeyCount++;
}

// Server: blank slot holding Key (any case).
function RemoveNanoKey( string Key )
{
	local int i;

	if ( Key=="" )
		return;
	for ( i=0; i<NanoKeyCount; i++ )
		if ( SlotAt(i)~=Key )
		{
			SetPropertyText( "NanoKey" $ i, "" );
			return;
		}
}
