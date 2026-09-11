identification division.
program-id. CALC-ENGINE.
environment division.
configuration section.
repository. function all intrinsic.
data division.
working-storage section.
01 saved-employee pic x(83).
01 calc-failed binary-char unsigned.
linkage section.
copy 'TIME-CARD.cpy'.
copy 'EMP-RECORD.cpy'.
copy 'CALC-RESULT.cpy'.
procedure division using TIME-CARD-RECORD EMP-MASTER-RECORD CALC-RESULT.
    initialize CALC-RESULT
    move 0 to calc-failed
    move EMP-MASTER-RECORD to saved-employee
    if TC-REG-HOURS is not numeric or TC-OT-HOURS is not numeric
        or EMP-PAY-RATE is not numeric
        or EMP-YTD-GROSS is not numeric
        or EMP-YTD-FED-TAX is not numeric
        or EMP-YTD-STATE-TAX is not numeric
        or EMP-YTD-FICA is not numeric
        or EMP-YTD-NET is not numeric
        goback returning 1
    end-if
    compute CALC-REG-PAY rounded = TC-REG-HOURS * EMP-PAY-RATE
        on size error move 1 to calc-failed
    end-compute
    compute CALC-OT-PAY rounded = TC-OT-HOURS * EMP-PAY-RATE * 1.5
        on size error move 1 to calc-failed
    end-compute
    compute CALC-GROSS-PAY rounded = CALC-REG-PAY + CALC-OT-PAY
        on size error move 1 to calc-failed
    end-compute
    if CALC-GROSS-PAY <= 500
        compute CALC-FED-TAX rounded = CALC-GROSS-PAY * 0.10
            on size error move 1 to calc-failed
        end-compute
    else
        compute CALC-FED-TAX rounded = 50 + (CALC-GROSS-PAY - 500) * 0.22
            on size error move 1 to calc-failed
        end-compute
    end-if
    compute CALC-STATE-TAX rounded = CALC-GROSS-PAY * 0.05
        on size error move 1 to calc-failed
    end-compute
    compute CALC-FICA-TAX rounded = CALC-GROSS-PAY * 0.0765
        on size error move 1 to calc-failed
    end-compute
    compute CALC-NET-PAY rounded = CALC-GROSS-PAY - CALC-FED-TAX
        - CALC-STATE-TAX - CALC-FICA-TAX
        on size error move 1 to calc-failed
    end-compute
    add CALC-GROSS-PAY to EMP-YTD-GROSS rounded
        on size error move 1 to calc-failed
    end-add
    add CALC-FED-TAX to EMP-YTD-FED-TAX rounded
        on size error move 1 to calc-failed
    end-add
    add CALC-STATE-TAX to EMP-YTD-STATE-TAX rounded
        on size error move 1 to calc-failed
    end-add
    add CALC-FICA-TAX to EMP-YTD-FICA rounded
        on size error move 1 to calc-failed
    end-add
    add CALC-NET-PAY to EMP-YTD-NET rounded
        on size error move 1 to calc-failed
    end-add
    if calc-failed not = 0
        move saved-employee to EMP-MASTER-RECORD
        initialize CALC-RESULT
    end-if
    goback returning calc-failed.
end program CALC-ENGINE.