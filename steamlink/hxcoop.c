/*
 * HXCoop: Steam ("Spacewar", AppID 480) relay for HX Deus Ex co-op.
 *
 * Players never deal with IP addresses or port forwarding:
 *  - host:  creates a friends-only Steam lobby, starts HX.exe as a listen server and
 *           relays every friend's packets between Steam and the local game port;
 *  - join:  finds Steam friends who host (or takes a lobby id / invite), binds a local
 *           UDP port and starts HX.exe connected to it, relaying to the host over Steam.
 * UE1 does its own reliability, so packets go as unreliable Steam messages on channel 0.
 * Channel 1 carries a 1 s keep-alive and a goodbye.
 * Game packets carry a 1 byte connection id in both directions. On a map change the game
 * opens a new connection from a new local port while the old one still sends for a moment;
 * each client side source address gets its own id, and the host side gives each id its own
 * socket (so its own source port), or the server takes the new handshake for the old
 * connection.
 *
 * steam_api.dll is loaded at runtime through the flat C API (no SDK headers), see
 * spacewar.md. Needs steam_appid.txt = 480 in the working directory.
 *
 *   HXCoop.exe                    menu
 *   HXCoop.exe host [map]         host, default map 01_NYC_UNATCOIsland
 *   HXCoop.exe join [lobby id]    join (no id: a friend who is hosting)
 * Options: --game <dir with HX.exe>  --port <game port, 7790>  --url-extra <?opts for the host URL>
 *          --hx-args <extra HX.exe arguments>  --no-launch (relay only)
 */
#define WIN32_LEAN_AND_MEAN
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <conio.h>

typedef uint64_t u64;

/* ---------------------------------------------------------------- steam flat api */

typedef struct { int32_t user; int32_t callback; uint8_t *param; int32_t param_size; } CallbackMsg;
#pragma pack(push, 8)
typedef struct { u64 call; int32_t callback; uint32_t param_size; } APICallCompleted;
typedef struct { int32_t result; u64 lobby; } LobbyCreated;
typedef struct { u64 lobby; uint32_t perms; bool locked; uint32_t response; } LobbyEnter;
typedef struct { u64 lobby, user_changed, making_change; uint32_t state; } LobbyChatUpdate;
typedef struct { u64 lobby, friend_id; } GameLobbyJoinRequested;
typedef struct { u64 friend_id; char connect[256]; } GameRichPresenceJoinRequested;
typedef struct { u64 game_id; uint32_t ip; uint16_t port, query_port; u64 lobby; } FriendGameInfo;
#pragma pack(pop)

#define CB_LOBBY_JOIN_REQUESTED 333
#define CB_RICH_PRESENCE_JOIN   337
#define CB_LOBBY_ENTER          504
#define CB_LOBBY_CHAT_UPDATE    506
#define CB_LOBBY_CREATED        513
#define CB_CALL_COMPLETED       703
#define CB_SESSION_REQUEST      1251
#define CB_SESSION_FAILED       1252

#define SEND_UNRELIABLE_NO_NAGLE 1
#define SEND_RELIABLE            8
#define IDENT_SIZE               160 /* real size 136, kept opaque */

