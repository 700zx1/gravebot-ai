#include <amxmodx>
#include <sockets>
#include <json>
#include <fakemeta>
#include <config>
#include <string>
#include <amxmisc>

// --- GraveBot native declarations (inline) ---
native GetBotCount();
native GetBotIdByIndex(botIndex);
native GetBotRole(botId);
native GetBotSubrole(botId);

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
    
    new cfgfile[32], cvar[32];
    copy(cfgfile, charsmax(cfgfile), CONFIG_FILE);
    
    // Read host
    copy(cvar, charsmax(cvar), "host");
    read_config_string(cfgfile, cvar, g_Host, charsmax(g_Host));
    
    // Read port
    copy(cvar, charsmax(cvar), "port");
    g_Port = read_config_int(cfgfile, cvar);
    
    // Read tick rate
    copy(cvar, charsmax(cvar), "tick_rate");
    g_TickRate = read_config_float(cfgfile, cvar);

    new error;
    g_Socket = socket_open(g_Host, g_Port, SOCKET_TCP, error, SOCK_NON_BLOCKING | SOCK_LIBC_ERRORS);
    if (g_Socket == -1) {
        log_amx("GraveBot-AI: socket_open failed (%d)", error);
        return;
    }

    // Send COMMAND_LIST handshake
    new buf[2048];
    new pos = format(buf, sizeof(buf), "COMMAND_LIST");
    for (new i = 0; i < sizeof g_Commands; i++) {
        pos += format(buf[pos], sizeof(buf) - pos, ";%s", g_Commands[i]);
    }
    socket_send(g_Socket, buf, pos);

    // Hook chat
    register_message(get_user_msgid("SayText2"), "OnSayText2");
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
    socket_send(g_Socket, jsonBuf, strlen(jsonBuf));

    new inBuf[256];
    new read = socket_recv(g_Socket, inBuf, sizeof(inBuf)-1);
    if (read > 0) {
        inBuf[read] = 0;
        trim(inBuf);
        if (strncmp(inBuf, "CHAT:", 5) == 0) {
            new msg[256];
            copy(msg, sizeof(msg), inBuf[5]);
            server_cmd("say %s", msg);
            new writeBuf[300]; 
            new wlen = format(writeBuf, sizeof(writeBuf), "TTS:%s", msg);
            socket_send(g_Socket, writeBuf, wlen);
        } else {
            set_cvar_string("gravebot", inBuf);
        }
    }

    set_task(g_TickRate, "BridgeTick", _, _, _, "rh");
}

stock BuildGameState(dest[], destlen)
{
    new JSON:obj = json_init_object();
    new map[64]; get_mapname(map, charsmax(map));
    json_object_set_string(obj, "map", map);
    new Float:limit = get_cvar_float("mp_timelimit") * 60.0;
    new Float:elapsed = get_cvar_float("mp_time");
    json_object_set_number(obj, "time_left", floatround(limit - elapsed));

    new JSON:arr = json_init_array();
    new botCount = GetBotCount();
    for (new idx = 0; idx < botCount; idx++) {
        new id = GetBotIdByIndex(idx);
        new JSON:bot = json_init_object();
        json_object_set_number(bot, "id", id);
        new BotRole:r = GetBotRole(id);
        new sr = GetBotSubrole(id);
        static const ROLE_NAMES[][] = {"ROLE_NONE","ROLE_DEFEND","ROLE_ATTACK"};
        static const SUBROLE_NAMES[][] = {
            "ROLE_SUB_NONE","ROLE_SUB_ATT_GET_SCI","ROLE_SUB_ATT_RTRN_SCI",
            "ROLE_SUB_ATT_KILL_SCI","ROLE_SUB_ATT_GET_RSRC","ROLE_SUB_ATT_RTRN_RSRC",
            "ROLE_SUB_ATT_BREAK","ROLE_SUB_DEF_ALLY","ROLE_SUB_DEF_SCIS",
            "ROLE_SUB_DEF_BASE","ROLE_SUB_DEF_RSRC","ROLE_SUB_DEF_BREAK"
        };
        json_object_set_string(bot, "role", ROLE_NAMES[r]);
        json_object_set_string(bot, "subrole", sr <= 11 ? SUBROLE_NAMES[sr] : "UNKNOWN");
        new Float:origin[3]; get_user_origin(id, origin);
        json_object_set_number(bot, "x", floatround(origin[0]));
        json_object_set_number(bot, "y", floatround(origin[1]));
        json_object_set_number(bot, "z", floatround(origin[2]));
        json_object_set_number(bot, "health", _:get_user_health(id));
        json_object_set_number(bot, "armor", get_user_armor(id));
        json_array_append_value(arr, bot);
    }
    json_object_set_value(obj, "bots", arr);
    json_serial_to_string(obj, dest, destlen, false); 
    json_free(obj);
    return strlen(dest);
}

public OnSayText2(id, msg_id, msg_name[], buffer[])
{
    new sender = get_msg_arg_int(1);
    new text[192]; get_msg_arg_string(2, text, charsmax(text));
    for (new i = 0; i < g_BotCount; i++) {
        if (sender == g_BotIds[i]) {
            new out[256]; new len = format(out, charsmax(out), "TTS:%s", text);
            socket_send(g_Socket, out, len);
            break;
        }
    }
    return PLUGIN_CONTINUE;
}
