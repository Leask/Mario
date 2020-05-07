unit VGA256;

  {  (C) Copyright 1994-2001, Mike Wiering, e-mail: mike.wiering@wxs.nl  }

  {
     Turbo Pascal VGA unit (Mode 13h, 320x200 256 colors), designed
     for side-scrolling games, uses planar mode, page-flipping (2 pages),
     statusline
  }

  {$DEFINE DEBUG}

(*   {$D,$L} *)
  {$R-}  { no range-checking }
  {$I-}  { no I/O-checking }
(*   {$G+} *)
    { allow 286 instructions }

interface

  { add 3 to a pointer variable - skip procedure header }
  function A3 (var P): Pointer;

  const
    VGA_SEGMENT           = $A000;

    WINDOWHEIGHT        = 13 * 14;
    WINDOWWIDTH         = 16 * 20;

    SCREEN_WIDTH        = 320;
    SCREEN_HEIGHT       = 200;

    VIR_SCREEN_WIDTH    = SCREEN_WIDTH + 2 * 20;
    VIR_SCREEN_HEIGHT   = 182;
    BYTES_PER_LINE      = VIR_SCREEN_WIDTH div 4;

    MISC_OUTPUT         = $03C2;
    SC_INDEX            = $03C4;
    GC_INDEX            = $03CE;
    CRTC_INDEX          = $03D4;
    VERT_RESCAN         = $03DA;

    MAP_MASK            = 2;
    MEMORY_MODE         = 4;

    VERT_RETRACE_MASK   = 8;

    MAX_SCAN_LINE       = 9;
    START_ADDRESS_HIGH  = $C;
    START_ADDRESS_LOW   = $D;
    UNDERLINE           = $14;
    MODE_CONTROL        = $17;

    READ_MAP            = 4;
    GRAPHICS_MODE       = 5;
    MISCELLANEOUS       = 6;

    MAX_SCREENS         = 24;
    MAX_PAGE            = 1;
    PAGE_SIZE           = (VIR_SCREEN_HEIGHT + MAX_SCREENS) * BYTES_PER_LINE;
    PAGE_0              = 0;
    PAGE_1              = $8000;

    YBASE               = 9;

  function DetectVGA: Boolean;
  procedure InitVGA;
  procedure OldMode;
  function GetMode: Byte;
  procedure SetMode (NewMode: Byte);
  procedure SetWidth (NewWidth: Word);
  procedure ClearVGAMem;
  procedure WaitDisplay;
  procedure WaitRetrace;
  procedure SetView (X, Y: Integer);
  procedure SetViewport (X, Y: Integer; PageNr: Byte);
  procedure SwapPages;
  procedure ShowPage;
  procedure Border (Attr: Byte);
  procedure SetYStart (NewYStart: Integer);
  procedure SetYEnd (NewYEnd: Integer);
  procedure SetYOffset (NewYOffset: Integer);
  function GetYOffset: Integer;
  procedure PutPixel (X, Y: Integer; Attr: Byte);
  function GetPixel (X, Y: Integer): Byte;
  procedure DrawImage (XPos, YPos, Width, Height: Integer; var BitMap);
  procedure RecolorImage (XPos, YPos, Width, Height: Integer; var BitMap; Diff: Byte);
  procedure DrawPart (XPos, YPos, Width, Height, Y1, Y2: Integer; var BitMap);
  procedure UpSideDown (XPos, YPos, Width, Height: Integer; var BitMap);
  procedure PutImage (XPos, YPos, Width, Height: Integer; var BitMap);
  procedure GetImage (XPos, YPos, Width, Height: Integer; var BitMap);
  procedure Fill (X, Y, W, H: Integer; Attr: Integer);
  procedure SetPalette (Color, Red, Green, Blue: Byte);
  procedure ReadPalette (var NewPalette);
  procedure ClearPalette;
  function CurrentPage: Integer;
  function GetPageOffset: Word;
  procedure ResetStack;
  function PushBackGr (X, Y, W, H: Integer): Word;
  procedure PopBackGr (Address: Word);
  procedure DrawBitmap (X, Y: Integer; var BitMap; Attr: Byte);

  const
    InGraphicsMode: Boolean = FALSE;

implementation

  function A3 (var P): Pointer;
    var
      P2: Pointer;
      W: Word absolute P2;
  begin
    P2 := @P;
    Inc (W, 3);
    A3 := P2;
  end;

  var
    OldExitProc: Pointer;
    OldScreenMode: Byte;

  const
    XView: Integer = 0;
    YView: Integer = 0;

    Page: Integer = 0;
    PageOffset: Word = 0;

    YOffset: Integer = 0;

    SAFE = 34 * BYTES_PER_LINE;

    Stack: array[0..MAX_PAGE] of Word =
      (PAGE_0 + PAGE_SIZE + SAFE,
       PAGE_1 + PAGE_SIZE + SAFE);


  {$F+}
  procedure NewExitProc;
    { Be sure to return to textmode if program is halted }
  begin
    OldMode;
    ExitProc := OldExitProc;
  end;
  {$F-}

  function GetMode: Byte;
    { Get video mode }
  begin
inline(
                     $55  (*         push    bp *)
                /$B4/$0F  (*         mov     ah, 0Fh *)
                /$CD/$10  (*         int     10h *)
            /$88/$46/$FF  (*         mov     @Result, al *)
                    /$5D  (*         pop     bp *)
);
  end;

  procedure SetMode (NewMode: Byte);
    { Set video mode }
  begin
inline(
                     $55  (*         push    bp *)
                /$30/$E4  (*         xor     ah, ah *)
            /$8A/$46/$06  (*         mov     al, NewMode *)
                /$CD/$10  (*         int     10h *)
                    /$5D  (*         pop     bp *)
);
  end;

  procedure SetWidth (NewWidth: Word);
    { Set screen width (NewWidth >= 40) }
  begin
inline(
             $8B/$46/$06  (*         mov     ax, NewWidth *)
                    /$50  (*         push    ax *)
            /$BA/$D4/$03  (*         mov     dx, CRTC_INDEX *)
            /$B8/$13/$00  (*         mov     ax, 13h *)
                    /$EE  (*         out     dx, al *)
                    /$58  (*         pop     ax *)
                    /$42  (*         inc     dx *)
                    /$EE  (*         out     dx, al *)
);
  end;

  function DetectVGA: Boolean;
    var
      VGADetected: Boolean;
  begin
    VGADetected := False;
inline(
                     $55  (*         push    bp *)
            /$B8/$00/$1A  (*         mov     ax, 1A00h *)
                /$CD/$10  (*         int     10h *)
                /$3C/$1A  (*         cmp     al, 1Ah *)
                /$75/$03  (*         jnz     @NoVGA *)
            /$FE/$46/$FE  (*         inc     VGADetected *)
(*     @NoVGA: *)
                    /$5D  (*         pop     bp *)
);
    DetectVGA := VGADetected;
  end;

  procedure InitVGA;
    { Start graphics mode 320x200 256 colors }
  begin
    ClearPalette;
    SetMode ($13);
    ClearPalette;
    SetWidth (BYTES_PER_LINE shr 1);
inline(
             $BA/$C4/$03  (*         mov     dx, SC_INDEX *)
                /$B0/$04  (*         mov     al, MEMORY_MODE *)
                    /$EE  (*         out     dx, al *)
                    /$42  (*         inc     dx *)
                    /$EC  (*         in      al, dx *)
                /$24/$F7  (*         and     al, not 8 *)
                /$0C/$04  (*         or      al, 4 *)
                    /$EE  (*         out     dx, al *)
            /$BA/$CE/$03  (*         mov     dx, GC_INDEX *)
                /$B0/$05  (*         mov     al, GRAPHICS_MODE *)
                    /$EE  (*         out     dx, al *)
                    /$42  (*         inc     dx *)
                    /$EC  (*         in      al, dx *)
                /$24/$EF  (*         and     al, not 10h *)
                    /$EE  (*         out     dx, al *)
                    /$4A  (*         dec     dx *)
                /$B0/$06  (*         mov     al, MISCELLANEOUS *)
                    /$EE  (*         out     dx, al *)
                    /$42  (*         inc     dx *)
                    /$EC  (*         in      al, dx *)
                /$24/$FD  (*         and     al, not 2 *)
                    /$EE  (*         out     dx, al *)
);
    ClearVGAMem;
