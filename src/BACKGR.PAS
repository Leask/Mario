unit BackGr;

interface

  uses
    Buffers,
    Vga256,
    Palettes;

  const
    Left = 0;
    Right = 1;
    Shift = 16;

  var
    BackGround: Byte;

  procedure InitBackGr (NewBackGr, bClouds: Byte);
  procedure DrawBackGr (FirstTime: Boolean);
  procedure DrawBackGrMap (Y1, Y2, Shift: Integer; C: Byte);
  procedure StartClouds;
  procedure DrawPalBackGr;
  procedure ReadColorMap;
  procedure DrawBricks (X, Y, W, H: Integer);
  procedure LargeBricks (X, Y, W, H: Integer);
  procedure Pillar (X, Y, W, H: Integer);
  procedure Windows (X, Y, W, H: Integer);
  procedure DrawBackGrBlock (X, Y, W, H: Integer);
  procedure SmoothFill (X, Y, W, H: Integer);


  procedure TraceCloud (X, Y, N: Integer; Dir, Attr, Ovr: Byte);
  procedure PutBackGr (var Map; Fill: Boolean);

implementation

  {$I PALBRICK.$00}
  {$I PALPILL.$00}
  {$I PALPILL.$01}
  {$I PALPILL.$02}

  {$I BOGEN.BK}
  {$I BOGEN7.BK}
  {$I BOGEN26.BK}
  {$I MOUNT.BK}

  const
    Speed = 3;
    BrickSpeed = 2;
    Max = (MaxWorldSize div Speed) * W;
    Height = 26;  { 7, 15, 20, 21, 23, 24, 26 }
    CloudSpeed = 4;
    MaxClouds = 7;
    MinCloudSize = 30;
    MaxCloudSize = 70;
    CloudHeight = 19;

  var
    BackGrMap: array [0 .. Max] of Byte;
    ColorMap: array [0 .. NV * H - 1] of Word;
    CloudMap: array [1 .. 2 * MaxClouds, 0 .. 1] of Integer;
    Clouds: Byte;


  procedure InitClouds;
  var
    i, j, Tmp0, Tmp1: Integer;
  begin
  {
    RandSeed := 18;
    for i := 1 to MaxClouds do
      CloudMap [i, 0] := Random (W * (MaxWorldSize div CloudSpeed) - MaxCloudSize);
    RandSeed := 2;
    for i := 1 to MaxClouds do
      CloudMap [i, 1] := Random (Options.Horizon - Height - CloudHeight);
    for i := 1 to MaxClouds do
      for j := i to MaxClouds do
      if CloudMap [j, 0] < CloudMap [i, 0] then
      begin
        Tmp0 := CloudMap [i, 0];
        Tmp1 := CloudMap [i, 1];
        CloudMap [i] := CloudMap [j];
        CloudMap [j, 0] := Tmp0;
        CloudMap [j, 1] := Tmp1;
      end;
    RandSeed := 6;
    for i := 1 to MaxClouds do
    begin
      CloudMap [i + MaxClouds, 0] := CloudMap [i, 0] + MinCloudSize +
        Random (MaxCloudSize - MinCloudSize);
      CloudMap [i + MaxClouds, 1] := CloudMap [i, 1];
    end;
  }
    CloudMap [1, 0] :=   50; CloudMap [1, 1] :=  58; CloudMap [MaxClouds + 1, 0] :=   92;
    CloudMap [2, 0] :=  180; CloudMap [2, 1] :=  20; CloudMap [MaxClouds + 2, 0] :=  228;
    CloudMap [3, 0] :=  430; CloudMap [3, 1] :=  40; CloudMap [MaxClouds + 3, 0] :=  484;
    CloudMap [4, 0] :=  570; CloudMap [4, 1] :=  15; CloudMap [MaxClouds + 4, 0] :=  600;
    CloudMap [5, 0] :=  840; CloudMap [5, 1] :=  30; CloudMap [MaxClouds + 5, 0] :=  900;
    CloudMap [6, 0] :=  980; CloudMap [6, 1] :=  60; CloudMap [MaxClouds + 6, 0] := 1040;
    CloudMap [7, 0] := 1200; CloudMap [7, 1] :=  20; CloudMap [MaxClouds + 7, 0] := 1240;
  end;

  procedure TraceCloud (X, Y, N: Integer; Dir, Attr, Ovr: Byte);
  var
    Min,
    Max: Integer;
    Ok: Byte;
  begin
