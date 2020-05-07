unit Keyboard;

  {  (C) Copyright 1994-2001, Mike Wiering, e-mail: mike.wiering@wxs.nl  }

  {
     Keyboard unit for use with Turbo Pascal 5.5
  }

interface

  const
    kb1 =  #2;   kbQ = #16;   kbA = #30;   kbZ = #44;
    kb2 =  #3;   kbW = #17;   kbS = #31;   kbX = #45;
    kb3 =  #4;   kbE = #18;   kbD = #32;   kbC = #46;
    kb4 =  #5;   kbR = #19;   kbF = #33;   kbV = #47;
    kb5 =  #6;   kbT = #20;   kbG = #34;   kbB = #48;
    kb6 =  #7;   kbY = #21;   kbH = #35;   kbN = #49;
    kb7 =  #8;   kbU = #22;   kbJ = #36;   kbM = #50;
    kb8 =  #9;   kbI = #23;   kbK = #37;
    kb9 = #10;   kbO = #24;   kbL = #38;
    kb0 = #11;   kbP = #25;

    kbEsc        =  #1;
    kbBS         = #14;
    kbTab        = #15;
    kbEnter      = #28;
    kbSP         = #57;
    kbUpArrow    = #72;
    kbLeftArrow  = #75;
    kbRightArrow = #77;
    kbDownArrow  = #80;

  var
    Key: Char;
    bKey: Byte absolute Key;


  procedure InitKeyBoard;
  procedure KeyBoardDone;

  procedure ResetKeyBoard;

  procedure RecordMacro;
  procedure PlayMacro;
  procedure SaveMacro;
  procedure StopMacro;
  function PlayingMacro: Boolean;

  function kbHit: Boolean;

  function kbLeft: Boolean;
  function kbRight: Boolean;
  function kbUp: Boolean;
  function kbDown: Boolean;
  function kbAlt: Boolean;
  function kbCtrl: Boolean;
  function kbLeftShift: Boolean;
  function kbRightShift: Boolean;
  function kbSpace: Boolean;

  function GetAsciiCode (c: Char): Char;

