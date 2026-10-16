//=============================================================================
// HXFixUdpServerQuery.
//
// HX's SendPlayers loops until it has counted Level.Game.NumPlayers player
// pawns, without stopping at the end of the PawnList. If NumPlayers is ever
// higher than the real count (mid login/logout, after travel pruning), any
// server browser query hits a runaway loop, which crashes the server.
//=============================================================================
class HXFixUdpServerQuery extends HXUdpServerQuery;

function bool SendPlayers( IpAddr Addr, int QueryNum, out int PacketNum, int bFinalPacket )
{
	local Pawn P;
	local int i, Num;
	local bool Result;

	for ( P=Level.PawnList; P!=None; P=P.NextPawn )
		if ( P.IsA('PlayerPawn') )
			Num++;
	Num = Min( Num, Level.Game.NumPlayers );

	for ( P=Level.PawnList; P!=None && i<Num; P=P.NextPawn )
	{
		if ( !P.IsA('PlayerPawn') )
			continue;

		if ( i==Num-1 && bFinalPacket==1 )
			Result = SendQueryPacket( Addr, GetPlayer(PlayerPawn(P), i), QueryNum, PacketNum, 1 ) || Result;
		else
			Result = SendQueryPacket( Addr, GetPlayer(PlayerPawn(P), i), QueryNum, PacketNum, 0 ) || Result;
		i++;
	}

	return Result;
}
