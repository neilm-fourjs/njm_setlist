--------------------------------------------------------------------------------
FUNCTION log( l_str )
	DEFINE l_str STRING
	DEFINE c base.channel
	LET c = base.channel.create()
	CALL c.openFile(base.application.getProgramName()||".log","a")
	DISPLAY CURRENT||":"||NVL(l_str,"NULL")
	CALL c.writeLine( CURRENT||":"||NVL(l_str,"NULL") )
	CALL c.close()
END FUNCTION