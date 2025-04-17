#include <amxmodx>
#include <sockets>
#include <json>
#include <fakemeta>

#define CONFIG_FILE "gravebot_ai_config.json"

new g_Socket;
new g_Host[64];
new g_Port;
new Float:g_TickRate;
new g_BotIds[32];
new g_BotCount;

// List of GraveBot commands
static const g_Commands[][] = {
    "help", "create <type> [team]", "remove <bot_name|id|all>",
    "kill <bot_name|id|all>", "rename <old_name> <new_name>",
    "team <bot_name|id> <team>", "respawn <bot_name|id>",
    "respawnall", "stats [bot_name|id]", "info [bot_name|id]",
    "pause [bot_name|id|all]", "resume <bot_name|id|all>",
    "chat [on|off]", "debug [on|off]", "path <bot_name|id>",
    "goal <bot_name|id> <x> <y> <z>", "follow <bot_name|id> [player_name]",
    "attack <bot_name|id> <target_name|id>",
    "give <bot_name|id> <weapon_name> [ammo]", "armor <bot_name|id> [amount]",
    "health <bot_name|id> [amount]", "reload",
    "script <bot_name|id> <script_file>",
    "sentinel <bot_name|id> [on|off]",
    "noclip <bot_name|id> [on|off]", "dump <filename>"
};

public plugin_init()
{
    register_plugin("GraveBot AI Bridge", "1.5", "You");
    read_config_string(CONFIG_FILE, "host", g_Host, sizeof(g_Host));
    g_Port = read_config_int(CONFIG_FILE, "port", 5000);
    g_TickRate = read_config_float(CONFIG_FILE, "tick_rate", 0.1);

    new error;
    g_Socket = socket_open(g_Host, g_Port, SOCKET_TCP, error, SOCK_NONBLOCKING|SOCK_LIBC_ERRORS);
    if (g_Socket == -1) {
        log_amx("GraveBot-AI: socket_open failed (%d)", error);
        return;
    }

    // Send COMMAND_LIST handshake
    new buf[2048]; new pos = format(buf, sizeof(buf), "COMMAND_LIST");
    for (new i = 0; i < sizeof g_Commands; i++) {
        pos += format(buf[pos], sizeof(buf)-pos, ";%s", g_Commands[i]);
    }
    socket_write(g_Socket, buf, pos);

    // Hook chat
    register_message("SayText2", "OnSayText2");
    set_task(g_TickRate, "BridgeTick", _, _, _, "rh");
}

stock UpdateBotList()
{
    g_BotCount = GetBotCount();
    for (new i = 0; i < g_BotCount; i++) {
        g_BotIds[i] = GetBotIdByIndex(i);
    }
}

public BridgeTick()
{
    UpdateBotList();

    new jsonBuf[2048];
    BuildGameState(jsonBuf, sizeof(jsonBuf));
    socket_write(g_Socket, jsonBuf, strlen(jsonBuf));

    new inBuf[256];
    new read = socket_read(g_Socket, inBuf, sizeof(inBuf)-1);
    if (read > 0) {
        inBuf[read] = '\0'; trim(inBuf);
        if (strncmp(inBuf, "CHAT:", 5) == 0) {
            new msg[256];
            strcopy(msg, sizeof(msg), inBuf[5]);
            server_cmd("say %s", msg);
            new writeBuf[300]; new wlen = format(writeBuf, sizeof(writeBuf), "TTS:%s", msg);
            socket_write(g_Socket, writeBuf, wlen);
        } else {
            set_cvar_string("gravebot", inBuf);
        }
    }

    set_task(g_TickRate, "BridgeTick", _, _, _, "rh");
}

stock BuildGameState(dest[], destlen)
{
    new obj = JSON_CreateObject();
    new map[64]; get_mapname(map, sizeof(map));
    JSON_SetString(obj, "map", map);
    new Float:limit = get_cvar_float("mp_timelimit") * 60.0;
    new Float:elapsed = get_cvar_float("mp_time");
    JSON_SetNumber(obj, "time_left", limit - elapsed);

    new arr = JSON_CreateArray();
    new botCount = GetBotCount();
    for (new idx = 0; idx < botCount; idx++) {
        new id = GetBotIdByIndex(idx);
        new bot = JSON_CreateObject();
        JSON_SetNumber(bot, "id", id);
        new r = GetBotRole(id), sr = GetBotSubrole(id);
        static const ROLE_NAMES[][] = {"ROLE_NONE","ROLE_DEFEND","ROLE_ATTACK"};
        static const SUBROLE_NAMES[][] = {
            "ROLE_SUB_NONE","ROLE_SUB_ATT_GET_SCI","ROLE_SUB_ATT_RTRN_SCI",
            "ROLE_SUB_ATT_KILL_SCI","ROLE_SUB_ATT_GET_RSRC","ROLE_SUB_ATT_RTRN_RSRC",
            "ROLE_SUB_ATT_BREAK","ROLE_SUB_DEF_ALLY","ROLE_SUB_DEF_SCIS",
            "ROLE_SUB_DEF_BASE","ROLE_SUB_DEF_RSRC","ROLE_SUB_DEF_BREAK"
        };
        JSON_SetString(bot, "role", ROLE_NAMES[r]);
        JSON_SetString(bot, "subrole", sr <= 11 ? SUBROLE_NAMES[sr] : "UNKNOWN");
        new Float:origin[3]; get_user_origin(id, origin);
        JSON_SetNumber(bot, "x", origin[0]); JSON_SetNumber(bot, "y", origin[1]);
        JSON_SetNumber(bot, "z", origin[2]);
        JSON_SetNumber(bot, "health", get_user_health(id));
        JSON_SetNumber(bot, "armor", get_user_armor(id));
        JSON_ArrayAdd(arr, bot);
    }
    JSON_SetArray(obj, "bots", arr);
    JSON_Print(dest, destlen, obj); JSON_Delete(obj);
    return strlen(dest);
}

public OnSayText2(id, msg_id, msg_name[], buffer[])
{
    new sender = read_byte(buffer);
    new text[192]; msg_read_string(buffer, text, charsmax(text));
    for (new i = 0; i < g_BotCount; i++) {
        if (sender == g_BotIds[i]) {
            new out[256]; new len = format(out, sizeof(out), "TTS:%s", text);
            socket_write(g_Socket, out, len);
            break;
        }
    }
    return PLUGIN_CONTINUE;
}
