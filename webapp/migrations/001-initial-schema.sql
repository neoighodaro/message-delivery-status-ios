-- Up
CREATE TABLE Messages (
    ID INTEGER NOT NULL,
    Message TEXT,
    Sender VARCHAR(50),
    PRIMARY KEY (ID)
);

-- Down
DROP TABLE Messages;