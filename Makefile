# Makefile for compiling gravebot_ai.sma
AMXMODX_INCLUDE ?= /path/to/amxmodx/scripting/
PAWNCC        ?= pawncc

PLUGIN = gravebot_ai

all:
	$(PAWNCC) +S $(PLUGIN).sma -i$(AMXMODX_INCLUDE) -O$(PLUGIN).amxx

clean:
	rm -f *.amxx *.amx
