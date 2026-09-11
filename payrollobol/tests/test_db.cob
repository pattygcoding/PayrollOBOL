identification division.
program-id. TEST-DB.
data division.
working-storage section.
copy 'EMP-RECORD.cpy'.
copy 'TIME-CARD.cpy'.
copy 'CALC-RESULT.cpy'.
01 status-code usage binary-long.
01 assertion-name pic x(40).
01 failures binary-long value 0.
procedure division.
    call 'INIT-DB' returning status-code
    move 'INIT-DB' to assertion-name perform check-status
    initialize EMP-MASTER-RECORD TIME-CARD-RECORD
    move 100101 to EMP-ID move 20260915 to TC-PAY-PERIOD-END
    move 12.50 to EMP-PAY-RATE move 40 to TC-REG-HOURS
    call 'CALC-ENGINE' using TIME-CARD-RECORD EMP-MASTER-RECORD
        CALC-RESULT returning status-code
    move 'CALC-ENGINE' to assertion-name perform check-status
    call 'LOG-TRANSACTION' using TIME-CARD-RECORD EMP-MASTER-RECORD
        CALC-RESULT returning status-code
    move 'LOG-TRANSACTION' to assertion-name perform check-status
    call 'COMMIT-DB' returning status-code
    move 'COMMIT-DB' to assertion-name perform check-status
    call 'CLOSE-DB' returning status-code
    move 'CLOSE-DB' to assertion-name perform check-status
    call 'CLOSE-DB' returning status-code
    move 'CLOSE-DB idempotent' to assertion-name perform check-status
    call 'INIT-DB' returning status-code
    move 'reopen DB' to assertion-name perform check-status
    move 20260930 to TC-PAY-PERIOD-END
    call 'LOG-TRANSACTION' using TIME-CARD-RECORD EMP-MASTER-RECORD
        CALC-RESULT returning status-code
    move 'uncommitted transaction' to assertion-name perform check-status
    call 'CLOSE-DB' returning status-code
    move 'close rolls back' to assertion-name perform check-status
    display 'DB-LOGGER failures: ' failures
    if failures > 0 stop run returning 1 end-if
    stop run returning 0.
check-status.
    if status-code not = 0
        display 'FAIL ' assertion-name ' expected=0 actual=' status-code
        add 1 to failures
    end-if.
end program TEST-DB.
