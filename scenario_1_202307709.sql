-- 1. CREATE TABLES AND INSERT BOOKS
DROP TABLE IF EXISTS book_loans CASCADE;
DROP TABLE IF EXISTS books CASCADE;

CREATE TABLE books (
    book_id INTEGER PRIMARY KEY,
    book_title VARCHAR(100),
    author VARCHAR(100),
    available_copies INTEGER
);

CREATE TABLE book_loans (
    loan_id SERIAL PRIMARY KEY,
    book_id INTEGER REFERENCES books(book_id),
    student_number VARCHAR(20),
    quantity INTEGER,
    loan_status VARCHAR(20)
);

INSERT INTO books (book_id, book_title, author, available_copies)
VALUES
(1, 'Database Systems', 'Thomas Connolly', 5),
(2, 'Computer Networks', 'Andrew Tanenbaum', 2),
(3, 'Cyber Security', 'William Stallings', 0);


-- 2. IF ELSIF ELSE - CHECK BOOK STOCK
DO $$
DECLARE
    v_copies INTEGER;
BEGIN
    SELECT available_copies
    INTO v_copies
    FROM books
    WHERE book_id = 1;

    IF v_copies = 0 THEN
        RAISE NOTICE 'Book is unavailable';
    ELSIF v_copies <= 2 THEN
        RAISE NOTICE 'Book is low on copies';
    ELSE
        RAISE NOTICE 'Book is sufficiently stocked';
    END IF;
END
$$ LANGUAGE plpgsql;


-- 3. WHILE LOOP AND NUMERIC FOR LOOP
DO $$
DECLARE
    v_reminder INTEGER := 1;
BEGIN
    WHILE v_reminder <= 3 LOOP
        RAISE NOTICE 'Overdue reminder %', v_reminder;
        v_reminder := v_reminder + 1;
    END LOOP;

    FOR v_shelf IN 1..3 LOOP
        RAISE NOTICE 'Library shelf number %', v_shelf;
    END LOOP;
END
$$ LANGUAGE plpgsql;


-- 4. BORROW BOOK PROCEDURE
CREATE OR REPLACE PROCEDURE borrow_book(
    p_book_id INTEGER,
    p_student_number VARCHAR(20),
    p_quantity INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_available INTEGER;
BEGIN
    IF p_quantity <= 0 THEN
        RAISE EXCEPTION 'Quantity must be greater than zero';
    END IF;

    SELECT available_copies
    INTO v_available
    FROM books
    WHERE book_id = p_book_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE NOTICE 'Book does not exist';

    ELSIF v_available < p_quantity THEN
        RAISE NOTICE 'Not enough copies available. Only % copies remain',
            v_available;

    ELSE
        UPDATE books
        SET available_copies = available_copies - p_quantity
        WHERE book_id = p_book_id;

        INSERT INTO book_loans
        (book_id, student_number, quantity, loan_status)
        VALUES
        (p_book_id, p_student_number, p_quantity, 'BORROWED');

        RAISE NOTICE 'Book borrowed successfully by student %',
            p_student_number;
    END IF;
END;
$$;


-- 5. TEST THE BORROW PROCEDURE
-- Two valid loans
CALL borrow_book(1, 'STU001', 2);

CALL borrow_book(2, 'STU002', 1);

-- Request exceeding available copies
CALL borrow_book(3, 'STU003', 5);

-- Display tables
SELECT * FROM books;

SELECT * FROM book_loans;


-- 6. RETURN BOOK PROCEDURE
CREATE OR REPLACE PROCEDURE return_book(
    p_loan_id INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_book_id INTEGER;
    v_quantity INTEGER;
    v_status VARCHAR(20);
BEGIN
    SELECT book_id, quantity, loan_status
    INTO v_book_id, v_quantity, v_status
    FROM book_loans
    WHERE loan_id = p_loan_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE NOTICE 'Loan does not exist';

    ELSIF v_status = 'RETURNED' THEN
        RAISE NOTICE 'Loan % has already been returned',
            p_loan_id;

    ELSE
        UPDATE books
        SET available_copies = available_copies + v_quantity
        WHERE book_id = v_book_id;

        UPDATE book_loans
        SET loan_status = 'RETURNED'
        WHERE loan_id = p_loan_id;

        RAISE NOTICE 'Loan % returned successfully',
            p_loan_id;
    END IF;
END;
$$;


-- Call twice on the same loan
CALL return_book(1);

CALL return_book(1);

-- Check results
SELECT * FROM books;

SELECT * FROM book_loans;


-- 7. EXPLICIT CURSOR
DO $$
DECLARE
    book_cursor CURSOR FOR
        SELECT book_id, book_title, available_copies
        FROM books
        WHERE available_copies <= 2;

    v_book_id INTEGER;
    v_book_title VARCHAR(100);
    v_copies INTEGER;
BEGIN
    OPEN book_cursor;

    LOOP
        FETCH book_cursor
        INTO v_book_id, v_book_title, v_copies;

        EXIT WHEN NOT FOUND;

        RAISE NOTICE
            'Book ID: %, Title: %, Copies remaining: %',
            v_book_id, v_book_title, v_copies;
    END LOOP;

    CLOSE book_cursor;
END
$$ LANGUAGE plpgsql;


-- 8. BORROW ZERO COPIES AND HANDLE EXCEPTION
DO $$
BEGIN
    BEGIN
        CALL borrow_book(1, 'STU004', 0);

    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Invalid quantity: %', SQLERRM;
    END;
END
$$ LANGUAGE plpgsql;


-- 9. FINAL QUERIES
SELECT
    book_id,
    book_title,
    author,
    available_copies
FROM books
ORDER BY book_id;

SELECT
    loan_id,
    book_id,
    student_number,
    quantity,
    loan_status
FROM book_loans
ORDER BY loan_id;