inline(
             $BA/$D4/$03  (*         mov     dx, CRTC_INDEX *)
                /$B0/$14  (*         mov     al, UNDERLINE *)
                    /$EE  (*         out     dx, al *)
                    /$42  (*         inc     dx *)
                    /$EC  (*         in      al, dx *)
                /$24/$BF  (*         and     al, not 40h *)
                    /$EE  (*         out     dx, al *)
                    /$4A  (*         dec     dx *)
                /$B0/$17  (*         mov     al, MODE_CONTROL *)
                    /$EE  (*         out     dx, al *)
                    /$42  (*         inc     dx *)
                    /$EC  (*         in      al, dx *)
                /$0C/$40  (*         or      al, 40h *)
                    /$EE  (*         out     dx, al *)
);
    if not InGraphicsMode then
    begin
      OldExitProc := ExitProc;
      ExitProc := @NewExitProc;
    end;
    InGraphicsMode := TRUE;
  end;

  procedure OldMode;
    { Return to the original screenmode }
  begin
    if InGraphicsMode then
    begin
      ClearVGAMem;
      ClearPalette;
      ShowPage;
    end;
    SetMode (OldScreenMode);
    InGraphicsMode := FALSE;
    ExitProc := OldExitProc;
  end;

  procedure ClearVGAMem;
  begin
inline(
                     $06  (*         push    es *)
            /$BA/$C4/$03  (*         mov     dx, SC_INDEX *)
            /$B8/$02/$0F  (*         mov     ax, 0F00h + MAP_MASK *)
                    /$EF  (*         out     dx, ax *)
            /$B8/$00/$A0  (*         mov     ax, VGA_SEGMENT *)
                /$8E/$C0  (*         mov     es, ax *)
                /$31/$C0  (*         xor     ax, ax *)
                /$89/$C7  (*         mov     di, ax *)
            /$B9/$00/$80  (*         mov     cx, 8000h *)
                    /$FC  (*         cld *)
                /$F3/$AB  (*         rep     stosw *)
                    /$07  (*         pop     es *)
);
  end;

  procedure WaitDisplay;
  begin
inline(
             $BA/$DA/$03  (*           mov     dx, VERT_RESCAN *)
                    /$EC  (*   @1:     in      al, dx *)
                /$A8/$08  (*           test    al, VERT_RETRACE_MASK *)
                /$75/$FB  (*           jnz     @1 *)
);
  end;

  procedure WaitRetrace;
  begin
inline(
             $BA/$DA/$03  (*           mov     dx, VERT_RESCAN *)
                    /$EC  (*   @1:     in      al, dx *)
                /$A8/$08  (*           test    al, VERT_RETRACE_MASK *)
                /$74/$FB  (*           jz      @1 *)
);
  end;

  procedure SetView (X, Y: Integer);
  begin
    XView := X;
    YView := Y;
  end;

  procedure SetViewport (X, Y: Integer; PageNr: Byte);
    { Set the offset of video memory }
  var
    i: Integer;
  begin
inline(
                     $FA  (*           cli *)

            /$BA/$DA/$03  (*           mov     dx, VERT_RESCAN               { wait for display } *)
                    /$EC  (*   @1:     in      al, dx *)
                /$A8/$08  (*           test    al, VERT_RETRACE_MASK *)
                /$75/$FB  (*           jnz     @1 *)

            /$D1/$66/$0A  (*           shl     X, 1 *)
            /$D1/$66/$08  (*           shl     Y, 1 *)
            /$8B/$46/$08  (*           mov     ax, Y *)
            /$BB/$2D/$00  (*           mov     bx, BYTES_PER_LINE / 2 *)
                /$F7/$E3  (*           mul     bx *)
            /$8B/$5E/$0A  (*           mov     bx, X *)
                /$B1/$03  (*           mov     cl, 3 *)
                /$D3/$EB  (*           shr     bx, cl *)
                /$01/$C3  (*           add     bx, ax *)
                /$B0/$0C  (*           mov     al, START_ADDRESS_HIGH *)
            /$8A/$66/$06  (*           mov     ah, PageNr *)
                /$D0/$CC  (*           ror     ah, 1 *)
                /$00/$FC  (*           add     ah, bh *)
            /$BA/$D4/$03  (*           mov     dx, CRTC_INDEX *)
                    /$EF  (*           out     dx, ax *)
                /$B0/$0D  (*           mov     al, START_ADDRESS_LOW *)
                /$88/$DC  (*           mov     ah, bl *)
                    /$EF  (*           out     dx, ax *)

            /$BA/$DA/$03  (*           mov     dx, VERT_RESCAN               { wait for retrace } *)
                    /$EC  (*   @2:     in      al, dx *)
                /$A8/$08  (*           test    al, VERT_RETRACE_MASK *)
                /$74/$FB  (*           jz      @2 *)

            /$8B/$46/$0A  (*           mov     ax, X *)
            /$25/$07/$00  (*           and     ax, 7 *)
                /$04/$10  (*           add     al, 10h *)
            /$BA/$C0/$03  (*           mov     dx, 3c0h *)
                /$88/$C4  (*           mov     ah, al *)
                /$B0/$33  (*           mov     al, 33h *)
                    /$EE  (*           out     dx, al *)
                /$86/$C4  (*           xchg    ah, al *)
                    /$EE  (*           out     dx, al *)
                    /$FB  (*           sti *)
);
  end;

  procedure SwapPages;
  begin
    case Page of
      0: begin
           Page := 1;
           PageOffset := PAGE_1 + YOffset * BYTES_PER_LINE;
         end;
      1: begin
           Page := 0;
           PageOffset := PAGE_0 + YOffset * BYTES_PER_LINE;
         end;
    end;
  end;

  procedure ShowPage;
  begin
    SetViewport (XView, YView, Page);
    SwapPages;
  end;

  procedure Border (Attr: Byte);
    { Draw a border around the screen }
  begin
inline(
                     $55  (*           push    bp *)
            /$B8/$01/$10  (*           mov     ax, 1001h *)
            /$8A/$7E/$06  (*           mov     bh, Attr *)
                /$CD/$10  (*           int     10h *)
                    /$5D  (*           pop     bp *)
);
  end;

  procedure SetYStart (NewYStart: Integer);
  begin
inline(
             $BA/$D4/$03  (*           mov     dx, CRTC_INDEX *)
                /$B0/$16  (*           mov     al, 16h *)
            /$8A/$66/$06  (*           mov     ah, Byte Ptr [NewYStart] *)
                    /$EF  (*           out     dx, ax *)
);
  end;

  procedure SetYEnd (NewYEnd: Integer);
  begin
inline(
             $BA/$D4/$03  (*           mov     dx, CRTC_INDEX *)
                /$B0/$15  (*           mov     al, 15h *)
            /$8A/$66/$06  (*           mov     ah, Byte Ptr [NewYEnd] *)
                    /$EF  (*           out     dx, ax *)
);
  end;

  procedure SetYOffset (NewYOffset: Integer);
  begin
    YOffset := NewYOffset;
  end;

  function GetYOffset: Integer;
  begin
    GetYOffset := YOffset;
  end;

  procedure PutPixel (X, Y: Integer; Attr: Byte);
    { Draw a single pixel at (X, Y) with color Attr }
  begin
inline(
                     $06  (*         push    es *)
            /$B8/$00/$A0  (*         mov     ax, VGA_SEGMENT *)
                /$8E/$C0  (*         mov     es, ax *)
            /$8B/$56/$08  (*         mov     dx, Y *)
            /$B8/$5A/$00  (*         mov     ax, BYTES_PER_LINE *)
                /$F7/$E2  (*         mul     dx *)
            /$8B/$4E/$0A  (*         mov     cx, X *)
                    /$51  (*         push    cx *)
                /$D1/$E9  (*         shr     cx, 1 *)
                /$D1/$E9  (*         shr     cx, 1 *)
                /$01/$C8  (*         add     ax, cx *)
                /$89/$C7  (*         mov     di, ax *)
        /$03/$3E/PageOffset  (*         add     di, PageOffset *)
                    /$59  (*         pop     cx *)
            /$80/$E1/$03  (*         and     cl, 3 *)
                /$B4/$01  (*         mov     ah, 1 *)
                /$D2/$E4  (*         shl     ah, cl *)
                /$B0/$02  (*         mov     al, MAP_MASK *)
            /$BA/$C4/$03  (*         mov     dx, SC_INDEX *)
                    /$EF  (*         out     dx, ax *)
            /$8A/$46/$06  (*         mov     al, Attr *)
                    /$AA  (*         stosb *)
                    /$07  (*         pop     es *)
);
  end;

  function GetPixel (X, Y: Integer): Byte;
    { Get color of pixel at (X, Y) }
  begin