static struct {
    bool (__cdecl *IsSteamRunning)(void);
    int (__cdecl *InitFlat)(char *err);
    void (__cdecl *Shutdown)(void);
    int32_t (__cdecl *GetHSteamPipe)(void);
    void (__cdecl *DispatchInit)(void);
    void (__cdecl *RunFrame)(int32_t);
    bool (__cdecl *GetNextCallback)(int32_t, CallbackMsg *);
    void (__cdecl *FreeLastCallback)(int32_t);
    bool (__cdecl *GetAPICallResult)(int32_t, u64, void *, int, int, bool *);
    void *(__cdecl *User)(void);
    void *(__cdecl *Matchmaking)(void);
    void *(__cdecl *Friends)(void);
    void *(__cdecl *Messages)(void);
    void *(__cdecl *Utils)(void);
    u64 (__cdecl *GetSteamID)(void *);
    u64 (__cdecl *CreateLobby)(void *, int, int);
    u64 (__cdecl *JoinLobby)(void *, u64);
    void (__cdecl *LeaveLobby)(void *, u64);
    bool (__cdecl *SetLobbyData)(void *, u64, const char *, const char *);
    const char *(__cdecl *GetLobbyData)(void *, u64, const char *);
    u64 (__cdecl *GetLobbyOwner)(void *, u64);
    bool (__cdecl *SetRichPresence)(void *, const char *, const char *);
    void (__cdecl *InviteDialog)(void *, u64);
    int (__cdecl *GetFriendCount)(void *, int);
    u64 (__cdecl *GetFriendByIndex)(void *, int, int);
    bool (__cdecl *GetFriendGamePlayed)(void *, u64, FriendGameInfo *);
    const char *(__cdecl *GetFriendPersonaName)(void *, u64);
    const char *(__cdecl *GetPersonaName)(void *);
    void (__cdecl *IdentSet)(void *, u64);
    u64 (__cdecl *IdentGet)(const void *);
    int (__cdecl *SendMessageToUser)(void *, const void *, const void *, uint32_t, int, int);
    int (__cdecl *ReceiveMessages)(void *, int, void **, int);
    bool (__cdecl *AcceptSession)(void *, const void *);
    bool (__cdecl *CloseSession)(void *, const void *);
    void (__cdecl *MessageRelease)(void *);
    bool (__cdecl *SetConfigInt)(void *, int, int32_t);
    void (__cdecl *InitRelay)(void *);
} S;

static void *g_user, *g_mm, *g_friends, *g_msgs, *g_utils;
static int32_t g_pipe;
static u64 g_me;

static void fail(const char *msg)
{
    printf("\n%s\n\nPress a key to close.\n", msg);
    _getch();
    exit(1);
}

static FARPROC need(HMODULE m, const char *name)
{
    FARPROC p = GetProcAddress(m, name);
    if (!p) {
        char buf[300];
        snprintf(buf, sizeof(buf), "steam_api.dll is missing %s (too old?).", name);
        fail(buf);
    }
    return p;
}

#define LOAD(field, name) *(FARPROC *)&S.field = need(m, name)
#define LOAD_OPT(field, name) *(FARPROC *)&S.field = GetProcAddress(m, name)

