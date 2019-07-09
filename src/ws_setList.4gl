IMPORT com
IMPORT util
IMPORT FGL db
IMPORT FGL log
IMPORT FGL g2_ws

SCHEMA songs

TYPE t_addSetList RECORD
	id INTEGER,
	name LIKE setlist.name,
	items DYNAMIC ARRAY OF INTEGER
END RECORD

CONSTANT c_itemsPerPage = 50

----------------------------------------------------------------------------------------------------
-- Initialize the service: Start the log, connect to database and start the service
PUBLIC FUNCTION init()
	CALL STARTLOG( log.errorLogName() )
  CALL db.connect("songs")
	WHENEVER ERROR CALL log.error_log
	LET g2_ws.m_server = fgl_getEnv("HOSTNAME")
  CALL log.logIt("Service started.")
  CALL g2_ws.start("ws_setList", "ws_setList")
END FUNCTION

----------------------------------------------------------------------------------------------------
-- WEB SERVICE FUNCTIONS
----------------------------------------------------------------------------------------------------


----------------------------------------------------------------------------------------------------
-- get no of pages for songs
PUBLIC FUNCTION pagesSongs()
    ATTRIBUTES(WSGet, WSPath = "/pagesSongs", WSDescription = "Get No of Pages of Songs")
    RETURNS STRING
	DEFINE response RECORD
		pages SMALLINT
	END RECORD
	SELECT COUNT(*) INTO response.pages FROM songs
	LET response.pages = response.pages / c_itemsPerPage
	IF response.pages MOD c_itemsPerPage THEN LET response.pages = response.pages + 1 END IF
  CALL log.logIt( SFMT("pagesSongs: %1", response.pages))
  RETURN g2_ws.service_reply(0, util.JSONObject.fromFGL(response).toString())
END FUNCTION
----------------------------------------------------------------------------------------------------
-- get list of songs
PUBLIC FUNCTION listSongs(
    l_pgno SMALLINT ATTRIBUTES(WSParam))
    ATTRIBUTES(WSGet, WSPath = "/listSongs/{l_pgno}", WSDescription = "Get Song List")
    RETURNS STRING
	DEFINE response RECORD
		arr DYNAMIC ARRAY OF RECORD LIKE songs.*,
		len SMALLINT
	END RECORD
  DEFINE x, y SMALLINT
  DECLARE songcur SCROLL CURSOR FOR SELECT * FROM songs ORDER BY titl
  IF l_pgno IS NULL THEN
    LET l_pgno = 1
  END IF
  OPEN songcur
  LET y = 1
  LET x = ((l_pgno - 1) * c_itemsPerPage) + 1
  WHILE STATUS != NOTFOUND
    FETCH ABSOLUTE x songcur INTO response.arr[y].*
    IF y = c_itemsPerPage OR STATUS = NOTFOUND THEN EXIT WHILE END IF
    DISPLAY "Row:", x," Titl:", response.arr[y].titl
    LET y = y + 1
    LET x = x + 1
  END WHILE
	IF response.arr[ response.arr.getLength() ].titl IS NULL THEN
		CALL response.arr.deleteElement( response.arr.getLength() )
	END IF
  CLOSE songcur
	LET response.len = response.arr.getLength()
  CALL log.logIt( SFMT("listSongs: %1", response.arr.getLength()))
  RETURN g2_ws.service_reply(0, util.JSONObject.fromFGL(response).toString())
END FUNCTION
----------------------------------------------------------------------------------------------------
-- get no of pages for setLists
PUBLIC FUNCTION pagesSetLists()
    ATTRIBUTES(WSGet, WSPath = "/pagesSetLists", WSDescription = "Get No of Pages of SetLists")
    RETURNS STRING
	DEFINE x SMALLINT
	DEFINE response RECORD
		pages SMALLINT
	END RECORD
	SELECT COUNT(*) INTO x FROM setlist WHERE stat != "D" OR stat IS NULL
	LET response.pages = x / c_itemsPerPage
	IF response.pages MOD c_itemsPerPage THEN LET response.pages = response.pages + 1 END IF
	IF response.pages = 0 AND x > 0 THEN LET response.pages = 1 END IF
  CALL log.logIt( SFMT("pagesSetLists: %1", response.pages))
  RETURN g2_ws.service_reply(0, util.JSONObject.fromFGL(response).toString())
END FUNCTION
----------------------------------------------------------------------------------------------------
-- get list of setLists
PUBLIC FUNCTION listSetLists(
    l_pgno SMALLINT ATTRIBUTES(WSParam))
    ATTRIBUTES(WSGet, WSPath = "/listSetLists/{l_pgno}", WSDescription = "Get SetList List")
    RETURNS STRING
	DEFINE response RECORD
		arr DYNAMIC ARRAY OF RECORD LIKE setlist.*,
		len SMALLINT
	END RECORD
  DEFINE x, y SMALLINT
  DECLARE slcur SCROLL CURSOR FOR SELECT * FROM setlist WHERE stat != "D" OR stat IS NULL ORDER BY name
  IF l_pgno IS NULL THEN LET l_pgno = 1 END IF
  OPEN slcur
  LET y = 1
  LET x = ((l_pgno - 1) * c_itemsPerPage) + 1
  WHILE STATUS != NOTFOUND
    FETCH ABSOLUTE x slcur INTO response.arr[y].*
    IF y = c_itemsPerPage OR STATUS = NOTFOUND THEN EXIT WHILE END IF
    DISPLAY "Row x:",x," y:",y, " name:",response.arr[y].name
    LET y = y + 1
    LET x = x + 1
    IF y = c_itemsPerPage THEN
      EXIT WHILE
    END IF
  END WHILE
  CLOSE slcur
	IF response.arr[y].name IS NULL THEN CALL response.arr.deleteElement(y) END IF
	LET response.len = response.arr.getLength()
  CALL log.logIt( SFMT("listSetLists: %1", response.arr.getLength()))
  RETURN g2_ws.service_reply(0, util.JSONObject.fromFGL(response).toString())
