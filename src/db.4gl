IMPORT os
IMPORT FGL log

PUBLIC DEFINE m_db VARCHAR(60)
PUBLIC DEFINE m_dbname VARCHAR(20)
PUBLIC DEFINE m_dbtype STRING

--------------------------------------------------------------------------------
FUNCTION connect(l_db)
	DEFINE l_db STRING
	DEFINE l_created_db BOOLEAN

	LET m_dbtype = base.Application.getResourceEntry("dbi.default.driver")
	LET m_dbname = l_db

	IF m_dbtype = "dbmsqt" THEN
		LET m_db = "../db/"||m_dbname||".db" --||"+driver='dbmsqt3xx'"
		IF NOT os.path.exists( m_db ) THEN
			LET l_created_db = TRUE
			CALL create()
		END IF

		TRY
			DISCONNECT m_dbname
		CATCH
		END TRY
	ELSE
		LET m_db = m_dbname
	END IF

	CALL log.logIt( SFMT("Connecting to DB: %1 Driver: %2 Profile: %3",m_dbname,m_dbtype, fgl_getEnv("FGLPROFILE")))
	TRY
		CONNECT TO m_dbname
	CATCH
		CALL fgl_winMessage("Error",SFMT("Failed to connect to db '%1'!\n%2",m_dbname,SQLERRMESSAGE),"exclamation")
		EXIT PROGRAM
	END TRY

	IF l_created_db THEN
		CALL load()
	END IF
	CALL log.logIt( "Connected to DB:"||NVL(m_dbname,"NULL"))

END FUNCTION
--------------------------------------------------------------------------------
FUNCTION drop()

	CALL log.logIt( "Dropping Tables, DB:"||NVL(m_db,"NULL"))

	IF m_dbtype = "dbmsqt" THEN
		CREATE DATABASE m_db
		CALL connect(m_dbname)
	END IF

	TRY
		DROP TABLE songs
		DROP TABLE setlist
		DROP TABLE setlist_song
		DROP TABLE setlist_hist
		CALL fgl_winMessage("Drops","Tables dropped.","information")
	CATCH
		CALL fgl_winMessage("Error",SFMT("Failed to drop tables\n%1 %2",STATUS,SQLERRMESSAGE),"exclamation")
		EXIT PROGRAM
	END TRY
	CALL create()
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION create()

	CALL log.logIt( "Creating DB:"||NVL(m_db,"NULL"))

	IF m_dbtype = "dbmsqt" THEN
		CREATE DATABASE m_db
		CALL connect(m_dbname)
	END IF

	TRY
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
		CREATE UNIQUE INDEX i_song ON songs(id);

		CREATE TABLE setlist (
			id SERIAL,
			name VARCHAR(20),
			stat CHAR(1)
		)
		CREATE UNIQUE INDEX i_setlist ON setlist(id);

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
		CALL fgl_winMessage("Creates","Tables created.","information")
	CATCH
		CALL fgl_winMessage("Error",SFMT("Failed to create tables\n%1 %2",STATUS,SQLERRMESSAGE),"exclamation")
		EXIT PROGRAM
	END TRY

--	CALL load()

END FUNCTION
--------------------------------------------------------------------------------
FUNCTION newload()
	DEFINE l_file STRING

	LET l_file =  "songs.unl"
	CALL log.logIt( "Loading Data from:"||l_file)
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
	CALL log.logIt( "Loading Data from:"||l_file)
	LOAD FROM l_file INSERT INTO setlist (id, name )

	LET l_file =  "setlist_song.unl"
	CALL log.logIt( "Loading Data from:"||l_file)
	LOAD FROM l_file INSERT INTO setlist_song (setlist_id,
												song_id,
												seq_no
												 )
END FUNCTION
----------------------------------------------------------------------------------------------------
FUNCTION unload()
	UNLOAD TO "setlist.unl" SELECT * FROM setlist
	UNLOAD TO "setlist_song.unl" SELECT * FROM setlist_song
	UNLOAD TO "songs.unl" SELECT * FROM songs
	UNLOAD TO "setlist_hist.unl" SELECT * FROM setlist_hist
	CALL fgl_winMessage("Unloads","Data unloaded.","information")
END FUNCTION
----------------------------------------------------------------------------------------------------
FUNCTION load()
	DEFINE l_id INTEGER

	DELETE FROM setlist
	DELETE FROM setlist_song
	DELETE FROM setlist_hist
	DELETE FROM songs

	LOAD FROM "songs.unl" INSERT INTO songs
	IF m_dbtype = "dbmpgs" THEN
		SELECT MAX(id) INTO l_id FROM songs
		LET l_id = l_id + 1
		EXECUTE IMMEDIATE "SELECT setval('songs_id_seq', "||l_id||")"
	END IF

	LOAD FROM "setlist.unl" INSERT INTO setlist (id, name )
	IF m_dbtype = "dbmpgs" THEN
		SELECT MAX(id) INTO l_id FROM setlist
		LET l_id = l_id + 1
		EXECUTE IMMEDIATE "SELECT setval('setlist_id_seq', "||l_id||")"
	END IF

	LOAD FROM "setlist_song.unl" INSERT INTO setlist_song
	LOAD FROM "setlist_hist.unl" INSERT INTO setlist_hist

	CALL fgl_winMessage("Loads","Data loaded.","information")

END FUNCTION
----------------------------------------------------------------------------------------------------
FUNCTION backup()
	DEFINE l_back STRING
	DEFINE l_dbbackup STRING
	DEFINE l_tim CHAR(8)

	LET l_dbbackup = os.path.join( os.path.dirname(os.path.pwd()),"db_backup")
	IF NOT os.path.exists(l_dbbackup) THEN
		IF NOT os.path.mkdir(l_dbbackup) THEN
			CALL log.logIt( SFMT("Failed to make backup dir '%1'",l_dbbackup) )
		END IF
	END IF
	--LET l_dbbackup = os.path.join( l_dbbackup,"test" )
	--LET l_dbbackup = os.path.join( l_dbbackup,(TODAY USING "YYYY-MM-DD"||"-"||TIME))

	LET l_tim = TIME
	LET l_tim = l_tim[1,2]||l_tim[4,5]||l_tim[7,8]
	LET l_dbbackup = os.path.join( l_dbbackup,(TODAY USING "YYYYMMDD")||"-"||l_tim CLIPPED)
	LET l_back = l_dbbackup.append("-songs.unl")
	CALL log.logIt( "Back up songs to "||NVL(l_back,"NULL"))
	UNLOAD TO l_back SELECT * FROM songs
	LET l_back = l_dbbackup.append("-setlist.unl")
	CALL log.logIt( "Back up setlist to "||NVL(l_back,"NULL"))
	UNLOAD TO l_back SELECT * FROM setlist
	LET l_back = l_dbbackup.append("-setlist_song.unl")
	CALL log.logIt( "Back up setlist_song to "||NVL(l_back,"NULL"))
	UNLOAD TO l_back SELECT * FROM setlist_song
	LET l_back = l_dbbackup.append("-setlist_hist.unl")
	CALL log.logIt( "Back up setlist_hist to "||NVL(l_back,"NULL"))
	UNLOAD TO l_back SELECT * FROM setlist_hist
END FUNCTION
----------------------------------------------------------------------------------------------------