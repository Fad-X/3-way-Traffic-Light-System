PROGRAM Networked_Traffic_Controller
  VAR_EXTERNAL
    I1_Red    : BOOL;
    I1_Yellow : BOOL;
    I1_Green  : BOOL;
    I2_Red    : BOOL;
    I2_Yellow : BOOL;
    I2_Green  : BOOL;
    I3_Red    : BOOL;
    I3_Yellow : BOOL;
    I3_Green  : BOOL;
  END_VAR

  VAR
    Timer_Master : TON;
    Timer_Reset  : TON;
    Cycle_Time   : TIME := T#30s;
    T_Cur        : TIME;
  END_VAR

  (* Master Cycle Timer: 30-second cycle *)
  Timer_Master(IN := NOT Timer_Reset.Q, PT := Cycle_Time);
  Timer_Reset(IN := Timer_Master.Q, PT := T#20ms);
  T_Cur := Timer_Master.ET;

  (* INTERSECTION 1: Main West *)
  IF T_Cur < T#14s THEN
    I1_Green := TRUE;  I1_Yellow := FALSE; I1_Red := FALSE;
  ELSIF T_Cur >= T#14s AND T_Cur < T#17s THEN
    I1_Green := FALSE; I1_Yellow := TRUE;  I1_Red := FALSE;
  ELSE
    I1_Green := FALSE; I1_Yellow := FALSE; I1_Red := TRUE;
  END_IF;

  (* INTERSECTION 2: Main East (4s Green Wave Offset) *)
  IF T_Cur >= T#4s AND T_Cur < T#18s THEN
    I2_Green := TRUE;  I2_Yellow := FALSE; I2_Red := FALSE;
  ELSIF T_Cur >= T#18s AND T_Cur < T#21s THEN
    I2_Green := FALSE; I2_Yellow := TRUE;  I2_Red := FALSE;
  ELSE
    I2_Green := FALSE; I2_Yellow := FALSE; I2_Red := TRUE;
  END_IF;

  (* INTERSECTION 3: Cross Avenue *)
  IF T_Cur >= T#22s AND T_Cur < T#27s THEN
    I3_Green := TRUE;  I3_Yellow := FALSE; I3_Red := FALSE;
  ELSIF T_Cur >= T#27s AND T_Cur < T#30s THEN
    I3_Green := FALSE; I3_Yellow := TRUE;  I3_Red := FALSE;
  ELSE
    I3_Green := FALSE; I3_Yellow := FALSE; I3_Red := TRUE;
  END_IF;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    VAR_GLOBAL
      I1_Red AT %QX0.0 : BOOL;
      I1_Yellow AT %QX0.1 : BOOL;
      I1_Green AT %QX0.2 : BOOL;
      I2_Red AT %QX0.3 : BOOL;
      I2_Yellow AT %QX0.4 : BOOL;
      I2_Green AT %QX0.5 : BOOL;
      I3_Red AT %QX0.6 : BOOL;
      I3_Yellow AT %QX0.7 : BOOL;
      I3_Green AT %QX1.0 : BOOL;
    END_VAR

    TASK TaskMain(INTERVAL := T#50ms, PRIORITY := 0);
    PROGRAM InstMain WITH TaskMain : Networked_Traffic_Controller;
  END_RESOURCE
END_CONFIGURATION
