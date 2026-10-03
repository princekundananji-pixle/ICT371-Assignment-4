-- 1. CREATE TABLES AND INSERT HOSTEL ROOMS

DROP TABLE IF EXISTS allocations CASCADE;
DROP TABLE IF EXISTS hostel_rooms CASCADE;

CREATE TABLE hostel_rooms (
    room_id INTEGER PRIMARY KEY,
    room_number VARCHAR(20),
    hostel_name VARCHAR(100),
    available_bed_spaces INTEGER
);

CREATE TABLE allocations (
    allocation_id SERIAL PRIMARY KEY,
    room_id INTEGER REFERENCES hostel_rooms(room_id),
    student_number VARCHAR(20),
    allocation_status VARCHAR(20)
);

INSERT INTO hostel_rooms
(room_id, room_number, hostel_name, available_bed_spaces)
VALUES
(1, 'A101', 'Mulungushi Hostel', 4),
(2, 'B202', 'Mulungushi Hostel', 1),
(3, 'C303', 'Mulungushi Hostel', 0);

SELECT * FROM hostel_rooms;


-- 2. IF ELSIF ELSE
-- Check whether a room is full, has one space,
-- or has several spaces.

DO $$
DECLARE
    v_spaces INTEGER;
BEGIN

    SELECT available_bed_spaces
    INTO v_spaces
    FROM hostel_rooms
    WHERE room_id = 2;

    IF v_spaces = 0 THEN
        RAISE NOTICE 'Room is full';

    ELSIF v_spaces = 1 THEN
        RAISE NOTICE 'Room has one available bed space';

    ELSE
        RAISE NOTICE 'Room has several available bed spaces';
    END IF;

END
$$ LANGUAGE plpgsql;


-- 3. WHILE LOOP AND NUMERIC FOR LOOP

DO $$
DECLARE
    v_day INTEGER := 1;
BEGIN

    WHILE v_day <= 3 LOOP
        RAISE NOTICE 'Hostel inspection day %', v_day;
        v_day := v_day + 1;
    END LOOP;

    FOR v_room IN 1..3 LOOP
        RAISE NOTICE 'Room check number %', v_room;
    END LOOP;

END
$$ LANGUAGE plpgsql;


-- 4. ALLOCATE ROOM PROCEDURE

CREATE OR REPLACE PROCEDURE allocate_room(
    p_room_id INTEGER,
    p_student_number VARCHAR(20)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_available INTEGER;
BEGIN

    IF p_student_number IS NULL
       OR TRIM(p_student_number) = '' THEN
        RAISE EXCEPTION 'Student number cannot be blank';
    END IF;

    SELECT available_bed_spaces
    INTO v_available
    FROM hostel_rooms
    WHERE room_id = p_room_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE NOTICE 'Hostel room does not exist';

    ELSIF v_available <= 0 THEN
        RAISE NOTICE 'No available bed spaces in this room';

    ELSE

        UPDATE hostel_rooms
        SET available_bed_spaces =
            available_bed_spaces - 1
        WHERE room_id = p_room_id;

        INSERT INTO allocations
        (
            room_id,
            student_number,
            allocation_status
        )
        VALUES
        (
            p_room_id,
            p_student_number,
            'ALLOCATED'
        );

        RAISE NOTICE
            'Room allocated successfully to student %',
            p_student_number;

    END IF;

END;
$$;


-- 5. TEST THE ALLOCATION PROCEDURE

-- Two valid allocations
CALL allocate_room(1, 'STU001');

CALL allocate_room(2, 'STU002');

-- Attempt to allocate a full room
CALL allocate_room(3, 'STU003');

-- Display hostel rooms
SELECT * FROM hostel_rooms;

-- Display allocations
SELECT * FROM allocations;


-- 6. CHECK-OUT PROCEDURE

CREATE OR REPLACE PROCEDURE check_out(
    p_allocation_id INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_room_id INTEGER;
    v_status VARCHAR(20);
BEGIN

    SELECT
        room_id,
        allocation_status
    INTO
        v_room_id,
        v_status
    FROM allocations
    WHERE allocation_id = p_allocation_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE NOTICE 'Allocation does not exist';

    ELSIF v_status = 'COMPLETED' THEN
        RAISE NOTICE
            'Allocation % has already been completed',
            p_allocation_id;

    ELSE

        UPDATE hostel_rooms
        SET available_bed_spaces =
            available_bed_spaces + 1
        WHERE room_id = v_room_id;

        UPDATE allocations
        SET allocation_status = 'COMPLETED'
        WHERE allocation_id = p_allocation_id;

        RAISE NOTICE
            'Student checked out successfully from allocation %',
            p_allocation_id;

    END IF;

END;
$$;


-- Call twice on the same allocation
CALL check_out(1);

CALL check_out(1);

-- Check results
SELECT * FROM hostel_rooms;

SELECT * FROM allocations;


-- 7. EXPLICIT CURSOR
-- Display rooms that are full or nearly full.

DO $$
DECLARE
    room_cursor CURSOR FOR
        SELECT
            room_id,
            room_number,
            available_bed_spaces
        FROM hostel_rooms
        WHERE available_bed_spaces <= 1;

    v_room_id INTEGER;
    v_room_number VARCHAR(20);
    v_spaces INTEGER;
BEGIN

    OPEN room_cursor;

    LOOP

        FETCH room_cursor
        INTO v_room_id,
             v_room_number,
             v_spaces;

        EXIT WHEN NOT FOUND;

        RAISE NOTICE
            'Room ID: %, Room: %, Available spaces: %',
            v_room_id,
            v_room_number,
            v_spaces;

    END LOOP;

    CLOSE room_cursor;

END
$$ LANGUAGE plpgsql;


-- 8. BLANK STUDENT NUMBER AND EXCEPTION HANDLING

DO $$
BEGIN

    BEGIN

        CALL allocate_room(
            1,
            ''
        );

    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE
                'Invalid student number: %',
                SQLERRM;
    END;

END
$$ LANGUAGE plpgsql;


-- 9. FINAL QUERIES

SELECT
    room_id,
    room_number,
    hostel_name,
    available_bed_spaces
FROM hostel_rooms
ORDER BY room_id;

SELECT
    allocation_id,
    room_id,
    student_number,
    allocation_status
FROM allocations
ORDER BY allocation_id;