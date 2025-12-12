CREATE TYPE check_status AS ENUM ('Start', 'Success', 'Failure');

-- Таблица Peers
CREATE TABLE peers (
    nickname VARCHAR PRIMARY KEY,
    birthday DATE NOT NULL
);

-- Таблица Tasks
CREATE TABLE tasks (
    title VARCHAR PRIMARY KEY,
    parenttask VARCHAR DEFAULT NULL,
    maxxp INTEGER NOT NULL,
    FOREIGN KEY (parenttask) REFERENCES tasks(title)
);

-- Таблица Checks
CREATE TABLE checks (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    peer VARCHAR NOT NULL,
    task VARCHAR NOT NULL,
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    FOREIGN KEY (peer) REFERENCES peers(nickname),
    FOREIGN KEY (task) REFERENCES tasks(title)
);

-- Таблица P2P
CREATE TABLE p2p (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    check_id BIGINT NOT NULL,
    checkingpeer VARCHAR NOT NULL,
    state check_status NOT NULL,
    time TIME NOT NULL DEFAULT CURRENT_TIME,
    FOREIGN KEY (check_id) REFERENCES checks(id),
    FOREIGN KEY (checkingpeer) REFERENCES peers(nickname)
);

-- Таблица Verter
CREATE TABLE verter (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    check_id BIGINT NOT NULL,
    state check_status NOT NULL,
    time TIME NOT NULL DEFAULT CURRENT_TIME,
    FOREIGN KEY (check_id) REFERENCES checks(id)
);

-- Таблица TransferredPoints
CREATE TABLE transferredpoints (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    checkingpeer VARCHAR NOT NULL,
    checkedpeer VARCHAR NOT NULL,
    pointsamount INTEGER NOT NULL DEFAULT 1,
    FOREIGN KEY (checkingpeer) REFERENCES peers(nickname),
    FOREIGN KEY (checkedpeer) REFERENCES peers(nickname)
);

-- Таблица Friends
CREATE TABLE friends (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    peer1 VARCHAR NOT NULL,
    peer2 VARCHAR NOT NULL,
    FOREIGN KEY (peer1) REFERENCES peers(nickname),
    FOREIGN KEY (peer2) REFERENCES peers(nickname),
    CHECK (peer1 <> peer2)
);

-- Таблица Recommendations
CREATE TABLE recommendations (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    peer VARCHAR NOT NULL,
    recommendedpeer VARCHAR NOT NULL,
    FOREIGN KEY (peer) REFERENCES peers(nickname),
    FOREIGN KEY (recommendedpeer) REFERENCES peers(nickname),
    CHECK (peer <> recommendedpeer)
);

-- Таблица XP
CREATE TABLE xp (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    check_id BIGINT NOT NULL,
    xpamount INTEGER NOT NULL,
    FOREIGN KEY (check_id) REFERENCES checks(id)
);

-- Таблица TimeTracking
CREATE TABLE timetracking (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    peer VARCHAR NOT NULL,
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    time TIME NOT NULL DEFAULT CURRENT_TIME,
    state INTEGER NOT NULL CHECK (state IN (1, 2)),
    FOREIGN KEY (peer) REFERENCES peers(nickname)
);

-- Создание индексов
CREATE INDEX idx_checks_peer ON checks(peer);
CREATE INDEX idx_checks_task ON checks(task);
CREATE INDEX idx_p2p_check_id ON p2p(check_id);
CREATE INDEX idx_verter_check_id ON verter(check_id);
CREATE INDEX idx_xp_check_id ON xp(check_id);
CREATE INDEX idx_timetracking_peer_date ON timetracking(peer, date);