END FUNCTION
----------------------------------------------------------------------------------------------------
-- get a setLists
PUBLIC FUNCTION getSetList(
    l_id SMALLINT ATTRIBUTES(WSParam))
    ATTRIBUTES(WSGet, WSPath = "/getSetList/{l_id}", WSDescription = "Get SetList List")
    RETURNS STRING
	DEFINE response RECORD
		arr DYNAMIC ARRAY OF RECORD LIKE setlist_song.*,
		len SMALLINT
	END RECORD
  DECLARE slscur SCROLL CURSOR FOR SELECT * FROM setlist_song WHERE setlist_id = l_id ORDER BY seq_no
  FOREACH slscur INTO response.arr[ response.arr.getLength() + 1 ].*
	END FOREACH
	CALL response.arr.deleteElement( response.arr.getLength() )
	LET response.len = response.arr.getLength()
  CALL log.logIt( SFMT("getSetList: %1", response.len))
	IF response.len > 0 THEN
  	RETURN g2_ws.service_reply(0,  util.JSONObject.fromFGL(response).toString())
	ELSE
  	RETURN g2_ws.service_reply(100, util.JSONObject.fromFGL(response).toString() )
	END IF
END FUNCTION
----------------------------------------------------------------------------------------------------
-- add a setList
PUBLIC FUNCTION addSetList( l_newSetList t_addSetList)
    ATTRIBUTES(WSPost, WSPath = "/addSetList", WSDescription = "Add SetList")
    RETURNS STRING
	DEFINE response RECORD
		reply STRING,
		id INTEGER
	END RECORD = ( reply: "addSetList", id: 0 )
	DEFINE x SMALLINT
	DEFINE l_stat CHAR(1) = "N"

	IF l_newSetList.id != 0 THEN
		DELETE FROM setlist WHERE id = l_newSetList.id
		DELETE FROM setlist_song WHERE setlist_id = l_newSetList.id
		LET l_stat = "U"
		TRY
			LET response.id = l_newSetList.id
			INSERT INTO setlist (id, name, stat) VALUES( l_newSetList.id, l_newSetList.name, l_stat )
			CALL db.fix_setlistSerial()
		CATCH
			LET response.reply = "Error %1 : %2", STATUS, SQLERRMESSAGE
		END TRY
	ELSE
		TRY
			INSERT INTO setlist ( name, stat) VALUES( l_newSetList.name, l_stat )
			LET response.id = SQLCA.sqlerrd[2]
		CATCH
			LET response.reply = "Error %1 : %2", STATUS, SQLERRMESSAGE
		END TRY
	END IF

	IF response.id != 0 THEN
		FOR x = 1 TO l_newSetList.items.getLength()
			INSERT INTO setlist_song VALUES( response.id, l_newSetList.items[x], x)
		END FOR
		CALL log.logIt( SFMT("addSetList id: %1 stat: %2 items: %3", response.id, l_stat, l_newSetList.items.getLength()))
		LET response.reply = SFMT("setList %1 inserted songs: %2", l_newSetList.name, l_newSetList.items.getLength())
	END IF
  RETURN g2_ws.service_reply(0,  util.JSONObject.fromFGL(response).toString())
END FUNCTION
----------------------------------------------------------------------------------------------------
-- delete setList
PUBLIC FUNCTION delSetList(
    l_id SMALLINT ATTRIBUTES(WSParam))
    ATTRIBUTES(WSGet, WSPath = "/delSetList/{l_id}", WSDescription = "Delete SetList")
    RETURNS STRING
	DEFINE response RECORD
		reply STRING
	END RECORD
{
	DELETE FROM setlist WHERE id = l_id
	DELETE FROM setlist_song WHERE setlist_id = l_id
}
	UPDATE setlist SET stat = "D" WHERE id = l_id
	IF STATUS = 0 THEN
		LET response.reply = SFMT("Setlist %1 deleted.", l_id)
	ELSE
		LET response.reply = SFMT("Setlist %1 delete failed: %2 %3.", l_id, STATUS,SQLERRMESSAGE)
	END IF
  CALL log.logIt( SFMT("delSetList: %1 - Reply: %2", l_id, response.reply ))
  RETURN g2_ws.service_reply(0,  util.JSONObject.fromFGL(response).toString())
END FUNCTION
----------------------------------------------------------------------------------------------------
-- Just exit the service
PUBLIC FUNCTION exit(
    ) ATTRIBUTES(WSGet, WSPath = "/exit", WSDescription = "Exit the service")
    RETURNS STRING
  CALL log.logIt("Server stopped by 'exit' call")
  RETURN g2_ws.service_reply(0, "Service Stopped.")
END FUNCTION
