01 EMP-MASTER-RECORD.
   05 EMP-ID                     PIC 9(6).
   05 EMP-NAME.
      10 EMP-LAST-NAME            PIC X(15).
      10 EMP-FIRST-NAME           PIC X(15).
   05 EMP-DEPT                    PIC X(4).
   05 EMP-PAY-RATE                PIC 9(4)V99 COMP-3.
   05 EMP-YTD-GROSS               PIC 9(7)V99 COMP-3.
   05 EMP-YTD-FED-TAX             PIC 9(7)V99 COMP-3.
   05 EMP-YTD-STATE-TAX           PIC 9(7)V99 COMP-3.
   05 EMP-YTD-FICA                PIC 9(7)V99 COMP-3.
   05 EMP-YTD-NET                 PIC 9(7)V99 COMP-3.
   05 FILLER                     PIC X(14).