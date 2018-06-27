
IMPORT os
SCHEMA songs

CONSTANT C_BREAK = "    *** BREAK *** "
TYPE t_listitem RECORD
		num SMALLINT,
		id INTEGER,
		titl VARCHAR(40),
		lrn VARCHAR(40),
		dur SMALLINT,
		tim CHAR(5),
		tempo STRING,
		songkey STRING
	END RECORD

DEFINE m_songs, m_filtered, m_setlist DYNAMIC ARRAY OF t_listitem
DEFINE m_saved, m_filter, m_filter2 BOOLEAN
DEFINE m_setlist_id INTEGER
DEFINE m_setlist_rec RECORD LIKE setlist.*
DEFINE m_cb_setlist ui.ComboBox
MAIN
	DEFINE l_back STRING
	DEFINE l_dbbackup STRING
	DEFINE l_tim CHAR(8)

	LET m_filter = FALSE

	CALL STARTLOG( base.application.getProgramName()||".err" )
	CALL log( "Current Directory:"||os.path.pwd() )

	CALL db_connect("songs")

	IF ARG_VAL(1) = "load" THEN CALL db_load() END IF

	CALL get_songs()

	OPEN FORM f FROM "setlist"
	DISPLAY FORM f

	CALL main_dialog()

	LET l_dbbackup = os.path.join( os.path.dirname(os.path.pwd()),"db_backup")
	IF NOT os.path.exists(l_dbbackup) THEN
		IF NOT os.path.mkdir(l_dbbackup) THEN
			CALL log( SFMT("Failed to make backup dir '%1'",l_dbbackup) )
		END IF
	END IF
	--LET l_dbbackup = os.path.join( l_dbbackup,"test" )
	--LET l_dbbackup = os.path.join( l_dbbackup,(TODAY USING "YYYY-MM-DD"||"-"||TIME))

	LET l_tim = TIME
	LET l_tim = l_tim[1,2]||l_tim[4,5]||l_tim[7,8]
	LET l_dbbackup = os.path.join( l_dbbackup,(TODAY USING "YYYYMMDD")||"-"||l_tim CLIPPED)
	LET l_back = l_dbbackup.append("-songs.unl")
	CALL log( "Back up songs to "||NVL(l_back,"NULL"))
	UNLOAD TO l_back SELECT * FROM songs
	LET l_back = l_dbbackup.append("-setlist.unl")
	CALL log( "Back up setlist to "||NVL(l_back,"NULL"))
	UNLOAD TO l_back SELECT * FROM setlist
	LET l_back = l_dbbackup.append("-setlist_song.unl")
	CALL log( "Back up setlist_song to "||NVL(l_back,"NULL"))
	UNLOAD TO l_back SELECT * FROM setlist_song
	LET l_back = l_dbbackup.append("-setlist_hist.unl")
	CALL log( "Back up setlist_hist to "||NVL(l_back,"NULL"))
	UNLOAD TO l_back SELECT * FROM setlist_hist
