identification division.
program-id. SEED-DATA.
environment division.
input-output section.
file-control.
    select master-file assign to 'data/input/emp_master.dat'
        organization sequential access sequential file status master-status.
    select card-file assign to 'data/input/timecards.dat'
        organization sequential access sequential file status card-status.
data division.
file section.
fd master-file.
01 master-disk pic x(100).
fd card-file.
01 card-disk pic x(32).
working-storage section.
copy 'EMP-RECORD.cpy'.
copy 'TIME-CARD.cpy'.
01 master-status pic xx.
01 card-status pic xx.
01 employee-number binary-long.
01 existing-file binary-char unsigned value 0.
procedure division.
    open input master-file
    evaluate master-status
        when '00' close master-file move 1 to existing-file
        when '35' continue
        when other display 'ERROR inspecting master: ' master-status
            stop run returning 1
    end-evaluate
    open input card-file
    evaluate card-status
        when '00' close card-file move 1 to existing-file
        when '35' continue
        when other display 'ERROR inspecting time cards: ' card-status
            stop run returning 1
    end-evaluate
    if existing-file = 1
        display 'ERROR seed refuses to overwrite existing input files'
        stop run returning 1
    end-if
    open output master-file card-file
    if master-status not = '00' or card-status not = '00'
        display 'ERROR opening seed output: ' master-status ' ' card-status
        stop run returning 1
    end-if
    perform varying employee-number from 1 by 1 until employee-number > 3
        initialize EMP-MASTER-RECORD TIME-CARD-RECORD
        compute EMP-ID = 100100 + employee-number
        move EMP-ID to TC-EMP-ID
        move 20260915 to TC-PAY-PERIOD-END
        move 40 to TC-REG-HOURS
        evaluate employee-number
            when 1
                move 'Morgan' to EMP-LAST-NAME move 'Alex' to EMP-FIRST-NAME
                move 'ENG' to EMP-DEPT move 32.50 to EMP-PAY-RATE
                move 5 to TC-OT-HOURS
            when 2
                move 'Chen' to EMP-LAST-NAME move 'Jordan' to EMP-FIRST-NAME
                move 'OPS' to EMP-DEPT move 28 to EMP-PAY-RATE
                move 37.50 to TC-REG-HOURS
            when 3
                move 'Patel' to EMP-LAST-NAME move 'Sam' to EMP-FIRST-NAME
                move 'ENG' to EMP-DEPT move 35 to EMP-PAY-RATE
                move 10 to TC-OT-HOURS
        end-evaluate
        move spaces to master-disk card-disk
        move EMP-MASTER-RECORD to master-disk(1:83)
        move TIME-CARD-RECORD(1:22) to card-disk(1:22)
        write master-disk write card-disk
        if master-status not = '00' or card-status not = '00'
            display 'ERROR writing seed: ' master-status ' ' card-status
            stop run returning 1
        end-if
    end-perform
    close master-file card-file
    if master-status not = '00' or card-status not = '00'
        display 'ERROR closing seed files' stop run returning 1
    end-if
    display 'Seeded 3 employees and 3 time cards for 2026-09-15'
    stop run returning 0.
end program SEED-DATA.