inline(
                     $06  (*         push    es *)
            /$B8/$00/$A0  (*         mov     ax, VGA_SEGMENT *)
                /$8E/$C0  (*         mov     es, ax *)
            /$8B/$56/$06  (*         mov     dx, Y *)
            /$B8/$5A/$00  (*         mov     ax, BYTES_PER_LINE *)
                /$F7/$E2  (*         mul     dx *)
            /$8B/$4E/$08  (*         mov     cx, X *)
                    /$51  (*         push    cx *)
                /$D1/$E9  (*         shr     cx, 1 *)
                /$D1/$E9  (*         shr     cx, 1 *)
                /$01/$C8  (*         add     ax, cx *)
                /$89/$C6  (*         mov     si, ax *)
        /$03/$36/PageOffset  (*         add     si, PageOffset *)
                    /$58  (*         pop     ax *)
                /$24/$03  (*         and     al, 3 *)
                /$88/$C4  (*         mov     ah, al *)
                /$B0/$04  (*         mov     al, READ_MAP *)
            /$BA/$CE/$03  (*         mov     dx, GC_INDEX *)
                    /$EF  (*         out     dx, ax *)
            /$26/$8A/$04  (*         seges   mov al, [si] *)
                    /$07  (*         pop     es *)
            /$88/$46/$FF  (*         mov     @Result, al *)
);
  end;

  procedure DrawImage (XPos, YPos, Width, Height: Integer; var BitMap);
    { Draw an image on the screen (NULL-bytes are ignored) }
  begin
inline(
                     $1E  (*         push    ds *)

            /$B8/$00/$A0  (*         mov     ax, VGA_SEGMENT *)
                /$8E/$C0  (*         mov     es, ax *)

            /$8B/$46/$0E  (*         mov     ax, YPos *)
            /$3D/$B6/$00  (*         cmp     ax, VIR_SCREEN_HEIGHT *)
                /$72/$0F  (*         jb      @NotNeg *)
    /$7E/$03/$E9/$8C/$00  (*         jg      @End *)
                /$89/$C3  (*         mov     bx, ax *)
            /$03/$5E/$0A  (*         add     bx, Height *)
    /$72/$03/$E9/$82/$00  (*         jnc     @End *)
(*   @NotNeg: *)
            /$BB/$5A/$00  (*         mov     bx, BYTES_PER_LINE *)
                /$F7/$E3  (*         mul     bx *)
            /$8B/$7E/$10  (*         mov     di, XPos *)
                /$89/$FB  (*         mov     bx, di *)
                /$D1/$EF  (*         shr     di, 1 *)
                /$D1/$EF  (*         shr     di, 1 *)
                /$01/$C7  (*         add     di, ax                  { DI = (YPos * 80) + XPos / 4 } *)
        /$03/$3E/PageOffset  (*         add     di, PageOffset *)

            /$C5/$76/$06  (*         lds     si, BitMap              { Point to bitmap } *)

            /$80/$E3/$03  (*         and     bl, 3 *)
                /$88/$D9  (*         mov     cl, bl *)
                /$B4/$01  (*         mov     ah, 1 *)
                /$D2/$E4  (*         shl     ah, cl *)
            /$80/$EB/$04  (*         sub     bl, 4 *)
            /$B9/$04/$00  (*         mov     cx, 4                   { 4 planes } *)

(*   @Plane: *)
                    /$53  (*         push    bx *)
                    /$51  (*         push    cx                      { Planes to go } *)
                    /$50  (*         push    ax                      { Mask in AH } *)

                /$B0/$02  (*         mov     al, MAP_MASK *)
            /$BA/$C4/$03  (*         mov     dx, SC_INDEX *)
                    /$EF  (*         out     dx, ax *)

                    /$FC  (*         cld *)
                    /$57  (*         push    di *)
            /$8B/$5E/$0C  (*         mov     bx, Width *)
                /$D1/$EB  (*         shr     bx, 1 *)
                /$D1/$EB  (*         shr     bx, 1 *)
            /$B8/$5A/$00  (*         mov     ax, BYTES_PER_LINE *)
                /$29/$D8  (*         sub     ax, bx                  { Space before next line } *)
            /$8B/$56/$0A  (*         mov     dx, Height *)
(*   @Line: *)
                /$89/$D9  (*         mov     cx, bx *)
                /$D1/$E9  (*         shr     cx, 1 *)

                    /$50  (*         push    ax *)
                    /$9C  (*         pushf *)

(*   @Pixel: *)
                    /$AD  (*         lodsw *)
                /$08/$C0  (*         or      al, al *)
                /$74/$03  (*         jz      @Skip1 *)
                    /$26  (*         seges *)
                /$88/$05  (*         mov     [di], al *)
(*   @Skip1: *)
                    /$47  (*         inc     di *)
                /$08/$E4  (*         or      ah, ah *)
                /$74/$03  (*         jz      @Skip2 *)
                    /$26  (*         seges *)
                /$88/$25  (*         mov     [di], ah *)
(*   @Skip2: *)
                    /$47  (*         inc     di *)
                /$E2/$ED  (*         loop    @Pixel *)

                    /$9D  (*         popf *)
                /$D1/$D1  (*         rcl     cx, 1 *)
                /$E3/$09  (*         jcxz    @Skip3 *)

                    /$AC  (*         lodsb *)
                /$08/$C0  (*         or      al, al *)
                /$74/$03  (*         jz      @Odd *)
                    /$AA  (*         stosb *)
                /$EB/$01  (*         jmp     @Skip3 *)
                    /$47  (*   @Odd: inc     di *)
(*   @Skip3: *)
                    /$58  (*         pop     ax *)
                /$01/$C7  (*         add     di, ax *)
                    /$4A  (*         dec     dx *)
                /$75/$D3  (*         jnz     @Line *)

                    /$5F  (*         pop     di *)

                    /$58  (*         pop     ax *)
                /$88/$E0  (*         mov     al, ah *)
                /$B1/$04  (*         mov     cl, 4 *)
                /$D2/$E0  (*         shl     al, cl *)
                /$08/$C4  (*         or      ah, al                  { Mask for next byte } *)
                /$D0/$C4  (*         rol     ah, 1                   { Bit mask for next plane } *)
                    /$59  (*         pop     cx                      { Planes } *)
                    /$5B  (*         pop     bx *)
                /$FE/$C3  (*         inc     bl                      { Still in the same byte? } *)
            /$83/$D7/$00  (*         adc     di, 0 *)
                /$E2/$A4  (*         loop    @Plane *)

(*     @End: *)
                    /$1F  (*         pop     ds *)
);
  end;

  procedure RecolorImage (XPos, YPos, Width, Height: Integer; var BitMap; Diff: Byte);
  begin
