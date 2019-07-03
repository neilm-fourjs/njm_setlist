IMPORT os
DEFINE m_logDir STRING
DEFINE m_logFile STRING
DEFINE m_errFile STRING
--------------------------------------------------------------------------------
FUNCTION errorLogName() RETURNS STRING
	IF m_logDir IS NULL THEN LET m_logDir = fgl_getEnv("LOGDIR") END IF
	IF m_logDir IS NULL THEN LET m_logDir = "." END IF
	IF m_errFile IS NULL THEN LET m_errFile = os.path.join(m_logDir,base.application.getProgramName()||".err") END IF
	RETURN m_errFile
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION error_log(  )
	CALL logIt( SFMT("Error %1 %2", STATUS, ERR_GET(STATUS) ) )
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION logIt( l_str )
	DEFINE l_str STRING
	DEFINE c base.channel
	IF m_logDir IS NULL THEN LET m_logDir = fgl_getEnv("LOGDIR") END IF
	IF m_logDir IS NULL THEN LET m_logDir = "." END IF
	IF m_logFile IS NULL THEN LET m_logFile = os.path.join(m_logDir,base.application.getProgramName()||".log") END IF
	LET c = base.channel.create()
	CALL c.openFile(m_logFile,"a")
	DISPLAY CURRENT||":"||m_logFile||":"||NVL(l_str,"NULL")
	CALL c.writeLine( CURRENT||":"||NVL(l_str,"NULL") )
	CALL c.close()
END FUNCTION