IMPORT util
IMPORT FGL lib
IMPORT FGL log
IMPORT FGL songs
IMPORT FGL cli_setlist
IMPORT FGL g2_ws
SCHEMA songs

PUBLIC CONSTANT C_BREAK = "    *** BREAK *** "

DEFINE m_songs songs

PUBLIC TYPE setList RECORD
	arr DYNAMIC ARRAY OF RECORD LIKE setlist.*,
	arrLen SMALLINT,
	currentList STRING,
	currentListId INTEGER,
	list DYNAMIC ARRAY OF t_listitem,
	listLen SMALLINT,
	saved BOOLEAN
END RECORD
--------------------------------------------------------------------------------
FUNCTION (this setList) get(l_server STRING, l_songs songs) RETURNS ()
	LET m_songs = l_songs
	LET this.saved = TRUE
	CALL this.arr.clear()
	LET this.arrLen = 0
	CALL this.list.clear()
	LET this.listLen = 0
	IF l_server IS NULL THEN
		CALL this.getFromDB()
	ELSE
		CALL this.getFromServer(l_server)
	END IF
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION (this setList) getList(l_server STRING, l_id INTEGER, l_songs songs) RETURNS ()
	DEFINE x SMALLINT
	LET m_songs = l_songs
	IF l_server IS NULL THEN
		CALL this.getListFromDB(l_id)
	ELSE
		CALL this.getListFromServer(l_server, l_id)
	END IF
	LET this.currentListId = l_id
	FOR x = 1 TO this.arrLen
		IF this.arr[x].id = l_id THEN
			LET this.currentList = this.arr[x].name
			EXIT FOR
		END IF
	END FOR
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION (this setList) getFromDB() RETURNS ()
	DEFINE l_setList RECORD LIKE setlist.*
	DECLARE sl_cur CURSOR FOR SELECT * FROM setlist WHERE stat != "D" OR stat IS NULL ORDER BY name
	FOREACH sl_cur INTO l_setlist.*
		CALL this.arr.appendElement()
		LET this.arrLen = this.arrLen + 1
		LET this.arr[ this.arrLen ].* = l_setlist.*
	END FOREACH
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION (this setList) getListFromDB( l_id INTEGER ) RETURNS ()
	DEFINE l_seq_no, l_song_id INTEGER
	DEFINE x SMALLINT
	CALL this.list.clear()
	LET this.listLen = 0
	LET this.saved = TRUE
	DECLARE sl2_cur CURSOR FOR
		SELECT song_id, seq_no FROM setlist_song WHERE setlist_id = l_id ORDER BY seq_no
	FOREACH sl2_cur INTO l_song_id, l_seq_no
		DISPLAY this.listLen," Song ID:",l_song_id
		IF l_song_id > 0 THEN
			LET this.listLen = this.listLen + 1
			CALL this.list.appendElement()
			FOR x = 1 TO m_songs.len
				IF m_songs.list[x].id = l_song_id THEN
					LET this.list[ this.listLen ].* = m_songs.list[x].*
				END IF
			END FOR
		ELSE
			CALL this.addBreak()
		END IF
	END FOREACH
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION (this setList) getFromServer(l_server STRING) RETURNS ()
	DEFINE x, y SMALLINT
	DEFINE l_ws_stat SMALLINT
	DEFINE l_ws_reply STRING
	DEFINE l_responsePages RECORD
		pages SMALLINT
	END RECORD
	DEFINE l_responseLists RECORD
	  arr DYNAMIC ARRAY OF RECORD LIKE setlist.*,
		len SMALLINT
	END RECORD
	LET cli_setlist.Endpoint.Address.Uri = l_server

	DISPLAY "Getting pages for setlist list ..."
	CALL cli_setlist.pagesSetLists() RETURNING l_ws_stat, l_ws_reply
	CALL g2_ws.service_reply_unpack( l_ws_stat, l_ws_reply ) RETURNING l_ws_stat, l_ws_reply
	DISPLAY "Setlist Pages Stat:", l_ws_stat," Reply:",l_ws_reply
	IF l_ws_stat != 0 THEN 
		CALL fgl_winMessage("WS Error",l_ws_reply,"exclamation")
		RETURN
	END IF
	CALL util.JSON.parse(l_ws_reply, l_responsePages )
	DISPLAY "Setlist Pages:",l_responsePages.pages

	FOR x = 1 TO l_responsePages.pages
		CALL cli_setlist.listSetLists(x) RETURNING l_ws_stat, l_ws_reply
		CALL g2_ws.service_reply_unpack( l_ws_stat, l_ws_reply ) RETURNING l_ws_stat, l_ws_reply
		DISPLAY "Setlists Stat:", l_ws_stat," Reply:",l_ws_reply
		IF l_ws_stat != 0 THEN 
			CALL fgl_winMessage("WS Error",l_ws_reply,"exclamation")
			RETURN
		END IF
		CALL util.JSON.parse(l_ws_reply, l_responseLists )
		FOR y = 1 TO l_responseLists.len
			LET this.arrLen = this.arrLen + 1
			LET this.arr[ this.arrLen ].* = l_responseLists.arr[y].*
		END FOR
	END FOR
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION (this setList) getListFromServer( l_server STRING, l_id INTEGER ) RETURNS ()
	DEFINE x, y SMALLINT
	DEFINE l_ws_stat SMALLINT
	DEFINE l_ws_reply STRING
	DEFINE l_responseLists RECORD
	  arr DYNAMIC ARRAY OF RECORD LIKE setlist_song.*,
		len SMALLINT
	END RECORD
	LET cli_setlist.Endpoint.Address.Uri = l_server
	CALL this.list.clear()
	LET this.listLen = 0
	LET this.saved = TRUE

	CALL cli_setlist.getSetList(l_id) RETURNING l_ws_stat, l_ws_reply
	CALL g2_ws.service_reply_unpack( l_ws_stat, l_ws_reply ) RETURNING l_ws_stat, l_ws_reply
	IF l_ws_stat != 0 THEN 
		CALL fgl_winMessage("WS Error",l_ws_reply,"exclamation")
		RETURN
	END IF
	DISPLAY "Setlist songs Stat:", l_ws_stat," Reply:",l_ws_reply
	CALL util.JSON.parse(l_ws_reply, l_responseLists )
	FOR y = 1 TO l_responseLists.len
		LET this.listLen = this.listLen + 1
			FOR x = 1 TO m_songs.len
				IF m_songs.list[x].id = l_responseLists.arr[y].song_id THEN
					LET this.list[ this.listLen ].* = m_songs.list[x].*
				END IF
			END FOR
	END FOR
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION (this setList) removeSong( l_idx INTEGER) RETURNS()
	CALL this.list.deleteElement( l_idx )
	LET this.saved = FALSE
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION (this setList) addSong( l_idx INTEGER, l_song songs.t_listitem) RETURNS()
	CALL this.list.insertElement( l_idx )
	LET this.list[ l_idx ].* = l_song.*
	LET this.listLen = this.listLen + 1
	LET this.saved = FALSE
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION (this setList) new(l_name LIKE setlist.name) RETURNS ()

	CALL this.list.clear()
	LET this.listLen = 0
	LET this.currentList = l_name
	LET this.currentListId = 0
	LET this.saved = FALSE
	CALL log.logIt( "New setlist:"||l_name)