END MAIN
--------------------------------------------------------------------------------
FUNCTION main_dialog()
	DEFINE l_dnd ui.DragDrop
	DEFINE l_drag_source STRING
	DEFINE x SMALLINT
	DEFINE l_rec t_listitem

	CALL get_setlist()
	CALL filter_list(__LINE__)
	CALL log( "Displaying setlist Id:"||NVL(m_setlist_id,"NULL"))
	DIALOG ATTRIBUTES( UNBUFFERED )
		DISPLAY ARRAY m_filtered TO tab1.*
			BEFORE ROW
				CALL disp_song( m_filtered[ arr_curr() ].id )
			ON UPDATE
				CALL upd_song( m_filtered[ arr_curr() ].id )
			ON DELETE
				CALL del_song( m_filtered[ arr_curr() ].id, m_filtered[ arr_curr() ].titl  )
			ON INSERT
				CALL new_song( arr_curr() )
			ON DRAG_START(l_dnd) LET l_drag_source = "songlist"
				DISPLAY "1.drag start:",l_drag_source
			ON DRAG_ENTER(l_dnd)
				IF l_drag_source = "song" THEN
					DISPLAY"1.drag enter okay:",l_drag_source
					CALL l_dnd.setOperation("insert")
					CALL l_dnd.setFeedback("all")
				ELSE
					DISPLAY"1.drag enter not okay:",l_drag_source
					CALL l_dnd.setOperation(NULL)
				END IF
      ON DROP(l_dnd)
				DISPLAY "1.drop:",l_drag_source
      ON DRAG_FINISHED(l_dnd) 
				DISPLAY "1.drag finished"
				INITIALIZE l_drag_source TO NULL
			ON ACTION addtosetlist
				LET m_setlist[ m_setlist.getLength()+1 ].* = m_filtered[ arr_curr() ].*
				LET m_saved = FALSE
				CALL calc_tots(__LINE__)
		END DISPLAY

		INPUT BY NAME m_setlist_id ATTRIBUTES(WITHOUT DEFAULTS)
			ON CHANGE m_setlist_id
				CALL get_setlist()
		END INPUT

		DISPLAY ARRAY m_setlist TO tab2.*
			BEFORE ROW
				CALL disp_song( m_setlist[ arr_curr() ].id )

			ON UPDATE
				CALL upd_song( m_setlist[ arr_curr() ].id )

			ON DELETE
				CALL log("Delete song from list:"||arr_curr()||":"||m_setlist[arr_curr()].titl)
				LET m_saved = FALSE
				CALL calc_tots(__LINE__)

			ON ACTION break_set
				CALL m_setlist.insertElement( arr_curr() )
				LET m_setlist[ arr_curr() ].titl = C_BREAK
				LET m_setlist[ arr_curr() ].lrn = "fa-coffee"
				LET m_setlist[ arr_curr() ].dur = 0
				LET m_setlist[ arr_curr() ].id = -1

			ON DRAG_START(l_dnd) LET l_drag_source = "song"
				DISPLAY "2.drag start:",l_drag_source
			ON DRAG_ENTER(l_dnd)
				CASE l_drag_source 
					WHEN "songlist"
						DISPLAY"2.drag enter okay:",l_drag_source
						CALL l_dnd.setOperation("copy")
						CALL l_dnd.setFeedback("insert")
					WHEN "song"
						DISPLAY"2.drag enter okay:",l_drag_source
						CALL l_dnd.setOperation("move")
						CALL l_dnd.setFeedback("insert")
				OTHERWISE
					DISPLAY"2.drag enter not okay:",l_drag_source
					CALL l_dnd.setOperation(NULL)
				END CASE
			ON DRAG_OVER(l_dnd)
				DISPLAY"2.drag over:",l_drag_source
      ON DROP(l_dnd)
				DISPLAY "2.drop:",l_drag_source
				IF l_drag_source = "songlist" THEN
					FOR x = 1 TO m_filtered.getLength()
						IF DIALOG.isRowSelected("tab1",x) THEN
							LET l_rec.* = m_filtered[x].*
							DISPLAY "2.dropped songlist row:",x," ",l_rec.titl," into:",l_dnd.getLocationRow()
							CALL m_setlist.insertElement( l_dnd.getLocationRow() )
							LET m_setlist[ l_dnd.getLocationRow() ].* = l_rec.*
							LET m_saved = FALSE
						END IF
					END FOR
					CALL calc_tots(__LINE__)
				END IF
				IF l_drag_source = "song" THEN
					FOR x = 1 TO m_setlist.getLength()
						IF DIALOG.isRowSelected("tab2",x) THEN
							LET l_rec.* = m_setlist[x].*
							CALL m_setlist.deleteElement(x)
							DISPLAY "2.dropped song row:",x," ",l_rec.titl," into:",l_dnd.getLocationRow()
							CALL m_setlist.insertElement( l_dnd.getLocationRow() )
							LET m_setlist[ l_dnd.getLocationRow() ].* = l_rec.*
							LET m_saved = FALSE
						END IF
					END FOR
				END IF
      ON DRAG_FINISHED(l_dnd) 
				DISPLAY "2.drag finished"
				INITIALIZE l_drag_source TO NULL

		END DISPLAY
		BEFORE DIALOG
      CALL DIALOG.setSelectionMode("tab1",TRUE)
      CALL DIALOG.setSelectionMode("tab2",TRUE)
			CALL calc_tots(__LINE__)

		ON ACTION close EXIT DIALOG
		ON ACTION exit
			IF NOT m_saved THEN
				IF fgl_winQuestion("Confirm","Save changes to setlist?","No","Yes|No","question",0) = "Yes" THEN
					CALL save_setlist()
				ELSE
					CALL log("Save setlist Id:"||NVL(m_setlist_id,"NULL")||" Cancelled.")
				END IF
			END IF
			EXIT DIALOG
		ON ACTION filter
			LET m_filter = NOT m_filter
			CALL filter_list(__LINE__)
		ON ACTION filter2
			LET m_filter2 = NOT m_filter2
			CALL filter_notlearnt()
		ON ACTION new_setlist
			CALL new_setlist()
		ON ACTION save_setlist
			CALL save_setlist()
		ON ACTION prn_setlist
			CALL prn_setlist(TRUE,"../etc/setlist")
		ON ACTION prn_setlist2
			CALL prn_setlist(TRUE,"../etc/songlist")
		ON ACTION prn_songlist
			CALL prn_setlist(FALSE,"../etc/songlist")
		ON ACTION del_setlist
			IF fgl_winQuestion("Confirm","Delete setlist?","No","Yes|No","question",0) = "Yes" THEN
				CALL del_setlist()
			ELSE
				CALL log("Delete setlist Id:"||NVL(m_setlist_id,"NULL")||" Cancelled.")
			END IF
	END DIALOG

