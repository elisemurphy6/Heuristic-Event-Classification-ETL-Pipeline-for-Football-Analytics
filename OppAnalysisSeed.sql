-- Seed data for quick demo
-- Run with: psql -f opposition_analysis_seed.sql

INSERT INTO teams (name, short_name, country) VALUES
 ('AS Roma Women','ROM','Italy'),
 ('Arsenal Women','ARS','England')
ON CONFLICT DO NOTHING;

INSERT INTO competitions (name, level, country) VALUES
 ('UEFA Women\'s Champions League','UCL','Europe'),
 ('Serie A Femminile','League','Italy')
ON CONFLICT DO NOTHING;

-- Sample match: Roma vs Arsenal
INSERT INTO matches (competition_id, match_date, home_team_id, away_team_id, venue, home_score, away_score)
SELECT c.competition_id, DATE '2025-10-15', t1.team_id, t2.team_id, 'Emirates Stadium', 1, 2
FROM competitions c, teams t1, teams t2
WHERE c.name = 'UEFA Women\'s Champions League' AND t1.name='AS Roma Women' AND t2.name='Arsenal Women'
ON CONFLICT DO NOTHING;

-- Minimal players
INSERT INTO players (team_id, full_name, position, foot)
SELECT team_id, 'Striker A', 'FW', 'Right' FROM teams WHERE name='AS Roma Women'
ON CONFLICT DO NOTHING;
INSERT INTO players (team_id, full_name, position, foot)
SELECT team_id, 'Midfielder B', 'MF', 'Right' FROM teams WHERE name='AS Roma Women'
ON CONFLICT DO NOTHING;
INSERT INTO players (team_id, full_name, position, foot)
SELECT team_id, 'Defender C', 'DF', 'Left' FROM teams WHERE name='Arsenal Women'
ON CONFLICT DO NOTHING;

-- Analysts
INSERT INTO analysts (full_name, email) VALUES
 ('John Doe','JohnDoe@example.com')
ON CONFLICT DO NOTHING;

-- Zones
INSERT INTO zones (name, description) VALUES
 ('Def Third - Left','Left side of defensive third'),
 ('Mid Third - Center','Central midfield third'),
 ('Final Third - Right','Right side of attacking third')
ON CONFLICT DO NOTHING;

-- Event types
INSERT INTO event_types (code, description) VALUES
 ('PASS','Completed or attempted pass'),
 ('SHOT','Shot on/off target'),
 ('PRESS_TRIG','Pressing trigger event'),
 ('TURNOVER','Possession lost/won'),
 ('SETPIECE','Corner/Free-kick/Throw-in restart')
ON CONFLICT DO NOTHING;

-- Tags
INSERT INTO tags (name, category) VALUES
 ('press_trigger','Pressing'),
 ('wide_overload','Build-up'),
 ('counterpress','Pressing')
ON CONFLICT DO NOTHING;

-- Fetch IDs
WITH ids AS (
  SELECT
    (SELECT match_id FROM matches LIMIT 1) AS match_id,
    (SELECT team_id FROM teams WHERE name='AS Roma Women') AS roma_id,
    (SELECT team_id FROM teams WHERE name='Arsenal Women') AS ars_id,
    (SELECT player_id FROM players WHERE full_name='Striker A' LIMIT 1) AS p_striker,
    (SELECT player_id FROM players WHERE full_name='Midfielder B' LIMIT 1) AS p_mid,
    (SELECT zone_id FROM zones WHERE name='Mid Third - Center') AS z_mid,
    (SELECT event_type_id FROM event_types WHERE code='PASS') AS et_pass,
    (SELECT event_type_id FROM event_types WHERE code='PRESS_TRIG') AS et_press,
    (SELECT event_type_id FROM event_types WHERE code='SETPIECE') AS et_setpiece
)
INSERT INTO events (match_id, minute, second, team_id, player_id, event_type_id, zone_id, outcome, qualifier)
SELECT match_id, 12, 30, roma_id, p_mid, et_pass, z_mid, 'Complete', '{"pass_length":22}'
FROM ids
UNION ALL
SELECT match_id, 13, 5, ars_id, NULL, et_press, z_mid, 'Won', '{"pressure":true}'
FROM ids
UNION ALL
SELECT match_id, 44, 10, roma_id, p_striker, et_setpiece, z_mid, 'Goal', '{"sp_type":"corner"}'
FROM ids;

-- Tag the press trigger
WITH e AS (
  SELECT event_id FROM events e
  JOIN event_types et ON et.event_type_id = e.event_type_id
  WHERE et.code='PRESS_TRIG' LIMIT 1
), t AS (
  SELECT tag_id FROM tags WHERE name='press_trigger' LIMIT 1
), a AS (
  SELECT analyst_id FROM analysts WHERE full_name='Elise Murphy' LIMIT 1
)
INSERT INTO event_tags (event_id, tag_id, analyst_id, note)
SELECT e.event_id, t.tag_id, a.analyst_id, 'Trigger: bad touch CB'
FROM e, t, a
ON CONFLICT DO NOTHING;

-- One clip linked to set-piece goal
WITH m AS (
  SELECT match_id FROM matches LIMIT 1
), ev AS (
  SELECT event_id FROM events e
  JOIN event_types et ON et.event_type_id = e.event_type_id
  WHERE et.code='SETPIECE' LIMIT 1
)
INSERT INTO video_clips (match_id, event_id, source_url, start_sec, end_sec)
SELECT m.match_id, ev.event_id, 'https://video.example.com/match1.mp4', 2600, 2612
FROM m, ev
ON CONFLICT DO NOTHING;

-- A placeholder report record
INSERT INTO reports (match_id, version, status, storage_url)
SELECT match_id, 1, 'DRAFT', NULL FROM matches
ON CONFLICT DO NOTHING;

-- Example notes
WITH m AS (SELECT match_id FROM matches LIMIT 1),
     a AS (SELECT analyst_id FROM analysts LIMIT 1)
INSERT INTO notes (match_id, analyst_id, topic, text)
SELECT m.match_id, a.analyst_id, 'Build-up tendencies',
       'Arsenal press triggers appeared on slow CB touches; Roma found success through mid-third switches.'
FROM m, a
ON CONFLICT DO NOTHING;
