IMPORT com
IMPORT util
IMPORT FGL db
IMPORT FGL log
IMPORT FGL g2_ws

SCHEMA songs

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
	SELECT COUNT(*) INTO x FROM setlist
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
  DECLARE slcur SCROLL CURSOR FOR SELECT * FROM setlist
  IF l_pgno IS NULL THEN
    LET l_pgno = 1
  END IF
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
	LET response.len = response.arr.getLength()
  CALL log.logIt( SFMT("listSetLists: %1", response.arr.getLength()))
  RETURN g2_ws.service_reply(0, util.JSONObject.fromFGL(response).toString())
END FUNCTION
----------------------------------------------------------------------------------------------------
-- get list of setLists songs
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
-- Just exit the service
PUBLIC FUNCTION exit(
    ) ATTRIBUTES(WSGet, WSPath = "/exit", WSDescription = "Exit the service")
    RETURNS STRING
  CALL log.logIt("Server stopped by 'exit' call")
  RETURN g2_ws.service_reply(0, "Service Stopped.")
END FUNCTION
