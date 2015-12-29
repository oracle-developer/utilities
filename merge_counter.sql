
-- ----------------------------------------------------------------------------------------------
--
-- Script:      merge_counter.sql
--
-- Author:      Adrian Billington
--              www.oracle-developer.net
--
-- Description: A package to maintain separate INSERT and UPDATE counts from a MERGE.
--
--              I first devised this method for an article for Quest's PL/SQL Pipelines. This
--              article can be found on the oracle-developer.net website at 
--              www.oracle-developer.net/display.php?id=220.
--              
--              This utility will work for all versions of 9i and above (i.e. when MERGE was
--              introduced).
--
--              A current limitation is that it does not support parallel MERGE. I'm waiting for
--              a documented feature of Oracle 10g to start working so I can put a parallel-
--              enabled version together.
--              
-- Usage:       Usage is quite simple. We maintain an insert counter, update counter or both.
--              For efficiency, it makes sense to maintain a single counter on the operation that
--              is LEAST likely to occur. For example, if a MERGE is likely to UPDATE 200,000 
--              records and INSERT just 5,000, then it makes sense to maintain an insert counter
--              only.
--
--              a) To maintain an insert counter
--                 -----------------------------
--
--                 MERGE
--                    INTO  target_table  t
--                    USING source_table s
--                    ON   (s.primary_key = t.primary_key)
--                 WHEN MATCHED THEN
--                    UPDATE
--                    SET    t.column_name = s.column_name
--                 WHEN NOT MATCHED THEN
--                    INSERT ( t.primary_key
--                           , t.column_name )
--                    VALUES ( DECODE(merge_counter.insert_counter,0,s.primary_key)
--                           , s.column_name );
--
--              b) To maintain an update counter
--                 -----------------------------
--
--                 MERGE
--                    INTO  target_table  t
--                    USING source_table s
--                    ON   (s.primary_key = t.primary_key)
--                 WHEN MATCHED THEN
--                    UPDATE
--                    SET    t.column_name = DECODE(merge_counter.update_counter,0,s.column_name)
--                 WHEN NOT MATCHED THEN
--                    INSERT ( t.primary_key
--                           , t.column_name )
--                    VALUES ( s.primary_key
--                           , s.column_name );
--       
--              c) Reporting insert and update rowcounts
--                 -------------------------------------
--
--                 INSERT
--                    => if insert counter used, merge_counter.get_insert_count
--                    => if update counter used, merge_counter.get_insert_count(sql%rowcount)
--
--                 UPDATE
--                    => if update counter used, merge_counter.get_update_count
--                    => if insert counter used, merge_counter.get_update_count(sql%rowcount)
--
--                 To reset the counters, use merge_counter.reset_counters.
-- 
-- ----------------------------------------------------------------------------------------------

CREATE PACKAGE merge_counter AS

   FUNCTION insert_counter 
      RETURN PLS_INTEGER;

   FUNCTION update_counter
      RETURN PLS_INTEGER;
      
   FUNCTION get_update_count
      RETURN PLS_INTEGER;

   FUNCTION get_update_count ( 
            merge_rowcount_in IN PLS_INTEGER
            ) RETURN PLS_INTEGER;

   FUNCTION get_insert_count
      RETURN PLS_INTEGER;

   FUNCTION get_insert_count ( 
            merge_rowcount_in in PLS_INTEGER
            ) RETURN PLS_INTEGER;

   PROCEDURE reset_counters;

END merge_counter;
/

CREATE PACKAGE BODY merge_counter AS

   g_update_counter PLS_INTEGER NOT NULL := 0;
   g_insert_counter PLS_INTEGER NOT NULL := 0;

   -------------------------------------------------------------------------
   
   FUNCTION insert_counter
      RETURN PLS_INTEGER IS
   BEGIN
      g_insert_counter := g_insert_counter + 1;
      RETURN 0;
   END insert_counter;

   -------------------------------------------------------------------------
   
   FUNCTION update_counter
      RETURN PLS_INTEGER IS
   BEGIN
      g_update_counter := g_update_counter + 1;
      RETURN 0;
   END update_counter;
   
   -------------------------------------------------------------------------
   
   FUNCTION get_update_count
      RETURN PLS_INTEGER is
   BEGIN
      RETURN g_update_counter;
   END get_update_count;

   -------------------------------------------------------------------------
   
   FUNCTION get_update_count (
            merge_rowcount_in IN PLS_INTEGER
            ) RETURN PLS_INTEGER IS
   BEGIN
      RETURN NVL( merge_rowcount_in - g_insert_counter, 0 );
   END get_update_count;

   -------------------------------------------------------------------------
   
   FUNCTION get_insert_count
      RETURN PLS_INTEGER IS
   BEGIN
      RETURN g_insert_counter;
   END get_insert_count;

   -------------------------------------------------------------------------

   FUNCTION get_insert_count (
            merge_rowcount_in IN PLS_INTEGER
            ) RETURN PLS_INTEGER IS
   BEGIN
      RETURN NVL( merge_rowcount_in - g_update_counter, 0 );
   END get_insert_count;

   -------------------------------------------------------------------------

   PROCEDURE reset_counters IS
   BEGIN
      g_update_counter := 0;
      g_insert_counter := 0; 
   END reset_counters;

END merge_counter;
/

CREATE OR REPLACE PUBLIC SYNONYM merge_counter FOR merge_counter;
GRANT EXECUTE ON merge_counter TO PUBLIC;
