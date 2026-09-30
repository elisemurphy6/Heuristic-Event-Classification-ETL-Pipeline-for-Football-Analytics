-- Core reference tables
CREATE TABLE Club 
(	ClubID INT IDENTITY(1,1) PRIMARY KEY,
    ClubName Varchar(75) NOT NULL UNIQUE,
    Country VarChar(50), 
	CompID INT IDENTITY(1.1) FORGIEN KEY RRFERENCES Comp(CompID),
	CompID INT IDENTITY(1.1) FORGIEN KEY RRFERENCES Comp(CompID),
	CompID INT IDENTITY(1.1) FORGIEN KEY RRFERENCES Comp(CompID),
	CompID INT IDENTITY(1.1) FORGIEN KEY RRFERENCES Comp(CompID)
);

CREATE TABLE Comp
(	CompID INT IDENTITY(1.1) PRIMARY KEY,
    CompName VarChar(25) NOT NULL,
    CompLevel Varchar(25),           -- e.g., League, Cup, UCL
    Country VarChar(50)
);

CREATE TABLE Match 
(	MatchID INT IDENTITY(1,1) PRIMARY KEY,
    CompID INT IDENTITY(1.1) FOREIGN KEY REFERENCES Comp(CompID) ON DELETE RESTRICT,
    MatchDate DATE NOT NULL,
    HomeTeamID INT NOT NULL FOREIGN KEY REFERENCES Club(ClubID) ON DELETE RESTRICT,
    AwayTeamID INT NOT NULL FOREIGN KEY REFERENCES Club(ClubID) ON DELETE RESTRICT,
    MatchVenue Varchar(50),
    HomeScore INT DEFAULT 0 CHECK (home_score >= 0),
    AwayScore INT DEFAULT 0 CHECK (away_score >= 0),
    CONSTRAINT chk_distinct_club CHECK (HomeTeamID <> AwayTeamID)
);

CREATE INDEX IndexMatcheDate ON Match(MatchDate);
CREATE INDEX IndexMatcheComp ON Match(CompID);

CREATE TABLE Player 
(	PlayerID INT IDENTITY(100,1) PRIMARY KEY,
    ClubID INT NOT NULL FOREIGN KEY REFERENCES Club(ClubID) ON DELETE RESTRICT,
    PlayerFirstName Varchar(50) NOT NULL,
	PlayerLastName Varchar(50),
	DOB Date NOT NULL,
    Position Varchar(50) Check(Position in 'GK', 'LB', 'CB', 'RB', 'LWB', 'RWB', 'DM', 'MD', 'ACM', 'AM', 'W', 'RW', 'LW', 'ST'), 
    Foot Varchar(20) Check(Foot in 'Right', 'Left', 'Both', 'L', 'R', 'L&R')
);

-- Lineup & participation (who played in which match and role)
CREATE TABLE LineUp 
(	MatchID INT NOT NULL FOREIGN KEY REFERENCES Match(MatchID) ON DELETE CASCADE,
    PlayerID INT NOT NULL FOREIGN KEY REFERENCES Player(PlayerID) ON DELETE RESTRICT,
    ClubID INT NOT NULL FOREIGN KEY REFERENCES Club(ClubID) ON DELETE RESTRICT,
    Role Varchar(50),             -- e.g., Starter, Sub
    MinuteOn INT DEFAULT 0 CHECK (MinuteOn BETWEEN 0 AND 130),
    MinuteOff INT ,        -- null means played until end
    PRIMARY KEY (MatchID, PlayerID),
    CONSTRAINT chk_lineup_team_consistency CHECK (ClubID IN (SELECT HomeTeamID FROM Match WHERE MatchID = LineUp.MatchID)
                                                   OR ClubID IN (SELECT AwayTeamID FROM Match WHERE MatchID = LineUp.MatchID))
);

-- Zones (pitch regions for analysis)
CREATE TABLE Zone 
(	ZoneID INT PRIMARY KEY,
    Area Varchar(50) NOT NULL UNIQUE,  -- e.g., "Defensive Third - Left", "Half-space Right (Final 3rd)"
    Notes Varchar(500)
);

-- Event types (controlled vocabulary)
CREATE TABLE EventType 
(	EventTypeID INT PRIMARY KEY,
    Code Varchar(50) NOT NULL UNIQUE,  -- e.g., PASS, SHOT, PRESS_TRIG, TURNOVER, SETPIECE
    Note Varchar(500)
);

