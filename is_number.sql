
-- ----------------------------------------------------------------------------------------------
--
-- Script:      is_number.sql
--
-- Author:      Adrian Billington
--              www.oracle-developer.net
--
-- Description: A couple of variations of an IS_NUMBER function. This is a common approach that
--              can certainly be found in at least one well-known PL/SQL book.
--
--              a) SQL and PL/SQL Version
--                 ----------------------
--                 Returns 1 if TRUE or 0 if FALSE.
--
--                 Example usage:
--
--                    SELECT is_number( {char_column} )
--                    FROM   ...;
--
--                    SELECT ...
--                    FROM   ...
--                    WHERE  is_number(char_column) = 1;
--
--              b) PL/SQL-only Version
--                 -------------------
--
--                  boolean_var := is_number(char);
--
--                  IF is_number(char) THEN...
-- 
-- Version:     1.0: original
--              1.1: removed deterministic keyword (thanks to Matthias Rogel)
--
-- ----------------------------------------------------------------------------------------------

--
-- SQL and PL/SQL version. Returns 1 if TRUE or 0 if FALSE...
--
CREATE FUNCTION is_number (
                str_in IN VARCHAR2
                ) RETURN NUMBER PARALLEL_ENABLE IS
   n NUMBER;
BEGIN
   n := TO_NUMBER(str_in);
   RETURN 1;
EXCEPTION
   WHEN VALUE_ERROR THEN
      RETURN 0;
END;
/


--
-- PL/SQL-only version (returns BOOLEAN)...
--
CREATE FUNCTION is_number (
                str_in IN VARCHAR2
                ) RETURN BOOLEAN PARALLEL_ENABLE IS
   n NUMBER;
BEGIN
   n := TO_NUMBER(str_in);
   RETURN TRUE;
EXCEPTION
   WHEN VALUE_ERROR THEN
      RETURN FALSE;
END;
/

CREATE OR REPLACE PUBLIC SYNONYM is_number FOR is_number;
GRANT EXECUTE ON is_number TO PUBLIC;
