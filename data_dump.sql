-- ---------------------------------------------------------------------------------------------------
--
-- Script:      data_dump.sql
--
-- Author:      Adrian Billington
--              www.oracle-developer.net
--
-- Description: A standalone procedure to dump the results of a query to delimited flat-file. This 
--              utility supports Oracle 8i upwards.
--
--              Note that the dynamic code that is built to perform the data dump can optionally be 
--              written to a separate file. 
--
-- Usage:       Usage is quite simple. A dynamic query is passed in as a parameter. As this uses 
--              DBMS_SQL to parse the SQL, all expressions must have an alias.
--
--              a) Dump the contents of a table
--                 ----------------------------
--
--                 BEGIN
--                    data_dump( query_in     => 'SELECT * FROM table_name',
--                               file_in      => 'table_name.csv',
--                               directory_in => 'LOG_DIR',
--                               delimiter_in => ',' );
--                 END;
--                 /
--
--              b) Use an expression in the query
--                 ------------------------------
--
--                 BEGIN
--                    data_dump( query_in     => 'SELECT ''LITERAL'' AS alias_name FROM table_name',
--                               file_in      => 'table_name.csv',
--                               directory_in => 'LOG_DIR',
--                               delimiter_in => ',' );
--                 END;
--                 /
--
--             See list of parameters for the various other options available.
-- 
-- ---------------------------------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE data_dump (
                            query_in        IN VARCHAR2,
                            file_in         IN VARCHAR2,
                            directory_in    IN VARCHAR2,
                            nls_date_fmt_in IN VARCHAR2 DEFAULT 'DD-MON-YYYY HH24:MI:SS',
                            write_action_in IN VARCHAR2 DEFAULT 'W',
                            array_size_in   IN PLS_INTEGER DEFAULT 1000,
                            delimiter_in    IN VARCHAR2 DEFAULT NULL,
                            dump_code_in    IN BOOLEAN DEFAULT FALSE) AUTHID CURRENT_USER IS

   v_fh           UTL_FILE.FILE_TYPE;
   v_ch           BINARY_INTEGER      := DBMS_SQL.OPEN_CURSOR;
   v_sql          VARCHAR2(32767)     := query_in;
   v_dir          VARCHAR2(512)       := directory_in;
   v_outfile      VARCHAR2(128)       := file_in;
   v_sqlfile      VARCHAR2(128)       := file_in||'.sql';
   v_arr_size     PLS_INTEGER         := array_size_in;
   v_col_cnt      PLS_INTEGER         := 0;
   v_delimiter    VARCHAR2(1)         := NULL;
   v_write_action VARCHAR2(1)         := write_action_in;
   v_nls_date_fmt VARCHAR2(30)        := nls_date_fmt_in;
   v_dummy        NUMBER;
   v_type         VARCHAR2(8);
   t_describe     DBMS_SQL.DESC_TAB;
   t_plsql        DBMS_SQL.VARCHAR2A;

   /* Procedure to output code for debug and assign plsql variable... */
   PROCEDURE put (
             string_in IN VARCHAR2
             ) IS
   BEGIN
      IF dump_code_in THEN
         UTL_FILE.PUT_LINE(v_fh,string_in);
      END IF;
      t_plsql(t_plsql.COUNT + 1) := string_in;
   END put;