inline(
                     $1E  (*         push    ds *)

            /$B8/$00/$A0  (*         mov     ax, VGA_SEGMENT *)
                /$8E/$C0  (*         mov     es, ax *)

            /$8B/$46/$10  (*         mov     ax, YPos *)
            /$3D/$B6/$00  (*         cmp     ax, VIR_SCREEN_HEIGHT *)
                /$72/$0F  (*         jb      @NotNeg *)
    /$7E/$03/$E9/$95/$00  (*         jg      @End *)
                /$89/$C3  (*         mov     bx, ax *)
            /$03/$5E/$0C  (*         add     bx, Height *)
    /$72/$03/$E9/$8B/$00  (*         jnc     @End *)
(*   @NotNeg: *)
            /$BB/$5A/$00  (*         mov     bx, BYTES_PER_LINE *)
                /$F7/$E3  (*         mul     bx *)
            /$8B/$7E/$12  (*         mov     di, XPos *)
                /$89/$FB  (*         mov     bx, di *)
                /$D1/$EF  (*         shr     di, 1 *)
                /$D1/$EF  (*         shr     di, 1 *)
                /$01/$C7  (*         add     di, ax                  { DI = (YPos * 80) + XPos / 4 } *)
        /$03/$3E/PageOffset  (*         add     di, PageOffset *)

            /$C5/$76/$08  (*         lds     si, BitMap              { Point to bitmap } *)

            /$80/$E3/$03  (*         and     bl, 3 *)
                /$88/$D9  (*         mov     cl, bl *)
                /$B4/$01  (*         mov     ah, 1 *)
                /$D2/$E4  (*         shl     ah, cl *)
            /$80/$EB/$04  (*         sub     bl, 4 *)
            /$B9/$04/$00  (*         mov     cx, 4                   { 4 planes } *)

(*   @Plane: *)
                    /$53  (*         push    bx *)
                    /$51  (*         push    cx                      { Planes to go } *)
                    /$50  (*         push    ax                      { Mask in AH } *)

                /$B0/$02  (*         mov     al, MAP_MASK *)
            /$BA/$C4/$03  (*         mov     dx, SC_INDEX *)
                    /$EF  (*         out     dx, ax *)

                    /$FC  (*         cld *)
                    /$57  (*         push    di *)
            /$8B/$5E/$0E  (*         mov     bx, Width *)
                /$D1/$EB  (*         shr     bx, 1 *)
                /$D1/$EB  (*         shr     bx, 1 *)
            /$B8/$5A/$00  (*         mov     ax, BYTES_PER_LINE *)
                /$29/$D8  (*         sub     ax, bx                  { Space before next line } *)
            /$8B/$56/$0C  (*         mov     dx, Height *)
(*   @Line: *)
                /$89/$D9  (*         mov     cx, bx *)
                /$D1/$E9  (*         shr     cx, 1 *)

                    /$50  (*         push    ax *)
                    /$9C  (*         pushf *)

(*   @Pixel: *)
                    /$AD  (*         lodsw *)
                /$08/$C0  (*         or      al, al *)
                /$74/$06  (*         jz      @Skip1 *)
            /$02/$46/$06  (*         add     al, Diff *)
                    /$26  (*         seges *)
                /$88/$05  (*         mov     [di], al *)
(*   @Skip1: *)
                    /$47  (*         inc     di *)
                /$08/$E4  (*         or      ah, ah *)
                /$74/$06  (*         jz      @Skip2 *)
            /$02/$66/$06  (*         add     ah, Diff *)
                    /$26  (*         seges *)
                /$88/$25  (*         mov     [di], ah *)
(*   @Skip2: *)
                    /$47  (*         inc     di *)
                /$E2/$E7  (*         loop    @Pixel *)

                    /$9D  (*         popf *)
                /$D1/$D1  (*         rcl     cx, 1 *)
                /$E3/$0C  (*         jcxz    @Skip3 *)

                    /$AC  (*         lodsb *)
                /$08/$C0  (*         or      al, al *)
                /$74/$06  (*         jz      @Odd *)
            /$02/$46/$06  (*         add     al, Diff *)
                    /$AA  (*         stosb *)
                /$EB/$01  (*         jmp     @Skip3 *)
                    /$47  (*   @Odd: inc     di *)
(*   @Skip3: *)
                    /$58  (*         pop     ax *)
                /$01/$C7  (*         add     di, ax *)
                    /$4A  (*         dec     dx *)
                /$75/$CA  (*         jnz     @Line *)

                    /$5F  (*         pop     di *)

                    /$58  (*         pop     ax *)
                /$88/$E0  (*         mov     al, ah *)
                /$B1/$04  (*         mov     cl, 4 *)
                /$D2/$E0  (*         shl     al, cl *)
                /$08/$C4  (*         or      ah, al                  { Mask for next byte } *)
                /$D0/$C4  (*         rol     ah, 1                   { Bit mask for next plane } *)
                    /$59  (*         pop     cx                      { Planes } *)
                    /$5B  (*         pop     bx *)
                /$FE/$C3  (*         inc     bl                      { Still in the same byte? } *)
            /$83/$D7/$00  (*         adc     di, 0 *)
                /$E2/$9B  (*         loop    @Plane *)

(*     @End: *)
                    /$1F  (*         pop     ds *)
);
  end;

  procedure DrawPart (XPos, YPos, Width, Height, Y1, Y2: Integer; var BitMap);
  begin
inline(
                     $1E  (*         push    ds *)
        /$83/$7E/$0E/$00  (*         cmp     Height, 0 *)
    /$7F/$03/$E9/$B1/$00  (*         jle     @End *)

            /$B8/$00/$A0  (*         mov     ax, VGA_SEGMENT *)
                /$8E/$C0  (*         mov     es, ax *)

            /$8B/$46/$12  (*         mov     ax, YPos *)
            /$3D/$B6/$00  (*         cmp     ax, VIR_SCREEN_HEIGHT *)
                /$72/$0F  (*         jb      @NotNeg *)
    /$7E/$03/$E9/$9F/$00  (*         jg      @End *)
                /$89/$C3  (*         mov     bx, ax *)
            /$03/$5E/$0E  (*         add     bx, Height *)
    /$72/$03/$E9/$95/$00  (*         jnc     @End *)
(*   @NotNeg: *)
            /$BB/$5A/$00  (*         mov     bx, BYTES_PER_LINE *)
                /$F7/$E3  (*         mul     bx *)
            /$8B/$7E/$14  (*         mov     di, XPos *)
                /$89/$FB  (*         mov     bx, di *)
                /$D1/$EF  (*         shr     di, 1 *)
                /$D1/$EF  (*         shr     di, 1 *)
                /$01/$C7  (*         add     di, ax                  { DI = (YPos * 80) + XPos / 4 } *)
        /$03/$3E/PageOffset  (*         add     di, PageOffset *)

            /$C5/$76/$06  (*         lds     si, BitMap              { Point to bitmap } *)

            /$80/$E3/$03  (*         and     bl, 3 *)
                /$88/$D9  (*         mov     cl, bl *)
                /$B4/$01  (*         mov     ah, 1 *)
                /$D2/$E4  (*         shl     ah, cl *)
            /$80/$EB/$04  (*         sub     bl, 4 *)
            /$B9/$04/$00  (*         mov     cx, 4                   { 4 planes } *)

(*   @Plane: *)
                    /$53  (*         push    bx *)
                    /$51  (*         push    cx                      { Planes to go } *)
                    /$50  (*         push    ax                      { Mask in AH } *)

                /$B0/$02  (*         mov     al, MAP_MASK *)
            /$BA/$C4/$03  (*         mov     dx, SC_INDEX *)
                    /$EF  (*         out     dx, ax *)

                    /$FC  (*         cld *)
                    /$57  (*         push    di *)
            /$8B/$5E/$10  (*         mov     bx, Width *)
                /$D1/$EB  (*         shr     bx, 1 *)
                /$D1/$EB  (*         shr     bx, 1 *)
            /$B8/$5A/$00  (*         mov     ax, BYTES_PER_LINE *)
                /$29/$D8  (*         sub     ax, bx                  { Space before next line } *)

                /$31/$D2  (*         xor     dx, dx *)
(*   @Line: *)
            /$3B/$56/$0C  (*         cmp     dx, Y1 *)
                /$7C/$31  (*         jl      @EndLine *)
            /$3B/$56/$0A  (*         cmp     dx, Y2 *)
                /$7F/$2C  (*         jg      @EndLine *)

                /$89/$D9  (*         mov     cx, bx *)
                /$D1/$E9  (*         shr     cx, 1 *)

                    /$50  (*         push    ax *)
                    /$9C  (*         pushf *)

(*   @Pixel: *)
                    /$AD  (*         lodsw *)
                /$08/$C0  (*         or      al, al *)
                /$74/$03  (*         jz      @Skip1 *)
                    /$26  (*         seges *)
                /$88/$05  (*         mov     [di], al *)
(*   @Skip1: *)
                    /$47  (*         inc     di *)
                /$08/$E4  (*         or      ah, ah *)
                /$74/$03  (*         jz      @Skip2 *)
                    /$26  (*         seges *)
                /$88/$25  (*         mov     [di], ah *)
(*   @Skip2: *)
                    /$47  (*         inc     di *)
                /$E2/$ED  (*         loop    @Pixel *)

                    /$9D  (*         popf *)
                /$D1/$D1  (*         rcl     cx, 1 *)
                /$E3/$09  (*         jcxz    @Skip3 *)

                    /$AC  (*         lodsb *)
                /$08/$C0  (*         or      al, al *)
                /$74/$03  (*         jz      @Odd *)
                    /$AA  (*         stosb *)
                /$EB/$01  (*         jmp     @Skip3 *)
                    /$47  (*   @Odd: inc     di *)
(*   @Skip3: *)
                    /$58  (*         pop     ax *)
                /$01/$C7  (*         add     di, ax *)
                /$EB/$05  (*         jmp     @1 *)

(*   @EndLine: *)
                /$01/$DE  (*         add     si, bx *)
            /$83/$C7/$5A  (*         add     di, BYTES_PER_LINE *)

                    /$42  (*   @1:   inc     dx *)
            /$3B/$56/$0E  (*         cmp     dx, Height *)
                /$72/$BF  (*         jb      @Line *)

                    /$5F  (*         pop     di *)

                    /$58  (*         pop     ax *)
                /$88/$E0  (*         mov     al, ah *)
                /$B1/$04  (*         mov     cl, 4 *)
                /$D2/$E0  (*         shl     al, cl *)
                /$08/$C4  (*         or      ah, al                  { Mask for next byte } *)
                /$D0/$C4  (*         rol     ah, 1                   { Bit mask for next plane } *)
                    /$59  (*         pop     cx                      { Planes } *)
                    /$5B  (*         pop     bx *)
                /$FE/$C3  (*         inc     bl                      { Still in the same byte? } *)
            /$83/$D7/$00  (*         adc     di, 0 *)
                /$E2/$91  (*         loop    @Plane *)

(*   @End: *)
                    /$1F  (*         pop     ds *)
);
  end;

  procedure UpSideDown (XPos, YPos, Width, Height: Integer; var BitMap);
    { Draw an image on the screen up-side-down (NULL-bytes are ignored) }
  begin
