--------------------------------------------------------------------------------
FUNCTION sec_to_time( l_sec, l_hours )
	DEFINE l_hours BOOLEAN
	DEFINE l_sec, l_min, l_hour SMALLINT
	DEFINE l_tim CHAR(7)
	IF l_sec = 0 OR l_sec IS NULL THEN RETURN NULL END IF
	LET l_min = l_sec / 60
	LET l_sec = l_sec - ( l_min*60 )
	LET l_hour = l_min / 60
	LET l_min = l_min - ( l_hour*60 )
	IF l_hours THEN
		LET l_tim = l_hour USING "&",":",l_min USING "#&",":",l_sec USING "&&"
	ELSE
		LET l_tim = l_min USING "#&",":",l_sec USING "&&"
	END IF
	RETURN l_tim
END FUNCTION