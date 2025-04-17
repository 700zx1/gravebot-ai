#if defined _config_included
    #endinput
#endif
#define _config_included

/* Read a string cvar from a *.cfg file */
native read_config_string(file[], cvar[], dest[], maxlen);

/* Read an integer cvar from a *.cfg file */
native read_config_int(file[], cvar[]);

/* Read a float cvar from a *.cfg file */
native Float:read_config_float(file[], cvar[]);