inline(
                     $1E  (*         push    ds *)

            /$B8/$00/$A0  (*         mov     ax, VGA_SEGMENT *)
                /$8E/$C0  (*         mov     es, ax *)

            /$8B/$46/$0E  (*         mov     ax, YPos *)
            /$3D/$B6/$00  (*         cmp     ax, VIR_SCREEN_HEIGHT *)
                /$72/$0F  (*         jb      @NotNeg *)
    /$7E/$03/$E9/$90/$00  (*         jg      @End *)
                /$89/$C3  (*         mov     bx, ax *)
            /$03/$5E/$0A  (*         add     bx, Height *)
    /$72/$03/$E9/$86/$00  (*         jnc     @End *)
(*   @NotNeg: *)
            /$03/$46/$0A  (*         add     ax, Height *)
                    /$48  (*         dec     ax *)
            /$BB/$5A/$00  (*         mov     bx, BYTES_PER_LINE *)
                /$F7/$E3  (*         mul     bx *)
            /$8B/$7E/$10  (*         mov     di, XPos *)
                /$89/$FB  (*         mov     bx, di *)
                /$D1/$EF  (*         shr     di, 1 *)
                /$D1/$EF  (*         shr     di, 1 *)
                /$01/$C7  (*         add     di, ax                  { DI = (YPos * 80) + XPos / 4 } *)
        /$03/$3E/PageOffset  (*         add     di, PageOffset *)

            /$C5/$76/$06  (*         lds     si, BitMap              { Point to bitmap } *)

            /$80/$E3/$03  (*         and     bl, 3 *)
                /$88/$D9  (*         mov     cl, bl *)
                /$B4/$01  (*         mov     ah, 1 *)
                /$D2/$E4  (*         shl     ah, cl *)
            /$80/$EB/$04  (*         sub     bl, 4 *)
            /$B9/$04/$00  (*         mov     cx, 4                   { 4 planes } *)

(*   @Plane: *)
                    /$53  (*         push    bx *)
                    /$51  (*         push    cx                      { Planes to go } *)
                    /$50  (*         push    ax                      { Mask in AH } *)

                /$B0/$02  (*         mov     al, MAP_MASK *)
            /$BA/$C4/$03  (*         mov     dx, SC_INDEX *)
                    /$EF  (*         out     dx, ax *)

                    /$FC  (*         cld *)
                    /$57  (*         push    di *)
            /$8B/$5E/$0C  (*         mov     bx, Width *)
                /$D1/$EB  (*         shr     bx, 1 *)
                /$D1/$EB  (*         shr     bx, 1 *)
            /$B8/$5A/$00  (*         mov     ax, BYTES_PER_LINE *)
                /$01/$D8  (*         add     ax, bx                  { Space before next line } *)
            /$8B/$56/$0A  (*         mov     dx, Height *)
(*   @Line: *)
                /$89/$D9  (*         mov     cx, bx *)
                /$D1/$E9  (*         shr     cx, 1 *)

                    /$50  (*         push    ax *)
                    /$9C  (*         pushf *)

(*   @Pixel: *)
                    /$AD  (*         lodsw *)
                /$08/$C0  (*         or      al, al *)
                /$74/$03  (*         jz      @Skip1 *)
                    /$26  (*         seges *)
                /$88/$05  (*         mov     [di], al *)
(*   @Skip1: *)
                    /$47  (*         inc     di *)
                /$08/$E4  (*         or      ah, ah *)
                /$74/$03  (*         jz      @Skip2 *)
                    /$26  (*         seges *)
                /$88/$25  (*         mov     [di], ah *)
(*   @Skip2: *)
                    /$47  (*         inc     di *)
                /$E2/$ED  (*         loop    @Pixel *)

                    /$9D  (*         popf *)
                /$D1/$D1  (*         rcl     cx, 1 *)
                /$E3/$09  (*         jcxz    @Skip3 *)

                    /$AC  (*         lodsb *)
                /$08/$C0  (*         or      al, al *)
                /$74/$03  (*         jz      @Odd *)
                    /$AA  (*         stosb *)
                /$EB/$01  (*         jmp     @Skip3 *)
                    /$47  (*   @Odd: inc     di *)
(*   @Skip3: *)
                    /$58  (*         pop     ax *)
                /$29/$C7  (*         sub     di, ax *)
                    /$4A  (*         dec     dx *)
                /$75/$D3  (*         jnz     @Line *)

                    /$5F  (*         pop     di *)

                    /$58  (*         pop     ax *)
                /$88/$E0  (*         mov     al, ah *)
                /$B1/$04  (*         mov     cl, 4 *)
                /$D2/$E0  (*         shl     al, cl *)
                /$08/$C4  (*         or      ah, al                  { Mask for next byte } *)
                /$D0/$C4  (*         rol     ah, 1                   { Bit mask for next plane } *)
                    /$59  (*         pop     cx                      { Planes } *)
                    /$5B  (*         pop     bx *)
                /$FE/$C3  (*         inc     bl                      { Still in the same byte? } *)
            /$83/$D7/$00  (*         adc     di, 0 *)
                /$E2/$A4  (*         loop    @Plane *)
(*   @End: *)
                    /$1F  (*         pop     ds *)
);
  end;

  procedure PutImage (XPos, YPos, Width, Height: Integer; var BitMap);
    { Draw an image on the screen (NULL-bytes are NOT ignored) }
  begin
inline(
                     $1E  (*         push    ds *)
                    /$06  (*         push    es *)
            /$B8/$00/$A0  (*         mov     ax, VGA_SEGMENT *)
                /$8E/$C0  (*         mov     es, ax *)

            /$8B/$46/$0E  (*         mov     ax, YPos *)
            /$BB/$5A/$00  (*         mov     bx, BYTES_PER_LINE *)
                /$F7/$E3  (*         mul     bx *)
            /$8B/$7E/$10  (*         mov     di, XPos *)
                /$89/$FB  (*         mov     bx, di *)
                /$D1/$EF  (*         shr     di, 1 *)
                /$D1/$EF  (*         shr     di, 1 *)
                /$01/$C7  (*         add     di, ax                  { DI = (YPos * 80) + XPos / 4 } *)
        /$03/$3E/PageOffset  (*         add     di, PageOffset *)

            /$C5/$76/$06  (*         lds     si, BitMap              { Point to bitmap } *)

            /$80/$E3/$03  (*         and     bl, 3 *)
                /$88/$D9  (*         mov     cl, bl *)
                /$B4/$01  (*         mov     ah, 1 *)
                /$D2/$E4  (*         shl     ah, cl *)
            /$80/$EB/$04  (*         sub     bl, 4 *)
            /$B9/$04/$00  (*         mov     cx, 4                   { 4 planes } *)

(*   @Plane: *)
                    /$53  (*         push    bx *)
                    /$51  (*         push    cx                      { Planes to go } *)
                    /$50  (*         push    ax                      { Mask in AH } *)

                /$B0/$02  (*         mov     al, MAP_MASK *)
            /$BA/$C4/$03  (*         mov     dx, SC_INDEX *)
                    /$EF  (*         out     dx, ax *)

                    /$FC  (*         cld *)
                    /$57  (*         push    di *)
            /$8B/$5E/$0C  (*         mov     bx, Width *)
                /$D1/$EB  (*         shr     bx, 1 *)
                /$D1/$EB  (*         shr     bx, 1 *)
            /$B8/$5A/$00  (*         mov     ax, BYTES_PER_LINE *)
                /$29/$D8  (*         sub     ax, bx                  { Space before next line } *)
            /$8B/$56/$0A  (*         mov     dx, Height *)
(*   @Line: *)
                /$89/$D9  (*         mov     cx, bx *)
                /$D1/$E9  (*         shr     cx, 1 *)
                /$F3/$A5  (*         rep     movsw *)
                /$D1/$D1  (*         rcl     cx, 1 *)
                /$F3/$A4  (*         rep     movsb *)
                /$01/$C7  (*         add     di, ax *)
                    /$4A  (*         dec     dx *)
                /$75/$F1  (*         jnz     @Line *)

                    /$5F  (*         pop     di *)

                    /$58  (*         pop     ax *)
                /$88/$E0  (*         mov     al, ah *)
                /$B1/$04  (*         mov     cl, 4 *)
                /$D2/$E0  (*         shl     al, cl *)
                /$08/$C4  (*         or      ah, al                  { Mask for next byte } *)
                /$D0/$C4  (*         rol     ah, 1                   { Bit mask for next plane } *)
                    /$59  (*         pop     cx                      { Planes } *)
                    /$5B  (*         pop     bx *)
                /$FE/$C3  (*         inc     bl                      { Still in the same byte? } *)
            /$83/$D7/$00  (*         adc     di, 0 *)
                /$E2/$C2  (*         loop    @Plane *)


                    /$07  (*         pop     es *)
                    /$1F  (*         pop     ds *)
);
  end;


  procedure GetImage (XPos, YPos, Width, Height: Integer; var BitMap);
  begin
