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
  DEFINE l_arr DYNAMIC ARRAY OF RECORD LIKE songs.*
  DEFINE x, y SMALLINT
  DECLARE songcur SCROLL CURSOR FOR SELECT * FROM songs
  IF l_pgno IS NULL THEN
    LET l_pgno = 1
  END IF
  OPEN songcur
  LET y = 1
  LET x = ((l_pgno - 1) * c_itemsPerPage) + 1
  WHILE STATUS != NOTFOUND
    DISPLAY "Row:", x
    FETCH ABSOLUTE x songcur INTO l_arr[y].*
    LET y = y + 1
    LET x = x + 1
    IF y = c_itemsPerPage THEN
      EXIT WHILE
    END IF
  END WHILE
  CLOSE songcur
  CALL log.logIt( SFMT("listSongs: %1", l_arr.getLength()))
  RETURN g2_ws.service_reply(0, util.JSONArray.fromFGL(l_arr).toString())
END FUNCTION
----------------------------------------------------------------------------------------------------
-- get no of pages for setLists
PUBLIC FUNCTION pagesSetLists()
    ATTRIBUTES(WSGet, WSPath = "/pagesSetLists", WSDescription = "Get No of Pages of SetLists")
    RETURNS STRING
	DEFINE response RECORD
		pages SMALLINT
	END RECORD
	SELECT COUNT(*) INTO response.pages FROM setlist
	LET response.pages = response.pages / c_itemsPerPage
	IF response.pages MOD c_itemsPerPage THEN LET response.pages = response.pages + 1 END IF
  CALL log.logIt( SFMT("pagesSetLists: %1", response.pages))
  RETURN g2_ws.service_reply(0, util.JSONObject.fromFGL(response).toString())
END FUNCTION
----------------------------------------------------------------------------------------------------
-- get list of setLists
PUBLIC FUNCTION listSetLists(
    l_pgno SMALLINT ATTRIBUTES(WSParam))
    ATTRIBUTES(WSGet, WSPath = "/listSetLists/{l_pgno}", WSDescription = "Get SetList List")
    RETURNS STRING
  DEFINE l_arr DYNAMIC ARRAY OF RECORD LIKE setlist.*
  DEFINE x, y SMALLINT
  DECLARE slcur SCROLL CURSOR FOR SELECT * FROM setlist
  IF l_pgno IS NULL THEN
    LET l_pgno = 1
  END IF
  OPEN slcur
  LET y = 1
  LET x = ((l_pgno - 1) * c_itemsPerPage) + 1
  WHILE STATUS != NOTFOUND
    DISPLAY "Row:", x
    FETCH ABSOLUTE x slcur INTO l_arr[y].*
    LET y = y + 1
    LET x = x + 1
    IF y = c_itemsPerPage THEN
      EXIT WHILE
    END IF
  END WHILE
  CLOSE slcur
  CALL log.logIt( SFMT("listSetLists: %1", l_arr.getLength()))
  RETURN g2_ws.service_reply(0, util.JSONArray.fromFGL(l_arr).toString())
END FUNCTION
----------------------------------------------------------------------------------------------------
-- get list of setLists songs
PUBLIC FUNCTION getSetList(
    l_id SMALLINT ATTRIBUTES(WSParam))
    ATTRIBUTES(WSGet, WSPath = "/getSetList/{l_id}", WSDescription = "Get SetList List")
    RETURNS STRING
  DEFINE l_arr DYNAMIC ARRAY OF RECORD LIKE setlist_song.*
  DECLARE slscur SCROLL CURSOR FOR SELECT * FROM setlist_song WHERE setlist_id = l_id
  FOREACH slscur INTO l_arr[ l_arr.getLength() + 1 ].*
	END FOREACH
	CALL l_arr.deleteElement( l_arr.getLength() )
  CALL log.logIt( SFMT("getSetList: %1", l_arr.getLength()))
	IF l_arr.getLength() > 0 THEN
  	RETURN g2_ws.service_reply(0, util.JSONArray.fromFGL(l_arr).toString())
	ELSE
  	RETURN g2_ws.service_reply(100, util.JSONArray.fromFGL(l_arr).toString())
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
