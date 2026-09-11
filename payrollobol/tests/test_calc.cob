identification division.
program-id. TEST-CALC.
data division.
working-storage section.
copy 'EMP-RECORD.cpy'.
copy 'TIME-CARD.cpy'.
copy 'CALC-RESULT.cpy'.
01 failures binary-long value 0.
01 status-code usage binary-long.
01 assertion-name pic x(60).
01 expected-value pic s9(12)v99 comp-3.
01 actual-value pic s9(12)v99 comp-3.
01 expected-display pic -(12)9.99.
01 actual-display pic -(12)9.99.
01 saved-record pic x(83).
procedure division.
    initialize EMP-MASTER-RECORD TIME-CARD-RECORD
    move 12.50 to EMP-PAY-RATE
    move 40 to TC-REG-HOURS
    call 'CALC-ENGINE' using TIME-CARD-RECORD EMP-MASTER-RECORD
        CALC-RESULT returning status-code
    move 'successful calculation' to assertion-name
    move 0 to expected-value move status-code to actual-value perform check-value
    move 'regular pay / federal boundary gross' to assertion-name
    move 500 to expected-value move CALC-REG-PAY to actual-value perform check-value
    move 'federal at exactly 500' to assertion-name
    move 50 to expected-value move CALC-FED-TAX to actual-value perform check-value
    move 'state 5 percent' to assertion-name
    move 25 to expected-value move CALC-STATE-TAX to actual-value perform check-value
    move 'FICA 7.65 percent' to assertion-name
    move 38.25 to expected-value move CALC-FICA-TAX to actual-value perform check-value
    move 'net at boundary' to assertion-name
    move 386.75 to expected-value move CALC-NET-PAY to actual-value perform check-value
    move 5 to TC-OT-HOURS
    call 'CALC-ENGINE' using TIME-CARD-RECORD EMP-MASTER-RECORD
        CALC-RESULT returning status-code
    move 'overtime at 1.5x' to assertion-name
    move 93.75 to expected-value move CALC-OT-PAY to actual-value perform check-value
    move 'gross with overtime' to assertion-name
    move 593.75 to expected-value move CALC-GROSS-PAY to actual-value perform check-value
    move 'graduated federal rounding above boundary' to assertion-name
    move 70.63 to expected-value move CALC-FED-TAX to actual-value perform check-value
    move 'state rounding' to assertion-name
    move 29.69 to expected-value move CALC-STATE-TAX to actual-value perform check-value
    move 'FICA rounding' to assertion-name
    move 45.42 to expected-value move CALC-FICA-TAX to actual-value perform check-value
    move 'net equals gross minus rounded taxes' to assertion-name
    move 448.01 to expected-value move CALC-NET-PAY to actual-value perform check-value
    move 'YTD gross accumulated' to assertion-name
    move 1093.75 to expected-value move EMP-YTD-GROSS to actual-value perform check-value
    move 'YTD federal accumulated' to assertion-name
    move 120.63 to expected-value move EMP-YTD-FED-TAX to actual-value perform check-value
    move 'YTD state accumulated' to assertion-name
    move 54.69 to expected-value move EMP-YTD-STATE-TAX to actual-value perform check-value
    move 'YTD FICA accumulated' to assertion-name
    move 83.67 to expected-value move EMP-YTD-FICA to actual-value perform check-value
    move 'YTD net accumulated' to assertion-name
    move 834.76 to expected-value move EMP-YTD-NET to actual-value perform check-value
    move 9999999.99 to EMP-YTD-NET
    move EMP-MASTER-RECORD to saved-record
    call 'CALC-ENGINE' using TIME-CARD-RECORD EMP-MASTER-RECORD
        CALC-RESULT returning status-code
    move 'YTD overflow returns failure' to assertion-name
    move 1 to expected-value move status-code to actual-value perform check-value
    if EMP-MASTER-RECORD not = saved-record
        display 'FAIL atomic YTD rollback: expected original record, actual modified'
        add 1 to failures
    end-if
    move 'overflow clears calculation' to assertion-name
    move 0 to expected-value move CALC-GROSS-PAY to actual-value perform check-value
    initialize EMP-MASTER-RECORD TIME-CARD-RECORD
    move 9999.99 to EMP-PAY-RATE
    move 99.99 to TC-REG-HOURS TC-OT-HOURS
    call 'CALC-ENGINE' using TIME-CARD-RECORD EMP-MASTER-RECORD
        CALC-RESULT returning status-code
    move 'pay overflow returns failure' to assertion-name
    move 1 to expected-value move status-code to actual-value perform check-value
    initialize EMP-MASTER-RECORD TIME-CARD-RECORD
    move 1.01 to EMP-PAY-RATE move 1 to TC-OT-HOURS
    call 'CALC-ENGINE' using TIME-CARD-RECORD EMP-MASTER-RECORD
        CALC-RESULT returning status-code
    move 'half cent overtime rounds up' to assertion-name
    move 1.52 to expected-value move CALC-OT-PAY to actual-value perform check-value
    initialize EMP-MASTER-RECORD TIME-CARD-RECORD
    call 'CALC-ENGINE' using TIME-CARD-RECORD EMP-MASTER-RECORD
        CALC-RESULT returning status-code
    move 'zero pay' to assertion-name
    move 0 to expected-value move CALC-NET-PAY to actual-value perform check-value
    move 'X' to TIME-CARD-RECORD(7:1)
    call 'CALC-ENGINE' using TIME-CARD-RECORD EMP-MASTER-RECORD
        CALC-RESULT returning status-code
    move 'invalid hours rejected' to assertion-name
    move 1 to expected-value move status-code to actual-value perform check-value
    display 'CALC-ENGINE failures: ' failures
    if failures > 0 stop run returning 1 end-if
    stop run returning 0.
check-value.
    if actual-value not = expected-value
        move expected-value to expected-display
        move actual-value to actual-display
        display 'FAIL ' assertion-name ' expected=' expected-display
            ' actual=' actual-display
        add 1 to failures
    end-if.
end program TEST-CALC.