BEGIN

   /* Open the file that the dynamic PL/SQL will be written to for debug... */
   IF dump_code_in THEN
      v_fh := UTL_FILE.FOPEN(v_dir, v_sqlfile, 'W', 32767);
   END IF;

   /* Parse the query that will be used to fetch all the data to be written out... */
   DBMS_SQL.PARSE(v_ch, v_sql, DBMS_SQL.NATIVE);

   /* Now describe the dynamic SQL to analyze the number of columns in the query... */
   DBMS_SQL.DESCRIBE_COLUMNS(v_ch, v_col_cnt, t_describe);

   /* Now begin the dynamic PL/SQL... */
   put('DECLARE');
   put('   v_fh     UTL_FILE.FILE_TYPE;');
   put('   v_eol    VARCHAR2(2);');
   put('   v_eollen PLS_INTEGER;');
   put('   CURSOR cur_sql IS');
   put('      '||REPLACE(v_sql,'"','''''')||';');

   /* Now loop through the describe table to declare arrays in the dynamic PL/SQL... */
   FOR i IN t_describe.FIRST .. t_describe.LAST LOOP
      IF t_describe(i).col_type = 2 THEN
         v_type := 'NUMBER';
      ELSIF t_describe(i).col_type = 12 THEN
         v_type := 'DATE';
      ELSE
         v_type := 'VARCHAR2';
      END IF;
      put('   "'||t_describe(i).col_name||'" DBMS_SQL.'||v_type||'_TABLE;');
   END LOOP;

   /* Syntax to set the date format to preserve time in the output, open the out file and start to collect... */
   put('BEGIN');
   put('   EXECUTE IMMEDIATE ''ALTER SESSION SET NLS_DATE_FORMAT = '''''||v_nls_date_fmt||''''''';');
   put('   v_eol := CASE');
   put('               WHEN DBMS_UTILITY.PORT_STRING LIKE ''IBMPC%''');
   put('               THEN CHR(13)||CHR(10)');
   put('               ELSE CHR(10)');
   put('            END;');
   put('   v_eollen := LENGTH(v_eol);');
   put('   v_fh := UTL_FILE.FOPEN('''||v_dir||''','''||v_outfile||''','''||v_write_action||''');');
   put('   OPEN cur_sql;');
   put('   LOOP');
   put('      FETCH cur_sql');

   IF t_describe.COUNT > 1 THEN

      put('      BULK COLLECT INTO "'||t_describe(t_describe.FIRST).col_name||'",');

      /* Add all other arrays into the fetch list except the last... */
      FOR i IN t_describe.FIRST + 1 .. t_describe.LAST - 1 LOOP
         put('                        "'||t_describe(i).col_name||'",');
      END LOOP;

      /* Add in the last array and limit... */
      put('                        "'||t_describe(t_describe.LAST).col_name||'" LIMIT '||v_arr_size||';');

   ELSE
      /* Just output the one collection and LIMIT... */
      put('      BULK COLLECT INTO "'||t_describe(t_describe.FIRST).col_name||'" LIMIT '||v_arr_size||';');

   END IF;

   /* Now add syntax to loop though the fetched array and write out the values to file... */
   put('      IF "'||t_describe(t_describe.FIRST).col_name||'".COUNT > 0 THEN');
   put('         FOR i IN "'||t_describe(t_describe.FIRST).col_name||'".FIRST .. "'||
                                  t_describe(t_describe.FIRST).col_name||'".LAST LOOP');

   FOR i IN t_describe.FIRST .. t_describe.LAST LOOP
      put('            UTL_FILE.PUT(v_fh,'''||v_delimiter||''' ||"'||t_describe(i).col_name||'"(i));');
      v_delimiter := NVL(delimiter_in,',');
   END LOOP;

   /* Add a new line marker into the file and move on to next record... */
   put('            UTL_FILE.NEW_LINE(v_fh);');
   put('         END LOOP;');

   /* Complete the IF statement... */
   put('      END IF;');

   /* Add in an EXIT condition and complete the loop syntax... */
   put('      EXIT WHEN cur_sql%NOTFOUND;');
   put('   END LOOP;');
   put('   CLOSE cur_sql;');
   put('   UTL_FILE.FCLOSE(v_fh);');

   /* Add in some exception handling... */
   put('EXCEPTION');
   put('   WHEN UTL_FILE.INVALID_PATH THEN');
   put('      DBMS_OUTPUT.PUT_LINE(''Error - invalid path.'');');
   put('      RAISE;');
   put('   WHEN UTL_FILE.INVALID_MODE THEN');
   put('      DBMS_OUTPUT.PUT_LINE(''Error - invalid mode.'');');
   put('      RAISE;');
   put('   WHEN UTL_FILE.INVALID_OPERATION THEN');
   put('      DBMS_OUTPUT.PUT_LINE(''Error - invalid operation.'');');
   put('      RAISE;');
   put('   WHEN UTL_FILE.INVALID_FILEHANDLE THEN');
   put('      DBMS_OUTPUT.PUT_LINE(''Error - invalid filehandle.'');');
   put('      RAISE;');
   put('   WHEN UTL_FILE.WRITE_ERROR THEN');
   put('      DBMS_OUTPUT.PUT_LINE(''Error - write error.'');');
   put('      RAISE;');
   put('   WHEN UTL_FILE.READ_ERROR THEN');
   put('      DBMS_OUTPUT.PUT_LINE(''Error - read error.'');');
   put('      RAISE;');
   put('   WHEN UTL_FILE.INTERNAL_ERROR THEN');
   put('      DBMS_OUTPUT.PUT_LINE(''Error - internal error.'');');
   put('      RAISE;');
   put('END;');

   /* Now close the cursor and sql file... */
   DBMS_SQL.CLOSE_CURSOR(v_ch);
   IF dump_code_in THEN
      UTL_FILE.FCLOSE(v_fh);
   END IF;

   /*
    * Execute the t_plsql collection to dump the data. Use DBMS_SQL as we have a collection
    * of syntax...
    */
   v_ch := DBMS_SQL.OPEN_CURSOR;
   DBMS_SQL.PARSE(v_ch, t_plsql, t_plsql.FIRST, t_plsql.LAST, TRUE, DBMS_SQL.NATIVE);
   v_dummy := DBMS_SQL.EXECUTE(v_ch);
   DBMS_SQL.CLOSE_CURSOR(v_ch);

EXCEPTION
   WHEN UTL_FILE.INVALID_PATH THEN
      DBMS_OUTPUT.PUT_LINE('Error - invalid path.');
      RAISE;
   WHEN UTL_FILE.INVALID_MODE THEN
      DBMS_OUTPUT.PUT_LINE('Error - invalid mode.');
      RAISE;
   WHEN UTL_FILE.INVALID_OPERATION THEN
      DBMS_OUTPUT.PUT_LINE('Error - invalid operation.');
      RAISE;
   WHEN UTL_FILE.INVALID_FILEHANDLE THEN
      DBMS_OUTPUT.PUT_LINE('Error - invalid filehandle.');
      RAISE;
   WHEN UTL_FILE.WRITE_ERROR THEN
      DBMS_OUTPUT.PUT_LINE('Error - write error.');
      RAISE;
   WHEN UTL_FILE.READ_ERROR THEN
      DBMS_OUTPUT.PUT_LINE('Error - read error.');
      RAISE;
   WHEN UTL_FILE.INTERNAL_ERROR THEN
      DBMS_OUTPUT.PUT_LINE('Error - internal error.');
      RAISE;
END;
/

CREATE OR REPLACE PUBLIC SYNONYM data_dump FOR data_dump;
GRANT EXECUTE ON data_dump TO PUBLIC;
