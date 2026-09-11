identification division.
program-id. DB-LOGGER.
environment division.
configuration section.
repository. function all intrinsic.
input-output section.
file-control.
    select schema-file assign to 'schema.sql'
        organization line sequential file status schema-status.
data division.
file section.
fd schema-file.
01 schema-line pic x(512).
working-storage section.
copy 'SQLITE-STATUS.cpy'.
copy 'LEDGER-ENTRY.cpy'.
01 schema-status pic xx.
01 sql-text pic x(16384).
01 sql-position binary-long.
01 schema-done binary-char unsigned.
01 transaction-open binary-char unsigned value 0.
01 registered-period pic 9(8) value 0.
01 saved-rc usage binary-long.
01 close-rc usage binary-long.
01 account-index binary-long.
01 debit-text pic 9(7).99.
01 credit-text pic 9(7).99.
01 null-pointer usage pointer value null.
linkage section.
copy 'TIME-CARD.cpy'.
copy 'EMP-RECORD.cpy'.
copy 'CALC-RESULT.cpy'.
procedure division.
    goback returning 1.
entry 'INIT-DB'.
    if SQLITE-HANDLE not = null goback returning 1 end-if
    move 0 to registered-period transaction-open
    call static "sqlite3_open" using
        by reference z'data/payroll.db'
        by reference SQLITE-HANDLE returning SQLITE-RC
    if SQLITE-RC not = SQLITE-OK
        perform show-error
        perform close-connection
        goback returning 1
    end-if
    move z'PRAGMA busy_timeout=5000;' to sql-text
    perform execute-sql
    if SQLITE-RC not = SQLITE-OK
        perform close-connection goback returning 1
    end-if
    move spaces to sql-text
    move 1 to sql-position
    move 0 to schema-done
    open input schema-file
    if schema-status not = '00'
        display 'ERROR opening schema.sql: ' schema-status
        perform close-connection goback returning 1
    end-if
    perform until schema-done = 1
        read schema-file
        evaluate schema-status
            when '10' move 1 to schema-done
            when '00'
                string trim(schema-line) x'0a'
                    into sql-text pointer sql-position
                    on overflow move 2 to schema-done
                end-string
            when other move 2 to schema-done
        end-evaluate
        if schema-done = 2
            display 'ERROR reading schema or DDL exceeds 16 KiB'
            close schema-file
            perform close-connection goback returning 1
        end-if
    end-perform
    close schema-file
    if sql-position > length(sql-text)
        perform close-connection goback returning 1
    end-if
    move low-value to sql-text(sql-position:1)
    perform execute-sql
    if SQLITE-RC not = SQLITE-OK
        perform close-connection goback returning 1
    end-if
    move z'BEGIN IMMEDIATE;' to sql-text
    perform execute-sql
    if SQLITE-RC not = SQLITE-OK
        perform close-connection goback returning 1
    end-if
    move 1 to transaction-open
    goback returning 0.
entry 'LOG-TRANSACTION' using TIME-CARD-RECORD EMP-MASTER-RECORD CALC-RESULT.
    if transaction-open not = 1 or TC-PAY-PERIOD-END is not numeric
        or EMP-ID is not numeric
        goback returning 1
    end-if
    if registered-period = 0
        move spaces to sql-text
        string "INSERT INTO payroll_runs(pay_period) VALUES('"
            TC-PAY-PERIOD-END "');" x'00' into sql-text
        end-string
        perform execute-sql
        if SQLITE-RC not = SQLITE-OK goback returning 1 end-if
        move TC-PAY-PERIOD-END to registered-period
    end-if
    if registered-period not = TC-PAY-PERIOD-END goback returning 1 end-if
    move TC-PAY-PERIOD-END to LE-PAY-PERIOD
    move EMP-ID to LE-EMP-ID
    perform varying account-index from 1 by 1 until account-index > 5
        move 0 to LE-DEBIT-AMOUNT LE-CREDIT-AMOUNT
        evaluate account-index
            when 1 move '5001' to LE-ACCOUNT-CODE
                move CALC-GROSS-PAY to LE-DEBIT-AMOUNT
            when 2 move '2101' to LE-ACCOUNT-CODE
                move CALC-FED-TAX to LE-CREDIT-AMOUNT
            when 3 move '2102' to LE-ACCOUNT-CODE
                move CALC-STATE-TAX to LE-CREDIT-AMOUNT
            when 4 move '2103' to LE-ACCOUNT-CODE
                move CALC-FICA-TAX to LE-CREDIT-AMOUNT
            when 5 move '1001' to LE-ACCOUNT-CODE
                move CALC-NET-PAY to LE-CREDIT-AMOUNT
        end-evaluate
        move LE-DEBIT-AMOUNT to debit-text
        move LE-CREDIT-AMOUNT to credit-text
        move spaces to sql-text
        string 'INSERT INTO general_ledger(pay_period,emp_id,account_code,'
            "debit_amount,credit_amount) VALUES('" LE-PAY-PERIOD "',"
            LE-EMP-ID ",'" trim(LE-ACCOUNT-CODE) "',"
            debit-text ',' credit-text ');' x'00' into sql-text
        end-string
        perform execute-sql
        if SQLITE-RC not = SQLITE-OK goback returning 1 end-if
    end-perform
    goback returning 0.
entry 'COMMIT-DB'.
    if transaction-open not = 1 goback returning 1 end-if
    move z'COMMIT;' to sql-text
    perform execute-sql
    if SQLITE-RC not = SQLITE-OK goback returning 1 end-if
    move 0 to transaction-open
    goback returning 0.
entry 'CLOSE-DB'.
    move 0 to saved-rc
    if transaction-open = 1
        move z'ROLLBACK;' to sql-text
        perform execute-sql
        move SQLITE-RC to saved-rc
        move 0 to transaction-open
    end-if
    perform close-connection
    if saved-rc not = 0 or close-rc not = 0 goback returning 1 end-if
    goback returning 0.
execute-sql.
    call static 'sqlite3_exec' using by value SQLITE-HANDLE
        by reference sql-text by value null-pointer null-pointer
        by reference SQLITE-ERR-MSG returning SQLITE-RC
    if SQLITE-RC not = SQLITE-OK perform show-error end-if
    if SQLITE-ERR-MSG not = null
        call static 'sqlite3_free' using by value SQLITE-ERR-MSG
        move null to SQLITE-ERR-MSG
    end-if.
show-error.
    display 'ERROR SQLite status ' SQLITE-RC
        ' (19 can indicate an already-posted pay period)'.
close-connection.
    move 0 to close-rc
    if SQLITE-HANDLE not = null
        call static 'sqlite3_close' using by value SQLITE-HANDLE
            returning close-rc
        if close-rc = 0 move null to SQLITE-HANDLE end-if
    end-if.
end program DB-LOGGER.