static void steam_start(void)
{
    FILE *f = fopen("steam_appid.txt", "r");
    if (f) fclose(f);
    else if ((f = fopen("steam_appid.txt", "w"))) { fputs("480", f); fclose(f); }

    HMODULE m = LoadLibraryA("steam_api.dll");
    if (!m) fail("steam_api.dll not found next to HXCoop.exe.");
    LOAD(IsSteamRunning, "SteamAPI_IsSteamRunning");
    LOAD(InitFlat, "SteamAPI_InitFlat");
    LOAD(Shutdown, "SteamAPI_Shutdown");
    LOAD(GetHSteamPipe, "SteamAPI_GetHSteamPipe");
    LOAD(DispatchInit, "SteamAPI_ManualDispatch_Init");
    LOAD(RunFrame, "SteamAPI_ManualDispatch_RunFrame");
    LOAD(GetNextCallback, "SteamAPI_ManualDispatch_GetNextCallback");
    LOAD(FreeLastCallback, "SteamAPI_ManualDispatch_FreeLastCallback");
    LOAD(GetAPICallResult, "SteamAPI_ManualDispatch_GetAPICallResult");
    LOAD(User, "SteamAPI_SteamUser_v023");
    LOAD(Matchmaking, "SteamAPI_SteamMatchmaking_v009");
    LOAD(Friends, "SteamAPI_SteamFriends_v018");
    LOAD(Messages, "SteamAPI_SteamNetworkingMessages_SteamAPI_v002");
    LOAD(Utils, "SteamAPI_SteamNetworkingUtils_SteamAPI_v004");
    LOAD(GetSteamID, "SteamAPI_ISteamUser_GetSteamID");
    LOAD(CreateLobby, "SteamAPI_ISteamMatchmaking_CreateLobby");
    LOAD(JoinLobby, "SteamAPI_ISteamMatchmaking_JoinLobby");
    LOAD(LeaveLobby, "SteamAPI_ISteamMatchmaking_LeaveLobby");
    LOAD(SetLobbyData, "SteamAPI_ISteamMatchmaking_SetLobbyData");
    LOAD(GetLobbyData, "SteamAPI_ISteamMatchmaking_GetLobbyData");
    LOAD(GetLobbyOwner, "SteamAPI_ISteamMatchmaking_GetLobbyOwner");
    LOAD(SetRichPresence, "SteamAPI_ISteamFriends_SetRichPresence");
    LOAD(InviteDialog, "SteamAPI_ISteamFriends_ActivateGameOverlayInviteDialog");
    LOAD(GetFriendCount, "SteamAPI_ISteamFriends_GetFriendCount");
    LOAD(GetFriendByIndex, "SteamAPI_ISteamFriends_GetFriendByIndex");
    LOAD(GetFriendGamePlayed, "SteamAPI_ISteamFriends_GetFriendGamePlayed");
    LOAD(GetFriendPersonaName, "SteamAPI_ISteamFriends_GetFriendPersonaName");
    LOAD(GetPersonaName, "SteamAPI_ISteamFriends_GetPersonaName");
    LOAD(IdentSet, "SteamAPI_SteamNetworkingIdentity_SetSteamID64");
    LOAD(IdentGet, "SteamAPI_SteamNetworkingIdentity_GetSteamID64");
    LOAD(SendMessageToUser, "SteamAPI_ISteamNetworkingMessages_SendMessageToUser");
    LOAD(ReceiveMessages, "SteamAPI_ISteamNetworkingMessages_ReceiveMessagesOnChannel");
    LOAD(AcceptSession, "SteamAPI_ISteamNetworkingMessages_AcceptSessionWithUser");
    LOAD(CloseSession, "SteamAPI_ISteamNetworkingMessages_CloseSessionWithUser");
    LOAD(MessageRelease, "SteamAPI_SteamNetworkingMessage_t_Release");
    LOAD(SetConfigInt, "SteamAPI_ISteamNetworkingUtils_SetGlobalConfigValueInt32");
    LOAD_OPT(InitRelay, "SteamAPI_ISteamNetworkingUtils_InitRelayNetworkAccess");

    if (!S.IsSteamRunning()) fail("Steam is not running. Start Steam, log in, and try again.");
    char err[1024] = "";
    int r = S.InitFlat(err);
    if (r != 0) {
        char buf[1200];
        snprintf(buf, sizeof(buf), "Could not connect to Steam (code %d): %s", r, err);
        fail(buf);
    }
    S.DispatchInit();
    g_pipe = S.GetHSteamPipe();
    g_user = S.User(); g_mm = S.Matchmaking(); g_friends = S.Friends();
    g_msgs = S.Messages(); g_utils = S.Utils();
    g_me = S.GetSteamID(g_user);
    if (S.InitRelay) S.InitRelay(g_utils);
}

static void ident(void *buf, u64 sid) { memset(buf, 0, IDENT_SIZE); S.IdentSet(buf, sid); }

/* Sender of a received SteamNetworkingMessage_t: identity at 16 (32 bit MSVC layout), 12 as fallback. */
static u64 msg_sender(void *msg)
{
    u64 sid = S.IdentGet((char *)msg + 16);
    if (!sid) sid = S.IdentGet((char *)msg + 12);
    return sid;
}

static int send_to(u64 sid, const void *data, int size, int flags, int channel)
{
    unsigned char id[IDENT_SIZE];
    ident(id, sid);
    return S.SendMessageToUser(g_msgs, id, data, (uint32_t)size, flags, channel);
}

static void accept_session(u64 sid)
{
    unsigned char id[IDENT_SIZE];
    ident(id, sid);
    S.AcceptSession(g_msgs, id);
}

static void close_session(u64 sid)
{
    unsigned char id[IDENT_SIZE];
    ident(id, sid);
    S.CloseSession(g_msgs, id);
}

static const char *friend_name(u64 sid)
{
    const char *n = S.GetFriendPersonaName(g_friends, sid);
    return n && *n ? n : "?";
}

/* ---------------------------------------------------------------- options, game launch */

static char g_game_dir[MAX_PATH];
static int g_port = 7790;
static char g_url_extra[512];
static char g_hx_args[1024];
static bool g_no_launch;
static HANDLE g_game;

static void find_game_dir(void)
{
    char exe[MAX_PATH], *slash;
    GetModuleFileNameA(NULL, exe, sizeof(exe));
    if ((slash = strrchr(exe, '\\'))) *slash = 0;
    const char *tries[] = { "%s\\..\\HX.exe", "%s\\HX.exe", "%s\\System\\HX.exe" };
    for (int i = 0; i < 3; i++) {
        char p[MAX_PATH];
        snprintf(p, sizeof(p), tries[i], exe);
        if (GetFileAttributesA(p) != INVALID_FILE_ATTRIBUTES) {
            char full[MAX_PATH];
            GetFullPathNameA(p, sizeof(full), full, NULL);
            if ((slash = strrchr(full, '\\'))) *slash = 0;
            snprintf(g_game_dir, sizeof(g_game_dir), "%s", full);
            return;
        }
    }
}