END FUNCTION
--------------------------------------------------------------------------------
FUNCTION (this setList) del(l_server STRING) RETURNS()
	DEFINE l_ws_stat SMALLINT
	DEFINE l_ws_reply STRING
	DEFINE x SMALLINT
	LET cli_setlist.Endpoint.Address.Uri = l_server

	CALL this.list.clear()
	LET this.listLen = 0
	LET this.saved = TRUE

	CALL log.logIt( "Delete setlist Id:"||this.currentListId)
	IF l_server IS NULL THEN
		DELETE FROM setlist WHERE id = this.currentListId
		DELETE FROM setlist_song WHERE setlist_id = this.currentListId
	ELSE
		CALL cli_setlist.delSetList(this.currentListId) RETURNING l_ws_stat, l_ws_reply
	END IF

-- delete from list of lists
	FOR x = 1 TO this.arrLen
		IF this.arr[x].id = this.currentListId THEN
			CALL this.arr.deleteElement(x)
			EXIT FOR
		END IF
	END FOR
	LET this.arrLen = this.arrLen - 1

	MESSAGE "Setlist Deleted."

END FUNCTION
--------------------------------------------------------------------------------
FUNCTION (this setList) save(l_server STRING)
	DEFINE x SMALLINT	DEFINE l_ws_stat SMALLINT
	DEFINE l_ws_reply STRING
	DEFINE l_post cli_setlist.addSetListRequestBodyType
	DEFINE l_response RECORD
		reply STRING,
		id INTEGER
	END RECORD
	LET cli_setlist.Endpoint.Address.Uri = l_server

	CALL log.logIt( "Saving setlist Id:"||NVL(this.currentListId,"NULL"))
	IF l_server IS NULL THEN
		IF this.currentListId = 0 THEN
			INSERT INTO setlist ( name ) VALUES( this.currentList )
			LET this.currentListId = SQLCA.sqlerrd[2]
		END IF
		DELETE FROM setlist_song WHERE setlist_id = this.currentListId
		FOR x = 1 TO this.listLen
			INSERT INTO setlist_song VALUES( this.currentListId, this.list[x].id, x )
		END FOR
	ELSE
		LET l_post.id = this.currentListId
		LET l_post.name = this.currentList
		FOR x = 1 TO this.listLen
			LET l_post.items[x] = this.list[x].id
		END FOR
		CALL cli_setlist.addSetList(l_post.*) RETURNING l_ws_stat, l_ws_reply
		CALL g2_ws.service_reply_unpack( l_ws_stat, l_ws_reply ) RETURNING l_ws_stat, l_ws_reply
	END IF
	DISPLAY "Setlist save Stat:", l_ws_stat," Reply:",l_ws_reply
	CALL util.JSON.parse(l_ws_reply, l_response )
	IF l_response.id != 0 THEN
		LET this.currentListId = l_response.id
		LET this.saved = TRUE
		MESSAGE SFMT("Setlist %1 Saved.", l_response.id)
	ELSE
		CALL fgl_winMessage("Error", l_response.reply, "exclamation")
	END IF

END FUNCTION
--------------------------------------------------------------------------------
FUNCTION (this setList) addBreak() RETURNS ()
		LET this.listLen = this.listLen + 1
		CALL this.list.appendElement()
		LET this.list[ this.listLen ].lrn = "fa-coffee"
		LET this.list[ this.listLen ].titl = C_BREAK
		LET this.list[ this.listLen ].songkey = NULL
		LET this.list[ this.listLen ].tempo = NULL
		LET this.list[ this.listLen ].tim = NULL
		LET this.list[ this.listLen ].num = -1
		LET this.list[ this.listLen ].id = -1
END FUNCTION