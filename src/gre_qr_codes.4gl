-- Generic reporting program
IMPORT os
IMPORT FGL log
IMPORT FGL prn_lib

DEFINE m_preview BOOLEAN
DEFINE m_text STRING
DEFINE m_filename STRING
MAIN

	CALL STARTLOG(base.application.getProgramName()||".err")

	CALL log.logIt(" Running ..." )
	LET m_filename = os.path.join(os.path.pwd(),"front250")
	LET m_filename = os.path.join(os.path.pwd(),"back250")

	LET m_text = ARG_VAL(1)
	--IF m_text.getLength() < 1 THEN LET m_text = "Start £ ± End" END IF
	IF m_text.getLength() < 1 THEN LET m_text = "" END IF

	LET m_preview = FALSE

	CALL runReport(m_filename, "SVG")
	CALL log.logIt(" Finished." )
END MAIN
--------------------------------------------------------------------------------
FUNCTION runReport(filename, output_format)
DEFINE
	output_format STRING,
	filename STRING,
	sax_handler om.SaxDocumentHandler

	INITIALIZE sax_handler TO NULL
	IF filename IS NOT NULL AND output_format IS NOT NULL THEN
		LET sax_handler = prn_lib.configureReport(filename || '.4rp', output_format, m_preview, FALSE)
	END IF

	CALL log.logIt(" Start Report ..." )
	START REPORT report_name TO XML HANDLER sax_handler
	--FOR i = 1 TO 10
	CALL log.logIt(" Outputing to Report ..." )

	OUTPUT TO REPORT report_name()
	CALL log.logIt(" Outputed to Report." )

	--END FOR
	CALL log.logIt(" Finish Report ..." )
	FINISH REPORT report_name

    
END FUNCTION
--------------------------------------------------------------------------------
REPORT report_name()

	FORMAT
		ON EVERY ROW
			PRINT m_text
  
END REPORT --report_name()
