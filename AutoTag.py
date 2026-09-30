import csv, re, os
import psycopg2
from psycopg2.extras import execute_batch, Json

# DB CONNECTION (manual edit)
PG_DSN = os.getenv("PG_DSN", "dbname=opta host=localhost user=postgres password=postgres")

# Heuristic rules
EVENTTYPE_RULES = [
    (r"\bshot|header|finishes|chance\b", 2),   # SHOT
    (r"\bturnover|lost ball|giveaway\b", 3),   # TURNOVER
    (r"\bcorner\b", 4),                        # SETPIECE_CORNER
    (r"\bfree ?kick|fk\b", 5),                 # SETPIECE_FREEKICK
    (r"\bpress|counter-press|trap\b", 6),      # PRESS_TRIG
    (r"\bpass|switch|diagonal|through\b", 1),  # PASS
]

TAG_RULES = [
    (r"\bhigh press|hp\b", 10),   # High Press
    (r"\bmid block\b", 11),
    (r"\blow block\b", 12),
    (r"\boverload (left|l)\b", 20),
    (r"\bswitch\b", 21),
    (r"\bcounter-press|counterpress\b", 22),
    (r"\bsecond phase\b", 30),
]

def pick_eventtype(raw):
    raw_l = raw.lower()
    for pat, etid in EVENTTYPE_RULES:
        if re.search(pat, raw_l):
            return etid
    return 1  # default PASS

def pick_tags(raw):
    raw_l = raw.lower()
    hits = []
    for pat, tid in TAG_RULES:
        if re.search(pat, raw_l):
            hits.append(tid)
    # derived tag examples
    if "corner" in raw_l and "flick" in raw_l:
        hits.append(30)  # Second Phase as an example
    return sorted(set(hits))

def confidence(raw, etid, tags):
    score = 0.5
    # boost if specific patterns exist
    if any(k in raw.lower() for k in ["corner","press","switch","turnover","diagonal"]):
        score += 0.2
    if etid in (4,5,6):  # set-piece/pressing types are strong signals
        score += 0.1
    score += min(0.2, 0.05*len(tags))
    return round(min(score, 0.95), 2)

def get_zone_id(cur, zone_label):
    cur.execute("SELECT ZoneID FROM Zone WHERE Area = %s", (zone_label,))
    row = cur.fetchone()
    return row[0] if row else None

def insert_events(rows):
    conn = psycopg2.connect(PG_DSN)
    conn.autocommit = False
    try:
        with conn.cursor() as cur:
            # Insert Events
            ev_sql = """
                INSERT INTO Event (MatchID, Minute, Second, ClubID, PlayerID, EventTypeID, ZoneID, Outcome, Note)
                VALUES (%s,%s,%s,%s, NULLIF(%s,-1),%s,%s,%s,%s)
                RETURNING EventID
            """
            # Insert EventTags
            et_sql = "INSERT INTO EventTag (EventID, TagID, AnalystID, Note) VALUES (%s,%s,1,%s)"

            for r in rows:
                zone_id = get_zone_id(cur, r['zone_hint']) if r['zone_hint'] else None
                etid = pick_eventtype(r['raw_note'])
                tags = pick_tags(r['raw_note'])
                conf = confidence(r['raw_note'], etid, tags)
                note = {
                    "detail": "auto",
                    "raw": r['raw_note'],
                    "confidence": conf
                }

                cur.execute(ev_sql, (
                    int(r['match_id']), int(r['minute']), int(r['second']),
                    int(r['club_id']), int(r['player_id']),
                    etid, zone_id, r['outcome'] or None, Json(note)
                ))
                event_id = cur.fetchone()[0]

                # Only tag if something hit; else leave for review
                for tag_id in tags:
                    cur.execute(et_sql, (event_id, tag_id, f"auto; conf={conf}"))

        conn.commit()
    except Exception as e:
        conn.rollback()
        raise
    finally:
        conn.close()

if __name__ == "__main__":
    rows = []
    with open("events_raw.csv", newline='', encoding='utf-8') as f:
        for r in csv.DictReader(f):
            rows.append(r)
    insert_events(rows)
    print("Auto-tagging complete.")

import csv, re, os
