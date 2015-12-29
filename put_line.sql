
-- ---------------------------------------------------------------------------------------------------
--
-- Script:      put_line.sql
--
-- Author:      Adrian Billington
--              www.oracle-developer.net
--
-- Description: A simple wrapper for DBMS_OUTPUT.PUT_LINE to workaround the 255 character limit. This
--              splits the input into chunks of a given length (default 255).
--
--              Note that as of 10.2, this is no longer necessary as Oracle have finally "fixed"
--              the DBMS_OUTPUT package to work with strings of up to 32767 bytes.
--
-- Usage:       Simple example of splitting a string into lengths of 50:
--
--                 BEGIN
--                    --<some code>--
--                    put_line(v_very_long_string, 50);
--                    --<some code>--
--                 END;
--
-- ---------------------------------------------------------------------------------------------------

create procedure put_line (
                 string_in IN VARCHAR2,
                 split_in  IN PLS_INTEGER DEFAULT 255
                 ) as
begin
   for i in 1 .. ceil(length(string_in)/split_in) loop
      dbms_output.put_line(substr(string_in,split_in*(i-1)+1,split_in));
   end loop;
end;
/

create or replace public synonym put_line for put_line;
grant execute on put_line to public;
