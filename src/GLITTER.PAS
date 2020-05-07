unit Glitter;

interface

  uses
    VGA256,
    Buffers,
    Crt;

  procedure ClearGlitter;
  procedure NewGlitter (X, Y: Integer; NewAttr, Duration: Byte);
  procedure NewStar (X, Y: Integer; NewAttr, Duration: Byte);
  procedure ShowGlitter;
  procedure HideGlitter;
  procedure CoinGlitter (X, Y: Integer);
  procedure StartGlitter (X, Y, W, H: Integer);

implementation

  const
    MaxGlitter = 75;

  var
    DataSeg: Word;

  type
    GlitterRec = record
      Attr: Byte;
      Pos: Word;
      BackGr: Array [0 .. MAX_PAGE] of Byte;
      Dummy1, Dummy2, Dummy3: Byte;  { Size: 8 bytes }
    end;

  var
    Count: String [MaxGlitter];
    NumGlitter: Byte absolute Count;
    GlitterList: array [1 .. MaxGlitter] of GlitterRec;

  procedure ClearGlitter;
  begin
    FillChar (Count, SizeOf (Count), #0);
  end;

  procedure NewGlitter (X, Y: Integer; NewAttr, Duration: Byte);
  var
    i: Integer;
  begin
    if (X < XView) or (X >= XView + NH * W) then
      Exit;
    i := 1;
    while (Count [i] > #0) and (i < MaxGlitter) do
      Inc (i);
    if (i < MaxGlitter) then
    begin
      if (Y < 0) or (Y > NV * H) then
        Exit;
      Count [i] := Chr (Duration);
      Inc (NumGlitter);
      with GlitterList [i] do
      begin
        Pos := Y * VIR_SCREEN_WIDTH + X;
        FillChar (BackGr, SizeOf (BackGr), #0);
        Attr := NewAttr;
      end;
    end;
  end;

  procedure NewStar (X, Y: Integer; NewAttr, Duration: Byte);
  begin
    NewGlitter (X, Y, NewAttr, Duration + 4);
    NewGlitter (X + 1, Y, NewAttr, Duration);
    NewGlitter (X, Y + 1, NewAttr, Duration);
    NewGlitter (X - 1, Y, NewAttr, Duration);
    NewGlitter (X, Y - 1, NewAttr, Duration);
  end;

  procedure ShowGlitter;
  var
    i,
    Page: Integer;
    PageOffset: Word;
  begin
    PageOffset := GetPageOffset;
    Page := CurrentPage;
    if NumGlitter > 0 then
      for i := 1 to MaxGlitter do
        if Count [i] > Chr (MAX_PAGE + 1) then
        begin
          {
            with GlitterList [i] do
            begin
              BackGr [WorkingPage] := GetPixel (XPos, YPos);
              PutPixel (XPos, YPos, Attr);
            end
          }
inline(
                     $06  (*                   push    es *)
                    /$1E  (*                   push    ds *)
            /$A1/> DataSeg  (*                   mov     ax, seg @Data *)
                /$8E/$D8  (*                   mov     ds, ax *)
        /$BE/> GlitterList  (*                   mov     si, offset GlitterList *)
        /$B8/> VGA_SEGMENT  (*                   mov     ax, VGA_SEGMENT *)
                /$8E/$C0  (*                   mov     es, ax *)
            /$8B/$5E/< i  (*                   mov     bx, i *)
                    /$4B  (*                   dec     bx *)
                /$B1/$03  (*                   mov     cl, 3 *)
                /$D3/$E3  (*                   shl     bx, cl *)
                /$01/$DE  (*                   add     si, bx *)
                    /$AC  (*                   lodsb                   { Attr } *)
                    /$50  (*                   push    ax *)
                    /$AD  (*                   lodsw                   { Pos } *)

                /$89/$C7  (*                   mov     di, ax *)
                /$D1/$EF  (*                   shr     di, 1 *)
                /$D1/$EF  (*                   shr     di, 1 *)
            /$03/$7E/< PageOffset  (*                   add     di, PageOffset *)
                /$24/$03  (*                   and     al, 3 *)
                /$88/$C1  (*                   mov     cl, al *)

            /$BA/$CE/$03  (*                   mov     dx, GC_INDEX *)
                /$88/$C4  (*                   mov     ah, al *)
                /$B0/$04  (*                   mov     al, READ_MAP *)
                    /$EF  (*                   out     dx, ax *)

                    /$26  (*                   seges *)
                /$8A/$1D  (*                   mov     bl, [di] *)

                /$B4/$01  (*                   mov     ah, 1 *)
                /$D2/$E4  (*                   shl     ah, cl *)
            /$BA/$C4/$03  (*                   mov     dx, SC_INDEX *)
                /$B0/$02  (*                   mov     al, MAP_MASK *)
                    /$EF  (*                   out     dx, ax *)

                    /$58  (*                   pop     ax *)
                    /$AA  (*                   stosb *)

            /$03/$76/< Page  (*                   add     si, Page *)
                /$88/$1C  (*                   mov     [si], bl        { BackGr [Page] } *)
                    /$1F  (*                   pop     ds *)
                    /$07  (*                   pop     es *)
);
        end
        else
          if Count [i] > #0 then
            with GlitterList [i] do
              BackGr [CurrentPage] := 0;
  end;

  procedure HideGlitter;
  var
    i,
    Page: Integer;
    PageOffset: Word;
  begin
    PageOffset := GetPageOffset;
    if NumGlitter = 0 then
      Exit;
    Page := CurrentPage;
    for i := MaxGlitter downto 1 do
      if Count [i] > #0 then
      begin
        {
        with GlitterList [i] do
          if BackGr [WorkingPage] <> 0 then
            PutPixel (XPos, YPos, BackGr [WorkingPage]);
        }
inline(
                     $06  (*                   push    es *)
                    /$1E  (*                   push    ds *)
            /$A1/> DataSeg  (*                   mov     ax, seg @Data *)
                /$8E/$D8  (*                   mov     ds, ax *)
            /$BE/> GlitterList  (*                   mov     si, offset GlitterList *)
            /$B8/$00/$A0  (*                   mov     ax, VGA_SEGMENT *)
                /$8E/$C0  (*                   mov     es, ax *)
            /$8B/$5E/ <i  (*                   mov     bx, i *)
                    /$4B  (*                   dec     bx *)
                /$B1/$03  (*                   mov     cl, 3 *)
                /$D3/$E3  (*                   shl     bx, cl *)
                /$01/$DE  (*                   add     si, bx *)
                    /$AC  (*                   lodsb                   { Attr } *)
                    /$AD  (*                   lodsw                   { Pos } *)
                /$89/$C7  (*                   mov     di, ax *)
                /$89/$C1  (*                   mov     cx, ax *)
            /$03/$76/< Page  (*                   add     si, Page *)
                /$8A/$1C  (*                   mov     bl, [si]        { BackGr [Page] } *)
                /$08/$DB  (*                   or      bl, bl *)
                /$74/$17  (*                   jz      @1 *)
                /$D1/$EF  (*                   shr     di, 1 *)
                /$D1/$EF  (*                   shr     di, 1 *)
            /$03/$7E/ <PageOffset  (*                   add     di, PageOffset *)
                /$B4/$01  (*                   mov     ah, 1 *)
            /$80/$E1/$03  (*                   and     cl, 3 *)
                /$D2/$E4  (*                   shl     ah, cl *)
            /$BA/$C4/$03  (*                   mov     dx, SC_INDEX *)
                /$B0/$02  (*                   mov     al, MAP_MASK *)
                    /$EF  (*                   out     dx, ax *)
                /$88/$D8  (*                   mov     al, bl *)
                    /$AA  (*                   stosb *)
                    /$1F  (*             @1:   pop     ds *)
                    /$07  (*                   pop     es *)
);
        Dec (Count [i]);
        if Count [i] = #0 then
          Dec (NumGlitter);
      end;
  end;

  procedure CoinGlitter (X, Y: Integer);
  begin
    NewStar (X + 5, Y + 2, $1F, 20);
    NewStar (X + W - 6, Y + 6, $1F, 18);
    NewStar (X + 10, Y + H - 3, $1F, 16);
    NewGlitter (X + W - 9, Y + 2, $1F, 15);
    NewGlitter (X + 6, Y + 7, $1F, 17);
    NewGlitter (X + 3, Y + 9, $1F, 15);
  end;

  procedure StartGlitter (X, Y, W, H: Integer);
  var
    i: Integer;
  begin
    NewStar (X + Random (W), Y + Random (H), $1F, 10 + Random (10));
    for i := 1 to 4 do
      NewGlitter (X + Random (W), Y + Random (H), $1F, 5 + Random (10));
  end;

begin
  DataSeg := DSeg;
end.