END FUNCTION
--------------------------------------------------------------------------------
FUNCTION cb_setlist(cb)
	DEFINE cb ui.ComboBox
	DEFINE l_id INTEGER
	DEFINE l_name VARCHAR(20)
	CALL cb.clear()
	LET m_cb_setlist = cb
	DECLARE sl_cur CURSOR FOR SELECT id,name FROM setlist
	FOREACH sl_cur INTO l_id, l_name
		IF l_name IS NOT NULL THEN
			CALL cb.addItem( l_id, l_name CLIPPED )
			LET m_setlist_id = l_id
		END IF
	END FOREACH
	CALL get_setlist()
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION get_songs()
	DEFINE l_song RECORD LIKE songs.*
	DEFINE l_listitem t_listitem
	CALL m_songs.clear()
	DECLARE song_cur CURSOR FOR SELECT * FROM songs ORDER BY titl
	FOREACH song_cur INTO l_song.*
		DISPLAY "songId:",l_song.id
		CALL m_songs.appendElement()
		CALL set_listItem(l_song.*, m_songs.getLength() ) RETURNING l_listitem.*
		LET m_songs[ m_songs.getLength() ].* =  l_listitem.*
	END FOREACH
	MESSAGE "Total Songs:",m_songs.getLength()
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION set_listItem(l_song, x)
	DEFINE l_song RECORD LIKE songs.*
	DEFINE x SMALLINT
	DEFINE l_listitem t_listitem
	LET l_listitem.id = l_song.id
	LET l_listitem.num = x
	LET l_listitem.titl = l_song.titl
	LET l_listitem.dur = l_song.dur
	LET l_listitem.songkey = l_song.songkey
	LET l_listitem.tim = sec_to_time( l_listitem.dur, FALSE )
	LET l_listitem.lrn = l_song.learnt
	IF l_listitem.lrn IS NULL THEN LET l_listitem.lrn = "N" END IF
	CASE l_listitem.lrn
		WHEN "Y" LET l_listitem.lrn = "learnt_y"
		WHEN "N" LET l_listitem.lrn = "learnt_n"
		WHEN "A" LET l_listitem.lrn = "learnt_a"
	END CASE
	LET l_listitem.tempo = l_song.tempo
	IF l_listitem.tempo IS NULL THEN LET l_listitem.tempo = " " END IF
	CASE l_listitem.tempo
		WHEN "F" LET l_listitem.tempo = "tempo_f"
		WHEN "M" LET l_listitem.tempo = "tempo_m"
		WHEN "S" LET l_listitem.tempo = "tempo_s"
	END CASE
	RETURN l_listitem.*
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION get_setlist()
	DEFINE l_song_id INTEGER
	DEFINE l_seq_no, l_cnt SMALLINT
	DEFINE l_song RECORD LIKE songs.*
	DEFINE l_listitem t_listitem
	LET l_cnt = 0
	CALL log( "Getting setlist Id:"||NVL(m_setlist_id,"NULL"))
	CALL m_setlist.clear()
	SELECT * INTO m_setlist_rec.* FROM setlist sl WHERE sl.id = m_setlist_id
	DECLARE sl2_cur CURSOR FOR
		SELECT song_id, seq_no, songs.* 
			FROM setlist sl, setlist_song
			LEFT OUTER JOIN songs ON setlist_song.song_id = songs.id
			WHERE sl.id = m_setlist_id
				AND sl.id = setlist_song.setlist_id
			ORDER BY seq_no
	FOREACH sl2_cur INTO l_song_id, l_seq_no, l_song.*
		CALL m_setlist.appendElement()
		DISPLAY m_setlist.getLength()," Song ID:",l_song_id
		IF l_song_id > 0 THEN
			LET l_cnt = l_cnt + 1
			CALL set_listItem(l_song.*, l_cnt ) RETURNING l_listitem.*
			LET m_setlist[ m_setlist.getLength() ].* = l_listitem.*
		ELSE
			LET m_setlist[ m_setlist.getLength() ].dur = 0
			LET m_setlist[ m_setlist.getLength() ].lrn = "fa-coffee"
			LET m_setlist[ m_setlist.getLength() ].titl = C_BREAK
			LET m_setlist[ m_setlist.getLength() ].songkey = NULL
			LET m_setlist[ m_setlist.getLength() ].tempo = NULL
			LET m_setlist[ m_setlist.getLength() ].tim = NULL
			LET m_setlist[ m_setlist.getLength() ].num = -1
			LET m_setlist[ m_setlist.getLength() ].id = -1
		END IF
	END FOREACH
	CALL calc_tots(__LINE__)
	LET m_saved = TRUE
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION filter_notlearnt()
	DEFINE x SMALLINT
	DISPLAY "Filter2 List:",m_filter2
	CALL m_filtered.clear()
	FOR x = 1 TO m_songs.getLength()
		IF m_songs[x].lrn != "learnt_n" OR NOT m_filter2 THEN
			CALL m_filtered.appendElement()
			LET m_filtered[ m_filtered.getLength() ].* = m_songs[x].*
		END IF
	END FOR
	CALL calc_tots(__LINE__)
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION filter_list(l_line SMALLINT)
	DEFINE x,y SMALLINT
	DEFINE l_filtered BOOLEAN
	DISPLAY SFMT("Filter List, Line %1 Filter: %2",l_line,m_filter)
	CALL m_filtered.clear()
	FOR x = 1 TO m_songs.getLength()
		LET l_filtered = FALSE
		IF m_filter THEN
			FOR y = 1 TO m_setlist.getLength()
				IF m_setlist[y].id = m_songs[x].id THEN
					LET l_filtered = TRUE
					EXIT FOR
				END IF
			END FOR
		END IF
		IF NOT l_filtered THEN
			CALL m_filtered.appendElement()
			LET m_filtered[ m_filtered.getLength() ].* = m_songs[x].*
		END IF
	END FOR
	CALL calc_tots(__LINE__)
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION new_setlist()
	DEFINE l_name VARCHAR(20)

	LET int_flag = FALSE
	PROMPT "Enter Name for Set List:" FOR l_name
	IF int_flag OR l_name IS NULL THEN RETURN END IF
	SELECT * FROM setlist WHERE name = l_name
	IF STATUS != NOTFOUND THEN
		CALL fgl_winMessage("Error","Set List already exists!","exclamation")
		RETURN
	END IF
	INSERT INTO setlist ( name ) VALUES( l_name )
	CALL m_setlist.clear()
	CALL cb_setlist(m_cb_setlist)
	CALL log( "New setlist Id:"||m_setlist_id||" Name:"||l_name)
	LET m_setlist_rec.name = l_name
	LET m_saved = FALSE