inline(
                     $1E  (*         push    ds *)
                    /$06  (*         push    es *)

        /$8B/$0E/PageOffset  (*         mov     cx, PageOffset *)

            /$B8/$00/$A0  (*         mov     ax, VGA_SEGMENT *)
                /$8E/$D8  (*         mov     ds, ax *)

            /$8B/$46/$0E  (*         mov     ax, YPos *)
            /$BB/$5A/$00  (*         mov     bx, BYTES_PER_LINE *)
                /$F7/$E3  (*         mul     bx *)
            /$8B/$76/$10  (*         mov     si, XPos *)
                /$89/$F3  (*         mov     bx, si *)
                /$D1/$EE  (*         shr     si, 1 *)
                /$D1/$EE  (*         shr     si, 1 *)
                /$01/$C6  (*         add     si, ax                  { SI = (YPos * 80) + XPos / 4 } *)
                /$01/$CE  (*         add     si, cx *)

            /$C4/$7E/$06  (*         les     di, BitMap              { Point to bitmap } *)

            /$80/$E3/$03  (*         and     bl, 3 *)
            /$80/$EB/$04  (*         sub     bl, 4 *)
            /$B9/$04/$00  (*         mov     cx, 4                   { 4 planes } *)

(*   @Plane: *)
                    /$53  (*         push    bx *)
                    /$51  (*         push    cx                      { Planes to go } *)

                /$88/$DC  (*         mov     ah, bl *)
            /$80/$E4/$03  (*         and     ah, 3 *)
                /$B0/$04  (*         mov     al, READ_MAP *)
            /$BA/$CE/$03  (*         mov     dx, GC_INDEX *)
                    /$EF  (*         out     dx, ax *)

                    /$FC  (*         cld *)
                    /$56  (*         push    si *)
            /$8B/$5E/$0C  (*         mov     bx, Width *)
                /$D1/$EB  (*         shr     bx, 1 *)
                /$D1/$EB  (*         shr     bx, 1 *)
            /$B8/$5A/$00  (*         mov     ax, BYTES_PER_LINE *)
                /$29/$D8  (*         sub     ax, bx                  { Space before next line } *)
            /$8B/$56/$0A  (*         mov     dx, Height *)
(*   @Line: *)
                /$89/$D9  (*         mov     cx, bx *)
                /$D1/$E9  (*         shr     cx, 1 *)
                /$F3/$A5  (*         rep     movsw *)
                /$D1/$D1  (*         rcl     cx, 1 *)
                /$F3/$A4  (*         rep     movsb *)
                /$01/$C6  (*         add     si, ax *)
                    /$4A  (*         dec     dx *)
                /$75/$F1  (*         jnz     @Line *)

                    /$5E  (*         pop     si *)

                    /$59  (*         pop     cx                      { Planes } *)
                    /$5B  (*         pop     bx *)
                /$FE/$C3  (*         inc     bl                      { Still in the same byte? } *)
            /$83/$D6/$00  (*         adc     si, 0 *)
                /$E2/$C9  (*         loop    @Plane *)


                    /$07  (*         pop     es *)
                    /$1F  (*         pop     ds *)
);
  end;

  procedure Fill (X, Y, W, H: Integer; Attr: Integer);
    { Fills an area on the screen with Attr }
  begin
inline(
             $B8/$00/$A0  (*         mov     ax, VGA_SEGMENT *)
                /$8E/$C0  (*         mov     es, ax *)

                    /$FC  (*         cld *)
            /$8B/$56/$0C  (*         mov     dx, Y *)
            /$B8/$5A/$00  (*         mov     ax, BYTES_PER_LINE *)
                /$F7/$E2  (*         mul     dx *)
            /$8B/$7E/$0E  (*         mov     di, X *)
                    /$57  (*         push    di *)
                /$D1/$EF  (*         shr     di, 1 *)
                /$D1/$EF  (*         shr     di, 1 *)
                /$01/$C7  (*         add     di, ax                  { DI = Y * (width / 4) + X / 4 } *)
        /$03/$3E/PageOffset  (*         add     di, PageOffset *)
                    /$59  (*         pop     cx *)
        /$81/$E1/$03/$00  (*         and     cx, 3                   { CX = X mod 4 } *)

                /$B4/$0F  (*         mov     ah, 0Fh *)
                /$D2/$E4  (*         shl     ah, cl *)
            /$80/$E4/$0F  (*         and     ah, 0Fh *)

            /$8B/$76/$08  (*         mov     si, H *)
                /$09/$F6  (*         or      si, si *)
                /$74/$79  (*         jz      @End                    { Height 0 } *)
            /$8A/$7E/$06  (*         mov     bh, byte ptr Attr *)
            /$8B/$56/$0A  (*         mov     dx, W *)
                /$09/$D2  (*         or      dx, dx *)
                /$74/$6F  (*         jz      @End                    { Width 0 } *)
                /$01/$D1  (*         add     cx, dx *)
            /$BA/$C4/$03  (*         mov     dx, SC_INDEX *)
                /$B0/$02  (*         mov     al, MAP_MASK *)
            /$83/$E9/$04  (*         sub     cx, 4 *)
                /$72/$45  (*         jc      @2 *)
            /$F6/$C1/$03  (*         test    cl, 3h *)
                /$75/$03  (*         jnz     @0 *)
            /$83/$E9/$04  (*         sub     cx, 4 *)
                /$72/$3B  (*   @0:   jc      @2 *)
                    /$EF  (*         out     dx, ax *)

                /$88/$F8  (*         mov     al, bh                  { Attr } *)
                    /$56  (*         push    si                      { Height } *)
                    /$57  (*         push    di *)
                    /$AA  (*   @4:   stosb                           { Left vertical line } *)
            /$83/$C7/$59  (*         add     di, BYTES_PER_LINE - 1 *)
                    /$4E  (*         dec     si *)
                /$75/$F9  (*         jnz     @4 *)
                    /$5F  (*         pop     di *)
                    /$47  (*         inc     di *)
                    /$5E  (*         pop     si *)

                    /$50  (*         push    ax *)
            /$B8/$02/$0F  (*         mov     ax, 0F00h + MAP_MASK *)
                    /$EF  (*         out     dx, ax *)
                    /$58  (*         pop     ax *)

                /$88/$C4  (*         mov     ah, al                  { Attr } *)
                    /$51  (*         push    cx                      { Width } *)
                /$D1/$E9  (*         shr     cx, 1 *)
                /$D1/$E9  (*         shr     cx, 1 *)

                    /$56  (*         push    si                      { Height } *)
                    /$57  (*         push    di *)
                    /$57  (*   @5:   push    di *)
                    /$51  (*         push    cx *)
                /$D1/$E9  (*         shr     cx, 1 *)
                /$F3/$AB  (*         rep     stosw                   { Fill middle part } *)
                /$D1/$D1  (*         rcl     cx, 1 *)
                /$F3/$AA  (*         rep     stosb *)
                    /$59  (*         pop     cx *)
                    /$5F  (*         pop     di *)
            /$83/$C7/$5A  (*         add     di, BYTES_PER_LINE *)
                    /$4E  (*         dec     si *)
                /$75/$EE  (*         jnz     @5 *)
                    /$5F  (*         pop     di *)
                /$01/$CF  (*         add     di, cx                  { Point to last strip } *)
                    /$5E  (*         pop     si                      { Height } *)

                    /$59  (*         pop     cx                      { Width } *)
                /$88/$C7  (*         mov     bh, al                  { Attr } *)
                /$B3/$0F  (*         mov     bl, 0Fh                 { Mask } *)
                /$EB/$02  (*         jmp     @3 *)

                /$88/$E3  (*   @2:   mov     bl, ah                  { Begin and end in one single byte } *)

            /$80/$E1/$03  (*   @3:   and     cl, 3 *)
                /$B4/$00  (*         mov     ah, 0 *)
                /$D0/$E4  (*   @1:   shl     ah, 1 *)
            /$80/$C4/$01  (*         add     ah, 1 *)
                /$FE/$C9  (*         dec     cl *)
                /$75/$F7  (*         jnz     @1 *)

                /$20/$DC  (*         and     ah, bl                  { Use both masks } *)
                /$B0/$02  (*         mov     al, MAP_MASK *)
                    /$EF  (*         out     dx, ax *)
                /$88/$F8  (*         mov     al, bh                  { Attr } *)
                    /$AA  (*   @6:   stosb                           { Draw right vertical line } *)
            /$83/$C7/$59  (*         add     di, BYTES_PER_LINE - 1 *)
                    /$4E  (*         dec     si *)
                /$75/$F9  (*         jnz     @6 *)
(*   @End: *)
);
  end;

  procedure SetPalette (Color, Red, Green, Blue: Byte);
  begin