inline(
                 $EB/$47  (*           jmp     @Start *)

(*     @PutList:     { SI = Offset, AH = Count } *)
        /$C6/$46/$FB/$00  (*           mov     Ok, 0 *)
                    /$50  (*           push    ax *)
                /$2E/$AD  (*           segcs   lodsw *)
                /$01/$C7  (*           add     di, ax *)
                    /$51  (*           push    cx *)
                    /$57  (*           push    di *)
            /$26/$8A/$05  (*     @@0:  seges   mov     al, [di] *)
                /$38/$D8  (*           cmp     al, bl *)
                /$75/$1B  (*           jnz     @@1 *)
            /$3B/$7E/$FE  (*           cmp     di, Min *)
                /$72/$0E  (*           jb      @@2 *)
            /$3B/$7E/$FC  (*           cmp     di, Max *)
                /$77/$09  (*           ja      @@2 *)
            /$26/$88/$15  (*           seges   mov     [di], dl *)
        /$C6/$46/$FB/$01  (*           mov     Ok, 1 *)
                /$EB/$08  (*           jmp     @@1 *)
        /$80/$7E/$FB/$01  (*     @@2:  cmp     Ok, 1 *)
                /$75/$02  (*           jnz     @@1 *)
                /$EB/$04  (*           jmp     @@3 *)
                    /$47  (*     @@1:  inc     di *)
                    /$49  (*           dec     cx *)
                /$75/$DA  (*           jnz     @@0 *)
                    /$5F  (*     @@3:  pop     di *)
        /$81/$C7/$40/$01  (*           add     di, 320 *)
                    /$59  (*           pop     cx *)
                    /$58  (*           pop     ax *)
    /$81/$46/$FE/$40/$01  (*           add     Min, 320 *)
    /$81/$46/$FC/$40/$01  (*           add     Max, 320 *)
                /$FE/$CC  (*           dec     ah *)
                /$75/$BA  (*           jnz     @PutList *)
                    /$C3  (*           retn *)

(*     @Start: *)
                    /$06  (*           push    es *)
            /$B8/$00/$A0  (*           mov     ax, VGA_SEGMENT *)
                /$8E/$C0  (*           mov     es, ax *)
                    /$FC  (*           cld *)
            /$BB/$40/$01  (*           mov     bx, 320 *)
            /$8B/$46/$0E  (*           mov     ax, Y *)

                /$F7/$E3  (*           mul     bx *)
                    /$50  (*           push    ax *)
        /$03/$06/$00/$00  (*           add     ax, XView *)
            /$89/$46/$FE  (*           mov     Min, ax *)
            /$89/$46/$FC  (*           mov     Max, ax *)
                    /$58  (*           pop     ax *)
    /$81/$46/$FC/$3F/$01  (*           add     Max, 320 - 1 *)
            /$03/$46/$10  (*           add     ax, X *)
                /$89/$C7  (*           mov     di, ax *)
            /$8A/$56/$08  (*           mov     dl, Attr *)

        /$80/$7E/$0A/$01  (*           cmp     Dir, Right *)
                /$74/$39  (*           jz      @Right *)
(*     @Left: *)
            /$E8/$00/$00  (*           call    @GetLeftList *)

/$09/$00/$FD/$FF/$FE/$FF/$FF/$FF/$FF/$FF/$FF/$FF/$00/$00/$FF/$FF/$00/$00/$00/$00/$00/$00/$00/$00/$01/$00
(*           dw      9, -3, -2, -1, -1, -1, 0, -1, 0, 0, 0, 0, 1 *)
/$00/$00/$01/$00/$01/$00/$01/$00/$02/$00/$03/$00  (*           dw      0, 1, 1, 1, 2, 3 *)

(*     @GetLeftList: *)
                    /$5E  (*           pop     si *)
                /$B4/$13  (*           mov     ah, 19 *)
            /$8A/$5E/$06  (*           mov     bl, Ovr *)
            /$8B/$4E/$0C  (*           mov     cx, N *)
                /$E3/$3C  (*           jcxz    @End *)
            /$E8/$00/$00  (*           call    @PutList *)
                /$EB/$37  (*           jmp     @End *)

(*     @Right: *)
            /$E8/$00/$00  (*           call    @GetRightList *)

/$00/$00/$03/$00/$02/$00/$01/$00/$01/$00/$01/$00/$00/$00/$01/$00/$00/$00/$00/$00/$00/$00/$00/$00/$FF/$FF/$00/$00/$FF/$FF
(*           dw      0, 3, 2, 1, 1, 1, 0, 1, 0, 0, 0, 0, -1, 0, -1 *)
/$FF/$FF/$FF/$FF/$FE/$FF/$FD/$FF  (*           dw      -1, -1, -2, -3 *)

(*     @GetRightList: *)
                    /$5E  (*           pop     si *)
                /$B4/$13  (*           mov     ah, 19 *)
            /$8A/$5E/$06  (*           mov     bl, Ovr *)
            /$8B/$4E/$0C  (*           mov     cx, N *)
                /$E3/$03  (*           jcxz    @End *)
            /$E8/$00/$00  (*           call    @PutList *)
(*     @End: *)
                    /$07  (*           pop     es *)
);
  end;

  procedure PutClouds (Offset, N: Integer);
  var
    i, X1, X2, Y: Integer;
    Attr, Ovr, Size, XSize: Byte;
  begin
    if Clouds = 0 then Exit;
    i := 1;
    repeat
      Attr := Clouds;
      Ovr := $E0;
      X1 := XView - Offset + CloudMap [i, 0];
      X2 := XView - Offset + CloudMap [i + MaxClouds, 0];
      XSize := X2 - X1 + 1;
      Y := CloudMap [i, 1];

      if N > 0 then
      begin
        Size := 0;
        if X2 + 10 >= XView + NH * W then Size := 10;
        if (X2 + 10 > XView) and (X2 < XView + NH * W + 10) then
          TraceCloud (X2 - N - Size, Y, N + Size, Right, Attr, Ovr);
        if (X1 + 10 > XView) and (X1 < XView + NH * W) then
        begin
          TraceCloud (X1 - N, Y, N, Left, Ovr, Attr);
          if not (X2 < XView + NH * W) then
            TraceCloud (X1, Y, XSize, Left, Attr, Ovr);
        end;
      end;
      if N < 0 then
      begin
        if (X2 + 10 > XView) and (X2 < XView + NH * W + 10) then
        begin
          TraceCloud (X2, Y, - N, Right, Ovr, Attr);
          if not (X1 > XView - 10) then
            TraceCloud (X2 - XSize, Y, XSize, Right, Attr, Ovr);
        end;
        Size := 0;
        if X1 < XView + 10 then Size := 10;
        if (X1 + 10 > XView) and (X1 < XView + NH * W + 10) then
          TraceCloud (X1, Y, - N + Size, Left, Attr, Ovr);
      end;

      Inc (i);
    until (i > MaxClouds);
  end;

  procedure StartClouds;
  var
    i: Integer;
  begin
    if Clouds = 0 then Exit;
    for i := XView + MaxCloudSize downto XView do
    begin
      XView := i;
      PutClouds (i div CloudSpeed, -CloudSpeed);
    end;
  end;

  procedure InitBackGr (NewBackGr, bClouds: Byte);
  var
    i, j, h: Integer;
    X, Y, Z: Real;
    F: Text;
  begin
    BackGround := NewBackGr;
    case BackGround of
      1, 2:
         begin

  {         RandSeed := 0;
           FillChar (BackGrMap, SizeOf (BackGrMap), 0);
           X := Pi / 4;
           h := 6 + Random (Height - 5);
           for i := 0 to Max do
           begin
             j := Round (Sqrt (H) * Sqrt (Abs (Round (h * Sin (X)))));
             if BackGrMap [i] < j then
               BackGrMap [i] := j;
             if j = 0 then
             begin
               h := 5 + Random (Height - 4);
               Dec (i, 1 + Random (Round (0.5 * Height)));
               if i < 0 then i := 0;
             end;
             X := X + (Pi / (2.75 * h));
           end;

           assign (F, 'BOGEN26');
           rewrite (F);
           write (F, 'A'#24);
           for i := 0 to Max do
             Write (F, chr (BackGrMap[i]));
           close (F); }

           move (A3(@BOGEN^)^, BackGrMap, SizeOf (BackGrMap));
         end;
      3: begin
         {
           RandSeed := $FF;
           FillChar (BackGrMap, SizeOf (BackGrMap), #0);
           j := 0;
           Y := 1/3;
           X := Height / 2;
           for i := 0 to Max do
           begin
             X := X + Y;
             if Y <> 0 then
               if (X + Y >= Height) or (X + Y <= 1) or (Random (100) > 94) then
               begin
                 j := Random (3) + 3;
                 Z := - Y * (10 + Random (1)) / ((10 + Random (1)));
                 Y := 0;
               end;
             if j > 0 then
             begin
               Dec (j);
               if j = 0 then
                 Y := Z;
             end;
             BackGrMap [i] := Round (X);
           end;
         }
           move (A3(@MOUNT^)^, BackGrMap, SizeOf (BackGrMap));
         end;
      9: move (A3(@BOGEN7^)^, BackGrMap, SizeOf (BackGrMap));
     10: move (A3(@BOGEN26^)^, BackGrMap, SizeOf (BackGrMap));


    end;
    if BackGround in [1, 9, 10] then
      for i := 0 to Max do
        BackGrMap [i] := Height - BackGrMap [i] + 1;

    Clouds := bClouds;
    if Clouds <> 0 then
      InitClouds;
  end;

  procedure PutBackGr (var Map; Fill: Boolean);
    var
      Y,
      PageOffset,
      X1, X2, XPos, X1Pos, X2Pos,
      DX,
      OldXView,
      XStart, OldXStart,
      Count: Integer;
      Bank: Byte;

  begin
    PageOffset := GetPageOffset;
    OldXView := LastXView[CurrentPage];
    Y := PageOffset + (Options.Horizon - HEIGHT) * BYTES_PER_LINE;
    X1 := Y + XView div 4;
    X2 := Y + (XView + NH * W) div 4;
    Bank := XView and 3;
    DX := XView - OldXView;
    XPos := XView;
    X1Pos := XView;
    X2Pos := OldXView + NH * W - 1;
    if DX < 0 then
    begin
      X1Pos := OldXView;
      X2Pos := XView + NH * W - 1;
    end;
    XStart := XView div Speed;
    OldXStart := OldXView div Speed + DX;
inline(
                     $1E  (*           push    ds *)
                    /$06  (*           push    es *)
            /$B8/$00/$A0  (*           mov     ax, VGA_SEGMENT *)
                /$8E/$C0  (*           mov     es, ax *)
            /$C5/$76/$08  (*           lds     si, Map *)
                    /$FC  (*           cld *)
    /$C7/$46/$E8/$04/$00  (*           mov     Count, 4 *)
            /$8A/$4E/$E7  (*     @1:   mov     cl, Bank *)
                /$B4/$01  (*           mov     ah, 1 *)
                /$D2/$E4  (*           shl     ah, cl *)
                /$B0/$02  (*           mov     al, MAP_MASK *)
            /$BA/$C4/$03  (*           mov     dx, SC_INDEX *)
                    /$EF  (*           out     dx, ax *)
                /$88/$CC  (*           mov     ah, cl *)
                /$B0/$04  (*           mov     al, READ_MAP *)
            /$BA/$CE/$03  (*           mov     dx, GC_INDEX *)
                    /$EF  (*           out     dx, ax *)
            /$8B/$56/$F6  (*           mov     dx, XPos *)
                /$B0/$F0  (*           mov     al, $F0 *)
            /$8B/$7E/$FA  (*           mov     di, X1 *)
            /$8B/$4E/$EA  (*           mov     cx, OldXStart *)
            /$8B/$5E/$EC  (*           mov     bx, XStart *)
                    /$53  (*     @4:   push    bx *)
                    /$51  (*           push    cx *)
                    /$52  (*           push    dx *)
                    /$57  (*           push    di *)
                /$8A/$20  (*           mov     ah, [bx + si]  { new position } *)
                /$89/$CB  (*           mov     bx, cx *)
                /$8A/$08  (*           mov     cl, [bx + si]  { old position } *)
                /$B5/$00  (*           mov     ch, 0 *)
        /$80/$7E/$06/$00  (*           cmp     Fill, 0 *)
    /$74/$03/$E9/$98/$00  (*           jnz     @Fill *)
            /$3B/$56/$F4  (*           cmp     dx, X1Pos *)
    /$73/$03/$E9/$90/$00  (*           jb      @Fill *)
            /$3B/$56/$F2  (*           cmp     dx, X2Pos *)
    /$76/$03/$E9/$88/$00  (*           ja      @Fill *)
                /$38/$CC  (*           cmp     ah, cl *)
                /$74/$46  (*           jz      @5 *)
                /$7C/$20  (*           jl      @8 *)
                    /$50  (*     @6:   push    ax *)
            /$B8/$5A/$00  (*           mov     ax, BYTES_PER_LINE *)
                /$F7/$E1  (*           mul     cx *)
                /$01/$C7  (*           add     di, ax *)
                    /$58  (*           pop     ax *)
            /$26/$38/$05  (*     @7:   seges   cmp     [di], al *)
                /$75/$07  (*           jnz     @@2 *)
                /$2C/$10  (*           sub     al, $10 *)
            /$26/$88/$05  (*           seges   mov     [di], al *)
                /$04/$10  (*           add     al, $10 *)
            /$83/$C7/$5A  (*     @@2:  add     di, BYTES_PER_LINE *)
                /$FE/$C1  (*           inc     cl *)
                /$38/$E1  (*           cmp     cl, ah *)
                /$72/$EB  (*           jb      @7 *)
                /$EB/$24  (*           jmp     @5 *)
                    /$50  (*     @8:   push    ax *)
            /$BB/$5A/$00  (*           mov     bx, BYTES_PER_LINE *)
                /$88/$E0  (*           mov     al, ah *)
                /$B4/$00  (*           mov     ah, 0 *)
                /$F7/$E3  (*           mul     bx *)
                /$01/$C7  (*           add     di, ax *)
                    /$58  (*           pop     ax *)
                /$2C/$10  (*     @9:   sub     al, $10 *)
            /$26/$38/$05  (*           seges   cmp     [di], al *)
                    /$9C  (*           pushf *)
                /$04/$10  (*           add     al, $10 *)
                    /$9D  (*           popf *)
                /$75/$03  (*           jnz     @@1 *)
            /$26/$88/$05  (*           seges   mov     [di], al *)
            /$83/$C7/$5A  (*     @@1:  add     di, BYTES_PER_LINE *)
                /$FE/$C4  (*           inc     ah *)
                /$38/$CC  (*           cmp     ah, cl *)
                /$72/$E9  (*           jb      @9 *)
                    /$5F  (*     @5:   pop     di *)
                    /$5A  (*           pop     dx *)
                    /$59  (*           pop     cx *)
                    /$5B  (*           pop     bx *)
            /$83/$C3/$04  (*           add     bx, 4 *)
            /$83/$C1/$04  (*           add     cx, 4 *)
            /$83/$C2/$04  (*           add     dx, 4 *)
                    /$47  (*           inc     di *)
            /$3B/$7E/$F8  (*           cmp     di, X2 *)
    /$73/$03/$E9/$7B/$FF  (*           jb      @4 *)
            /$FE/$46/$E7  (*     @2:   inc     Bank *)
        /$80/$7E/$E7/$04  (*           cmp     Bank, 4 *)
                /$75/$0A  (*           jnz     @3 *)
        /$80/$66/$E7/$03  (*           and     Bank, 3 *)
            /$FF/$46/$FA  (*           inc     X1 *)
            /$FF/$46/$F8  (*           inc     X2 *)
            /$FF/$46/$EA  (*     @3:   inc     OldXStart *)
            /$FF/$46/$EC  (*           inc     XStart *)
            /$FF/$46/$F6  (*           inc     XPos *)
            /$FF/$4E/$E8  (*           dec     Count *)
    /$74/$03/$E9/$34/$FF  (*           jnz     @1 *)
                    /$07  (*           pop     es *)
                    /$1F  (*           pop     ds *)
                /$EB/$3D  (*           jmp     @Exit *)

(*     @Fill: *)
                    /$53  (*           push    bx *)
                    /$51  (*           push    cx *)
                /$88/$E9  (*           mov     cl, ch *)
                /$B5/$00  (*           mov     ch, 0 *)
                /$88/$E3  (*           mov     bl, ah *)
                /$B7/$00  (*           mov     bh, 0 *)
            /$83/$F9/$1A  (*     @@5:  cmp     cx, HEIGHT *)
                /$77/$2A  (*           ja      @@3 *)
                /$39/$D9  (*           cmp     cx, bx *)
                /$72/$14  (*           jb      @@4 *)
                /$2C/$10  (*           sub     al, $10 *)
            /$26/$38/$05  (*           seges   cmp     [di], al *)
                    /$9C  (*           pushf *)
                /$04/$10  (*           add     al, $10 *)
                    /$9D  (*           popf *)
                /$75/$03  (*           jnz     @@7 *)
            /$26/$88/$05  (*           seges   mov     [di], al *)
            /$83/$C7/$5A  (*     @@7:  add     di, BYTES_PER_LINE *)
                    /$41  (*           inc     cx *)
                /$EB/$E3  (*           jmp     @@5 *)
            /$26/$38/$05  (*     @@4:  seges   cmp     [di], al *)
                /$75/$07  (*           jnz     @@6 *)
                /$2C/$10  (*           sub     al, $10 *)
            /$26/$88/$05  (*           seges   mov     [di], al *)
                /$04/$10  (*           add     al, $10 *)
            /$83/$C7/$5A  (*     @@6:  add     di, BYTES_PER_LINE *)
                    /$41  (*           inc     cx *)
                /$EB/$D1  (*           jmp     @@5 *)
                    /$59  (*     @@3:  pop     cx *)
                    /$5B  (*           pop     bx *)
                /$EB/$85  (*           jmp     @5 *)

(*     @Exit: *)
);
  end;


  procedure BrickPalette (i: Integer);
  var
    j: Integer;
  begin
    i := i mod 20;
    for j := 0 to 19 do
      if (i = j) then
        CopyPalette ($FE, $E0 + j)
      else
        if (((i + 2) mod 20) = j) then
          CopyPalette ($FF, $E0 + j)
        else
          CopyPalette ($FD, $E0 + j);
  end;

  procedure LargeBrickPalette (i: Integer);
  var
    j: Integer;
  begin
    i := i mod 32;
    for j := 0 to 31 do
      if (i = j) or (((i + 1) mod 32) = j) then
        CopyPalette ($D6, $E0 + j)
      else
        if (((i + 3) mod 32) = j) or (((i + 4) mod 32) = j) then
          CopyPalette ($D4, $E0 + j)
        else
          CopyPalette ($D1, $E0 + j);
  end;

  procedure PillarPalette (i: Integer);
  const
    ShadowPos = 28;
    ShadowEnd = 36;
  var
    j, k, l: Integer;
    c1, c2, c3,
    Base: Byte;
  begin
    Base := Options.BackGrColor1;
    C1 := Palette [Base, 0] div 4;
    C2 := Palette [Base, 1] div 4;
    C3 := Palette [Base, 2] div 4;
    i := i mod 60;
    j := 0;
    k := 1;
    repeat
      for l := j to k do
      begin
        OutPalette ($C0 + ((l + i) mod 60), C1 + k, C2 + k, C3 + k);
        OutPalette ($C0 + ((ShadowPos + i - l) mod 60), C1 + k, C2 + k, C3 + k);
      end;
      j := k;
      k := k + 1;
    until k >= 15;
    for j := ShadowPos to ShadowEnd do
    begin
      if C1 > 0 then Dec (C1);
      if C2 > 0 then Dec (C2);
      if C3 > 0 then Dec (C3);
      OutPalette ($C0 + ((j + i) mod 60), C1, C2, C3);
    end;
    Base := Options.BackGrColor2;
    C1 := Palette [Base, 0] div 4;
    C2 := Palette [Base, 1] div 4;
    C3 := Palette [Base, 2] div 4;
    for j := ShadowEnd + 1 to 59 do
      OutPalette ($C0 + ((i + j) mod 60), C1, C2, C3);
  end;

  procedure WindowPalette (i: Integer);
  var
    j: Integer;
  begin
    i := i mod 32;
    for j := 0 to 5 do
      CopyPalette (1, $E0 + ((i + j) mod 32));
    for j := 6 to 31 do
      CopyPalette (16, $E0 + ((i + j) mod 32));
  end;

  procedure DrawBackGr (FirstTime: Boolean);
  var
    i: Integer;
  begin
    case BackGround of
      1 .. 3,
      9..11: PutBackGr (BackGrMap, FirstTime);
    end;

    if Clouds <> 0 then
    begin
      i := XView div CloudSpeed;
      PutClouds (i, XView - LastXView [CurrentPage]);
    end;
  end;

  procedure DrawBackGrMap (Y1, Y2, Shift: Integer; C: Byte);
    var
      i, j: Integer;
  begin
    for i := 0 to 320 - 1 do
    begin
      for j := Y1 - BackGrMap[i + Shift] to Y2 do
        if GetPixel (i, j) >= $C0 then
          PutPixel (i, j, C);
    end;
  end;

  procedure DrawPalBackGr;
  var
    i: Integer;
  begin
    i := Round (XView / BrickSpeed);
    case BackGround of
      4: BrickPalette (i);
      5: LargeBrickPalette (i);
      6: PillarPalette (i);
      7: WindowPalette (i);
    end;
  end;

  procedure ReadColorMap;
  var
    i: Integer;
  begin
    for i := 0 to NV * H - 1 do
      ColorMap [i] := GetPixel (XView + Shift, i) * 256 +
        GetPixel (XView + Shift + 1, i);
  end;

  procedure DrawBricks (X, Y, W, H: Integer);
  begin
    PutImage (X, Y, W, H, A3(@PALBRICK000^)^);
  end;

  procedure LargeBricks (X, Y, W, H: Integer);
  begin
inline(
                     $06  (*             push  es *)
            /$BB/$40/$01  (*             mov   bx, 320 *)
            /$8B/$46/$0A  (*             mov   ax, Y *)
(*   {          add   ax, WindowY } *)
                /$F7/$E3  (*             mul   bx *)
            /$03/$46/$0C  (*             add   ax, X *)
                /$89/$C7  (*             mov   di, ax *)
                /$88/$C3  (*             mov   bl, al *)
            /$80/$E3/$1F  (*             and   bl, 00011111b *)
            /$80/$C3/$E0  (*             add   bl, $E0 *)
            /$B8/$00/$A0  (*             mov   ax, VGA_SEGMENT *)
                /$8E/$C0  (*             mov   es, ax *)
            /$8B/$4E/$06  (*             mov   cx, H *)
            /$8B/$56/$0A  (*             mov   dx, Y *)

                    /$52  (*             push  dx *)
            /$80/$C2/$0E  (*             add   dl, 14          { Why? } *)
            /$80/$E2/$10  (*             and   dl, 00010000b *)
                /$08/$D2  (*             or    dl, dl *)
                /$74/$03  (*             jz    @0 *)
            /$80/$F3/$10  (*             xor   bl, 16 *)
(*     @0: *)
                    /$5A  (*             pop   dx *)

                /$E3/$41  (*             jcxz  @End *)
(*     @1: *)
                    /$51  (*             push  cx *)
            /$8B/$4E/$08  (*             mov   cx, W *)
                /$E3/$36  (*             jcxz  @3 *)
                    /$57  (*             push  di *)

                /$B0/$D4  (*             mov   al, $D4 *)
            /$80/$E2/$0F  (*             and   dl, 00001111b *)
            /$80/$FA/$02  (*             cmp   dl, 2 *)
                /$74/$0E  (*             jz    @@1 *)
                /$77/$18  (*             ja    @Brick *)
                /$B0/$D1  (*             mov   al, $D1 *)
            /$80/$FA/$00  (*             cmp   dl, 0 *)
                /$77/$05  (*             ja    @@1 *)

(* /$B0/$D6/$80/$F3/$10/$88/$C4/$D1/$E9/$F3/$AB/$D1/$D1/$F3/$AA/
$EB/$0C/$88/$D8/$24/$1F/$04/$E0/$AA/$FE/$C0/$49/$75/$F6/$5F/$81/$C7/$40/
$01/$59/$42/$49/$75/$BF/$07/$5D/$CA/$08/$00/$55/$89/$E5/$8B/$46/$0C/$99/
$F7/$7E/$08/$99/$B9/$03/$00/$F7/$F9/$92/$3 *)

                /$B0/$D6  (*             mov   al, $D6 *)
            /$80/$F3/$10  (*             xor   bl, 16 *)
(*     @@1: *)
                /$88/$C4  (*             mov   ah, al *)
                /$D1/$E9  (*             shr   cx, 1 *)
                /$F3/$AB  (*             rep   stosw *)
                /$D1/$D1  (*             rcl   cx, 1 *)
                /$F3/$AA  (*             rep   stosb *)
                /$EB/$0C  (*             jmp   @LineEnd *)

(*     @Brick: *)
                /$88/$D8  (*             mov   al, bl *)
(*     @2: *)
                /$24/$1F  (*             and   al, 00011111b *)
                /$04/$E0  (*             add   al, $E0 *)
                    /$AA  (*             stosb *)
                /$FE/$C0  (*             inc   al *)
                    /$49  (*             dec   cx *)
                /$75/$F6  (*             jnz   @2 *)

(*     @LineEnd: *)
                    /$5F  (*             pop   di *)
        /$81/$C7/$40/$01  (*             add   di, 320 *)
(*     @3: *)
                    /$59  (*             pop   cx *)
                    /$42  (*             inc   dx *)
                    /$49  (*             dec   cx *)
                /$75/$BF  (*             jnz   @1 *)
(*     @End: *)
                    /$07  (*             pop   es *)
);
  end;

  procedure Pillar (X, Y, W, H: Integer);
  begin
    case (X div W) mod 3 of
      0: PutImage (X, Y, W, H, A3(@PalPill000^)^);
      1: PutImage (X, Y, W, H, A3(@PalPill001^)^);
      2: PutImage (X, Y, W, H, A3(@PalPill002^)^);
    end;
  end;

  procedure Windows (X, Y, W, H: Integer);
  const
    Y1 =  50;
    Y2 =  80;
  begin
inline(
                     $06  (*             push  es *)
            /$BB/$40/$01  (*             mov   bx, 320 *)
            /$8B/$46/$0A  (*             mov   ax, Y *)
                /$89/$C6  (*             mov   si, ax *)
            /$83/$C6/$16  (*             add   si, 22 *)
(*   {          add   ax, WindowY } *)
                /$F7/$E3  (*             mul   bx *)
            /$03/$46/$0C  (*             add   ax, X *)
                /$89/$C7  (*             mov   di, ax *)
                /$88/$C3  (*             mov   bl, al *)
            /$80/$CB/$C0  (*             or    bl, $C0 *)
            /$B8/$00/$A0  (*             mov   ax, VGA_SEGMENT *)
                /$8E/$C0  (*             mov   es, ax *)
            /$8B/$4E/$06  (*             mov   cx, H *)
                /$E3/$35  (*             jcxz  @End *)
(*     @1: *)
                    /$51  (*             push  cx *)
            /$8B/$4E/$08  (*             mov   cx, W *)
                /$E3/$29  (*             jcxz  @3 *)

                    /$57  (*             push  di *)
                /$88/$D8  (*             mov   al, bl *)

        /$81/$E6/$1F/$00  (*             and   si, 00011111b *)
            /$83/$FE/$03  (*             cmp   si, 00000011b *)
                /$72/$0C  (*             jb    @4 *)

                /$24/$1F  (*     @2:     and   al, 00011111b *)
                /$0C/$E0  (*             or    al, 11100000b *)
                    /$AA  (*             stosb *)
                /$FE/$C0  (*             inc   al *)
                    /$49  (*             dec   cx *)
                /$75/$F6  (*             jnz   @2 *)
                /$EB/$0C  (*             jmp   @LineEnd *)

            /$B8/$01/$01  (*     @4:     mov   ax, 0101h *)
                    /$FC  (*             cld *)
                /$D1/$E9  (*             shr   cx, 1 *)
                /$F3/$AB  (*             rep   stosw *)
                /$D1/$D1  (*             rcl   cx, 1 *)
                /$F3/$AA  (*             rep   stosb *)

(*     @LineEnd: *)
                    /$5F  (*             pop   di *)
        /$81/$C7/$40/$01  (*             add   di, 320 *)
(*     @3: *)
                    /$59  (*             pop   cx *)
                    /$42  (*             inc   dx *)
                    /$46  (*             inc   si *)
                    /$49  (*             dec   cx *)
                /$75/$CB  (*             jnz   @1 *)
(*     @End: *)
                    /$07  (*             pop   es *)
);
  end;

  procedure DrawBackGrBlock (X, Y, W, H: Integer);
  var
    i: Integer;
  begin
  {  Fill (X, Y, W, H, $F0); }
    if Options.SkyType in [2, 5, 9, 10, 11] then
      SmoothFill (X, Y, W, H)
    else
      case BackGround of

        4: DrawBricks (X, Y, W, H);
        5: LargeBricks (X, Y, W, H);
        6: Pillar (X, Y, W, H);
        7: Windows (X, Y, W, H);
        else
          for i := 0 to H - 1 do
            Fill (X, Y + i, W, 1, ColorMap [Y + i]);
      end;
  end;

  procedure SmoothFill (X, Y, W, H: Integer);
    { X mod 4 = 0, W mod 4 = 0 }
    var
      PageOffset: Word;
      Horizon: Integer;
  begin
    PageOffset := GetPageOffset;
    Horizon := Options.Horizon - 4;  { -4 for BumpBlock }
inline(
                     $06  (*         push    es *)
            /$B8/$00/$A0  (*         mov     ax, VGA_SEGMENT *)
                /$8E/$C0  (*         mov     es, ax *)

            /$8B/$56/$0A  (*         mov     dx, Y *)
            /$B8/$5A/$00  (*         mov     ax, VIR_SCREEN_WIDTH / 4 *)
                /$F7/$E2  (*         mul     dx *)
            /$8B/$7E/$0C  (*         mov     di, X *)
                /$D1/$EF  (*         shr     di, 1 *)
                /$D1/$EF  (*         shr     di, 1 *)
                /$01/$C7  (*         add     di, ax *)
            /$03/$7E/$FE  (*         add     di, PageOffset *)

            /$8B/$46/$0A  (*         mov     ax, Y *)
            /$3B/$46/$FC  (*         cmp     ax, Horizon *)
                /$72/$04  (*         jb      @0 *)
                /$B2/$F0  (*         mov     dl, $F0 *)
                /$EB/$0F  (*         jmp     @3 *)

                /$B3/$06  (*     @0: mov     bl, 6 *)
                /$F6/$F3  (*         div     bl *)
                /$B2/$EF  (*         mov     dl, $EF *)
                /$28/$C2  (*         sub     dl, al *)
            /$80/$FA/$E0  (*         cmp     dl, $E0 *)
                /$73/$02  (*         jnb     @3 *)
                /$B2/$E0  (*         mov     dl, $E0 *)
                /$88/$E6  (*     @3: mov     dh, ah *)

            /$8B/$5E/$06  (*         mov     bx, H *)
            /$83/$FB/$00  (*         cmp     bx, 0 *)
                /$7E/$7B  (*         jle     @End *)
            /$8B/$4E/$08  (*         mov     cx, W *)
                /$D1/$E9  (*         shr     cx, 1 *)
                /$D1/$E9  (*         shr     cx, 1 *)

                    /$FC  (*         cld *)

                    /$57  (*     @1: push    di *)
                    /$51  (*         push    cx *)
                    /$52  (*         push    dx *)
                /$B4/$0F  (*         mov     ah, 0Fh *)
                /$B0/$02  (*         mov     al, MAP_MASK *)
            /$BA/$C4/$03  (*         mov     dx, SC_INDEX *)
                    /$EF  (*         out     dx, ax *)
                    /$5A  (*         pop     dx *)
                /$88/$D0  (*         mov     al, dl *)
                /$88/$C4  (*         mov     ah, al *)
                /$D1/$E9  (*         shr     cx, 1 *)
                /$F3/$AB  (*         rep     stosw *)
                /$D1/$D1  (*         rcl     cx, 1 *)
                /$F3/$AA  (*         rep     stosb *)
                    /$59  (*         pop     cx *)
                    /$5F  (*         pop     di *)

            /$80/$FE/$03  (*         cmp     dh, 3 *)
                /$72/$2C  (*         jb      @4 *)
                /$3C/$E0  (*         cmp     al, $E0 *)
                /$74/$07  (*         jz      @2 *)
                /$3C/$F0  (*         cmp     al, $F0 *)
                /$74/$03  (*         jz      @2 *)
            /$2D/$01/$01  (*         sub     ax, 0101h *)
                    /$50  (*     @2: push    ax *)
                    /$52  (*         push    dx *)
                /$B4/$05  (*         mov     ah, 0101b *)
                    /$51  (*         push    cx *)
                /$88/$F1  (*         mov     cl, dh *)
            /$80/$E1/$01  (*         and     cl, 1 *)
                /$D2/$E4  (*         shl     ah, cl *)
                    /$59  (*         pop     cx *)
                /$B0/$02  (*         mov     al, MAP_MASK *)
            /$BA/$C4/$03  (*         mov     dx, SC_INDEX *)
                    /$EF  (*         out     dx, ax *)
                    /$5A  (*         pop     dx *)
                    /$58  (*         pop     ax *)
                    /$57  (*         push    di *)
                    /$51  (*         push    cx *)
                /$D1/$E9  (*         shr     cx, 1 *)
                /$F3/$AB  (*         rep     stosw *)
                /$D1/$D1  (*         rcl     cx, 1 *)
                /$F3/$AA  (*         rep     stosb *)
                    /$59  (*         pop     cx *)
                    /$5F  (*         pop     di *)

            /$FF/$46/$0A  (*     @4: inc     Y *)
            /$8B/$46/$0A  (*         mov     ax, Y *)
            /$3B/$46/$FC  (*         cmp     ax, Horizon *)
                /$72/$02  (*         jb      @9 *)
                /$B2/$F0  (*         mov     dl, $F0 *)
                /$FE/$C6  (*     @9: inc     dh *)
            /$80/$FE/$06  (*         cmp     dh, 6 *)
                /$75/$0E  (*         jnz     @5 *)
                /$B6/$00  (*         mov     dh, 0 *)
            /$80/$FA/$E0  (*         cmp     dl, $E0 *)
                /$74/$07  (*         jz      @5 *)
            /$80/$FA/$F0  (*         cmp     dl, $F0 *)
                /$74/$02  (*         jz      @5 *)
                /$FE/$CA  (*         dec     dl *)
            /$83/$C7/$5A  (*     @5: add     di, VIR_SCREEN_WIDTH / 4 *)
                    /$4B  (*         dec     bx *)
                /$75/$8D  (*         jnz     @1 *)

(*   @End: *)
                    /$07  (*         pop     es *)
);
  end;

end.
