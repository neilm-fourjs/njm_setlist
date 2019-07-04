
IMPORT FGL lib

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
	arr DYNAMIC ARRAY OF RECORD LIKE songs.*,
	list DYNAMIC ARRAY OF t_listitem,
	len SMALLINT
END RECORD
--------------------------------------------------------------------------------
FUNCTION (this songs) get(l_server STRING) RETURNS ()
	IF l_server IS NULL THEN
		CALL this.getFromDB()
	ELSE
		CALL this.getFromServer( l_server )
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
FUNCTION (this songs) getFromServer(l_server STRING) RETURNS ()
	DEFINE l_song RECORD LIKE songs.*
	CALL this.arr.clear()
	CALL this.list.clear()
	LET this.len = 0
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION (this songs)getSong( l_id INTEGER, l_song RECORD LIKE songs.* INOUT )
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
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION (this songs) upd(l_id INTEGER) RETURNS ()
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION (this songs) del(l_id INTEGER) RETURNS ()
END FUNCTION