static void launch_hx(const char *url)
{
    if (g_no_launch) return;
    char cmd[2048], exe[MAX_PATH];
    snprintf(exe, sizeof(exe), "%s\\HX.exe", g_game_dir);
    snprintf(cmd, sizeof(cmd), "\"%s\" \"%s\" %s", exe, url, g_hx_args);
    STARTUPINFOA si; PROCESS_INFORMATION pi;
    memset(&si, 0, sizeof(si)); si.cb = sizeof(si);
    if (!CreateProcessA(exe, cmd, NULL, NULL, FALSE, 0, NULL, g_game_dir, &si, &pi)) {
        char buf[MAX_PATH + 100];
        snprintf(buf, sizeof(buf), "Could not start %s (error %lu).", exe, GetLastError());
        fail(buf);
    }
    CloseHandle(pi.hThread);
    g_game = pi.hProcess;
    printf("Started HX: %s\n", url);
}

static bool game_exited(void)
{
    return g_game && WaitForSingleObject(g_game, 0) == WAIT_OBJECT_0;
}

/* ---------------------------------------------------------------- callbacks */

typedef void (*CbHandler)(int id, void *data);

static void pump(CbHandler h)
{
    CallbackMsg msg;
    S.RunFrame(g_pipe);
    while (S.GetNextCallback(g_pipe, &msg)) {
        if (msg.callback == CB_CALL_COMPLETED) {
            APICallCompleted *done = (APICallCompleted *)msg.param;
            void *buf = calloc(1, done->param_size + 16);
            bool failed = true;
            if (S.GetAPICallResult(g_pipe, done->call, buf, done->param_size, done->callback, &failed) && !failed)
                h(done->callback, buf);
            free(buf);
        } else
            h(msg.callback, msg.param);
        S.FreeLastCallback(g_pipe);
    }
}

/* ---------------------------------------------------------------- udp helpers */

static SOCKET udp_socket(int port)
{
    SOCKET s = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    struct sockaddr_in a; memset(&a, 0, sizeof(a));
    a.sin_family = AF_INET; a.sin_addr.s_addr = htonl(INADDR_LOOPBACK); a.sin_port = htons((u_short)port);
    if (bind(s, (struct sockaddr *)&a, sizeof(a)) != 0) { closesocket(s); return INVALID_SOCKET; }
    u_long nb = 1; ioctlsocket(s, FIONBIO, &nb);
    DWORD bytes; BOOL off = FALSE; /* SIO_UDP_CONNRESET: ignore ICMP port unreachable */
    WSAIoctl(s, 0x9800000C, &off, sizeof(off), NULL, 0, &bytes, NULL, NULL);
    int buf = 1 << 20;
    setsockopt(s, SOL_SOCKET, SO_RCVBUF, (char *)&buf, sizeof(buf));
    setsockopt(s, SOL_SOCKET, SO_SNDBUF, (char *)&buf, sizeof(buf));
    return s;
}

static int local_port(SOCKET s)
{
    struct sockaddr_in a; int len = sizeof(a);
    getsockname(s, (struct sockaddr *)&a, &len);
    return ntohs(a.sin_port);
}

static void relay_config(void)
{
    /* k_ESteamNetworkingConfig_SendBufferSize 9, RecvBufferSize 47, RecvMaxMessageSize 49 */
    S.SetConfigInt(g_utils, 9, 4 << 20);
    S.SetConfigInt(g_utils, 47, 4 << 20);
}

/* ---------------------------------------------------------------- host */

#define MAX_PEERS 16
#define MAX_CONNS 8
typedef struct { int id; SOCKET s; DWORD last; } Conn;
typedef struct { u64 sid; Conn conns[MAX_CONNS]; DWORD last_heard, last_ping; } Peer;
static Peer g_peers[MAX_PEERS];
static u64 g_lobby;
static bool g_lobby_failed;

static Peer *find_peer(u64 sid)
{
    for (int i = 0; i < MAX_PEERS; i++) if (g_peers[i].sid == sid) return &g_peers[i];
    return NULL;
}