END FUNCTION
--------------------------------------------------------------------------------
FUNCTION del_setlist()

	IF m_setlist_id IS NOT NULL THEN
		CALL log( "Delete setlist Id:"||m_setlist_id)
		DELETE FROM setlist WHERE id = m_setlist_id
		DELETE FROM setlist_song WHERE setlist_id = m_setlist_id
		MESSAGE "Setlist Deleted."
		CALL m_setlist.clear()
		CALL cb_setlist(m_cb_setlist)
	END IF

END FUNCTION
--------------------------------------------------------------------------------
FUNCTION save_setlist()
	DEFINE x SMALLINT

	CALL log( "Saving setlist Id:"||NVL(m_setlist_id,"NULL"))
	DELETE FROM setlist_song WHERE setlist_id = m_setlist_id
	FOR x = 1 TO m_setlist.getLength()
		INSERT INTO setlist_song VALUES( m_setlist_id, m_setlist[x].id, x )
	END FOR
	LET m_saved = TRUE
	MESSAGE "Setlist Saved."

END FUNCTION
--------------------------------------------------------------------------------
FUNCTION new_song( l_arr )
	DEFINE l_arr INTEGER
	DEFINE l_song RECORD LIKE songs.*
	DEFINE l_min, l_sec SMALLINT
	DEFINE l_id INTEGER
	LET l_song.capo = 0
	LET l_song.done_live = "N"
	LET l_song.genre = "F"
	LET l_song.guitar_fx = "None"
	LET l_song.learnt = "N"
	LET l_song.recorded = "N"
	LET l_song.tuning = "S"
	LET l_song.vox = "T"
	LET l_song.vox_fx = "None"
	INPUT BY NAME l_song.*,l_min,l_sec WITHOUT DEFAULTS
	IF NOT int_flag THEN
		LET l_song.songkey[1] = UPSHIFT(l_song.songkey[1])
		LET l_song.songkey[2,3] = DOWNSHIFT(l_song.songkey[2,3])
		SELECT MAX( id ) INTO l_id FROM songs
		LET l_song.id = l_id + 1
		LET l_song.dur = ( l_min * 60 ) + l_sec
		LET m_songs[ l_arr ].dur = l_song.dur
		LET m_songs[ l_arr ].titl = l_song.titl
		DISPLAY BY NAME l_song.dur
		INSERT INTO songs VALUES l_song.*
		CALL get_songs()
	END IF
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION del_song( l_id INTEGER, l_titl STRING )
	IF fgl_winQuestion("Confirm","Delete this song?\n"||l_titl,"No","Yes|No","questions",0) = "No" THEN
		LET int_flag = TRUE
		RETURN
	END IF
	DELETE FROM songs WHERE id = l_id
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION upd_song( l_id INTEGER )
	DEFINE l_song RECORD LIKE songs.*
	DEFINE l_min, l_sec SMALLINT

	CALL get_song(l_id) RETURNING l_song.*
	LET l_min = l_song.dur / 60
	LET l_sec = l_song.dur - ( l_min * 60 )

	INPUT BY NAME l_song.*,l_min,l_sec WITHOUT DEFAULTS
	LET l_song.dur = ( l_min * 60 ) + l_sec
	LET l_song.songkey[1] = UPSHIFT(l_song.songkey[1])
	LET l_song.songkey[2,3] = DOWNSHIFT(l_song.songkey[2,3])
	IF NOT int_flag THEN
		DISPLAY BY NAME l_song.dur
		UPDATE songs SET songs.* = l_song.* WHERE id = l_id
		CALL get_songs()
		CALL get_setlist()
	END IF
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION get_song(l_id)
	DEFINE l_id INTEGER
	DEFINE l_song RECORD LIKE songs.*
	SELECT * INTO l_song.* FROM songs WHERE id = l_id
	IF l_song.capo IS NULL THEN LET l_song.capo = 0 END IF
	IF l_song.learnt IS NULL THEN LET l_song.learnt = "N" END IF
	IF l_song.done_live IS NULL THEN LET l_song.done_live = "N" END IF
	IF l_song.genre IS NULL THEN LET l_song.genre = "F" END IF
	IF l_song.tempo IS NULL THEN LET l_song.tempo = "S" END IF
	IF l_song.recorded IS NULL THEN LET l_song.recorded = "N" END IF
	RETURN l_song.*
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION calc_tots(l_line SMALLINT)
	DEFINE l_tot, l_tot2, x, l_cnt, l_cnt2 SMALLINT
	DISPLAY SFMT("Calc tots: from %1, MainList: %2 SetList: %3",l_line,m_filtered.getLength(),m_setlist.getLength())
	LET l_tot = 0
	LET l_tot2 = 0
	LET l_cnt = 0
	LET l_cnt2 = 0
	FOR x = 1 TO m_filtered.getLength()
		LET l_tot = l_tot + m_filtered[x].dur
	END FOR
	DISPLAY sec_to_time( l_tot, TRUE )||"("||m_filtered.getLength()||")" TO l_stot
	LET l_tot = 0
	FOR x = 1 TO m_setlist.getLength()
		IF m_setlist[x].id > 0 THEN
			LET l_cnt = l_cnt + 1
			LET l_cnt2 = l_cnt2 + 1
			LET l_tot = l_tot + m_setlist[x].dur
			LET l_tot2 = l_tot2 + m_setlist[x].dur
		ELSE
			LET m_setlist[x].titl = C_BREAK||"   Dur: ",sec_to_time( l_tot2, TRUE )||" ("||l_cnt2||")"
			LET l_cnt2 = 0
			LET l_tot2 = 0
		END IF
	END FOR
	DISPLAY sec_to_time( l_tot, TRUE )||"("||l_cnt||")" TO l_atot
