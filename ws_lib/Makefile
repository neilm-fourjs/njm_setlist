export FGLPROFILE=../etc/fglprofile.pgs
export FGLWSDEBUG=3

HOST=https://generodemos.dynu.net
URL=$(HOST)/f/ws/r/ws_setlist/ws_setList

all: clean cli_setlist.openapi cli_setlist.42m

cli_setlist.openapi: 
	wget --no-check-certificate -O $@ $(URL)?openapi.json

cli_setlist.4gl: 
	fglrestful -o cli_setlist.4gl $(URL)?openapi.json

cli_setlist.42m: cli_setlist.4gl
	fglcomp $^

clean:
	rm cli_setlist.*
	
