identification division.
program-id. REPORT-WRITER.
environment division.
configuration section.
repository. function all intrinsic.
input-output section.
file-control.
    select spool-file assign to 'data/output/report_spool.tmp'
        organization sequential file status spool-status.
    select sorted-file assign to 'data/output/report_sorted.tmp'
        organization sequential file status sorted-status.
    select sort-work assign to 'data/output/report_sort.tmp'.
    select report-file assign to 'data/output/payroll_report.txt.tmp'
        organization line sequential file status report-status.
    select result-file assign to 'data/output/results.psv.tmp'
        organization line sequential file status result-status.
data division.
file section.
fd spool-file.
01 spool-record pic x(162).
fd sorted-file.
01 sorted-record pic x(162).
sd sort-work.
01 sort-record.
   05 sort-dept pic x(4).
   05 sort-emp-id pic 9(6).
   05 sort-payload pic x(152).
fd report-file.
01 report-line pic x(160).
fd result-file.
01 result-line pic x(300).
working-storage section.
copy 'EMP-RECORD.cpy'.
copy 'TIME-CARD.cpy'.
copy 'CALC-RESULT.cpy'.
01 spool-status pic xx.
01 sorted-status pic xx.
01 report-status pic xx.
01 result-status pic xx.
01 report-open binary-char unsigned value 0.
01 spool-open binary-char unsigned value 0.
01 output-open binary-char unsigned value 0.
01 report-failed binary-char unsigned value 0.
01 end-sorted binary-char unsigned.
01 page-number pic 9(4).
01 line-count binary-long.
01 run-timestamp pic x(21).
01 current-department pic x(4).
01 employee-count pic 9(6).
01 department-count pic 9(6).
01 detail-taxes pic 9(7)v99 comp-3.
01 total-gross pic 9(13)v99 comp-3.
01 total-taxes pic 9(13)v99 comp-3.
01 total-net pic 9(13)v99 comp-3.
01 total-credits pic 9(13)v99 comp-3.
01 department-gross pic 9(13)v99 comp-3.
01 department-taxes pic 9(13)v99 comp-3.
01 department-net pic 9(13)v99 comp-3.
01 money-gross pic $$,$$$,$$$,$$$,$$9.99.
01 money-taxes pic $$,$$$,$$$,$$$,$$9.99.
01 money-net pic $$,$$$,$$$,$$$,$$9.99.
01 regular-hours pic z9.99.
01 overtime-hours pic z9.99.
01 plain-hours pic 99.99.
01 plain-ot pic 99.99.
01 plain-money.
   05 plain-reg pic 9(6).99.
   05 plain-overtime pic 9(6).99.
   05 plain-gross pic 9(6).99.
   05 plain-fed pic 9(6).99.
   05 plain-state pic 9(6).99.
   05 plain-fica pic 9(6).99.
   05 plain-net pic 9(6).99.
linkage section.
01 report-action pic x(8).
01 report-input pic x(152).
procedure division using report-action report-input.
    evaluate report-action
        when 'OPEN'
            if report-open = 1 goback returning 1 end-if
            move 0 to report-failed employee-count department-count
                page-number line-count total-gross total-taxes total-net
                department-gross department-taxes department-net
            move spaces to current-department
            move current-date to run-timestamp
            open output spool-file
            if spool-status not = '00' goback returning 1 end-if
            move 1 to spool-open report-open
        when 'DETAIL'
            if spool-open not = 1 goback returning 1 end-if
            move report-input(37:4) to spool-record(1:4)
            move report-input(1:6) to spool-record(5:6)
            move report-input to spool-record(11:152)
            write spool-record
            if spool-status not = '00' move 1 to report-failed end-if
        when 'FINISH'
            if spool-open not = 1 goback returning 1 end-if
            close spool-file move 0 to spool-open
            if spool-status not = '00' goback returning 1 end-if
            sort sort-work on ascending key sort-dept sort-emp-id
                using spool-file giving sorted-file
            if sort-return not = 0 goback returning 1 end-if
            perform generate-report
            move 0 to report-open
        when 'ABORT'
            if spool-open = 1 close spool-file end-if
            move 0 to spool-open report-open
        when other goback returning 1
    end-evaluate
    goback returning report-failed.
