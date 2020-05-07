unit Stars;

interface

  uses
    Buffers,
    VGA256;

  procedure ClearStars;
  procedure InitStars;
  procedure ShowStars;
  procedure HideStars;

implementation

  const
    STAR_SPEED = 10;
    Max = (MaxWorldSize div STAR_SPEED) * W;

  var
    StarMap: array [0 .. 319] of Word;
    LastX: array [0 .. 3] of Integer;
    BlinkCounter: Integer;
    C1, C2: Byte;

  procedure ClearStars;
  begin
    FillChar (StarBackGr^, SizeOf (StarBackGr^), #0);
    FillChar (LastX, SizeOf (LastX), #0);
  end;

  procedure InitStars;
  var
    i: Integer;
  begin
    ClearStars;
    RandSeed := 0;
    for i := 0 to 319 do
      StarMap [i] := ((Random (Options.Horizon) {+ WindowY}) * 320 + i);
    if Options.Stars in [1, 2] then
      for i := 0 to 319 do
        if Random (10) > 2 then StarMap [i] := 0;
    case Options.Stars of
      1: begin
           C1 := 29;
           C2 := 31;
         end;
      2: begin
           C1 := 90;
           C2 := 92;
         end;
    end;
  end;

  procedure ShowStars;
  var
    X: Integer;
    P1,
    P2: Pointer;
  begin
    LastX [CurrentPage] := XView;
    X := (8 * XView) div STAR_SPEED;
    P1 := @StarMap [0];
    P2 := @StarBackGr^ [CurrentPage, 0];
    BlinkCounter := Random (320);
inline(
         $8B/$1E/$00/$00  (*           mov     bx, BlinkCounter *)
                    /$06  (*           push    es *)
                    /$1E  (*           push    ds *)
            /$C5/$76/$FA  (*           lds     si, P1          { StarMap } *)
            /$C4/$7E/$F6  (*           les     di, P2          { StarBackGr } *)
            /$B9/$40/$01  (*           mov     cx, 320 *)
                    /$FC  (*           cld *)

                    /$51  (*     @1:   push    cx *)
                    /$AD  (*           lodsw *)
                /$09/$C0  (*           or      ax, ax *)
                /$74/$30  (*           jz      @2 *)

            /$03/$46/$FE  (*           add     ax, X *)
                    /$06  (*           push    es *)
                    /$57  (*           push    di *)
                /$89/$C7  (*           mov     di, ax *)
            /$B8/$00/$A0  (*           mov     ax, 0A000h *)
                /$8E/$C0  (*           mov     es, ax *)
            /$26/$8A/$15  (*           seges   mov     dl, [di] *)
                /$08/$D2  (*           or      dl, dl *)
                /$74/$18  (*           jz      @3 *)
            /$80/$FA/$F0  (*           cmp     dl, 0F0h *)
                /$74/$05  (*           jz      @6 *)
            /$80/$FA/$A0  (*           cmp     dl, 0A0h *)
                /$73/$04  (*           jae     @5 *)
                /$30/$D2  (*     @6:   xor     dl, dl *)
                /$EB/$0A  (*           jmp     @3 *)
            /$A0/$00/$00  (*     @5:   mov     al, C1 *)
                    /$4B  (*           dec     bx *)
                /$75/$03  (*           jnz     @4 *)
            /$A0/$00/$00  (*           mov     al, C2 *)
                    /$AA  (*     @4:   stosb *)
                    /$5F  (*     @3:   pop     di *)
                    /$07  (*           pop     es *)
                /$88/$D0  (*           mov     al, dl *)
                    /$AA  (*           stosb *)

                    /$59  (*     @2:   pop     cx *)
                    /$49  (*           dec     cx *)
                /$75/$C6  (*           jnz     @1 *)

                    /$1F  (*           pop     ds *)
                    /$07  (*           pop     es *)
);
  end;

  procedure HideStars;
  var
    X: Integer;
    P1,
    P2: Pointer;
  begin
    X := (8 * LastX [CurrentPage]) div STAR_SPEED;
    P1 := @StarMap [0];
    P2 := @StarBackGr^ [CurrentPage, 0];
inline(
                     $06  (*           push    es *)
                    /$1E  (*           push    ds *)
            /$C5/$76/$FA  (*           lds     si, P1          { StarMap } *)
            /$C4/$7E/$F6  (*           les     di, P2          { StarBackGr } *)
            /$B9/$40/$01  (*           mov     cx, 320 *)
                    /$FC  (*           cld *)

                    /$51  (*     @1:   push    cx *)
                    /$AD  (*           lodsw *)
                /$09/$C0  (*           or      ax, ax *)
                /$74/$19  (*           jz      @2 *)
            /$03/$46/$FE  (*           add     ax, X *)
                /$89/$C3  (*           mov     bx, ax *)

            /$26/$8A/$05  (*           seges   mov     al, [di] *)
                    /$47  (*           inc     di *)
                /$08/$C0  (*           or      al, al *)
                /$74/$0C  (*           jz      @2 *)

                    /$06  (*           push    es *)
                    /$57  (*           push    di *)
                /$89/$DF  (*           mov     di, bx *)
            /$BB/$00/$A0  (*           mov     bx, 0A000h *)
                /$8E/$C3  (*           mov     es, bx *)

                    /$AA  (*           stosb *)
                    /$5F  (*           pop     di *)
                    /$07  (*           pop     es *)

                    /$59  (*     @2:   pop     cx *)
                    /$49  (*           dec     cx *)
                /$75/$DD  (*           jnz     @1 *)

                    /$1F  (*           pop     ds *)
                    /$07  (*           pop     es *)
);
  end;

end.
