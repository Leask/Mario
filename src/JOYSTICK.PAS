unit Joystick;

  {  (C) Copyright 1995-2001, Mike Wiering, e-mail: mike.wiering@wxs.nl  }

  {
     Joystick unit for use with Turbo Pascal 5.5
  }

interface

  var
    jsDetected,
    jsEnabled,
    jsCalibrated,
    jsWaitButton,
    jsButtonPressed,
    jsButton1,
    jsButton2,
    jsLeft,
    jsRight,
    jsUp,
    jsDown: Boolean;

  type
    JoyRec =
      record
        X,
        Y,
        XCenter,
        YCenter,
        XMin,
        YMin,
        XMax,
        YMax,
        XLeft,
        YUp,
        XRight,
        YDown: Word;
      end;

  var
    jr: JoyRec;

  procedure ReadJoystick;
  procedure ResetJoystick;
  procedure Calibrate;

implementation

  uses
    Crt;

  const
    JOYSTICK_PORT = $201;

  var
    jrX,
    jrY: Integer;

  procedure ReadJoystick;
  begin
    jrX := 0;
    jrY := 0;
    if jsEnabled then
inline(
                     $9C  (*         pushf *)
                /$29/$C9  (*         sub     cx, cx *)
            /$BA/$01/$02  (*         mov     dx, JOYSTICK_PORT *)
                    /$EC  (*         in      al, dx *)
                /$F6/$D0  (*         not     al *)
                /$88/$C4  (*         mov     ah, al *)
            /$25/$10/$20  (*         and     ax, 2010h *)
            /$A2/jsButton1  (*         mov     jsButton1, al *)
                /$D0/$EC  (*         shr     ah, 1 *)
        /$88/$26/jsButton2  (*         mov     jsButton2, ah *)
            /$BB/$01/$02  (*         mov     bx, 0201h *)
                    /$FA  (*         cli *)
                    /$EE  (*         out     dx, al *)
                /$B4/$00  (*         mov     ah, 0 *)
(*     @@1: *)
                    /$EC  (*         in      al, dx *)
                /$20/$D8  (*         and     al, bl *)
        /$01/$06/jrX  (*         add     jr.X, ax *)
                    /$EC  (*         in      al, dx *)
                /$20/$F8  (*         and     al, bh *)
                /$D0/$E8  (*         shr     al, 1 *)
        /$01/$06/jrY  (*         add     jr.Y, ax *)
                    /$EC  (*         in      al, dx *)
                /$A8/$03  (*         test    al, 3 *)
                /$74/$08  (*         jz      @@2 *)
                    /$41  (*         inc     cx *)
                /$75/$E8  (*         jnz     @@1 *)
    /$C6/$06/jsEnabled/$00  (*         mov     jsEnabled, 0 *)
(*     @@2: *)
                    /$9D  (*         popf *)
);
    jr.X := jrX;
    jr.Y := jrY;
    with jr do
      if jsEnabled and (not jsWaitButton) then
      begin
        jsLeft := (X < XLeft);
        jsRight := (X > XRight);
        jsUp := (Y < YUp);
        jsDown := (Y > YDown);
      end
      else
      begin
        jsLeft := FALSE;
        jsRight := FALSE;
        jsUp := FALSE;
        jsDown := FALSE;
        jsButtonPressed := jsButtonPressed or jsButton1 or jsButton2;
        jsButton1 := FALSE;
        jsButton2 := FALSE;
      end;
  end;

  procedure ResetJoystick;
    var
      i: Integer;
      TotalX,
      TotalY: LongInt;
  begin
    jsEnabled := TRUE;
    ReadJoystick;
    if jsEnabled then
      with jr do
      begin
        TotalX := 0;
        TotalY := 0;
        for i := 1 to 16 do
        begin
          ReadJoystick;
          Inc (TotalX, X);
          Inc (TotalY, Y);
        end;
        X := TotalX div 16;
        Y := TotalY div 16;
        XCenter := X;
        YCenter := Y;
        XMin := X;
        YMin := Y;
        XMax := X;
        YMax := Y;
        XLeft := X;
        YUp := Y;
        XRight := X;
        YUp := Y;
        ReadJoystick;
        jsCalibrated := FALSE;
      end;
  end;

  procedure Calibrate;
  begin
    ReadJoystick;
    if jsEnabled then
      with jr do
      begin
        if X < XMin then
        begin
          XMin := X;
          XLeft := (XMin + XCenter) div 2;
        end;
        if Y < YMin then
        begin
          YMin := Y;
          YUp := (YMin + YCenter) div 2;
        end;
        if X > XMax then
        begin
          XMax := X;
          XRight := (XMax + XCenter) div 2;
        end;
        if Y > YMax then
        begin
          YMax := Y;
          YDown := (YMax + YCenter) div 2;
        end;
        jsCalibrated := TRUE;
      end;
  end;

begin
  jsCalibrated := FALSE;
  jsWaitButton := FALSE;
  ResetJoystick;
  jsDetected := jsEnabled;
  ReadJoystick;
end.