generate-report.
    open input sorted-file
    if sorted-status not = '00' move 1 to report-failed exit paragraph end-if
    open output report-file result-file
    if report-status = '00' and result-status = '00'
        move 1 to output-open
    else
        if report-status = '00' close report-file end-if
        if result-status = '00' close result-file end-if
        close sorted-file move 1 to report-failed exit paragraph
    end-if
    move 'period|id|lastName|firstName|department|regularHours|overtimeHours|regularPay|overtimePay|gross|federal|state|fica|net'
        to result-line
    write result-line
    if result-status not = '00' move 1 to report-failed end-if
    perform page-header
    move 0 to end-sorted
    perform until end-sorted = 1 or report-failed = 1
        read sorted-file
        evaluate sorted-status
            when '10' move 1 to end-sorted
            when '00'
                move sorted-record(11:83) to EMP-MASTER-RECORD
                move sorted-record(94:34) to TIME-CARD-RECORD
                move sorted-record(128:35) to CALC-RESULT
                perform detail-line
            when other move 1 to report-failed
        end-evaluate
    end-perform
    if employee-count > 0 perform department-footer end-if
    if line-count > 51 perform page-header end-if
    move all '=' to report-line perform emit-line
    move total-gross to money-gross move total-taxes to money-taxes
    move total-net to money-net
    move spaces to report-line
    string 'GRAND TOTAL | EMPLOYEES ' employee-count
        ' | GROSS ' trim(money-gross) ' | TAXES ' trim(money-taxes)
        ' | NET ' trim(money-net) into report-line
    end-string
    perform emit-line
    compute total-credits = total-taxes + total-net
    move total-credits to money-net
    move spaces to report-line
    if total-gross = total-credits
        string 'BALANCED | DEBITS ' trim(money-gross)
            ' = CREDITS ' trim(money-net) into report-line end-string
    else
        move 'OUT OF BALANCE' to report-line move 1 to report-failed
    end-if
    perform emit-line
    close sorted-file report-file result-file
    move 0 to output-open
    if sorted-status not = '00' or report-status not = '00'
        or result-status not = '00' move 1 to report-failed end-if.
page-header.
    if page-number > 0
        move spaces to report-line
        write report-line after advancing page
        if report-status not = '00' move 1 to report-failed end-if
    end-if
    add 1 to page-number
    move 0 to line-count
    move spaces to report-line
    string 'PayrollOBOL | PAYROLL REGISTER' ' | PAGE ' page-number
        ' | RUN ' run-timestamp(1:4) '-' run-timestamp(5:2) '-'
        run-timestamp(7:2) ' ' run-timestamp(9:2) ':'
        run-timestamp(11:2) ':' run-timestamp(13:2) into report-line
    end-string
    perform emit-line
    move 'EMP ID  NAME                            DEPT  REG HRS OT HRS                 GROSS                 TAXES                   NET'
        to report-line perform emit-line
    move all '-' to report-line perform emit-line.
detail-line.
    if department-count > 0 and current-department not = EMP-DEPT
        perform department-footer
    end-if
    if department-count = 0 move EMP-DEPT to current-department end-if
    if line-count >= 55 perform page-header end-if
    compute detail-taxes = CALC-FED-TAX + CALC-STATE-TAX + CALC-FICA-TAX
    add 1 to employee-count department-count
    add CALC-GROSS-PAY to total-gross department-gross
    add detail-taxes to total-taxes department-taxes
    add CALC-NET-PAY to total-net department-net
    move CALC-GROSS-PAY to money-gross move detail-taxes to money-taxes
    move CALC-NET-PAY to money-net
    move TC-REG-HOURS to regular-hours move TC-OT-HOURS to overtime-hours
    move spaces to report-line
    string EMP-ID '  ' EMP-LAST-NAME ' ' EMP-FIRST-NAME '  '
        EMP-DEPT '  ' regular-hours '  ' overtime-hours '  '
        money-gross '  ' money-taxes '  ' money-net into report-line
    end-string
    perform emit-line
    move TC-REG-HOURS to plain-hours move TC-OT-HOURS to plain-ot
    move CALC-REG-PAY to plain-reg move CALC-OT-PAY to plain-overtime
    move CALC-GROSS-PAY to plain-gross move CALC-FED-TAX to plain-fed
    move CALC-STATE-TAX to plain-state move CALC-FICA-TAX to plain-fica
    move CALC-NET-PAY to plain-net
    move spaces to result-line
    string TC-PAY-PERIOD-END '|' EMP-ID '|' trim(EMP-LAST-NAME) '|'
        trim(EMP-FIRST-NAME) '|' trim(EMP-DEPT) '|' plain-hours '|'
        plain-ot '|' plain-reg '|' plain-overtime '|' plain-gross '|'
        plain-fed '|' plain-state '|' plain-fica '|' plain-net
        into result-line
    end-string
    write result-line
    if result-status not = '00' move 1 to report-failed end-if.
department-footer.
    if line-count >= 54 perform page-header end-if
    move department-gross to money-gross
    move department-taxes to money-taxes move department-net to money-net
    move spaces to report-line
    string 'DEPARTMENT ' current-department ' | EMPLOYEES ' department-count
        ' | GROSS ' trim(money-gross) ' | TAXES ' trim(money-taxes)
        ' | NET ' trim(money-net) into report-line
    end-string
    perform emit-line
    move spaces to report-line perform emit-line
    move 0 to department-count department-gross department-taxes department-net.
emit-line.
    write report-line
    if report-status not = '00' move 1 to report-failed end-if
    add 1 to line-count.
end program REPORT-WRITER.
