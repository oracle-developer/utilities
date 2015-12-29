-- ----------------------------------------------------------------------------------------------
--
-- Script:       csort.sql
--
-- Utility:      CSORT (Collection SORTer)
--
-- Author:       Adrian Billington
--               www.oracle-developer.net
--
-- Description:  A simple package containing two functions to sort collections:
--
--                 1) sort
--                 2) sort_small
--
--               These functions contain techniques suitable for the size of collection that 
--               needs to be sorted. In most cases, the SORT function will be the most efficient
--               to use. The SORT_SMALL function should be the most efficient when dealing with
--               tiny collections of just a few small elements. For more information on sorting
--               collections and choosing the right function, read the following article:
--
--                  http://www.oracle-developer.net/display.php?id=428
--
--               This package supports collections of a single nested table type of strings.
--               Nested table types are the most flexible of collections - they can be used
--               in all SQL and PL/SQL assignments and they are supported by all MULTISET
--               operations. To implement sorts for your own standard collection type, simply
--               replace the name of the type used throughout the utility.
--
--               This utility can be made generic (i.e. to support any nested table type) by
--               using either ANYDATA or subtitutable types, but this would be slower and more
--               complex to use.
--
-- Usage:        a) Sort a pre-populated collection in SQL
--               -----------------------------------------
--               SELECT CSORT.SORT(collection)
--               FROM   table_name;
--
--               b) Sort a pre-populated small collection in PL/SQL
--               --------------------------------------------------
--               PROCEDURE ... ( p_collection IN varchar2_ntt ) IS
--                  v_sorted_collection varchar2_ntt := varchar2_ntt();
--               BEGIN
--                  ...
--                  v_sorted_collection := CSORT.SORT_SMALL(p_collection);
--                  ...
--               END;
--
--               c) Sort a collection descending in SQL
--               --------------------------------------
--               SELECT CSORT.SORT(collection, 'Y')
--               FROM   table_name;
--
--               d) Distinct sort a collection in SQL
--               ------------------------------------
--               SELECT CSORT.SORT(collection, 'N', 'Y')
--               FROM   table_name;
--
--               ...or...
--
--               SELECT CSORT.SORT(collection, NULL, 'Y')
--               FROM   table_name;
--
--               e) Distinct descending sort in SQL
--               ----------------------------------
--               SELECT CSORT.SORT(collection, 'Y', 'Y')
--               FROM   table_name;             
--                                        
-- Versions:     This utility will work for all versions of 9i Release 2 and upwards.
--               To make it 8i compatible, remove the SORT_SMALL function and use the
--               SORT function for all requirements.
--
-- Required:     1) CREATE PROCEDURE
--               2) CREATE TYPE
--               3) CREATE PUBLIC SYNONYM (see bottom of script and exclude as necessary)
--
-- Disclaimer:   http://www.oracle-developer.net/disclaimer.php
--
-- ----------------------------------------------------------------------------------------------

CREATE TYPE varchar2_ntt AS TABLE OF VARCHAR2(4000);
/

CREATE PACKAGE csort AS

   FUNCTION sort( p_collection IN varchar2_ntt,
                  p_descending IN VARCHAR2 DEFAULT 'N',
                  p_distinct   IN VARCHAR2 DEFAULT 'N' )
      RETURN varchar2_ntt;

   FUNCTION sort_small( p_collection IN varchar2_ntt,
                        p_descending IN VARCHAR2 DEFAULT 'N',
                        p_distinct   IN VARCHAR2 DEFAULT 'N' )
      RETURN varchar2_ntt;

END csort;
/

CREATE PACKAGE BODY csort AS

   FUNCTION boolean_option( p_option IN VARCHAR2 ) 
      RETURN BOOLEAN IS
   BEGIN
      RETURN UPPER(p_option) = 'Y';
   END boolean_option;

   -----------------------------------------------------------------

   FUNCTION sort( 
            p_collection IN varchar2_ntt,
            p_descending IN VARCHAR2 DEFAULT 'N',
            p_distinct   IN VARCHAR2 DEFAULT 'N' ) RETURN varchar2_ntt IS

      v_collection varchar2_ntt := varchar2_ntt();

   BEGIN

      EXECUTE IMMEDIATE 
         'SELECT ' || CASE
                         WHEN boolean_option(p_distinct)
                         THEN 'DISTINCT'
                      END || ' column_value
          FROM   TABLE(:p_collection)
          ORDER  BY column_value ' || CASE
                                         WHEN boolean_option(p_descending)
                                         THEN 'DESC'
                                         ELSE 'ASC'
                                      END
      BULK COLLECT INTO v_collection
      USING p_collection;

      RETURN v_collection;

   END sort;

   -----------------------------------------------------------------

   FUNCTION sort_small( p_collection IN varchar2_ntt,
                        p_descending IN VARCHAR2 DEFAULT 'N',
                        p_distinct   IN VARCHAR2 DEFAULT 'N' ) 
      RETURN varchar2_ntt IS
   
      TYPE sorter_aat IS TABLE OF PLS_INTEGER
         INDEX BY VARCHAR2(4000);
   
      v_collection  varchar2_ntt := varchar2_ntt();
      v_sorter      sorter_aat;
      v_sorter_idx  VARCHAR2(4000);
      v_source_idx  PLS_INTEGER;
      v_descending  BOOLEAN := boolean_option(p_descending);
      v_distinct    BOOLEAN := boolean_option(p_distinct);
   
   BEGIN

      -- Sort the collection using the sorter array...
      -- --------------------------------------------------
      v_source_idx := p_collection.FIRST;
      WHILE v_source_idx IS NOT NULL LOOP
         v_sorter_idx := p_collection(v_source_idx);
         v_sorter(v_sorter_idx) := CASE
                                      WHEN NOT v_sorter.EXISTS(v_sorter_idx)
                                      OR   v_distinct
                                      THEN 1
                                      ELSE v_sorter(v_sorter_idx) + 1
                                   END;
         v_source_idx := p_collection.NEXT(v_source_idx);
      END LOOP;
   
      -- Assign sorted elements back to collection...
      -- --------------------------------------------------
      v_sorter_idx := CASE
                         WHEN v_descending
                         THEN v_sorter.LAST 
                         ELSE v_sorter.FIRST
                       END;

      WHILE v_sorter_idx IS NOT NULL LOOP
   
         -- Handle multiple copies of same value. For distinct
         -- collections, there will only be one element...
         -- --------------------------------------------------
         FOR i IN 1 .. v_sorter(v_sorter_idx) LOOP
            v_collection.EXTEND;
            v_collection(v_collection.LAST) := v_sorter_idx;
         END LOOP;
   
         v_sorter_idx := CASE
                            WHEN v_descending
                            THEN v_sorter.PRIOR(v_sorter_idx)
                            ELSE v_sorter.NEXT(v_sorter_idx)
                         END;
   
      END LOOP;
   
      RETURN v_collection;
   
   END sort_small;                                           

END csort;
/

CREATE PUBLIC SYNONYM varchar2_ntt FOR varchar2_ntt;
CREATE PUBLIC SYNONYM csort FOR csort;
GRANT EXECUTE ON varchar2_ntt TO PUBLIC;
GRANT EXECUTE ON csort TO PUBLIC;