static void drop_peer(Peer *p, const char *why)
{
    if (!p || !p->sid) return;
    printf("%s left (%s).\n", friend_name(p->sid), why);
    for (int i = 0; i < MAX_CONNS; i++) if (p->conns[i].s) closesocket(p->conns[i].s);
    close_session(p->sid);
    memset(p, 0, sizeof(*p));
}

static SOCKET game_socket(void)
{
    SOCKET s = udp_socket(0);
    if (s == INVALID_SOCKET) return s;
    struct sockaddr_in a; memset(&a, 0, sizeof(a));
    a.sin_family = AF_INET; a.sin_addr.s_addr = htonl(INADDR_LOOPBACK); a.sin_port = htons((u_short)g_port);
    connect(s, (struct sockaddr *)&a, sizeof(a));
    return s;
}

static Peer *add_peer(u64 sid)
{
    for (int i = 0; i < MAX_PEERS; i++) {
        Peer *p = &g_peers[i];
        if (p->sid) continue;
        memset(p, 0, sizeof(*p));
        p->sid = sid; p->last_heard = p->last_ping = GetTickCount();
        printf("%s connected through Steam.\n", friend_name(sid));
        return p;
    }
    return NULL;
}

/* The socket for one game connection of a peer, created on first use. Connections idle
   for 30 s are closed, the oldest one is reused when all slots are taken. */
static Conn *peer_conn(Peer *p, int id)
{
    Conn *free_slot = NULL, *oldest = &p->conns[0];
    for (int i = 0; i < MAX_CONNS; i++) {
        Conn *c = &p->conns[i];
        if (c->s && c->id == id) return c;
        if (!c->s && !free_slot) free_slot = c;
        if (c->last < oldest->last) oldest = c;
    }
    if (!free_slot) { closesocket(oldest->s); memset(oldest, 0, sizeof(*oldest)); free_slot = oldest; }
    free_slot->s = game_socket();
    if (free_slot->s == INVALID_SOCKET) { free_slot->s = 0; return NULL; }
    free_slot->id = id; free_slot->last = GetTickCount();
    return free_slot;
}

static void host_cb(int id, void *data)
{
    switch (id) {
    case CB_LOBBY_CREATED: {
        LobbyCreated *c = data;
        if (c->result != 1) { g_lobby_failed = true; break; }
        g_lobby = c->lobby;
        char buf[64];
        S.SetLobbyData(g_mm, g_lobby, "hxcoop", "1");
        S.SetLobbyData(g_mm, g_lobby, "host", S.GetPersonaName(g_friends));
        snprintf(buf, sizeof(buf), "+connect_lobby %llu", (unsigned long long)g_lobby);
        S.SetRichPresence(g_friends, "connect", buf);
        S.SetRichPresence(g_friends, "status", "Hosting Deus Ex HX co-op");
        break;
    }
    case CB_SESSION_REQUEST: {
        u64 sid = S.IdentGet(data);
        accept_session(sid);
        break;
    }
    case CB_SESSION_FAILED: {
        u64 sid = S.IdentGet((char *)data + 0);
        drop_peer(find_peer(sid), "connection failed");
        break;
    }
    case CB_LOBBY_CHAT_UPDATE: {
        LobbyChatUpdate *u = data;
        if (u->state & (0x2 | 0x4 | 0x8 | 0x10)) drop_peer(find_peer(u->user_changed), "left the lobby");
        break;
    }
    }
}