-- Event fact table
CREATE TABLE Event 
(	EventID INT IDENTITY(500,1) PRIMARY KEY,
    MatchID INT NOT NULL FOREIGN KEY REFERENCES Match(MatchID) ON DELETE CASCADE,
    Minute INT NOT NULL CHECK (minute BETWEEN 0 AND 130),
    Second INT NOT NULL CHECK (second BETWEEN 0 AND 59),
    ClubID INT NOT NULL FOREIGN KEY REFERENCES Club(ClubID) ON DELETE RESTRICT,
    PlayerID INT FOREIGN KEY REFERENCES Player(PlayerID) ON DELETE SET NULL,
    EventTypeID INT NOT NULL FOREIGN KEY REFERENCES EventType(EventTypeID) ON DELETE RESTRICT,
    ZoneID INT FOREIGN KEY REFERENCES Zone(ZoneID) ON DELETE SET NULL,
    Outcome Varchar(50),           -- e.g., Complete, Incomplete, Won, Lost, Goal
    Note Varchar(500),        -- flexible detail: {"pass_length": 18.2, "pressure": true}
    WhenCreated TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IndexEventMatch ON Event(MatchID);
CREATE INDEX IndexEventTeam ON Event(ClubID);
CREATE INDEX IndexEventPlayer ON Event(PlayerID);
CREATE INDEX IndexEventType ON Event(EventTypeID);
CREATE INDEX IndexEventZone ON Event(ZoneID);
CREATE INDEX IndexEventMinute ON Event(MatchID, minute);

-- Tags: analyst-defined tactical labels (press triggers, patterns)
CREATE TABLE Tag 
(   TagID INT PRIMARY KEY,
    TagName Varchar(50) NOT NULL UNIQUE,
    Category Varchar(50)            -- e.g., "Pressing", "Build-up", "Set-piece"
);

-- M:N link between Event and Tag
CREATE TABLE EventTag 
(   EventID BIGINT NOT NULL FOREIGN KEY REFERENCES Event(EventID) ON DELETE CASCADE,
    TagID INT NOT NULL FOREIGN KEY REFERENCES Tag(TagID) ON DELETE RESTRICT,
    AnalystID INT FOREIGN KEY REFERENCES Analyst(AnalystID),
    Note Varchar(50),
    Created TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (EventID, TagID)
);

-- Analysts (for ownership & notes)
CREATE TABLE Analyst (
    AnalystID INT PRIMARY KEY,
    AnalystFirstName Varchar(50) NOT NULL UNIQUE,
	AnalystLastName Varchar(50) UNIQUE,
    Email Varchar(50)
);

-- Video clips referencing raw video (can map to Event or stand-alone)
CREATE TABLE VideoClip 
(   ClipID INT IDENTITY (100,1) PRIMARY KEY,
    MatchID INT NOT NULL FOREIGN KEY REFERENCES Match(MatchID) ON DELETE CASCADE,
    EventID INT FOREIGN KEY REFERENCES Event(EventID) ON DELETE SET NULL,
    SourceURL Varchar(200) NOT NULL,
    StartTime INT NOT NULL CHECK (start_sec >= 0),
    EndTime INT NOT NULL CHECK (end_sec > start_sec)
);

-- Reports: generated or manual decks
CREATE TABLE Report
(   ReportID INT IDENTITY(1,1) PRIMARY KEY,
    MatchID INT NOT NULL FOREIGN KEY REFERENCES Match(MatchID) ON DELETE CASCADE,
    Version INT NOT NULL DEFAULT 1,
    Status Varchar(50) NOT NULL DEFAULT 'DRAFT',  -- DRAFT, READY, PUBLISHED
    StorageURL Varchar(200),                      -- link to PPT/PDF
    ReportCreated TIMESTAMP DEFAULT NOW(),
    UNIQUE (MatchID, Version)
);

-- Helpful views for the presentation/demo
CREATE OR REPLACE VIEW PressTriggers AS
SELECT e.EventID, e.MatchID, e.minute, e.second, t.Name AS TagName, tm.Name AS ClubName
FROM Event e
JOIN EventTag et ON et.EventID = e.EventID
JOIN Tag t ON t.TagID = et.TagID
JOIN Club tm ON tm.ClubID = e.ClubID
WHERE t.name LIKE '%press%';

CREATE OR REPLACE VIEW SPOutcomes AS
SELECT m.MatchID,
       SUM(CASE WHEN et.code LIKE'%SETPIECE%' AND e.outcome = 'Goal' THEN 1 ELSE 0 END) AS sp_goals,
       COUNT(*) FILTER (WHERE et.code LIKE '%SETPIECE%')                                  AS sp_total
FROM Match m
LEFT JOIN Event e ON e.MatchID = m.MatchID
LEFT JOIN EventType et ON et.EventTypeID = e.EventTypeID
GROUP BY m.MatchID;

-- Basic function to flip a report to READY when a match marked complete exists
CREATE OR REPLACE FUNCTION mark_report_ready(p_match_id INT)
RETURNS VOID AS $$
DECLARE r_id INT;
BEGIN
  SELECT ReportID INTO r_id FROM Report WHERE MatchID = p_match_id ORDER BY version DESC LIMIT 1;
  IF r_id IS NOT NULL THEN
    UPDATE Report SET status = 'READY' WHERE ReportID = r_id;
  END IF;
END;

