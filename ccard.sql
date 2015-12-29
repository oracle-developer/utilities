-- ----------------------------------------------------------------------------------------------
--
-- Script:       ccard.sql
--
-- Utility:      CCARD (Collection CARDinality)
--
-- Author:       Adrian Billington
--               www.oracle-developer.net
--
-- Description:  A simple utility named CCARD to provide the CBO with the exact cardinality of a
--               collection used in a TABLE() query. Without it, the CBO uses a default value 
--               (8,168 rows on a database with an 8kb block size) and this is usually inaccurate
--               and can lead to sub-optimal execution plans. The effect of CCARD is similar to
--               that of the CARDINALITY hint, except that CCARD uses supported methods and the
--               CARDINALITY hint is undocumented (up to 11.1.0.7 at the time of writing).
--
--               The CCARD utility is implemented by a function and an Oracle Data Cartridge for
--               the Extensible Optimiser. Once installed, the CCARD utility is simple to use (it
--               is just a function call wrapped around a collection in a TABLE query). See the
--               Usage section below for examples. For more information on the mechanism itself,
--               read http://www.oracle-developer.net/display.php?id=427.
--
--               The most common use of small collections in SQL is for variable in-lists, with
--               queries of the form:
--
--                  SELECT {columns}
--                  FROM   table_name
--                  WHERE  column_name IN (SELECT column_value
--                                         FROM   TABLE(collection));
--
--               CCARD is primarily designed for use with these types of variable in-list 
--               queries but it can also be used for queries of the form:
--
--                  SELECT {columns}
--                  FROM   TABLE(collection);
--
--               See the Usage section for specific examples.
--
--               CCARD cannot be used where the collection is derived from another table 
--               function (see Restrictions below).
--
-- Usage:        a) Variable in-list in SQL with a hard-coded collection
--               -------------------------------------------------------
--
--               SELECT {columns}
--               FROM   table_name
--               WHERE  column_name IN (SELECT column_value
--                                      FROM   TABLE(
--                                                ccard(
--                                                   ccard_ntt('A','B','C'))));
--
--               b) Variable in-list in PL/SQL with collection parameter
--               -------------------------------------------------------
--
--               PROCEDURE procedure_name( p_inlist IN ccard_ntt ) IS
--               ...
--                  CURSOR cur IS
--                     SELECT {columns}
--                     FROM   table_name
--                     WHERE  column_name IN (SELECT column_value
--                                            FROM   TABLE(ccard(p_inlist))); 
--               ...
--               BEGIN
--               ...
--               END procedure_name;
--                                        
-- Benefits:     Without CCARD:
--
--                  SELECT *
--                  FROM   TABLE(collection_type('A','B','C'));
--
--                  --------------------------------------------------------------
--                  | Id  | Operation                             | Name | Rows  |
--                  --------------------------------------------------------------
--                  |   0 | SELECT STATEMENT                      |      |  8168 |
--                  |   1 |  COLLECTION ITERATOR CONSTRUCTOR FETCH|      |       |
--                  --------------------------------------------------------------
--
--               With CCARD:
--
--                  SELECT *
--                  FROM   TABLE(ccard(collection_type('A','B','C')));
--
--                  -----------------------------------------------------------
--                  | Id  | Operation                         | Name  | Rows  |
--                  -----------------------------------------------------------
--                  |   0 | SELECT STATEMENT                  |       |     3 |
--                  |   1 |  COLLECTION ITERATOR PICKLER FETCH| CCARD |       |
--                  -----------------------------------------------------------
--
-- Restrictions: CCARD cannot be used when the collection is supplied by another table function.
--               For example, for a query such as SELECT * FROM TABLE(ccard(table_function)), 
--               the CBO will default to an incorrect cardinality of 1 (rounded up from 0). This 
--               means that variable in-list queries of the following forms will not benefit from
--               the CCARD utility:
--
--                  SELECT {columns}
--                  FROM   TABLE(ccard(string_to_table(:some_delimited_string)));
--
--                  SELECT {columns}
--                  FROM   TABLE(ccard(string_to_table('A,B,C')));
--
--               In such cases, the advice is to use best practice and pass collections as
--               collections and not as delimited strings that need to be parsed!
--
-- Versions:     This utility will work for all versions of 10g and upwards.
--
-- Required:     1) CREATE PROCEDURE
--               2) CREATE TYPE
--               3) CREATE PUBLIC SYNONYM (see bottom of script and exclude as necessary)
--
-- Disclaimer:   http://www.oracle-developer.net/disclaimer.php
--
-- ----------------------------------------------------------------------------------------------

CREATE TYPE ccard_ntt AS TABLE OF VARCHAR2(4000);
/

CREATE FUNCTION ccard (
                p_collection IN ccard_ntt
                ) RETURN ccard_ntt DETERMINISTIC AS
BEGIN
   RETURN p_collection;
END ccard;
/

CREATE TYPE ccard_ot AS OBJECT (

   dummy_attribute NUMBER,

   STATIC FUNCTION ODCIGetInterfaces (
                   p_interfaces OUT SYS.ODCIObjectList
                   ) RETURN NUMBER,
  
   STATIC FUNCTION ODCIStatsTableFunction (
                   p_function   IN  SYS.ODCIFuncInfo,
                   p_stats      OUT SYS.ODCITabFuncStats,
                   p_args       IN  SYS.ODCIArgDescList,
                   p_collection IN  ccard_ntt
                   ) RETURN NUMBER
);
/

CREATE TYPE BODY ccard_ot AS

   STATIC FUNCTION ODCIGetInterfaces (
                   p_interfaces OUT SYS.ODCIObjectList
                   ) RETURN NUMBER IS
   BEGIN
      p_interfaces := SYS.ODCIObjectList(
                         SYS.ODCIObject ('SYS', 'ODCISTATS2')
                         );
      RETURN ODCIConst.success;
   END ODCIGetInterfaces;

   STATIC FUNCTION ODCIStatsTableFunction (
                   p_function   IN  SYS.ODCIFuncInfo,
                   p_stats      OUT SYS.ODCITabFuncStats,
                   p_args       IN  SYS.ODCIArgDescList,
                   p_collection IN  ccard_ntt
                   ) RETURN NUMBER IS
   BEGIN
      p_stats := SYS.ODCITabFuncStats(p_collection.COUNT);
      RETURN ODCIConst.success;
   END ODCIStatsTableFunction;

END;
/

ASSOCIATE STATISTICS WITH FUNCTIONS ccard USING ccard_ot;

CREATE PUBLIC SYNONYM ccard_ntt FOR ccard_ntt;
CREATE PUBLIC SYNONYM ccard FOR ccard;
GRANT EXECUTE ON ccard_ntt TO PUBLIC;
GRANT EXECUTE ON ccard TO PUBLIC;