static int run_host(const char *map)
{
    S.CreateLobby(g_mm, 1 /* friends only */, MAX_PEERS + 1);
    printf("Creating a friends-only Steam lobby...\n");
    DWORD t0 = GetTickCount();
    while (!g_lobby && !g_lobby_failed && GetTickCount() - t0 < 15000) { pump(host_cb); Sleep(20); }
    if (!g_lobby) fail("Steam did not create a lobby. Check that you are online in Steam.");

    char url[1024];
    snprintf(url, sizeof(url), "%s?Listen?Port=%d?Game=HXFix.HXFixGameInfo%s", map, g_port, g_url_extra);
    launch_hx(url);

    printf("\nHosting. Friends join by running HXCoop and choosing Join\n"
           "(or Steam friends list: right-click you -> Join Game, with HXCoop already open).\n"
           "Lobby id: %llu\nKeep this window open while you play. Close HX to stop.\n\n",
           (unsigned long long)g_lobby);

    static unsigned char buf[65536];
    for (;;) {
        pump(host_cb);
        void *msgs[64];
        int n;
        while ((n = S.ReceiveMessages(g_msgs, 0, msgs, 64)) > 0) {
            for (int i = 0; i < n; i++) {
                u64 sid = msg_sender(msgs[i]);
                Peer *p = find_peer(sid);
                if (!p) p = add_peer(sid);
                unsigned char *data = *(unsigned char **)msgs[i];
                int size = *(int *)((char *)msgs[i] + 4);
                if (p && size > 1) {
                    Conn *c = peer_conn(p, data[0]);
                    p->last_heard = GetTickCount();
                    if (c) { c->last = p->last_heard; send(c->s, (char *)data + 1, size - 1, 0); }
                }
                S.MessageRelease(msgs[i]);
            }
        }
        while ((n = S.ReceiveMessages(g_msgs, 1, msgs, 64)) > 0) {
            for (int i = 0; i < n; i++) {
                Peer *p = find_peer(msg_sender(msgs[i]));
                if (p) {
                    p->last_heard = GetTickCount();
                    if (*(int *)((char *)msgs[i] + 4) >= 1 && (*(char **)msgs[i])[0] == 'B') drop_peer(p, "quit");
                }
                S.MessageRelease(msgs[i]);
            }
        }
        DWORD now = GetTickCount();
        for (int i = 0; i < MAX_PEERS; i++) {
            Peer *p = &g_peers[i];
            if (!p->sid) continue;
            for (int k = 0; k < MAX_CONNS; k++) {
                Conn *c = &p->conns[k];
                int got;
                if (!c->s) continue;
                while ((got = recv(c->s, (char *)buf + 1, sizeof(buf) - 1, 0)) > 0) {
                    buf[0] = (unsigned char)c->id;
                    c->last = now;
                    send_to(p->sid, buf, got + 1, SEND_UNRELIABLE_NO_NAGLE, 0);
                }
                if (c->s && now - c->last > 30000) { closesocket(c->s); memset(c, 0, sizeof(*c)); }
            }
            if (now - p->last_ping > 1000) { p->last_ping = now; send_to(p->sid, "K", 1, SEND_RELIABLE, 1); }
            if (now - p->last_heard > 20000) drop_peer(p, "timed out");
        }
        if (game_exited()) break;
        Sleep(1);
    }
    for (int i = 0; i < MAX_PEERS; i++)
        if (g_peers[i].sid) { send_to(g_peers[i].sid, "B", 1, SEND_RELIABLE, 1); drop_peer(&g_peers[i], "host closed"); }
    S.LeaveLobby(g_mm, g_lobby);
    S.SetRichPresence(g_friends, "connect", "");
    S.SetRichPresence(g_friends, "status", "");
    for (int i = 0; i < 20; i++) { pump(host_cb); Sleep(10); }
    return 0;
}

/* ---------------------------------------------------------------- join */

static u64 g_join_lobby, g_host;
static bool g_join_failed;

static u64 parse_connect(const char *s)
{
    const char *p = strstr(s, "+connect_lobby");
    if (!p) return 0;
    return strtoull(p + 14, NULL, 10);
}

static void join_cb(int id, void *data)
{
    switch (id) {
    case CB_LOBBY_JOIN_REQUESTED:
        if (!g_join_lobby) g_join_lobby = ((GameLobbyJoinRequested *)data)->lobby;
        break;
    case CB_RICH_PRESENCE_JOIN:
        if (!g_join_lobby) g_join_lobby = parse_connect(((GameRichPresenceJoinRequested *)data)->connect);
        break;
    case CB_LOBBY_ENTER: {
        LobbyEnter *e = data;
        if (e->lobby != g_join_lobby) break;
        if (e->response != 1) { g_join_failed = true; break; }
        g_host = S.GetLobbyOwner(g_mm, e->lobby);
        break;
    }
    case CB_SESSION_REQUEST: {
        u64 sid = S.IdentGet(data);
        if (sid == g_host) accept_session(sid);
        break;
    }
    }
}