inline(
             $BA/$C8/$03  (*           mov     dx, 03C8h       { DAC Write Address Register } *)
            /$8A/$46/$0C  (*           mov     al, Color *)
                    /$EE  (*           out     dx, al *)
                    /$42  (*           inc     dx *)
            /$8A/$46/$0A  (*           mov     al, Red *)
                    /$EE  (*           out     dx, al *)
            /$8A/$46/$08  (*           mov     al, Green *)
                    /$EE  (*           out     dx, al *)
            /$8A/$46/$06  (*           mov     al, Blue *)
                    /$EE  (*           out     dx, al *)
);
  end;

  procedure ReadPalette (var NewPalette);
    { Read whole palette }
  begin
inline(
                     $1E  (*         push    ds *)
            /$C5/$76/$06  (*         lds     si, NewPalette *)
            /$BA/$C8/$03  (*         mov     dx, 3C8h        { VGA pel address } *)
                /$B0/$00  (*         mov     al, 0 *)
                    /$FA  (*         cli *)
                    /$FC  (*         cld *)
                    /$EE  (*         out     dx, al *)
                    /$42  (*         inc     dx *)
            /$B9/$00/$03  (*         mov     cx, 3 * 100h *)
                    /$AC  (*   @1:   lodsb *)
                    /$EE  (*         out     dx, al *)
                    /$49  (*         dec     cx *)
                /$75/$FB  (*         jnz     @1 *)
                    /$FB  (*         sti *)
                    /$1F  (*         pop     ds *)

(* {          push    es *)
(*           push    bp *)
(*           mov     ax, 1012h *)
(*           xor     bx, bx *)
(*           mov     cx, 256 *)
(*           les     dx, NewPalette *)
(*           int     10h *)
(*           pop     bp *)
(*           pop     es   } *)
);
  end;

  procedure ClearPalette;
  begin
inline(
                     $FA  (*         cli *)
            /$BA/$C8/$03  (*         mov     dx, 3C8h        { VGA pel address } *)
                /$B0/$00  (*         mov     al, 0 *)
                    /$EE  (*         out     dx, al *)
                    /$42  (*         inc     dx *)
            /$B9/$00/$03  (*         mov     cx, 3 * 100h *)
                    /$EE  (*   @1:   out     dx, al *)
                    /$49  (*         dec     cx *)
                /$75/$FC  (*         jnz     @1 *)
                    /$FB  (*         sti *)
);
  end;


  function CurrentPage: Integer;
  begin
    CurrentPage := Page;
  end;

  function GetPageOffset: Word;
  begin
    GetPageOffset := PageOffset;
  end;

  procedure ResetStack;
  begin
    Stack[0] := PAGE_0 + PAGE_SIZE + SAFE;
    Stack[1] := PAGE_1 + PAGE_SIZE + SAFE;
  end;

  function PushBackGr (X, Y, W, H: Integer): Word;
    { Save background (X mod 4 = 0, W mod 4 = 0) }
    var
      StackPointer: Word;
  begin
    PushBackGr := 0;
    if not ((Y + H >= 0) and (Y < 200)) then
      Exit;
    StackPointer := Stack [Page];
inline(
         $8B/$1E/PageOffset  (*         mov     bx, PageOffset *)
            /$8B/$7E/$FC  (*         mov     di, StackPointer *)
                    /$1E  (*         push    ds *)
                    /$06  (*         push    es *)

            /$B8/$00/$A0  (*         mov     ax, VGA_SEGMENT *)
                /$8E/$D8  (*         mov     ds, ax *)
                /$8E/$C0  (*         mov     es, ax *)

                    /$FC  (*         cld *)
            /$BA/$C4/$03  (*         mov     dx, SC_INDEX *)
            /$B8/$02/$01  (*         mov     ax, 0100h + MAP_MASK *)
                    /$EF  (*         out     dx, ax *)
            /$8B/$46/$0C  (*         mov     ax, X *)
                /$89/$05  (*         mov     [di], ax *)
            /$B8/$02/$02  (*         mov     ax, 0200h + MAP_MASK *)
                    /$EF  (*         out     dx, ax *)
            /$8B/$46/$0A  (*         mov     ax, Y *)
                /$89/$05  (*         mov     [di], ax *)
            /$B8/$02/$04  (*         mov     ax, 0400h + MAP_MASK *)
                    /$EF  (*         out     dx, ax *)
            /$8B/$46/$08  (*         mov     ax, W *)
                /$89/$05  (*         mov     [di], ax *)
            /$B8/$02/$08  (*         mov     ax, 0800h + MAP_MASK *)
                    /$EF  (*         out     dx, ax *)
            /$8B/$46/$06  (*         mov     ax, H *)
                    /$AB  (*         stosw *)
                /$B0/$4D  (*         mov     al, 'M' *)
                    /$AA  (*         stosb *)

            /$BA/$CE/$03  (*         mov     dx, GC_INDEX *)
                /$B0/$05  (*         mov     al, GRAPHICS_MODE *)
                    /$EE  (*         out     dx, al *)
                    /$42  (*         inc     dx *)
                    /$EC  (*         in      al, dx *)
                    /$50  (*         push    ax *)
                /$B0/$41  (*         mov     al, 41h *)
                    /$EE  (*         out     dx, al *)

            /$BA/$C4/$03  (*         mov     dx, SC_INDEX *)
            /$B8/$02/$0F  (*         mov     ax, 0F00h + MAP_MASK *)
                    /$EF  (*         out     dx, ax *)

            /$B8/$04/$00  (*         mov     ax, READ_MAP *)
            /$BA/$CE/$03  (*         mov     dx, GC_INDEX *)
                    /$EF  (*         out     dx, ax *)

            /$8B/$56/$0A  (*         mov     dx, Y *)
            /$B8/$5A/$00  (*         mov     ax, BYTES_PER_LINE *)
                /$F7/$E2  (*         mul     dx *)
            /$8B/$76/$0C  (*         mov     si, X *)
                /$D1/$EE  (*         shr     si, 1 *)
                /$D1/$EE  (*         shr     si, 1 *)
                /$01/$C6  (*         add     si, ax *)
                /$01/$DE  (*         add     si, bx *)

            /$8B/$4E/$08  (*         mov     cx, W *)
                /$D1/$E9  (*         shr     cx, 1 *)
                /$D1/$E9  (*         shr     cx, 1 *)

            /$8B/$5E/$06  (*         mov     bx, H *)

                    /$51  (*   @1:   push    cx *)
                    /$F3  (*         rep *)
                    /$A4  (*         movsb                   { copy 4 pixels } *)
                    /$59  (*         pop     cx *)
            /$83/$C6/$5A  (*         add     si, BYTES_PER_LINE *)
                /$29/$CE  (*         sub     si, cx *)
                    /$4B  (*         dec     bx *)
                /$75/$F4  (*         jnz     @1 *)

            /$BA/$CE/$03  (*         mov     dx, GC_INDEX *)
                    /$58  (*         pop     ax *)
                /$88/$C4  (*         mov     ah, al *)
                /$B0/$05  (*         mov     al, GRAPHICS_MODE *)
                    /$EF  (*         out     dx, ax *)

                    /$07  (*         pop     es *)
                    /$1F  (*         pop     ds *)
);
    PushBackGr := Stack [Page];
    Inc (Stack [Page], W * H + 8);
  end;

  procedure PopBackGr (Address: Word);
    var
      X, Y, W, H: Integer;
  begin
    if Address = 0 then
      Exit;
