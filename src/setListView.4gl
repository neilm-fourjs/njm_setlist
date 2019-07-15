

IMPORT FGL db
IMPORT FGL lib
IMPORT FGL songs
IMPORT FGL setList

SCHEMA songs

DEFINE m_setlist_id INTEGER
DEFINE m_songs songs
DEFINE m_setList setList
DEFINE m_cb_setlist ui.ComboBox
DEFINE m_arr DYNAMIC ARRAY OF RECORD
		fld1 STRING,
		fld2 STRING
	END RECORD

MAIN
	DEFINE l_server STRING

	LET l_server = fgl_getEnv("WSSERVER")
	IF l_server IS NULL OR l_server.getLength() < 2 THEN
		CALL fgl_winMessage("Error","WSSERVER Not Set!","exclamation")
		EXIT PROGRAM
	END IF

	CALL m_songs.get(l_server)
	CALL m_setList.get(l_server, m_songs)

	OPEN FORM f FROM "setListView"
	DISPLAY FORM f

	IF m_setlist_id IS NULL OR m_setlist_id = 0 THEN LET m_setlist_id = m_setlist.arrLen END IF
	CALL m_setlist.getList(m_setlist_id, m_songs )
	CALL set_mArr()

	DIALOG ATTRIBUTES( UNBUFFERED )
		INPUT BY NAME m_setlist_id ATTRIBUTES(WITHOUT DEFAULTS)
			ON CHANGE m_setlist_id
				CALL m_setlist.getList(m_setlist_id, m_songs )
				CALL set_mArr()
		END INPUT

		DISPLAY ARRAY m_arr TO tab2.*
		END DISPLAY

		ON ACTION close EXIT DIALOG
		ON ACTION exit EXIT DIALOG
	END DIALOG
END MAIN
--------------------------------------------------------------------------------
FUNCTION set_mArr()
	DEFINE x SMALLINT
	DEFINE l_tot STRING
	CALL m_arr.clear()
	FOR x = 1 TO m_setList.listLen
		LET m_arr[x].fld1 = SFMT("%1 - %2", m_setList.list[x].titl, m_songs.arr[ m_setList.list[x].num ].artist )
		LET m_arr[x].fld2 = SFMT("%1) %2",x,  m_setList.list[x].tim)
	END FOR
	CALL m_setList.totals() RETURNING l_tot, x
	DISPLAY lib.sec_to_time(l_tot, TRUE) TO l_tot
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