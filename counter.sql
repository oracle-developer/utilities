-- ---------------------------------------------------------------------------------------------------
--
-- Script:      counter.sql
--
-- Author:      Adrian Billington
--              www.oracle-developer.net
--
-- Description: A deliberately simple package to keep a counter running. Useful for investigations
--              and instrumentation.
--
--              Note the PUBLIC synonym and grant at the end of the source code.
--
-- Usage:       Usage is very simple.
--
--              a) Initialise a counter
--                 --------------------
--
--                 BEGIN
--                    counter.initialise();                 --<-- starts at 0
--                    counter.initialise(p_counter => 100); --<-- starts at 100
--                 END;
--                 /
--
--              b) Increment a counter
--                 -------------------
--
--                 BEGIN
--                    counter.increment();                  --<-- increment by 1
--                    counter.increment(p_increment => 50); --<-- increment by 50
--                 END;
--                 /
--
--              c) Increment a counter and retrieve the latest counter value in SQL
--                 ----------------------------------------------------------------
--
--                 SELECT counter.incrementf() AS counter
--                 FROM   some_table
--                 WHERE  ...
--
--                 Note that this function is called INCREMENTF because the INCREMENT 
--                 identifier used for the corresponding procedure is a reserved word 
--                 and can't be used in SQL unless in double-quotes (i.e.
--                 counter.increment doesn't work but counter."INCREMENT" does). 
--                 
--              d) Increment a counter and retrieve the latest counter value in PL/SQL
--                 -------------------------------------------------------------------
--
--                 DECLARE
--                    v_counter PLS_INTEGER;
--                 BEGIN
--                    DBMS_OUTPUT.PUT_LINE(counter.incrementf());  --<-- direct usage
--                    v_counter := counter.incrementf();           --<-- assignment
--                 END;
--                 /
--
--              e) Show the counter with a message in PL/SQL
--                 -----------------------------------------
--                 BEGIN
--                    counter.show(p_msg => 'My counter is');                   --<-- resets the counter
--                    counter.show(p_msg => 'My counter is', p_reset => FALSE); --<-- retains the counter
--                 END;
--                 /
--
--              f) Retrieve the counter into a variable
--                 ------------------------------------
--                 DECLARE
--                    n PLS_INTEGER;
--                 BEGIN
--                    ...
--                    n := counter.show();                 --<-- resets the counter
--                    n := counter.show(p_reset => FALSE); --<-- retains the counter
--                    ...
--                 END;
--                 /
--
--              g) Reset the counter
--                 -----------------
--                 BEGIN
--                    counter.reset();
--                 END;
--                 /
-- 
-- ---------------------------------------------------------------------------------------------------

CREATE PACKAGE counter AS

   PROCEDURE initialise(
             p_counter IN PLS_INTEGER DEFAULT 0
             );

   PROCEDURE increment( 
             p_increment IN PLS_INTEGER DEFAULT 1
             );

   FUNCTION incrementf( 
            p_increment IN PLS_INTEGER DEFAULT 1
            ) RETURN PLS_INTEGER;

   PROCEDURE show(
             p_msg   IN VARCHAR2 DEFAULT NULL,
             p_reset IN BOOLEAN DEFAULT TRUE
             );

   FUNCTION show(
            p_reset IN BOOLEAN DEFAULT TRUE
            ) RETURN PLS_INTEGER;

   PROCEDURE reset;

END counter;
/

CREATE PACKAGE BODY counter AS

   g_counter PLS_INTEGER := 0;

   --------------------------------------------------------
   PROCEDURE initialise(
             p_counter IN PLS_INTEGER DEFAULT 0
             ) IS
   BEGIN
      g_counter := NVL(p_counter,0);
   END initialise;

   --------------------------------------------------------
   PROCEDURE increment(
             p_increment IN PLS_INTEGER DEFAULT 1
             ) IS
   BEGIN
      g_counter := g_counter + NVL(p_increment,1);
   END increment;

   --------------------------------------------------------
   FUNCTION incrementf( 
            p_increment IN PLS_INTEGER DEFAULT 1
            ) RETURN PLS_INTEGER IS
   BEGIN
     increment(p_increment);
     RETURN show(FALSE);
   END incrementf;

   --------------------------------------------------------
   FUNCTION show(
            p_reset IN BOOLEAN DEFAULT TRUE
            ) RETURN PLS_INTEGER IS
      v_counter PLS_INTEGER := g_counter;
   BEGIN
      IF p_reset THEN 
         counter.reset();
      END IF;
      RETURN v_counter;
   END show;

   --------------------------------------------------------
   PROCEDURE show(
             p_msg   IN VARCHAR2 DEFAULT NULL,
             p_reset IN BOOLEAN DEFAULT TRUE
             ) IS
   BEGIN
      DBMS_OUTPUT.PUT_LINE(
         CASE
            WHEN p_msg IS NOT NULL 
            THEN CHR(10) || p_msg || ': ' 
         END || 
         show(p_reset)
         );
   END show;

   --------------------------------------------------------
   PROCEDURE reset IS
   BEGIN
      g_counter := 0;
   END reset;

END counter;
/

CREATE OR REPLACE PUBLIC SYNONYM counter FOR counter;
GRANT EXECUTE ON counter TO PUBLIC;
