
IMPORT os

--------------------------------------------------------------------------------
FUNCTION configureReport(l_filename, l_outputformat, l_preview, l_labels)
	DEFINE
		l_filename STRING,
		l_outfilename STRING,
		l_preview BOOLEAN,
		l_labels BOOLEAN,
		l_outputformat STRING,
		l_stat INTEGER,
		l_greserver STRING,
		l_gresrvPort INTEGER,
		l_paperWidth STRING,
		l_paperHeight STRING,
		l_labelWidth STRING,
		l_labelHeight STRING,
		l_labelsPerRow INTEGER,
		l_labelsPerColumn INTEGER,
		l_topMargin STRING,
		l_bottomMargin STRING,
		l_leftMargin STRING,
		l_rightMargin STRING,
		l_fontDirectory STRING

	IF l_outputFormat = "Image" THEN
		LET l_outfilename = os.path.join(os.path.pwd(),l_filename||".png")
	ELSE
		LET l_outfilename = os.path.join(os.path.pwd(),l_filename||"."||l_outputformat.toLowerCase())
	END IF
	CALL log(" Report Configuring for '"||l_filename||"' ..." )
	-- load the 4rp file
	LET l_stat = fgl_report_loadCurrentSettings(l_filename)

	LET l_greServer = fgl_getEnv("GRESERVER")
	LET l_greSrvPort = fgl_getEnv("GRESERVERPORT")
	IF l_greServer IS NOT NULL AND l_greSrvPort IS NOT NULL THEN
		CALL log(" Using Distributed mode:"||l_greServer||":"||l_greSrvPort )
		CALL fgl_report_configureDistributedProcessing(l_greServer,l_greSrvPort)
	ELSE
		CALL log(" NOT Using Distributed mode." )
	END IF

	IF l_outputFormat = "PDF" THEN
		LET l_fontDirectory = fgl_getEnv("FONTDIR")
		DISPLAY "Setting FontDir:",l_fontDirectory
		CALL fgl_report_configurePDFDevice(l_fontDirectory ,NULL,NULL,NULL ,NULL ,NULL)
	END IF

	-- change some parameters
	CALL fgl_report_selectDevice(l_outputformat)
	CALL fgl_report_setPrinterFidelity (TRUE)
	CALL fgl_report_selectPreview(l_preview)
	CALL fgl_report_setOutputFileName(l_outfilename)

-- Do Labels
	IF l_labels THEN
		LET l_paperWidth = "a4width"
		LET l_paperHeight = "a4length"
		LET l_labelWidth = NULL -- use 4rp size
		LET l_labelHeight = NULL -- use 4rp size
		LET l_labelsPerRow = "1"
		LET l_labelsPerColumn = "3"
		LET l_topMargin = ".5cm"
		LET l_bottomMargin = ".5cm"
		LET	l_leftMargin = ".5cm"
		LET l_rightMargin = ".5cm"
		CALL fgl_report_selectLogicalPageMapping( "labels" )
		CALL fgl_report_configureLabelOutput(
				l_paperWidth,
				l_paperHeight ,
				l_labelWidth ,
				l_labelHeight ,
				l_labelsPerRow ,
				l_labelsPerColumn )
		CALL fgl_report_setPaperMargins(l_topMargin, l_bottomMargin, l_leftMargin, l_rightMargin )
	END IF
	CALL log(SFMT( "GRE Report %1 Dev: %2 Preview: %3 Out: %4", l_filename, l_outputformat, l_preview, l_outfilename ) )

	CALL log(" Report Configured." )
	-- use the report
	-- RETURN fgl_report_createProcessLevelDataFile( "data.xml" )
	RETURN fgl_report_commitCurrentSettings()
END FUNCTION
