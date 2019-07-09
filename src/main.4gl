
-- New version of the setlist demo that uses Genero 3.20 module objects.

-- Idea - can I use an INTERFACE to the class for DB vs WS ?

IMPORT os
IMPORT FGL log
IMPORT FGL db
IMPORT FGL prn_lib
IMPORT FGL lib
IMPORT FGL songs
IMPORT FGL setList

SCHEMA songs

DEFINE m_filter_listed DYNAMIC ARRAY OF songs.t_listitem
DEFINE m_filter_list, m_filter_learnt BOOLEAN
DEFINE m_use_db BOOLEAN = FALSE
DEFINE m_setlist_id INTEGER
DEFINE m_songs songs
DEFINE m_setList setList
DEFINE m_cb_setlist ui.ComboBox

MAIN
	DEFINE l_server STRING

	LET m_filter_list = FALSE
	LET l_server = fgl_getEnv("WSSERVER")
	IF l_server IS NULL OR l_server.getLength() < 2 THEN
		LET m_use_db = TRUE
	END IF

	CALL STARTLOG( log.errorLogName() )
	CALL log.logIt( "Current Directory:"||os.path.pwd() )

	IF m_use_db THEN
		CALL db.connect("songs")
		CASE ARG_VAL(1)
			WHEN "recreate" CALL db.backup() CALL db.drop() CALL db.load()
			WHEN "drop" CALL db.drop()
			WHEN "create" CALL db.create()
			WHEN "newload" CALL db.newload()
			WHEN "load" CALL db.load()
			WHEN "unload" CALL db.unload()
			WHEN "undel" UPDATE setlist SET stat = "N"
		END CASE
	END IF

	CALL m_songs.get(l_server)
	CALL m_setList.get(l_server, m_songs)

	OPEN FORM f FROM "setlist"
	DISPLAY FORM f
	IF NOT m_use_db THEN
		CALL appendTitle(SFMT("SRV:%1",l_server))
	ELSE
		CALL appendTitle(SFMT("DB:%1",db.m_db))
	END IF

	CALL main_dialog()

	IF m_use_db THEN
		CALL db.backup()
	END IF
