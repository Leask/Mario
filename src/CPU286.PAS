unit CPU286;

  { This unit halts a program if the CPU is not a 286 or higher }

(*   {$G+} *)

interface


implementation

  var
    CPU: Word;

begin
inline(
                     $55  (*         push    bp *)
                    /$54  (*         push    sp *)
                    /$58  (*         pop     ax *)
                /$39/$E0  (*         cmp     ax, sp *)
                /$74/$05  (*         jz      @Not86 *)
            /$B8/$56/$00  (*         mov     ax, 86 *)
                /$EB/$03  (*         jmp     @End *)
(*   @Not86: *)
            /$B8/$1E/$01  (*         mov     ax, 286 *)
(*   @End: *)
            /$A3/CPU      (*         mov     CPU, ax *)
                    /$5D  (*         pop     bp *)
);
  if CPU < 286 then
  begin
    WriteLn ('286 required.');
    Halt;
  end;
end.
