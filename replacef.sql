
-- --------------------------------------------------------------------------------------
--
-- Script:      replacef.sql
--
-- Version:     1.1
--
-- Author:      Adrian Billington
--              www.oracle-developer.net
--
-- Description: A function and collection type to simplify building and debugging of
--              strings, particularly dynamic SQL.
--
--              Example Usage
--              -------------
--
--              a) Debugging based on inputs
--
--                 DECLARE
--                    v_sql   VARCHAR2(128);
--                    nt_args replacef_ntt := replacef_ntt();
--                 BEGIN
--                    v_sql := 'ALTER TABLE %s.%s TRUNCATE PARTITION %s';
--                    nt_args := replacef_ntt('table_owner','table_name','partition_name');
--                    DBMS_OUTPUT.PUT_LINE(replacef(v_sql,nt_args));
--                 END;
--                 /
--
--              b) Building strings for execute
--
--                 DECLARE
--                    v_sql   VARCHAR2(128);
--                    nt_args replacef_ntt := replacef_ntt();
--                 BEGIN
--                    v_sql := 'ALTER TABLE %s.%s TRUNCATE PARTITION %s';
--                    nt_args := replacef_ntt('table_owner','table_name','partition_name');
--                    v_sql := replacef(v_sql,nt_args);
--                    EXECUTE IMMEDIATE v_sql;
--                 END;
--                 /
--
--              Note that the number of replacements is determined by whichever has the
--              fewest components - that is, the least of the number of placeholders in 
--              the string or the number of elements in the collection. You might wish
--              to change this to raise an exception on mismatch.
-- 
-- History:     1.0: initial version
--              1.1: bug-fix in v_args algorithm (thanks to Jason Weinstein for correction)
--
--
-- --------------------------------------------------------------------------------------


CREATE TYPE replacef_ntt AS TABLE OF VARCHAR2(4000);
/

CREATE FUNCTION replacef ( p_msg  IN VARCHAR2,
                           p_args IN replacef_ntt DEFAULT replacef_ntt(),
                           p_plc  IN VARCHAR2 DEFAULT '%s' ) RETURN VARCHAR2 IS

   v_msg  VARCHAR2(32767) := p_msg;
   v_args PLS_INTEGER := LEAST((LENGTH(v_msg)-LENGTH(REPLACE(v_msg,p_plc)))/LENGTH(p_plc),p_args.COUNT);
   v_pos  PLS_INTEGER;

BEGIN

   FOR i IN 1 .. v_args LOOP
      v_pos := INSTR( v_msg, p_plc );
      v_msg := REPLACE( 
                  SUBSTR( v_msg, 1, v_pos + LENGTH(p_plc)-1 ), p_plc, p_args(i)
                  ) || SUBSTR( v_msg, v_pos + LENGTH(p_plc) );
   END LOOP;
   
   RETURN v_msg;
   
END replacef;
/

CREATE PUBLIC SYNONYM replacef_ntt FOR args_ntt;
CREATE PUBLIC SYNONYM replacef FOR replacef;
GRANT EXECUTE ON replacef_ntt TO PUBLIC;
GRANT EXECUTE ON replacef TO PUBLIC;