END MAIN
--------------------------------------------------------------------------------
FUNCTION main_dialog()
	DEFINE l_dnd ui.DragDrop
	DEFINE l_drag_source STRING
	DEFINE x SMALLINT
	DEFINE l_name LIKE setlist.name
	DEFINE l_rec songs.t_listitem

	IF m_setlist_id IS NULL OR m_setlist_id = 0 THEN LET m_setlist_id = m_setlist.arrLen END IF
	CALL m_setlist.getList(m_setlist_id, m_songs )
	CALL filter(__LINE__)
	CALL log.logIt( "Displaying setlist Id:"||NVL(m_setlist_id,"NULL"))
	DIALOG ATTRIBUTES( UNBUFFERED )
		DISPLAY ARRAY m_filter_listed TO tab1.*
			BEFORE ROW
				CALL disp_song( m_filter_listed[ arr_curr() ].id )
			ON UPDATE
				CALL m_songs.upd( m_filter_listed[ arr_curr() ].id )
			ON DELETE
				CALL m_songs.del( m_filter_listed[ arr_curr() ].id  )
			ON INSERT
				CALL m_songs.new( arr_curr() )
			ON DRAG_START(l_dnd) LET l_drag_source = "songlist"
				DISPLAY "1.drag start:",l_drag_source
			ON DRAG_ENTER(l_dnd)
				IF l_drag_source = "setlist" THEN
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
				CALL m_setList.addSong( 0, m_filter_listed[ arr_curr() ] )
				CALL calc_tots(__LINE__)
		END DISPLAY

		INPUT BY NAME m_setlist_id ATTRIBUTES(WITHOUT DEFAULTS)
			ON CHANGE m_setlist_id
				CALL m_setlist.getList(m_setlist_id, m_songs )
		END INPUT

		DISPLAY ARRAY m_setlist.list TO tab2.*
			BEFORE ROW
				CALL disp_song( m_setlist.list[ arr_curr() ].id )

			ON DELETE
				CALL log.logIt("Delete song from list:"||arr_curr()||":"||m_setlist.list[arr_curr()].titl)
				LET m_setlist.saved = FALSE
				CALL calc_tots(__LINE__)

			ON ACTION break_set
				CALL m_setList.addBreak()

			ON DRAG_START(l_dnd) LET l_drag_source = "setlist"
				DISPLAY "2.drag start:",l_drag_source

			ON DRAG_ENTER(l_dnd)
				CASE l_drag_source 
					WHEN "songlist"
						DISPLAY"2.drag enter okay:",l_drag_source
						CALL l_dnd.setOperation("copy")
						CALL l_dnd.setFeedback("insert")
					WHEN "setlist"
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
					FOR x = 1 TO m_filter_listed.getLength()
						IF DIALOG.isRowSelected("tab1",x) THEN
							LET l_rec.* = m_filter_listed[x].*
							DISPLAY "2.dropped songlist row:",x," ",l_rec.titl," into:",l_dnd.getLocationRow()
							CALL m_setlist.addSong( l_dnd.getLocationRow(), l_rec )
						END IF
					END FOR
					CALL calc_tots(__LINE__)
				END IF
				IF l_drag_source = "setlist" THEN
					FOR x = 1 TO m_setlist.listLen
						IF DIALOG.isRowSelected("tab2",x) THEN
							LET l_rec.* = m_setlist.list[x].*
							CALL m_setlist.removeSong(x)
							DISPLAY "2.dropped song row:",x," ",l_rec.titl," into:",l_dnd.getLocationRow()
							CALL m_setlist.addSong( l_dnd.getLocationRow(), l_rec )
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
			IF NOT m_setlist.saved THEN
				IF fgl_winQuestion("Confirm","Save changes to setlist?","No","Yes|No","question",0) = "Yes" THEN
					CALL m_setList.save()
				ELSE
					CALL log.logIt("Save setlist Id:"||NVL(m_setlist_id,"NULL")||" Cancelled.")
				END IF
			END IF
			EXIT DIALOG

		ON ACTION filter
			LET m_filter_list = NOT m_filter_list
			CALL DIALOG.getForm().setElementImage("filter", IIF(m_filter_list,"reset_filter","fa-filter") )
			CALL filter(__LINE__)
		ON ACTION filter2
			LET m_filter_learnt = NOT m_filter_learnt
			CALL DIALOG.getForm().setElementImage("filter2", IIF(m_filter_learnt,"reset_filter","fa-filter") )
			CALL filter(__LINE__)

		ON ACTION prn_setlist
			CALL prn_setlist(TRUE,"../etc/setlist")
		ON ACTION prn_setlist2
			CALL prn_setlist(TRUE,"../etc/songlist")
		ON ACTION prn_songlist
			CALL prn_setlist(FALSE,"../etc/songlist")

		ON ACTION save_setlist
			CALL m_setList.save()

		ON ACTION new_setlist
			LET int_flag = FALSE
			PROMPT "Enter Name for Set List:" FOR l_name
			IF int_flag OR l_name IS NULL THEN LET int_flag = FALSE CONTINUE DIALOG END IF
			FOR x = 1 TO m_setList.arrLen
				IF m_setList.arr[x].name = l_name THEN
					CALL fgl_winMessage("Error","Set List already exists!","exclamation")
					CONTINUE DIALOG
				END IF
			END FOR
			CALL m_setList.new( l_name )
			LET m_setlist_id = 0
			CALL cb_setList( m_cb_setlist )

		ON ACTION del_setlist
			IF fgl_winQuestion("Confirm","Delete setlist?","No","Yes|No","question",0) = "Yes" THEN
				CALL m_setList.del()
				CALL cb_setList( m_cb_setlist )
				LET m_setlist_id = m_setlist.arrLen
				CALL m_setlist.getList( m_setlist_id, m_songs )
			ELSE
				CALL log.logIt("Delete setlist Id:"||NVL(m_setlist_id,"NULL")||" Cancelled.")
			END IF
	END DIALOG