/* Friends who host: playing AppID 480 in a lobby that says hxcoop=1 (checked after joining). */
static int list_hosting_friends(u64 *lobbies, u64 *owners, int max)
{
    int n = 0, count = S.GetFriendCount(g_friends, 0x04 /* immediate */);
    for (int i = 0; i < count && n < max; i++) {
        u64 f = S.GetFriendByIndex(g_friends, i, 0x04);
        FriendGameInfo gi;
        memset(&gi, 0, sizeof(gi));
        if (!S.GetFriendGamePlayed(g_friends, f, &gi)) continue;
        if ((gi.game_id & 0xFFFFFF) != 480 || !gi.lobby) continue;
        lobbies[n] = gi.lobby; owners[n] = f; n++;
    }
    return n;
}

static void pick_lobby(void)
{
    u64 lobbies[32], owners[32];
    int shown = -1;
    printf("Looking for Steam friends who are hosting...\n"
           "(You can also accept a Steam invite, or type a lobby id and press Enter.)\n");
    char typed[64] = ""; int tl = 0;
    while (!g_join_lobby) {
        pump(join_cb);
        int n = list_hosting_friends(lobbies, owners, 32);
        if (n == 1) {
            printf("Found %s.\n", friend_name(owners[0]));
            g_join_lobby = lobbies[0];
            break;
        }
        if (n > 1 && n != shown) {
            printf("\nFriends hosting:\n");
            for (int i = 0; i < n; i++) printf("  %d) %s\n", i + 1, friend_name(owners[i]));
            printf("Type a number and press Enter: ");
            shown = n;
        }
        while (_kbhit()) {
            int c = _getch();
            if (c == '\r') {
                printf("\n");
                u64 v = strtoull(typed, NULL, 10);
                if (v >= 1 && v <= (u64)n) g_join_lobby = lobbies[v - 1];
                else if (v > 1000) g_join_lobby = v;
                tl = 0; typed[0] = 0;
            } else if (c >= '0' && c <= '9' && tl < 60) { typed[tl++] = (char)c; typed[tl] = 0; putchar(c); }
        }
        Sleep(50);
    }
}

static int run_join(u64 lobby)
{
    g_join_lobby = lobby;
    if (!g_join_lobby) pick_lobby();

    for (int attempt = 0; attempt < 3 && !g_host; attempt++) {
        g_join_failed = false;
        printf("Joining lobby %llu...\n", (unsigned long long)g_join_lobby);
        S.JoinLobby(g_mm, g_join_lobby);
        DWORD t0 = GetTickCount();
        while (!g_host && !g_join_failed && GetTickCount() - t0 < 15000) { pump(join_cb); Sleep(20); }
    }
    if (!g_host) fail("Could not join the lobby. Is your friend still hosting?");
    const char *tag = S.GetLobbyData(g_mm, g_join_lobby, "hxcoop");
    if (tag && *tag && strcmp(tag, "1") != 0) fail("That lobby is not an HX co-op game.");
    printf("Host: %s\n", friend_name(g_host));
    accept_session(g_host);

    SOCKET s = udp_socket(0);
    if (s == INVALID_SOCKET) fail("Could not open a local UDP port.");
    int port = local_port(s);
    char url[256];
    snprintf(url, sizeof(url), "127.0.0.1:%d", port);
    launch_hx(url);
    printf("Relaying 127.0.0.1:%d <-> %s over Steam. Keep this window open. Close HX to stop.\n", port, friend_name(g_host));

    /* one id per game source address (connection), see the top of the file */
    struct sockaddr_in games[MAX_CONNS]; DWORD games_last[MAX_CONNS]; int games_n = 0;
    unsigned char next_id = 0, ids[MAX_CONNS];
    static unsigned char buf[65536];
    DWORD last_heard = GetTickCount(), last_ping = 0, warned = 0;
    for (;;) {
        pump(join_cb);
        struct sockaddr_in from; int fl = sizeof(from), got;
        while ((got = recvfrom(s, (char *)buf + 1, sizeof(buf) - 1, 0, (struct sockaddr *)&from, &fl)) > 0) {
            int k;
            for (k = 0; k < games_n; k++)
                if (games[k].sin_port == from.sin_port && games[k].sin_addr.s_addr == from.sin_addr.s_addr) break;
            if (k == games_n) {
                if (games_n < MAX_CONNS) games_n++;
                else { k = 0; for (int j = 1; j < MAX_CONNS; j++) if (games_last[j] < games_last[k]) k = j; }
                games[k] = from; ids[k] = next_id++;
            }
            games_last[k] = GetTickCount();
            buf[0] = ids[k];
            send_to(g_host, buf, got + 1, SEND_UNRELIABLE_NO_NAGLE, 0);
            fl = sizeof(from);
        }
        void *msgs[64]; int n;
        while ((n = S.ReceiveMessages(g_msgs, 0, msgs, 64)) > 0) {
            for (int i = 0; i < n; i++) {
                unsigned char *data = *(unsigned char **)msgs[i];
                int size = *(int *)((char *)msgs[i] + 4);
                if (msg_sender(msgs[i]) == g_host && size > 1) {
                    last_heard = GetTickCount();
                    for (int k = 0; k < games_n; k++)
                        if (ids[k] == data[0]) { sendto(s, (char *)data + 1, size - 1, 0, (struct sockaddr *)&games[k], sizeof(games[k])); break; }
                }
                S.MessageRelease(msgs[i]);
            }
        }
        while ((n = S.ReceiveMessages(g_msgs, 1, msgs, 64)) > 0) {
            for (int i = 0; i < n; i++) {
                if (msg_sender(msgs[i]) == g_host) {
                    last_heard = GetTickCount();
                    if ((*(char **)msgs[i])[0] == 'B') printf("The host closed the game.\n");
                }
                S.MessageRelease(msgs[i]);
            }
        }
        DWORD now = GetTickCount();
        if (now - last_ping > 1000) { last_ping = now; send_to(g_host, "K", 1, SEND_RELIABLE, 1); }
        if (now - last_heard > 20000 && now - warned > 20000) { warned = now; printf("No answer from the host for 20 s...\n"); }
        if (game_exited()) break;
        if (g_no_launch && _kbhit() && _getch() == 27) break;
        Sleep(1);
    }
    send_to(g_host, "B", 1, SEND_RELIABLE, 1);
    S.LeaveLobby(g_mm, g_join_lobby);
    for (int i = 0; i < 20; i++) { pump(join_cb); Sleep(10); }
    close_session(g_host);
    return 0;
}

