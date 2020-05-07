unit Txt;

  {$R-}

interface

  uses
    VGA256,
    Buffers;

  const
    Normal      = $00;
    Bold        = $01;
    Shadow      = $02;

  procedure SetFont (i: Integer; Style: Word);
  function Letter (i: Integer): Pointer;
  function TextWidth (S: String): Integer;
  procedure WriteText (X, Y: Integer; S: String; Attr: Byte);
  function CenterX (S: String): Integer;
  procedure CenterText (Y: Integer; S: String; Attr: Byte);

implementation

  {$S-}

  const
    bShadow: Boolean = FALSE;
    bBold: Boolean = FALSE;

  var
    Font: Pointer;
    Base: Byte;

  procedure SwissFont; external; {$L SWISS}

  procedure Font8x8; external; {$L F8X8}

  procedure SetFont (i: Integer; Style: Word);
  begin
    case i of
      0: begin
           Font := @Font8x8;
           Base := 0;
         end;
      1: begin
           Font := @SwissFont;
           Base := 32;
         end;
    end;
    bBold := Style or Bold = Style;
    bShadow := Style or Shadow = Style;
  end;

  function Letter (i: Integer): pointer;
    var
      W1,
      W2: Word;
      P: Pointer;
  begin
    P := Font;
    Dec (i, Base);
inline(
                     $1E  (*         push    ds *)
            /$C5/$76/$F4  (*         lds     si, P *)

                /$89/$F3  { mov bx, si }

            /$8B/$46/$06  (*         mov     ax, i *)
                /$D1/$E0  (*         shl     ax, 1 *)
                /$01/$C6  (*         add     si, ax *)
                    /$AD  (*         lodsw *)

                /$2D/0/1  { sub ax, 100h }
                /$01/$D8  { add ax, bx }

            /$8C/$5E/$FA  (*         mov     W1, ds *)
            /$89/$46/$F8  (*         mov     W2, ax *)
                    /$1F  (*         pop     ds *)
);
    Letter := Ptr (W1, W2);
  end;

  function TextWidth (S: String): Integer;
    var
      P: Pointer;
      Width: Integer;
      i: Byte;
      A: Word;
  begin
    P := Font;
    Width := 0;
    for i := 1 to Length (S) do
    begin
      A := Ord (S [i]) shl 1;
      Dec (A, 2 * Base);
inline(
                     $1E  (*         push    ds *)
        /$C5/$B6/$FA/$FE  (*         lds     si, P *)

                /$89/$F3  { mov bx, si }

        /$8B/$86/$F4/$FE  (*         mov     ax, A *)
                /$01/$C6  (*         add     si, ax *)
                    /$FC  (*         cld *)
                    /$AD  (*         lodsw *)

                /$2D/0/1  { sub ax, 100h }
                /$01/$D8  { add ax, bx }

                /$89/$C6  (*         mov     si, ax *)
                    /$AC  (*         lodsb *)
                /$B4/$00  (*         mov     ah, 0 *)
        /$01/$86/$F8/$FE  (*         add     Width, ax *)
                    /$1F  (*         pop     ds *)
);
      Inc (Width, Byte (bBold) + Byte (bShadow));
    end;
    TextWidth := Width;
  end;

  procedure WriteText (X, Y: Integer; S: String; Attr: Byte);
    var
      i: Byte;
      C: Char;
  begin
    i := 1;
    repeat
      C := S [i];
      if bShadow then
        DrawBitmap (X + 1, Y + 1, Letter (Ord (C))^, 16);
      if bBold then
      begin
        if bShadow then
          DrawBitmap (X, Y + 1, Letter (Ord (C))^, 16);
        DrawBitmap (X - 1, Y, Letter (Ord (C))^, Attr);
      end;
      DrawBitmap (X, Y, Letter (Ord (C))^, Attr);
      inc (X, TextWidth (C));
      Inc (i);
    until i > Length (S);
  end;

  function CenterX (S: String): Integer;
  begin
    CenterX := XView + (SCREEN_WIDTH - TextWidth (S)) shr 1;
  end;

  procedure CenterText (Y: Integer; S: String; Attr: Byte);
  begin
    WriteText (CenterX (S), Y, S, Attr);
  end;

begin
  SetFont (0, Normal);
end.