END FUNCTION
--------------------------------------------------------------------------------
FUNCTION cb_setList(l_cb ui.ComboBox)
	DEFINE x SMALLINT
	LET m_cb_setlist = l_cb
	CALL l_cb.clear()
	FOR x = 1 TO m_setList.arrLen
		CALL l_cb.addItem( m_setList.arr[x].id, m_setList.arr[x].name )
	END FOR
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION disp_song( l_id )
	DEFINE l_id INTEGER
	DEFINE l_min, l_sec SMALLINT
	DEFINE l_song RECORD LIKE songs.*
	CALL m_songs.getSong(l_id, l_song ) -- sets l_song
	DISPLAY BY NAME l_song.*
	LET l_min = l_song.dur / 60
	LET l_sec = l_song.dur - (l_min*60)
	DISPLAY BY NAME l_min, l_sec
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION filter(l_line SMALLINT)
	DEFINE x,y SMALLINT
	DEFINE l_filtered BOOLEAN
	DISPLAY SFMT("Filter List, Line %1 Filter: %2",l_line,m_filter_list)
	CALL m_filter_listed.clear()
	FOR x = 1 TO m_songs.len
		LET l_filtered = FALSE
		IF m_filter_list THEN
			FOR y = 1 TO m_setlist.listLen
				IF m_setlist.list[y].id = m_songs.list[x].id THEN
					LET l_filtered = TRUE
					EXIT FOR
				END IF
			END FOR
		END IF
		IF m_songs.list[x].lrn = "learnt_n" AND m_filter_learnt THEN
			LET l_filtered = TRUE
		END IF
		IF NOT l_filtered THEN
			CALL m_filter_listed.appendElement()
			LET m_filter_listed[ m_filter_listed.getLength() ].* = m_songs.list[x].*
		END IF
	END FOR
	CALL calc_tots(__LINE__)
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION calc_tots(l_line SMALLINT)
	DEFINE l_tot, x, l_cnt SMALLINT
	DISPLAY SFMT("Calc tots: from %1, MainList: %2 SetList: %3",l_line,m_filter_listed.getLength(),m_setlist.listLen)
	LET l_tot = 0
	LET l_cnt = 0
	FOR x = 1 TO m_filter_listed.getLength()
		LET l_tot = l_tot + m_filter_listed[x].dur
	END FOR
	DISPLAY sec_to_time( l_tot, TRUE )||"("||m_filter_listed.getLength()||")" TO l_stot

	CALL m_setlist.totals() RETURNING l_tot, l_cnt
	DISPLAY sec_to_time( l_tot, TRUE )||"("||l_cnt||")" TO l_atot
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION appendTitle( l_new STRING )
	DEFINE l_titl STRING
	LET l_titl = ui.Window.getCurrent().getText()
	CALL ui.Window.getCurrent().setText( l_titl||" "||l_new )
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION prn_setlist(l_setList BOOLEAN, l_filename STRING)
--&ifdef GRE
	DEFINE
		l_output_format STRING,
		l_sax_handler om.SaxDocumentHandler
	DEFINE x, l_pg SMALLINT
	DEFINE l_song RECORD LIKE songs.*
	DEFINE l_dur STRING

	LET l_output_format = "PDF"

	INITIALIZE l_sax_handler TO NULL
	IF l_filename IS NOT NULL AND l_output_format IS NOT NULL THEN
		LET l_sax_handler = prn_lib.configureReport(l_filename || '.4rp', l_output_format, TRUE, FALSE)
	END IF

	CALL log.logIt(" Start Report ..." )
	START REPORT report_name TO XML HANDLER l_sax_handler

	CALL log.logIt(" Outputing to Report ..." )

	LET l_pg = 1
	IF l_setList THEN
	--	CALL m_setlist.sort("titl",FALSE)
		FOR x = 1 TO m_setList.listLen
			IF m_setlist.list[x].id > 0 THEN
				CALL m_songs.getSong(m_setlist.list[x].id, l_song) -- sets l_song.* 
				LET l_dur = sec_to_time( l_song.dur, FALSE)
				OUTPUT TO REPORT report_name( l_pg, x, m_setlist.currentList, l_song.*, l_dur )
			ELSE
				LET l_pg = l_pg + 1
			END IF
		END FOR
	ELSE
		FOR x = 1 TO m_songs.len
			LET l_dur = sec_to_time( m_songs.arr[x].dur, FALSE )
			OUTPUT TO REPORT report_name( l_pg, x, "All Songs", m_songs.arr[x].*, l_dur )
		END FOR
	END IF

	CALL log.logIt(" Finish Report ..." )
	FINISH REPORT report_name
--&endif
END FUNCTION
--------------------------------------------------------------------------------
REPORT report_name(l_pg SMALLINT, x SMALLINT, l_titl STRING, l_song RECORD LIKE songs.*, l_dur STRING )
	ORDER EXTERNAL BY  l_pg
	FORMAT
		FIRST PAGE HEADER
			PRINT l_titl
		ON EVERY ROW
			PRINT l_pg, x,l_song.*, l_dur
END REPORT --report_name()