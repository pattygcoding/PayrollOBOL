identification division.
program-id. VERIFY-MASTER.
environment division.
input-output section.
file-control.
    select master-file assign to 'data/output/emp_master_new.dat'
        organization sequential file status master-status.
data division.
file section.
fd master-file.
01 disk-record pic x(100).
working-storage section.
copy 'EMP-RECORD.cpy'.
01 master-status pic xx.
01 employee-number binary-long.
01 failures binary-long value 0.
01 expected-value pic 9(9)v99 comp-3.
01 actual-value pic 9(9)v99 comp-3.
01 assertion-name pic x(40).
01 expected-text pic 9(9).99.
01 actual-text pic 9(9).99.
procedure division.
    open input master-file
    if master-status not = '00'
        display 'FAIL master open expected=00 actual=' master-status
        stop run returning 1
    end-if
    perform varying employee-number from 1 by 1 until employee-number > 3
        read master-file
        if master-status not = '00'
            display 'FAIL master read expected=00 actual=' master-status
            stop run returning 1
        end-if
        move disk-record(1:83) to EMP-MASTER-RECORD
        move 'employee ID' to assertion-name
        compute expected-value = 100100 + employee-number
        move EMP-ID to actual-value perform check-value
        move 'YTD gross' to assertion-name
        evaluate employee-number
            when 1 move 1543.75 to expected-value
            when 2 move 1050 to expected-value
            when 3 move 1925 to expected-value
        end-evaluate
        move EMP-YTD-GROSS to actual-value perform check-value
        move 'YTD federal' to assertion-name
        evaluate employee-number
            when 1 move 279.63 to expected-value
            when 2 move 171 to expected-value
            when 3 move 363.50 to expected-value
        end-evaluate
        move EMP-YTD-FED-TAX to actual-value perform check-value
        move 'YTD state' to assertion-name
        evaluate employee-number
            when 1 move 77.19 to expected-value
            when 2 move 52.50 to expected-value
            when 3 move 96.25 to expected-value
        end-evaluate
        move EMP-YTD-STATE-TAX to actual-value perform check-value
        move 'YTD FICA' to assertion-name
        evaluate employee-number
            when 1 move 118.10 to expected-value
            when 2 move 80.33 to expected-value
            when 3 move 147.26 to expected-value
        end-evaluate
        move EMP-YTD-FICA to actual-value perform check-value
        move 'YTD net' to assertion-name
        evaluate employee-number
            when 1 move 1068.83 to expected-value
            when 2 move 746.17 to expected-value
            when 3 move 1317.99 to expected-value
        end-evaluate
        move EMP-YTD-NET to actual-value perform check-value
    end-perform
    read master-file
    if master-status not = '10'
        display 'FAIL master EOF expected=10 actual=' master-status
        add 1 to failures
    end-if
    close master-file
    display 'MASTER verification failures: ' failures
    if failures > 0 stop run returning 1 end-if
    stop run returning 0.
check-value.
    if expected-value not = actual-value
        move expected-value to expected-text move actual-value to actual-text
        display 'FAIL ' assertion-name ' expected=' expected-text ' actual=' actual-text
        add 1 to failures
    end-if.
end program VERIFY-MASTER.