/* ---------------------------------------------------------------- main */

int main(int argc, char **argv)
{
    const char *mode = NULL, *arg = NULL;
    SetConsoleTitleA("HX Co-op (Steam)");
    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "--game") && i + 1 < argc) snprintf(g_game_dir, sizeof(g_game_dir), "%s", argv[++i]);
        else if (!strcmp(argv[i], "--port") && i + 1 < argc) g_port = atoi(argv[++i]);
        else if (!strcmp(argv[i], "--url-extra") && i + 1 < argc) snprintf(g_url_extra, sizeof(g_url_extra), "%s", argv[++i]);
        else if (!strcmp(argv[i], "--hx-args") && i + 1 < argc) snprintf(g_hx_args, sizeof(g_hx_args), "%s", argv[++i]);
        else if (!strcmp(argv[i], "--no-launch")) g_no_launch = true;
        else if (!strcmp(argv[i], "+connect_lobby") && i + 1 < argc) { mode = "join"; arg = argv[++i]; }
        else if (!mode) mode = argv[i];
        else if (!arg) arg = argv[i];
    }
    if (!g_game_dir[0]) find_game_dir();
    if (!g_no_launch && !g_game_dir[0]) fail("HX.exe not found. Put the HXCoop folder inside Deus Ex\\System.");

    WSADATA w;
    WSAStartup(MAKEWORD(2, 2), &w);
    steam_start();
    relay_config();
    printf("HX Co-op over Steam - signed in as %s\n\n", S.GetPersonaName(g_friends));

    if (!mode) {
        printf("  1) Host a game\n  2) Join a friend's game\n\nChoose 1 or 2: ");
        for (;;) {
            int c = _getch();
            if (c == '1') { mode = "host"; break; }
            if (c == '2') { mode = "join"; break; }
            if (c == 27) return 0;
        }
        printf("%c\n\n", mode[0] == 'h' ? '1' : '2');
    }
    int r;
    if (!_stricmp(mode, "host")) r = run_host(arg ? arg : "01_NYC_UNATCOIsland");
    else if (!_stricmp(mode, "join")) r = run_join(arg ? strtoull(arg, NULL, 10) : 0);
    else fail("Usage: HXCoop.exe [host [map] | join [lobby id]]");
    S.Shutdown();
    return r;
}
