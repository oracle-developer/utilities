
-----------------------------------------------------------------------------
--
-- Script:  timer.sql
--
-- Author:  Adrian Billington
--          www.oracle-developer.net
--
-- Package: TIMER
--
--
-- Purpose: Timing package for testing durations of alternative coding
--          approaches. Based on Steven Feuerstein's original timer package
--          but simplified and modified. Works for Oracle versions 8i and
--          above.
--
-----------------------------------------------------------------------------

CREATE OR REPLACE PACKAGE timer AS

   secs  CONSTANT PLS_INTEGER := 1;
   mins  CONSTANT PLS_INTEGER := 2;
   hrs   CONSTANT PLS_INTEGER := 3;
   days  CONSTANT PLS_INTEGER := 4;

   PROCEDURE snap (
             show_stack_in IN BOOLEAN DEFAULT FALSE
             );

   PROCEDURE show (
             prefix_in IN VARCHAR2 DEFAULT NULL,
             format_in IN PLS_INTEGER DEFAULT timer.secs
             );

END timer;
/

sho err

CREATE OR REPLACE PACKAGE BODY timer IS

   /* Package (global) variables... */
   g_last_timing  PLS_INTEGER := NULL;
   g_show_stack   BOOLEAN := FALSE;

   /******************* FUNCTION caller *********************/
   FUNCTION caller RETURN VARCHAR2 IS
      v_stk VARCHAR2(4000) := DBMS_UTILITY.FORMAT_CALL_STACK;
      v_dpt PLS_INTEGER := 6;
      v_pos PLS_INTEGER := 21;
      v_dlm VARCHAR2(1) := CHR(10);
   BEGIN
      RETURN NVL(
                SUBSTR(
                   SUBSTR(
                      v_stk,
                      INSTR( v_stk, v_dlm ,1,(v_dpt-1))+1,
                      INSTR( v_stk, v_dlm ,1, v_dpt) - (INSTR( v_stk, v_dlm, 1, (v_dpt-1)))-1
                      ),
                   v_pos ),
                '[unknown]' );
   END caller;

   /******************* PROCEDURE snap *********************/
   PROCEDURE snap (
             show_stack_in IN BOOLEAN DEFAULT FALSE
             ) IS
   BEGIN
      g_last_timing := DBMS_UTILITY.GET_TIME;
      IF show_stack_in THEN  
         g_show_stack := show_stack_in;
         DBMS_OUTPUT.PUT_LINE('[started ' || caller() || ']');
      END IF;
   END snap;

   /******************* FUNCTION elapsed *********************/
   FUNCTION elapsed RETURN NUMBER IS
   BEGIN
      RETURN DBMS_UTILITY.GET_TIME - g_last_timing;
   END elapsed;

   /******************* FUNCTION reformat *********************/
   FUNCTION reformat (
            input_in  IN NUMBER,
            format_in IN VARCHAR2 DEFAULT 9999900
            ) RETURN VARCHAR2 IS
   BEGIN
      RETURN TRIM(TO_CHAR(input_in, format_in));
   END reformat;

   /******************* FUNCTION remainder *********************/
   FUNCTION REMAINDER (
            input_in   IN PLS_INTEGER,
            modulus_in IN PLS_INTEGER,
            format_in  IN VARCHAR2 DEFAULT '900'
            ) RETURN VARCHAR2 IS
   BEGIN
      RETURN reformat(MOD(input_in, modulus_in), format_in);
   END REMAINDER;
   
   /******************* PROCEDURE show *********************/
   PROCEDURE show (
             prefix_in IN VARCHAR2 DEFAULT NULL,
             format_in IN PLS_INTEGER DEFAULT timer.secs
             ) IS
      /*
       * Construct message for display of elapsed time. Programmer can
       * include a prefix to the message and also ask that the last
       * timing variable be reset/updated to save calling snap again.
       */
      TYPE typ_rec_elapsed IS RECORD
      (    hsecs PLS_INTEGER
      ,    secs  PLS_INTEGER
      ,    mins  PLS_INTEGER
      ,    hrs   PLS_INTEGER
      ,    days  PLS_INTEGER
      );
      rec_elapsed      typ_rec_elapsed;
      v_elapsed_string VARCHAR2(128);
      v_message        VARCHAR2(512);
      v_label          VARCHAR2(128);
   
   BEGIN
   
      IF g_last_timing IS NULL THEN
         DBMS_OUTPUT.PUT_LINE('Timer not started.');
      ELSE
         /* Capture the elapsed time and format it into the "set timing on" format of SQL*Plus... */
         rec_elapsed.hsecs := elapsed();
         rec_elapsed.secs := TRUNC(rec_elapsed.hsecs/100);
         rec_elapsed.mins := TRUNC(rec_elapsed.hsecs/6000);
         rec_elapsed.hrs := TRUNC(rec_elapsed.hsecs/360000);
         rec_elapsed.days := TRUNC(rec_elapsed.hsecs/8640000);
   
         IF format_in = timer.secs THEN
            v_elapsed_string := reformat(rec_elapsed.hsecs/100, '99999990.00') || ' seconds';
         ELSIF format_in = timer.mins THEN
            v_elapsed_string := reformat(rec_elapsed.mins) 
                                || ' minutes ' 
                                || REMAINDER(rec_elapsed.secs,60) 
                                || ' seconds';
         ELSIF format_in = timer.hrs THEN
            v_elapsed_string := reformat(rec_elapsed.hrs) 
                                || ' hours ' 
                                || REMAINDER(rec_elapsed.mins,60) 
                                || ' minutes';
         ELSE
            v_elapsed_string := reformat(rec_elapsed.days)
                                || ' days '
                                || REMAINDER(rec_elapsed.hrs,24) 
                                || ' hours';
         END IF;
      
         /* Build the message string... */
         v_label := NVL(prefix_in, 'elapsed');
         v_message := '[' || v_label ||'] '|| v_elapsed_string;
   
         /* Output... */
         IF g_show_stack THEN
            DBMS_OUTPUT.PUT_LINE('[stopped ' || caller() || ']');
         END IF;
         DBMS_OUTPUT.PUT_LINE(v_message);
   
         /* Reset... */
         g_last_timing := NULL;
         g_show_stack := FALSE;
      END IF;
   
   END show;

END timer;
/

CREATE PUBLIC SYNONYM timer FOR timer;
GRANT EXECUTE ON timer TO PUBLIC;
