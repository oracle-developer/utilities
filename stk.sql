
-- ---------------------------------------------------------------------------------------------------
--
-- Script:      stk.sql
--
-- Author:      Adrian Billington
--              www.oracle-developer.net
--
-- Description: A package for parsing the PL/SQL call stack. Includes functions to identify a
--              program's name or its caller.
--
-- Usage:       Use in PL/SQL. The available functions are as follows:
--
--                 a) WHOAMI returns either SCHEMA.OBJECT or anonymous block;
--
--                 b) CALLER returns either SCHEMA.OBJECT or anonymous block of a program's
--                    invoker. Additionally, the program name of any level in the stack can
--                    be optionally returned;
--
--                 c) PARSE is exposed to return an entire line of the stack at the supplied
--                    depth.
-- 
-- ---------------------------------------------------------------------------------------------------

CREATE PACKAGE stk AS

   FUNCTION parse (
            depth_in IN PLS_INTEGER DEFAULT 2
            ) RETURN VARCHAR2;

   FUNCTION caller (
            depth_in IN PLS_INTEGER DEFAULT 3
            ) RETURN VARCHAR2;

   FUNCTION whoami RETURN VARCHAR2;

END stk;
/

CREATE PACKAGE BODY stk AS

   TYPE ntt_varchar2 IS TABLE OF VARCHAR2(1028);

   FUNCTION string_to_table (
            string_in    IN VARCHAR2,
            delimiter_in IN VARCHAR2 DEFAULT ','
            ) RETURN ntt_varchar2 IS
            
      v_wkg_str VARCHAR2(32767) := string_in || delimiter_in;
      v_pos     PLS_INTEGER;
      nt_return ntt_varchar2 := ntt_varchar2();
      
   BEGIN
   
      LOOP
         v_pos := INSTR(v_wkg_str,delimiter_in);
         EXIT WHEN NVL(v_pos,0) = 0;
         nt_return.EXTEND;
         nt_return(nt_return.LAST) := TRIM(SUBSTR(v_wkg_str,1,v_pos-1));
         v_wkg_str := SUBSTR(v_wkg_str,v_pos+1);
      END LOOP;

      RETURN nt_return;

   END string_to_table;
   
   --------------------------------------------------------------

   FUNCTION parse (
            depth_in IN PLS_INTEGER DEFAULT 2
            ) RETURN VARCHAR2 IS
   
      v_call_stack   VARCHAR2(4096);
      nt_stack_lines ntt_varchar2;
      c_recsep       CONSTANT VARCHAR2(1) := CHR(10);
      c_headlines    CONSTANT PLS_INTEGER := 3;
   
   BEGIN
   
      /* Get the call stack, removing the trailing newline... */
      v_call_stack := RTRIM(DBMS_UTILITY.FORMAT_CALL_STACK, c_recsep);
   
      /* Turn the call stack into a collection of lines... */
      nt_stack_lines := string_to_table(v_call_stack, c_recsep);
   
      /* Return the depth required (ignoring the header lines)... */
      RETURN nt_stack_lines(depth_in + c_headlines);
   
   EXCEPTION
      WHEN SUBSCRIPT_BEYOND_COUNT THEN
         RETURN NULL;
   END parse;

   --------------------------------------------------------------

   FUNCTION caller (
            depth_in IN PLS_INTEGER DEFAULT 3
            ) RETURN VARCHAR2 IS
   
      v_callinfo VARCHAR2(255);
      v_proginfo VARCHAR2(128);
      v_lineinfo PLS_INTEGER;
      v_return   VARCHAR2(128);
      c_colsep   CONSTANT VARCHAR2(2) := '  '; -- two spaces
      c_no_stack CONSTANT VARCHAR2(32) := 'Caller information not available'; 
   
   BEGIN
   
      /* Get the call information from the call stack... */
      v_callinfo := stk.parse(depth_in);
   
      /* Strip out the program and line number... */
      IF v_callinfo IS NOT NULL THEN
         v_proginfo := TRIM(SUBSTR(v_callinfo, INSTR(v_callinfo, c_colsep, -1) + LENGTH(c_colsep)));
         v_lineinfo := TO_NUMBER(TRIM(SUBSTR(v_callinfo, INSTR(v_callinfo, c_colsep),
                                                INSTR(v_callinfo, c_colsep || v_proginfo) - 
                                                   INSTR(v_callinfo, c_colsep))));
   
         v_return := v_proginfo ||', line '|| NVL(TO_CHAR(v_lineinfo), '<none>');
      ELSE
         v_return := c_no_stack;
      END IF;
   
      RETURN v_return;
   
   END caller;

   --------------------------------------------------------------

   FUNCTION whoami RETURN VARCHAR2 AS
   
      v_callinfo  VARCHAR2(255);
      v_program   VARCHAR2(128);
      c_anonymous CONSTANT VARCHAR2(15) := 'anonymous block';
      c_colsep    CONSTANT VARCHAR2(2) := ' '; -- one space
   
   BEGIN
   
      /* Get the call information from the call stack... */
      v_callinfo := stk.parse(3);
   
      /* If an anonymous block, then return as such, else derive the program name... */
      IF INSTR(v_callinfo, c_anonymous) > 0 THEN
         v_program := '<' || c_anonymous || '>';
      ELSE
         v_program := TRIM(SUBSTR(v_callinfo, INSTR(v_callinfo, c_colsep, -1) + LENGTH(c_colsep)));
      END IF;
   
      RETURN v_program;
   
   END whoami;

END stk;
/

CREATE OR REPLACE PUBLIC SYNONYM stk FOR stk;
GRANT EXECUTE ON stk TO PUBLIC;

