identification division.
program-id. MAIN.
environment division.
configuration section.
repository. function all intrinsic.
input-output section.
file-control.
    select master-file assign to 'data/input/emp_master.dat'
        organization sequential file status master-status.
    select card-file assign to 'data/input/timecards.dat'
        organization sequential file status card-status.
    select new-master assign to 'data/output/emp_master_new.dat.tmp'
        organization sequential file status new-status.
    select marker-file assign to 'data/output/publication.pending'
        organization line sequential file status marker-status.
data division.
file section.
fd master-file.
01 master-disk pic x(100).
fd card-file.
01 card-disk pic x(32).
fd new-master.
01 new-disk pic x(100).
fd marker-file.
01 marker-line pic x(100).
working-storage section.
copy 'EMP-RECORD.cpy'.
copy 'TIME-CARD.cpy'.
copy 'CALC-RESULT.cpy'.
01 master-status pic xx.
01 card-status pic xx.
01 new-status pic xx.
01 marker-status pic xx.
01 master-open binary-char unsigned value 0.
01 card-open binary-char unsigned value 0.
01 new-open binary-char unsigned value 0.
01 db-open binary-char unsigned value 0.
01 marker-owned binary-char unsigned value 0.
01 committed binary-char unsigned value 0.
01 master-eof binary-char unsigned value 0.
01 card-eof binary-char unsigned value 0.
01 previous-master pic 9(6) value 0.
01 previous-card pic 9(6) value 0.
01 run-period pic 9(8) value 0.
01 processed-count pic 9(6) value 0.
01 status-code usage binary-long.
01 ignored-status usage binary-long.
01 character-index binary-long.
01 error-message pic x(120).
01 report-action pic x(8).
01 report-input.
   05 report-employee pic x(83).
   05 report-card pic x(34).
   05 report-calculation pic x(35).
01 source-path pic x(128).
01 target-path pic x(128).
01 file-information.
    05 file-byte-count pic 9(18) binary.
    05 file-modified pic x(8).
procedure division.
    call 'INIT-DB' returning status-code
    if status-code not = 0
        move 'Database initialization failed' to error-message perform fail-batch
    end-if
    move 1 to db-open
    open input marker-file
    if marker-status = '00'
        close marker-file
        move 'Publication recovery required: see data/output/publication.pending'
            to error-message perform fail-batch
    end-if
    if marker-status not = '35'
        move 'Cannot inspect publication marker' to error-message perform fail-batch
    end-if
    open input master-file
    if master-status not = '00'
        move 'Cannot open employee master' to error-message perform fail-batch
    end-if
    move 1 to master-open
    open input card-file
    if card-status not = '00'
        move 'Cannot open time cards' to error-message perform fail-batch
    end-if
    move 1 to card-open
    call 'CBL_CHECK_FILE_EXIST' using z'data/input/emp_master.dat'
        file-information returning status-code
    if status-code not = 0 or function mod(file-byte-count, 100) not = 0
        move 'Malformed/truncated 100-byte employee file'
            to error-message perform fail-batch
    end-if
    call 'CBL_CHECK_FILE_EXIST' using z'data/input/timecards.dat'
        file-information returning status-code
    if status-code not = 0 or function mod(file-byte-count, 32) not = 0
        move 'Malformed/truncated 32-byte time-card file'
            to error-message perform fail-batch
    end-if
    perform read-master perform read-card
    if card-eof = 1
        move 'No time cards: no payroll posted' to error-message perform fail-batch
    end-if
    open output marker-file
    if marker-status not = '00'
        move 'Cannot create publication marker' to error-message perform fail-batch
    end-if
    move 1 to marker-owned
    move spaces to marker-line
    string 'PAY PERIOD ' run-period
        ' - Query payroll_runs before recovering staged output.' into marker-line
    end-string
    write marker-line
    if marker-status not = '00'
        close marker-file
        move 'Cannot write publication marker' to error-message perform fail-batch
    end-if
    close marker-file
    if marker-status not = '00'
        move 'Cannot close publication marker' to error-message perform fail-batch
    end-if
    open output new-master
    if new-status not = '00'
        move 'Cannot create next master' to error-message perform fail-batch
    end-if
    move 1 to new-open
    move 'OPEN' to report-action perform call-report
    perform until master-eof = 1
        if card-eof = 0 and TC-EMP-ID < EMP-ID
            move 'Unmatched time card' to error-message perform fail-batch
        end-if
        if card-eof = 0 and TC-EMP-ID = EMP-ID
            call 'CALC-ENGINE' using TIME-CARD-RECORD EMP-MASTER-RECORD
                CALC-RESULT returning status-code
            if status-code not = 0
                move 'Invalid payroll data or monetary/YTD overflow'
                    to error-message perform fail-batch
            end-if
            call 'LOG-TRANSACTION' using TIME-CARD-RECORD EMP-MASTER-RECORD
                CALC-RESULT returning status-code
            if status-code not = 0
                move 'Ledger posting failed; period may already be posted'
                    to error-message perform fail-batch
            end-if
            move EMP-MASTER-RECORD to report-employee
            move TIME-CARD-RECORD to report-card
            move CALC-RESULT to report-calculation
            move 'DETAIL' to report-action perform call-report
            add 1 to processed-count
            perform read-card
        end-if
        move master-disk to new-disk
        move EMP-MASTER-RECORD to new-disk(1:83)
        write new-disk
        if new-status not = '00'
            move 'Failed writing next master' to error-message perform fail-batch
        end-if
        perform read-master
    end-perform
    if card-eof = 0
        move 'Unmatched time card after employee EOF' to error-message perform fail-batch
    end-if
    close master-file card-file new-master
    move 0 to master-open card-open new-open
    if master-status not = '00' or card-status not = '00' or new-status not = '00'
        move 'File close failed' to error-message perform fail-batch
    end-if
    move 'FINISH' to report-action perform call-report
    call 'COMMIT-DB' returning status-code
    if status-code not = 0
        move 'Database commit failed' to error-message perform fail-batch
    end-if
    move 1 to committed
    move z'data/output/emp_master_new.dat.tmp' to source-path
    move z'data/output/emp_master_new.dat' to target-path perform publish-file
    move z'data/output/payroll_report.txt.tmp' to source-path
    move z'data/output/payroll_report.txt' to target-path perform publish-file
    move z'data/output/results.psv.tmp' to source-path
    move z'data/output/results.psv' to target-path perform publish-file
    call 'CLOSE-DB' returning status-code move 0 to db-open
    if status-code not = 0
        move 'Database close failed after commit' to error-message perform fail-batch
    end-if
    call 'CBL_DELETE_FILE' using z'data/output/publication.pending'
        returning status-code
    if status-code not = 0
        move 'Cannot remove publication marker after commit'
            to error-message perform fail-batch
    end-if
    perform clean-spool
    display 'SUCCESS period=' run-period ' employees=' processed-count
    stop run returning 0.
