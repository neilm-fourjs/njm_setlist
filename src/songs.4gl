
IMPORT util
IMPORT FGL lib
IMPORT FGL g2_ws
IMPORT FGL cli_setlist

SCHEMA songs

PUBLIC TYPE t_listitem RECORD
		num SMALLINT,
		id INTEGER,
		titl VARCHAR(40),
		lrn VARCHAR(40),
		dur SMALLINT,
		tim CHAR(5),
		tempo STRING,
		songkey STRING
	END RECORD

PUBLIC TYPE songs RECORD
  server STRING,
	arr DYNAMIC ARRAY OF RECORD LIKE songs.*,
	list DYNAMIC ARRAY OF t_listitem,
	len SMALLINT
END RECORD
--------------------------------------------------------------------------------
FUNCTION (this songs) get(l_server STRING) RETURNS ()
	LET this.server = l_server
	IF l_server IS NULL THEN
		CALL this.getFromDB()
	ELSE
		CALL this.getFromWS()
	END IF
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION (this songs) getFromDB() RETURNS ()
	DEFINE l_song RECORD LIKE songs.*
	CALL this.arr.clear()
	CALL this.list.clear()
	LET this.len = 0
	DECLARE song_cur CURSOR FOR SELECT * FROM songs ORDER BY titl
	FOREACH song_cur INTO l_song.*
		CALL this.arr.appendElement()
		LET this.len = this.len + 1
		LET this.arr[ this.len ].* = l_song.*
		CALL this.set_listItem( this.len )
	END FOREACH
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION (this songs) getFromWS() RETURNS ()
	DEFINE x, y SMALLINT
	DEFINE l_ws_stat SMALLINT
	DEFINE l_ws_reply STRING
	DEFINE l_responsePages RECORD
		pages SMALLINT
	END RECORD
	DEFINE l_responseSongs RECORD
	  arr DYNAMIC ARRAY OF RECORD LIKE songs.*,
		len SMALLINT
	END RECORD
	LET cli_setlist.Endpoint.Address.Uri = this.server

	CALL this.arr.clear()
	CALL this.list.clear()
	LET this.len = 0

	DISPLAY "Getting pages for songs list ..."
	CALL cli_setlist.pagesSongs() RETURNING l_ws_stat, l_ws_reply
	CALL g2_ws.service_reply_unpack( l_ws_stat, l_ws_reply ) RETURNING l_ws_stat, l_ws_reply
	DISPLAY "Songs Pages Stat:", l_ws_stat," Reply:",l_ws_reply
	IF l_ws_stat != 0 THEN 
		CALL fgl_winMessage("WS Error",l_ws_reply,"exclamation")
		RETURN
	END IF

	CALL util.JSON.parse(l_ws_reply, l_responsePages )
	DISPLAY "Songs Pages:",l_responsePages.pages

	FOR x = 1 TO l_responsePages.pages
		CALL cli_setlist.listSongs(x) RETURNING l_ws_stat, l_ws_reply
		CALL g2_ws.service_reply_unpack( l_ws_stat, l_ws_reply ) RETURNING l_ws_stat, l_ws_reply
--		DISPLAY "Songs Stat:", l_ws_stat," Reply:",l_ws_reply
		IF l_ws_stat != 0 THEN 
			CALL fgl_winMessage("WS Error",l_ws_reply,"exclamation")
			RETURN
		END IF
		CALL util.JSON.parse(l_ws_reply, l_responseSongs )
		FOR y = 1 TO l_responseSongs.len
			LET this.len = this.len + 1
			LET this.arr[ this.len ].* = l_responseSongs.arr[y].*
			CALL this.set_listItem( this.len )
		END FOR
	END FOR

END FUNCTION
--------------------------------------------------------------------------------
FUNCTION (this songs) getSong( l_id INTEGER, l_song RECORD LIKE songs.* INOUT )
	DEFINE x SMALLINT
	INITIALIZE l_song.* TO NULL
	FOR x = 1 TO this.len
		IF this.arr[x].id = l_id THEN
			LET l_song.* = this.arr[x].*
		END IF
	END FOR
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION (this songs) set_listItem(x SMALLINT) RETURNS ()
	DEFINE l_listitem t_listitem
	LET l_listitem.id = this.arr[x].id
	LET l_listitem.num = x
	LET l_listitem.titl = this.arr[x].titl
	LET l_listitem.dur = this.arr[x].dur
	LET l_listitem.songkey = this.arr[x].songkey
	LET l_listitem.tim = lib.sec_to_time( l_listitem.dur, FALSE )
	LET l_listitem.lrn = this.arr[x].learnt
	IF l_listitem.lrn IS NULL THEN LET l_listitem.lrn = "N" END IF
	CASE l_listitem.lrn
		WHEN "Y" LET l_listitem.lrn = "learnt_y"
		WHEN "N" LET l_listitem.lrn = "learnt_n"
		WHEN "A" LET l_listitem.lrn = "learnt_a"
	END CASE
	LET l_listitem.tempo = this.arr[x].tempo
	IF l_listitem.tempo IS NULL THEN LET l_listitem.tempo = " " END IF
	CASE l_listitem.tempo
		WHEN "F" LET l_listitem.tempo = "tempo_f"
		WHEN "M" LET l_listitem.tempo = "tempo_m"
		WHEN "S" LET l_listitem.tempo = "tempo_s"
	END CASE
	LET this.list[ x ].* =  l_listitem.*
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION (this songs) new(l_id INTEGER) RETURNS ()
	LET cli_setlist.Endpoint.Address.Uri = this.server
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION (this songs) upd(l_id INTEGER) RETURNS ()
	LET cli_setlist.Endpoint.Address.Uri = this.server
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION (this songs) del(l_id INTEGER) RETURNS ()
	LET cli_setlist.Endpoint.Address.Uri = this.server
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION (this songs) totals() RETURNS (INT, INT)
	DEFINE l_tot, x, l_cnt SMALLINT
	LET l_tot = 0
	LET l_cnt = 0
	FOR x = 1 TO this.len
		LET l_tot = l_tot + this.arr[x].dur
	END FOR
	RETURN l_tot, l_cnt
END FUNCTION