-- ============================================
-- ICT371 ASSIGNMENT 4
-- SCENARIO 5: ENGINEERING WORKSHOP TOOL LOANS
-- ============================================

-- 1. CREATE TABLES AND INSERT TOOLS

DROP TABLE IF EXISTS tool_loans CASCADE;
DROP TABLE IF EXISTS tools CASCADE;

CREATE TABLE tools (
    tool_id INTEGER PRIMARY KEY,
    tool_name VARCHAR(100),
    tool_type VARCHAR(100),
    available_quantity INTEGER
);

CREATE TABLE tool_loans (
    loan_id SERIAL PRIMARY KEY,
    tool_id INTEGER REFERENCES tools(tool_id),
    student_number VARCHAR(20),
    quantity INTEGER,
    loan_status VARCHAR(20)
);

INSERT INTO tools
(tool_id, tool_name, tool_type, available_quantity)
VALUES
(1, 'Hammer', 'Hand Tool', 10),
(2, 'Screwdriver Set', 'Hand Tool', 3),
(3, 'Electric Drill', 'Power Tool', 0);

SELECT * FROM tools;


-- 2. IF ELSIF ELSE
-- Check whether tools are unavailable,
-- low in quantity, or readily available.

DO $$
DECLARE
    v_quantity INTEGER;
BEGIN

    SELECT available_quantity
    INTO v_quantity
    FROM tools
    WHERE tool_id = 2;

    IF v_quantity = 0 THEN
        RAISE NOTICE 'Tool is unavailable';

    ELSIF v_quantity <= 3 THEN
        RAISE NOTICE 'Tool quantity is low';

    ELSE
        RAISE NOTICE 'Tool is readily available';
    END IF;

END
$$ LANGUAGE plpgsql;


-- 3. WHILE LOOP AND NUMERIC FOR LOOP

DO $$
DECLARE
    v_reminder INTEGER := 1;
BEGIN

    WHILE v_reminder <= 3 LOOP
        RAISE NOTICE 'Workshop safety reminder %', v_reminder;
        v_reminder := v_reminder + 1;
    END LOOP;

    FOR v_tool IN 1..3 LOOP
        RAISE NOTICE 'Tool inspection number %', v_tool;
    END LOOP;

END
$$ LANGUAGE plpgsql;


-- 4. ISSUE TOOL PROCEDURE

CREATE OR REPLACE PROCEDURE issue_tool(
    p_tool_id INTEGER,
    p_student_number VARCHAR(20),
    p_quantity INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_available INTEGER;
BEGIN

    IF p_quantity <= 0 THEN
        RAISE EXCEPTION 'Tool quantity must be greater than zero';
    END IF;

    SELECT available_quantity
    INTO v_available
    FROM tools
    WHERE tool_id = p_tool_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE NOTICE 'Tool does not exist';

    ELSIF v_available < p_quantity THEN
        RAISE NOTICE
            'Not enough tools available. Only % remain',
            v_available;

    ELSE

        UPDATE tools
        SET available_quantity =
            available_quantity - p_quantity
        WHERE tool_id = p_tool_id;

        INSERT INTO tool_loans
        (
            tool_id,
            student_number,
            quantity,
            loan_status
        )
        VALUES
        (
            p_tool_id,
            p_student_number,
            p_quantity,
            'ISSUED'
        );

        RAISE NOTICE
            'Tool issued successfully to student %',
            p_student_number;

    END IF;

END;
$$;


-- 5. TEST THE ISSUE TOOL PROCEDURE

-- Two valid tool loans
CALL issue_tool(1, 'STU001', 2);

CALL issue_tool(2, 'STU002', 1);

-- Request exceeding available stock
CALL issue_tool(3, 'STU003', 5);

-- Display tools
SELECT * FROM tools;

-- Display tool loans
SELECT * FROM tool_loans;


-- 6. RETURN TOOL PROCEDURE

CREATE OR REPLACE PROCEDURE return_tool(
    p_loan_id INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_tool_id INTEGER;
    v_quantity INTEGER;
    v_status VARCHAR(20);
BEGIN

    SELECT
        tool_id,
        quantity,
        loan_status
    INTO
        v_tool_id,
        v_quantity,
        v_status
    FROM tool_loans
    WHERE loan_id = p_loan_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE NOTICE 'Tool loan does not exist';

    ELSIF v_status = 'RETURNED' THEN
        RAISE NOTICE
            'Tool loan % has already been returned',
            p_loan_id;

    ELSE

        UPDATE tools
        SET available_quantity =
            available_quantity + v_quantity
        WHERE tool_id = v_tool_id;

        UPDATE tool_loans
        SET loan_status = 'RETURNED'
        WHERE loan_id = p_loan_id;

        RAISE NOTICE
            'Tool loan % returned successfully',
            p_loan_id;

    END IF;

END;
$$;


-- Call twice on the same loan
CALL return_tool(1);

CALL return_tool(1);

-- Check results
SELECT * FROM tools;

SELECT * FROM tool_loans;


-- 7. EXPLICIT CURSOR
-- Display tools with low availability.

DO $$
DECLARE
    tool_cursor CURSOR FOR
        SELECT
            tool_id,
            tool_name,
            available_quantity
        FROM tools
        WHERE available_quantity <= 3;

    v_tool_id INTEGER;
    v_tool_name VARCHAR(100);
    v_quantity INTEGER;
BEGIN

    OPEN tool_cursor;

    LOOP

        FETCH tool_cursor
        INTO v_tool_id,
             v_tool_name,
             v_quantity;

        EXIT WHEN NOT FOUND;

        RAISE NOTICE
            'Tool ID: %, Tool: %, Quantity remaining: %',
            v_tool_id,
            v_tool_name,
            v_quantity;

    END LOOP;

    CLOSE tool_cursor;

END
$$ LANGUAGE plpgsql;


-- 8. ISSUE ZERO TOOLS AND HANDLE EXCEPTION

DO $$
BEGIN

    BEGIN

        CALL issue_tool(
            1,
            'STU004',
            0
        );

    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE
                'Invalid tool quantity: %',
                SQLERRM;
    END;

END
$$ LANGUAGE plpgsql;


-- 9. FINAL QUERIES

SELECT
    tool_id,
    tool_name,
    tool_type,
    available_quantity
FROM tools
ORDER BY tool_id;

SELECT
    loan_id,
    tool_id,
    student_number,
    quantity,
    loan_status
FROM tool_loans
ORDER BY loan_id;