read-master.
    read master-file
    evaluate master-status
        when '10' move 1 to master-eof exit paragraph
        when '00' continue
        when other
            move 'Malformed/truncated 100-byte employee record'
                to error-message perform fail-batch
    end-evaluate
    move master-disk(1:83) to EMP-MASTER-RECORD
    if EMP-ID is not numeric or EMP-ID <= previous-master
        move 'Employee keys must be unique and ascending'
            to error-message perform fail-batch
    end-if
    if EMP-PAY-RATE is not numeric or EMP-YTD-GROSS is not numeric
        or EMP-YTD-FED-TAX is not numeric or EMP-YTD-STATE-TAX is not numeric
        or EMP-YTD-FICA is not numeric or EMP-YTD-NET is not numeric
        move 'Invalid packed-decimal employee data' to error-message perform fail-batch
    end-if
    perform varying character-index from 7 by 1 until character-index > 40
        if master-disk(character-index:1) < space
            or master-disk(character-index:1) > '~'
            or master-disk(character-index:1) = '|'
            move 'Names/departments must be printable ASCII without pipes'
                to error-message perform fail-batch
        end-if
    end-perform
    if EMP-DEPT = spaces
        move 'Employee department is required' to error-message perform fail-batch
    end-if
    move EMP-ID to previous-master.
read-card.
    read card-file
    evaluate card-status
        when '10' move 1 to card-eof exit paragraph
        when '00' continue
        when other
            move 'Malformed/truncated 32-byte time card'
                to error-message perform fail-batch
    end-evaluate
    initialize TIME-CARD-RECORD
    move card-disk(1:22) to TIME-CARD-RECORD(1:22)
    if TC-EMP-ID is not numeric or TC-REG-HOURS is not numeric
        or TC-OT-HOURS is not numeric or TC-PAY-PERIOD-END is not numeric
        move 'Non-numeric time card' to error-message perform fail-batch
    end-if
    if TC-EMP-ID <= previous-card
        move 'Time-card keys must be unique and ascending'
            to error-message perform fail-batch
    end-if
    if test-date-yyyymmdd(TC-PAY-PERIOD-END) not = 0
        or card-disk(23:10) not = spaces
        move 'Invalid pay-period date or time-card padding'
            to error-message perform fail-batch
    end-if
    if run-period = 0 move TC-PAY-PERIOD-END to run-period end-if
    if TC-PAY-PERIOD-END not = run-period
        move 'Mixed pay periods are not allowed' to error-message perform fail-batch
    end-if
    move TC-EMP-ID to previous-card.
call-report.
    call 'REPORT-WRITER' using report-action report-input returning status-code
    if status-code not = 0
        move 'Report generation failed' to error-message perform fail-batch
    end-if.
publish-file.
    call 'CBL_DELETE_FILE' using target-path returning ignored-status
    call 'CBL_RENAME_FILE' using source-path target-path returning status-code
    if status-code not = 0
        move 'COMMITTED: output publication failed; recovery required'
            to error-message perform fail-batch
    end-if.
fail-batch.
    display 'ERROR ' trim(error-message) ' emp=' EMP-ID ' card=' TC-EMP-ID
    if master-open = 1 close master-file end-if
    if card-open = 1 close card-file end-if
    if new-open = 1 close new-master end-if
    move 'ABORT' to report-action
    call 'REPORT-WRITER' using report-action report-input returning ignored-status
    if db-open = 1 call 'CLOSE-DB' returning ignored-status end-if
    if marker-owned = 1 and committed = 0
        call 'CBL_DELETE_FILE' using z'data/output/emp_master_new.dat.tmp'
            returning ignored-status
        call 'CBL_DELETE_FILE' using z'data/output/payroll_report.txt.tmp'
            returning ignored-status
        call 'CBL_DELETE_FILE' using z'data/output/results.psv.tmp'
            returning ignored-status
        call 'CBL_DELETE_FILE' using z'data/output/publication.pending'
            returning ignored-status
        perform clean-spool
    end-if
    stop run returning 1.
clean-spool.
    call 'CBL_DELETE_FILE' using z'data/output/report_spool.tmp'
        returning ignored-status
    call 'CBL_DELETE_FILE' using z'data/output/report_sorted.tmp'
        returning ignored-status.
end program MAIN.
