IMPORT os

DEFINE m_db VARCHAR(60)
DEFINE m_dbname VARCHAR(20)

--------------------------------------------------------------------------------
FUNCTION db_connect(l_db)
	DEFINE l_db STRING
	DEFINE l_created_db BOOLEAN

	LET m_dbname = l_db
	LET m_db = "../db/"||m_dbname||".db" --||"+driver='dbmsqt3xx'"
	IF NOT os.path.exists( m_db ) THEN
		LET l_created_db = db_create()
	END IF

	TRY
		DISCONNECT m_dbname
	CATCH
	END TRY
	CALL log( "Connecting to DB:"||NVL(m_dbname,"NULL"))
	TRY
		CONNECT TO m_dbname
	CATCH
		CALL fgl_winMessage("Error",SFMT("Failed to connect to db '%1'!\n%2",m_dbname,SQLERRMESSAGE),"exclamation")
		EXIT PROGRAM
	END TRY

	IF l_created_db THEN
		CALL db_load()
	END IF
	CALL log( "Connected to DB:"||NVL(m_dbname,"NULL"))

END FUNCTION
--------------------------------------------------------------------------------
FUNCTION db_create()

	CALL log( "Creating DB:"||NVL(m_db,"NULL"))
	CREATE DATABASE m_db

	CALL db_connect(m_dbname)

	CREATE TABLE songs (
		id SERIAL,
		titl VARCHAR(40),
		artist VARCHAR(40),
		dur SMALLINT,
		done_live CHAR(1),
		learnt CHAR(1),
		recorded CHAR(1),
		tempo CHAR(1),
		songkey CHAR(3),
		style CHAR(1),
		genre CHAR(1),
		vox VARCHAR(16),
		vox_fx VARCHAR(16),
		tuning CHAR(2),
		capo SMALLINT,
		guitar_fx VARCHAR(16)
	)

	CREATE TABLE setlist (
		id SERIAL,
		name VARCHAR(20)
	)

	CREATE TABLE setlist_song (
		setlist_id INTEGER,
		song_id INTEGER,
		seq_no SMALLINT
	)

	CREATE TABLE setlist_hist (
		setlist_id INTEGER,
		location VARCHAR(80),
		performance DATE
	)

	RETURN TRUE
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION db_load()
	DEFINE l_file STRING

	LET l_file =  "songs.unl"
	CALL log( "Loading Data from:"||l_file)
	LOAD FROM l_file INSERT INTO songs ( 
												titl, 
												artist, 
												dur ) {,
												done_live,
												learnt,
												recorded ,
												tempo,
												songkey,
												style,
												genre,
												vox,
												vox_fx,
												tuning,
												capo,
												guitar_fx)}

	UPDATE songs SET dur = 0 WHERE dur IS NULL;
	UPDATE songs SET capo = 0 WHERE capo IS NULL;
	UPDATE songs SET vox = "T" WHERE vox IS NULL;
	UPDATE songs SET vox_fx = "None" WHERE vox_fx IS NULL;
	UPDATE songs SET guitar_fx = "None" WHERE guitar_fx IS NULL;
	UPDATE songs SET tuning = "S" WHERE tuning IS NULL;

	LET l_file =  "setlist.unl"
	CALL log( "Loading Data from:"||l_file)
	LOAD FROM l_file INSERT INTO setlist (id, name )

	LET l_file =  "setlist_song.unl"
	CALL log( "Loading Data from:"||l_file)
	LOAD FROM l_file INSERT INTO setlist_song (setlist_id,
												song_id,
												seq_no
												 )

END FUNCTION