END FUNCTION
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
--------------------------------------------------------------------------------
FUNCTION disp_song( l_id )
	DEFINE l_id INTEGER
	DEFINE l_min, l_sec SMALLINT
	DEFINE l_song RECORD LIKE songs.*

	CALL get_song(l_id) RETURNING l_song.*
	DISPLAY BY NAME l_song.*
	LET l_min = l_song.dur / 60
	LET l_sec = l_song.dur - (l_min*60)
	DISPLAY BY NAME l_min, l_sec

END FUNCTION
--------------------------------------------------------------------------------
FUNCTION prn_setlist(l_setList BOOLEAN, l_filename STRING)
--&ifdef GRE
	DEFINE
		l_output_format STRING,
		l_sax_handler om.SaxDocumentHandler
	DEFINE x SMALLINT
	DEFINE l_song RECORD LIKE songs.*
	DEFINE l_dur STRING

	LET l_output_format = "PDF"

	INITIALIZE l_sax_handler TO NULL
	IF l_filename IS NOT NULL AND l_output_format IS NOT NULL THEN
		LET l_sax_handler = configureReport(l_filename || '.4rp', l_output_format, TRUE, FALSE)
	END IF

	CALL log(" Start Report ..." )
	START REPORT report_name TO XML HANDLER l_sax_handler
	--FOR i = 1 TO 10
	CALL log(" Outputing to Report ..." )

	IF l_setList THEN
	--	CALL m_setlist.sort("titl",FALSE)
		FOR x = 1 TO m_setlist.getLength()
			CALL get_song(m_setlist[x].id) RETURNING l_song.*
			LET l_dur = sec_to_time( l_song.dur, FALSE)
			OUTPUT TO REPORT report_name( x, l_song.*, l_dur )
		END FOR
	ELSE
		FOR x = 1 TO m_songs.getLength()
			CALL get_song(m_songs[x].id) RETURNING l_song.*
			LET l_dur = sec_to_time( l_song.dur, FALSE )
			OUTPUT TO REPORT report_name( x, l_song.*, l_dur )
		END FOR
	END IF
	CALL log(" Outputed to Report." )

	--END FOR
	CALL log(" Finish Report ..." )
	FINISH REPORT report_name

--&endif
END FUNCTION
--------------------------------------------------------------------------------
REPORT report_name(x, l_song, l_dur)
	DEFINE x SMALLINT
	DEFINE l_song RECORD LIKE songs.*
	DEFINE l_dur STRING

	FORMAT
		FIRST PAGE HEADER
			PRINT m_setlist_rec.name

		ON EVERY ROW
			PRINT x,l_song.*, l_dur
  
END REPORT --report_name()
