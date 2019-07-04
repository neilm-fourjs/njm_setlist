IMPORT FGL lib
IMPORT FGL log
IMPORT FGL songs
SCHEMA songs

PUBLIC CONSTANT C_BREAK = "    *** BREAK *** "
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
	IF l_server IS NULL THEN
		CALL this.getFromDB()
	ELSE
		CALL this.getFromServer(l_server)
	END IF
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION (this setList) getFromDB() RETURNS ()
	DEFINE l_setList RECORD LIKE setlist.*
	CALL this.arr.clear()
	LET this.arrLen = 0
	DECLARE sl_cur CURSOR FOR SELECT * FROM setlist
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
	LET this.saved = TRUE
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
--------------------------------------------------------------------------------
FUNCTION (this setList) getFromServer(l_server STRING) RETURNS ()
	CALL this.arr.clear()
	LET this.arrLen = 0
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION (this setList) getListFromServer( l_server STRING, l_id INTEGER ) RETURNS ()

END FUNCTION
--------------------------------------------------------------------------------
FUNCTION (this setList) new() RETURNS()
	DEFINE l_name VARCHAR(20)
	DEFINE x SMALLINT
	LET int_flag = FALSE
	PROMPT "Enter Name for Set List:" FOR l_name
	IF int_flag OR l_name IS NULL THEN RETURN END IF

	FOR x = 1 TO this.arrLen
		IF this.arr[x].name != l_name THEN
			CALL fgl_winMessage("Error","Set List already exists!","exclamation")
			RETURN
		END IF
	END FOR

	INSERT INTO setlist ( name ) VALUES( l_name )
	CALL this.list.clear()
	LET this.listLen = 0
	LET this.currentList = l_name
	LET this.currentListId = SQLCA.sqlerrd[2]
	LET this.saved = FALSE
	CALL log.logIt( "New setlist Id:"||this.currentListId||" Name:"||l_name)

END FUNCTION
--------------------------------------------------------------------------------
FUNCTION (this setList) del() RETURNS()

	CALL log.logIt( "Delete setlist Id:"||this.currentListId)
	DELETE FROM setlist WHERE id = this.currentListId
	DELETE FROM setlist_song WHERE setlist_id = this.currentListId
	MESSAGE "Setlist Deleted."
	CALL this.list.clear()

END FUNCTION
--------------------------------------------------------------------------------
FUNCTION (this setList) save()
	DEFINE x SMALLINT

	CALL log.logIt( "Saving setlist Id:"||NVL(this.currentListId,"NULL"))
	DELETE FROM setlist_song WHERE setlist_id = this.currentListId
	FOR x = 1 TO this.listLen
		INSERT INTO setlist_song VALUES( this.currentListId, this.list[x].id, x )
	END FOR
	LET this.saved = TRUE
	MESSAGE "Setlist Saved."

END FUNCTION