implementation

  uses
    Dos;

  const
    HandlerActive: Boolean = FALSE;
    KeyHit: Boolean = FALSE;

  const
    MaxKeys = 9;

  const
    KeyMap: Array[1..MaxKeys] of Boolean =
      (False, False, False, False, False, False, False, False, False);

    PressCode: Array[1..MaxKeys] of Char =
      ('K', 'M', 'H', 'P', '8', #29, '*', '6', '9');

    ReleaseCode: Array[1..MaxKeys] of Char =
      (#203, #205, #200, #208, #184, #157, #170, #182, #185);

  {$F+}
  {$S-}
  procedure GetKey;
  begin
inline(
                     $5D  (*           pop     bp *)

                    /$9C  (*           pushf *)
                    /$50  (*           push    ax *)
                    /$51  (*           push    cx *)
                    /$52  (*           push    dx *)
                    /$57  (*           push    di *)
                    /$06  (*           push    es *)
            /$B8/$00/$00  (*           mov     ax, seg @Data *)
                /$8E/$C0  (*           mov     es, ax *)
    /$26/$FE/$06/>KeyHit  (*           inc     es:KeyHit *)
                /$E4/$60  (*           in      al, 60h *)
                /$88/$C2  (*           mov     dl, al *)
          /$26/$A2/> Key  (*           mov     es:Key, al *)
        /$BF/> PressCode  (*           mov     di, offset PressCode *)
          /$B9/ >MaxKeys  (*           mov     cx, MaxKeys *)
                    /$FC  (*           cld *)
                    /$F2  (*           repnz *)
                    /$AE  (*           scasb *)
                /$75/$0B  (*           jnz     @1 *)
   /$BF/> KeyMap + MaxKeys (*           mov     di, offset KeyMap[MaxKeys] *)
                /$29/$CF  (*           sub     di, cx *)
                /$B0/$01  (*           mov     al, 1 *)
                    /$4F  (*           dec     di *)
                    /$AA  (*           stosb *)
                /$EB/$1A  (*           jmp     @2 *)
      /$BF/> ReleaseCode  (*   @1:     mov     di, offset ReleaseCode *)
          /$B9/> MaxKeys  (*           mov     cx, MaxKeys *)
                    /$FC  (*           cld *)
                    /$F2  (*           repnz *)
                    /$AE  (*           scasb *)
                /$75/$0F  (*           jnz     @2 *)
 /$26/$C6/$06/> KeyHit /$00  (*           mov     es:KeyHit, 0 *)
   /$BF/> KeyMap + MaxKeys (*           mov     di, offset KeyMap[MaxKeys] *)
                /$29/$CF  (*           sub     di, cx *)
                /$B0/$00  (*           mov     al, 0 *)
                    /$4F  (*           dec     di *)
                    /$AA  (*           stosb *)
                    /$07  (*   @2:     pop     es *)
                /$E4/$61  (*           in      al, 61h *)
                    /$50  (*           push    ax *)
                /$0C/$80  (*           or      al, 80h *)
                /$E6/$61  (*           out     61h, al *)
                    /$58  (*           pop     ax *)
                /$E6/$61  (*           out     61h, al *)
                    /$FA  (*           cli *)
                /$B0/$20  (*           mov     al, 20h *)
                /$E6/$20  (*           out     20h, al *)
                    /$FB  (*           sti *)

                    /$5F  (*           pop     di *)
                    /$5A  (*           pop     dx *)
                    /$59  (*           pop     cx *)
                    /$58  (*           pop     ax *)
                    /$9D  (*           popf *)
                    /$CF  (*           iret  *)
);
  end;
  {$F-}


  const
    keyLeft   = 1;
    keyRight  = 2;
    keyUp     = 3;
    keyDown   = 4;
    keyAlt    = 5;
    keyCtrl   = 6;
    keyShiftL = 7;
    keyShiftR = 8;
    keySpace  = 9;

  const
    MAX_SEQ_LEN = 100;

  type
    KeySeq = array[0..MAX_SEQ_LEN - 1] of Word;

  var
    Sequence: array[1..MaxKeys] of KeySeq;
    SeqPos: array[1..MaxKeys] of Word;

  const
    Recording: Boolean = FALSE;
    Playing: Boolean = FALSE;

  var
    OldKbIntVec: Procedure;
    OldExitProc: Pointer;


  {$F+}
  procedure NewExitProc;
  begin
    KeyBoardDone;
    ExitProc := OldExitProc;
  end;
  {$F-}

  procedure InitKeyBoard;
    var
      i: Integer;
  begin
    Port[$60] := $ED;
    for i := 1 to 1000 do ;
    Port[$60] := 0;
    OldExitProc := ExitProc;
    GetIntVec($09, @OldKbIntVec);
    ExitProc := @NewExitProc;
    SetIntVec($09, Addr(GetKey));
    HandlerActive := TRUE;
    KeyHit := FALSE;
  end;

  procedure KeyBoardDone;
  begin
    if not HandlerActive then
      Exit;
    SetIntVec($09, @OldKbIntVec);
    HandlerActive := FALSE;
    Mem[$0:$417] := 0;
  end;

  procedure ResetKeyBoard;
  var
    i: Byte;
  begin
    Recording := FALSE;
    Playing := FALSE;
    for i := 1 to MaxKeys
    do
      KeyMap[i] := False;
    Key := #0;
  end;


  procedure Macro; external; {$L DEMOKEYS.OBJ}

  procedure RecordMacro;
  begin
    Recording := TRUE;
    Playing := FALSE;
    FillChar (SeqPos, sizeof (SeqPos), 0);
    FillChar (Sequence, sizeof (SeqPos), 0);
    RandSeed := 0;
  end;

  procedure PlayMacro;
  begin
    Playing := TRUE;
    Recording := FALSE;
    FillChar (SeqPos, sizeof (SeqPos), 0);
    Move (@Macro^, Sequence, sizeof (Sequence));
{    FillChar (Sequence, sizeof (SeqPos), 0); }
    RandSeed := 0;
  end;

  procedure StopMacro;
  begin
    Playing := FALSE;
    Recording := FALSE;
  end;

  procedure SaveMacro;
    var
      F: File of KeySeq;
      i: Integer;
  begin
    Assign (F, '$');
    ReWrite (F);
    for i := 1 to MaxKeys do
      Write (F, Sequence[i]);
    Close (F);

    Recording := FALSE;
    FillChar (SeqPos, sizeof (SeqPos), 0);
  end;

  function PlayingMacro: Boolean;
  begin
    PlayingMacro := Playing;
  end;

  function Check (KeyNr: Byte; Press: Boolean): Boolean;
  begin
    Check := Press;
    if Playing or Recording then
    begin
      if Recording then
      begin
        if Press xor (SeqPos[KeyNr] mod 2 = 1) then
        begin
          Inc (SeqPos[KeyNr]);
          if SeqPos[KeyNr] >= MAX_SEQ_LEN then
            SeqPos[KeyNr] := MAX_SEQ_LEN - 1;
        end;
        Inc (Sequence[KeyNr, SeqPos[KeyNr]]);
      end;
      if Playing then
      begin
        if Sequence[KeyNr, SeqPos[KeyNr]] = 0 then
          Playing := FALSE
        else
        begin
          Dec (Sequence[KeyNr, SeqPos[KeyNr]]);
          if Sequence[KeyNr, SeqPos[KeyNr]] = 0 then
            Inc (SeqPos[KeyNr]);
          Check := (SeqPos[KeyNr] mod 2 = 1);
        end;
      end;
    end;
  end;

  function kbHit: Boolean;
  begin
    kbHit := KeyHit;
    KeyHit := FALSE;
  end;

  function kbLeft: Boolean;
  begin
    kbLeft := Check (keyLeft, KeyMap[keyLeft]);
  end;

  function kbRight: Boolean;
  begin
    kbRight := Check (keyRight, KeyMap[keyRight]);
  end;

  function kbUp: Boolean;
  begin
    kbUp := Check (keyUp, KeyMap[keyUp]);
  end;

  function kbDown: Boolean;
  begin
    kbDown := Check (keyDown, KeyMap[keyDown]);
  end;

  function kbAlt: Boolean;
  begin
    kbAlt := Check (keyAlt, KeyMap[keyAlt]);
  end;

  function kbCtrl: Boolean;
  begin
    kbCtrl := Check (keyCtrl, KeyMap[keyCtrl]);
  end;

  function kbLeftShift: Boolean;
  begin
    kbLeftShift := Check (keyShiftL, KeyMap[keyShiftL]);
  end;

  function kbRightShift: Boolean;
  begin
    kbRightShift := Check (keyShiftR, KeyMap[keyShiftR]);
  end;

  function kbSpace: Boolean;
  begin
    kbSpace := Check (keySpace, KeyMap[keySpace]);
  end;

  function GetAsciiCode (c: Char): Char;
    const
      kbTable: array[0..3] of string[10] =
        ('1234567890',
         'QWERTYUIOP',
         'ASDFGHJKL',
         'ZXCVBNM');
    var
      i: Byte absolute c;
  begin
    case i of
       2..11: GetAsciiCode := kbTable[0, i - 2 + 1];
      16..25: GetAsciiCode := kbTable[1, i - 16 + 1];
      30..38: GetAsciiCode := kbTable[2, i - 30 + 1];
      44..50: GetAsciiCode := kbTable[3, i - 44 + 1];
    else
      GetAsciiCode := #0;
    end
  end;

  type
    WordPtr = ^Word;

  var
    P: Pointer;
    L: LongInt absolute P;
    W: WordPtr;
begin
  P := @GetKey;
  Inc (L, 11);
  W := P;
  W^ := DSeg;
end.