inline(
         $8B/$1E/PageOffset  (*         mov     bx, PageOffset *)
            /$8B/$76/$06  (*         mov     si, Address *)

                    /$1E  (*         push    ds *)
                    /$06  (*         push    es *)

            /$B8/$00/$A0  (*         mov     ax, VGA_SEGMENT *)
                /$8E/$D8  (*         mov     ds, ax *)
                /$8E/$C0  (*         mov     es, ax *)

                    /$FC  (*         cld *)
            /$BA/$CE/$03  (*         mov     dx, GC_INDEX *)
            /$B8/$04/$00  (*         mov     ax, 0000h + READ_MAP *)
                    /$EF  (*         out     dx, ax *)
                /$8B/$04  (*         mov     ax, [si] *)
            /$89/$46/$FE  (*         mov     X, ax *)
            /$B8/$04/$01  (*         mov     ax, 0100h + READ_MAP *)
                    /$EF  (*         out     dx, ax *)
                /$8B/$04  (*         mov     ax, [si] *)
            /$89/$46/$FC  (*         mov     Y, ax *)
            /$B8/$04/$02  (*         mov     ax, 0200h + READ_MAP *)
                    /$EF  (*         out     dx, ax *)
                /$8B/$04  (*         mov     ax, [si] *)
            /$89/$46/$FA  (*         mov     W, ax *)
            /$B8/$04/$03  (*         mov     ax, 0300h + READ_MAP *)
                    /$EF  (*         out     dx, ax *)
                    /$AD  (*         lodsw *)
            /$89/$46/$F8  (*         mov     H, ax *)
                    /$AC  (*         lodsb *)
                /$3C/$4D  (*         cmp     al, 'M' *)
                /$74/$03  (*         jz      @@1 *)
(* {$IFDEF DEBUG} *)
                    /$CC  (*         int     3 *)
(* {$ENDIF} *)
                /$EB/$4C  (*         jmp     @End *)
(*     @@1: *)
            /$BA/$CE/$03  (*         mov     dx, GC_INDEX *)
                /$B0/$05  (*         mov     al, GRAPHICS_MODE *)
                    /$EE  (*         out     dx, al *)
                    /$42  (*         inc     dx *)
                    /$EC  (*         in      al, dx *)
                    /$50  (*         push    ax *)
                /$B0/$41  (*         mov     al, 41h *)
                    /$EE  (*         out     dx, al *)

            /$BA/$C4/$03  (*         mov     dx, SC_INDEX *)
            /$B8/$02/$0F  (*         mov     ax, 0F00h + MAP_MASK *)
                    /$EF  (*         out     dx, ax *)

            /$B8/$04/$00  (*         mov     ax, READ_MAP *)
            /$BA/$CE/$03  (*         mov     dx, GC_INDEX *)
                    /$EF  (*         out     dx, ax *)

            /$8B/$56/$FC  (*         mov     dx, Y *)
            /$B8/$5A/$00  (*         mov     ax, BYTES_PER_LINE *)
                /$F7/$E2  (*         mul     dx *)
            /$8B/$7E/$FE  (*         mov     di, X *)
                /$D1/$EF  (*         shr     di, 1 *)
                /$D1/$EF  (*         shr     di, 1 *)
                /$01/$C7  (*         add     di, ax *)
                /$01/$DF  (*         add     di, bx *)

            /$8B/$4E/$FA  (*         mov     cx, W *)
                /$D1/$E9  (*         shr     cx, 1 *)
                /$D1/$E9  (*         shr     cx, 1 *)

            /$8B/$5E/$F8  (*         mov     bx, H *)

                    /$51  (*   @1:   push    cx *)
                    /$F3  (*         rep *)
                    /$A4  (*         movsb                   { copy 4 pixels } *)
                    /$59  (*         pop     cx *)
            /$83/$C7/$5A  (*         add     di, BYTES_PER_LINE *)
                /$29/$CF  (*         sub     di, cx *)
                    /$4B  (*         dec     bx *)
                /$75/$F4  (*         jnz     @1 *)

            /$BA/$CE/$03  (*         mov     dx, GC_INDEX *)
                    /$58  (*         pop     ax *)
                /$88/$C4  (*         mov     ah, al *)
                /$B0/$05  (*         mov     al, GRAPHICS_MODE *)
                    /$EF  (*         out     dx, ax *)

                    /$07  (*   @end: pop     es *)
                    /$1F  (*         pop     ds *)
);
  end;

  procedure DrawBitmap (X, Y: Integer; var BitMap; Attr: Byte);
    { Bitmap starts with size W, H (Byte) }
  var
    W, H, PageOffset: Integer;
  begin
    PageOffset := GetPageOffset;
inline(
                     $06  (*         push    es *)
                    /$1E  (*         push    ds *)

            /$C5/$76/$08  (*         lds     si, BitMap *)
                /$B4/$00  (*         mov     ah, 0 *)
                    /$FC  (*         cld *)
                    /$AC  (*         lodsb *)
            /$89/$46/$FE  (*         mov     W, ax *)
                    /$AC  (*         lodsb *)
            /$89/$46/$FC  (*         mov     H, ax *)
            /$B8/$00/$A0  (*         mov     ax, VGA_SEGMENT *)
                /$8E/$C0  (*         mov     es, ax *)

                /$B3/$00  (*         mov     bl, 0 *)
            /$8B/$4E/$FC  (*         mov     cx, H *)
            /$8B/$56/$0C  (*         mov     dx, Y *)
                    /$51  (*     @1: push    cx *)
            /$8B/$4E/$0E  (*         mov     cx, X *)
            /$8B/$7E/$FE  (*         mov     di, W *)
                    /$51  (*     @2: push    cx *)
                    /$52  (*         push    dx *)
                /$08/$DB  (*         or      bl, bl *)
                /$75/$05  (*         jnz     @3 *)
                    /$AC  (*         lodsb *)
                /$88/$C7  (*         mov     bh, al *)
                /$B3/$08  (*         mov     bl, 8 *)
                /$FE/$CB  (*     @3: dec     bl *)
                /$D0/$EF  (*         shr     bh, 1 *)
                /$73/$2B  (*         jnc     @4 *)

                    /$56  (*         push    si *)
                    /$57  (*         push    di *)
                    /$53  (*         push    bx *)
            /$8A/$46/$06  (*         mov     al, Attr *)

(*     @PutPixel: *)
(*       { CX = X, DX = Y, AL = Attr } *)
                    /$50  (*         push    ax *)
            /$B8/$5A/$00  (*         mov     ax, BYTES_PER_LINE *)
                /$F7/$E2  (*         mul     dx *)
                    /$51  (*         push    cx *)
                /$D1/$E9  (*         shr     cx, 1 *)
                /$D1/$E9  (*         shr     cx, 1 *)
                /$01/$C8  (*         add     ax, cx *)
                /$89/$C7  (*         mov     di, ax *)
            /$03/$7E/$FA  (*         add     di, PageOffset *)
                    /$59  (*         pop     cx *)
            /$80/$E1/$03  (*         and     cl, 3 *)
                /$B4/$01  (*         mov     ah, 1 *)
                /$D2/$E4  (*         shl     ah, cl *)
                /$B0/$02  (*         mov     al, MAP_MASK *)
            /$BA/$C4/$03  (*         mov     dx, SC_INDEX *)
                    /$EF  (*         out     dx, ax *)
                    /$58  (*         pop     ax *)
                    /$AA  (*         stosb *)

                    /$5B  (*         pop     bx *)
                    /$5F  (*         pop     di *)
                    /$5E  (*         pop     si *)

(*     @4: *)
                    /$5A  (*         pop     dx *)
                    /$59  (*         pop     cx *)
                    /$41  (*         inc     cx *)
                    /$4F  (*         dec     di *)
                /$75/$BE  (*         jnz     @2 *)

                    /$42  (*         inc     dx *)
                    /$59  (*         pop     cx *)
                    /$49  (*         dec     cx *)
                /$75/$B2  (*         jnz     @1 *)
                    /$1F  (*         pop     ds *)
                    /$07  (*         pop     es *)
);
  end;

begin
  OldScreenMode := GetMode;
end.
