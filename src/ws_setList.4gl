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
  CALL db.connect("songs")
  CALL log.logIt("Service started.")
  CALL g2_ws.start("ws_setList", "ws_setList")
END FUNCTION

----------------------------------------------------------------------------------------------------
-- WEB SERVICE FUNCTIONS
----------------------------------------------------------------------------------------------------

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

  RETURN g2_ws.service_reply(0, util.JSONArray.fromFGL(l_arr).toString())
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

  RETURN g2_ws.service_reply(0, util.JSONArray.fromFGL(l_arr).toString())
END FUNCTION
----------------------------------------------------------------------------------------------------
-- Just exit the service
PUBLIC FUNCTION exit(
    ) ATTRIBUTES(WSGet, WSPath = "/exit", WSDescription = "Exit the service")
    RETURNS STRING
  CALL log.logIt("Server stopped by 'exit' call")
  RETURN g2_ws.service_reply(0, "Service Stopped.")
END FUNCTION
