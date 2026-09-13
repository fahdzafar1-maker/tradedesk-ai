"""
TradeDesk AI - owner dashboard API.

Two jobs:
  1. Show the contractor what the AI front desk did - calls handled, jobs
     booked, pipeline value, what got escalated, and what it cost.
  2. Be the thing that proves ROI during a sales conversation.

Reads only. It never writes to the database.
"""

import os
from datetime import date, timedelta

import asyncpg
from fastapi import FastAPI, HTTPException, Query
from fastapi.responses import HTMLResponse, JSONResponse

DATABASE_URL = os.environ.get("DATABASE_URL")
DASHBOARD_TOKEN = os.environ.get("DASHBOARD_TOKEN")  # unset = open (demo only)

app = FastAPI(title="TradeDesk AI Dashboard", docs_url="/docs")
_pool: asyncpg.Pool | None = None


@app.on_event("startup")
async def startup() -> None:
    global _pool
    if not DATABASE_URL:
        raise RuntimeError("DATABASE_URL is not set")
    _pool = await asyncpg.create_pool(DATABASE_URL, min_size=1, max_size=5)


@app.on_event("shutdown")
async def shutdown() -> None:
    if _pool:
        await _pool.close()


def _check_token(token: str | None) -> None:
    """A dashboard shows one business's real data - it does not hang open."""
    if DASHBOARD_TOKEN and token != DASHBOARD_TOKEN:
        raise HTTPException(status_code=401, detail="Invalid or missing token")


@app.get("/health")
async def health() -> dict:
    async with _pool.acquire() as con:
        await con.fetchval("SELECT 1")
    return {"ok": True}


@app.get("/api/summary")
async def summary(
    business_id: str = Query(..., min_length=36, max_length=36),
    days: int = Query(14, ge=1, le=90),
    token: str | None = Query(None),
) -> JSONResponse:
    _check_token(token)
    since = date.today() - timedelta(days=days)

    async with _pool.acquire() as con:
        # Every query below is a fixed template with bound parameters.
        business = await con.fetchrow(
            "SELECT name, trade, phone FROM businesses WHERE id = $1 AND active = true",
            business_id,
        )
        if not business:
            raise HTTPException(status_code=404, detail="Business not found")

        totals = await con.fetchrow(
            """
            SELECT
                count(*)                                              AS conversations,
                count(*) FILTER (WHERE c.outcome = 'booked')          AS booked,
                count(*) FILTER (WHERE c.outcome = 'escalated')       AS escalated,
                count(*) FILTER (WHERE c.outcome = 'abandoned')       AS abandoned,
                COALESCE(SUM(j.quoted_low), 0)                        AS pipeline_low,
                COALESCE(SUM(j.quoted_high), 0)                       AS pipeline_high,
                COALESCE(SUM(c.total_cost_usd), 0)                    AS ai_cost
            FROM conversations c
            LEFT JOIN jobs j ON j.id = c.job_id
            WHERE c.business_id = $1 AND c.started_at >= $2
            """,
            business_id, since,
        )

        daily = await con.fetch(
            """
            SELECT date_trunc('day', started_at)::date        AS day,
                   count(*)                                   AS conversations,
                   count(*) FILTER (WHERE outcome = 'booked')  AS booked
            FROM conversations
            WHERE business_id = $1 AND started_at >= $2
            GROUP BY 1 ORDER BY 1
            """,
            business_id, since,
        )

        escalations = await con.fetch(
            """
            SELECT reason, detail, created_at, acknowledged_at
            FROM escalations
            WHERE business_id = $1 AND created_at >= $2
            ORDER BY created_at DESC LIMIT 10
            """,
            business_id, since,
        )

        agents = await con.fetch(
            """
            SELECT agent, output_status, count(*) AS runs,
                   COALESCE(SUM(cost_usd), 0)     AS cost
            FROM agent_runs
            WHERE business_id = $1 AND created_at >= $2
            GROUP BY 1, 2 ORDER BY 1, 2
            """,
            business_id, since,
        )

    return JSONResponse({
        "business": dict(business),
        "days": days,
        "totals": {k: float(v) if hasattr(v, "quantize") else v
                   for k, v in dict(totals).items()},
        "daily": [{"day": r["day"].isoformat(),
                   "conversations": r["conversations"],
                   "booked": r["booked"]} for r in daily],
        "escalations": [{"reason": r["reason"], "detail": r["detail"],
                         "created_at": r["created_at"].isoformat(),
                         "acknowledged": r["acknowledged_at"] is not None}
                        for r in escalations],
        "agents": [{"agent": r["agent"], "status": r["output_status"],
                    "runs": r["runs"], "cost": float(r["cost"])} for r in agents],
    })


@app.get("/", response_class=HTMLResponse)
async def dashboard() -> str:
    return DASHBOARD_HTML


DASHBOARD_HTML = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>TradeDesk AI - Front Desk Report</title>
<style>
  :root {
    --bg: #fbfbfa; --surface: #ffffff; --border: #e6e4e0;
    --ink: #1a1a18; --ink-2: #55524c; --ink-3: #8a857d;
    --bar: #2f6f8f; --bar-soft: #a8c9d8;
    --good: #2e6f4e; --warn: #8a5a12; --crit: #9b2c2c;
  }
  @media (prefers-color-scheme: dark) {
    :root:not([data-theme="light"]) {
      --bg: #16161a; --surface: #1e1e23; --border: #32323a;
      --ink: #f2f1ee; --ink-2: #b9b5ad; --ink-3: #85817a;
      --bar: #6fb3d2; --bar-soft: #35586b;
      --good: #6cc08b; --warn: #d4a24c; --crit: #e08585;
    }
  }
  * { box-sizing: border-box; }
  body { margin:0; background:var(--bg); color:var(--ink);
    font:15px/1.5 ui-sans-serif,system-ui,-apple-system,"Segoe UI",sans-serif; }
  .wrap { max-width: 1000px; margin: 0 auto; padding: 32px 20px 64px; }
  h1 { font-size: 22px; margin: 0 0 4px; letter-spacing: -0.01em; }
  .sub { color: var(--ink-3); font-size: 13px; margin-bottom: 28px; }
  .tiles { display:grid; grid-template-columns:repeat(auto-fit,minmax(160px,1fr)); gap:12px; }
  .tile { background:var(--surface); border:1px solid var(--border);
    border-radius:10px; padding:16px 18px; }
  .tile .label { font-size:12px; color:var(--ink-3); text-transform:uppercase;
    letter-spacing:.05em; }
  .tile .value { font-size:30px; font-weight:600; letter-spacing:-0.02em;
    margin-top:6px; font-variant-numeric: tabular-nums; }
  .tile .note { font-size:12px; color:var(--ink-2); margin-top:4px; }
  section { margin-top:32px; }
  h2 { font-size:14px; text-transform:uppercase; letter-spacing:.05em;
    color:var(--ink-3); margin:0 0 12px; font-weight:600; }
  .chart { background:var(--surface); border:1px solid var(--border);
    border-radius:10px; padding:20px; overflow-x:auto; }
  .bars { display:flex; align-items:flex-end; gap:6px; height:150px; min-width:320px; }
  .col { flex:1; display:flex; flex-direction:column; justify-content:flex-end;
    align-items:center; gap:4px; min-width:22px; }
  .bar { width:100%; background:var(--bar); border-radius:4px 4px 0 0;
    min-height:2px; position:relative; }
  .bar.booked { background:var(--bar-soft); border-radius:0;
    box-shadow: 0 -2px 0 var(--surface); }
  .col .d { font-size:11px; color:var(--ink-3); white-space:nowrap; }
  table { width:100%; border-collapse:collapse; background:var(--surface);
    border:1px solid var(--border); border-radius:10px; overflow:hidden; font-size:14px; }
  th { text-align:left; font-size:12px; color:var(--ink-3); font-weight:600;
    padding:10px 14px; border-bottom:1px solid var(--border); }
  td { padding:10px 14px; border-bottom:1px solid var(--border); color:var(--ink-2); }
  tr:last-child td { border-bottom:none; }
  .pill { display:inline-block; padding:2px 8px; border-radius:999px;
    font-size:12px; font-weight:600; }
  .pill.emergency { color:var(--crit); }
  .pill.other { color:var(--warn); }
  .empty { color:var(--ink-3); padding:20px; text-align:center;
    background:var(--surface); border:1px solid var(--border); border-radius:10px; }
  .err { color:var(--crit); }
</style>
</head>
<body>
<div class="wrap">
  <h1 id="biz">Loading...</h1>
  <div class="sub" id="range"></div>
  <div class="tiles" id="tiles"></div>

  <section>
    <h2>Conversations per day</h2>
    <div class="chart"><div class="bars" id="bars"></div></div>
  </section>

  <section>
    <h2>Escalated to a human</h2>
    <div id="esc"></div>
  </section>

  <section>
    <h2>Agent activity</h2>
    <div id="agents"></div>
  </section>
</div>

<script>
const params = new URLSearchParams(location.search);
const businessId = params.get('business_id') || '11111111-1111-1111-1111-111111111111';
const token = params.get('token');
const days = params.get('days') || 14;

const money = n => '$' + Number(n).toLocaleString('en-US', {maximumFractionDigits: 0});

function tile(label, value, note) {
  return '<div class="tile"><div class="label">' + label + '</div>' +
         '<div class="value">' + value + '</div>' +
         (note ? '<div class="note">' + note + '</div>' : '') + '</div>';
}

async function load() {
  let url = '/api/summary?business_id=' + encodeURIComponent(businessId) + '&days=' + days;
  if (token) url += '&token=' + encodeURIComponent(token);

  const res = await fetch(url);
  if (!res.ok) {
    document.getElementById('biz').innerHTML =
      '<span class="err">Could not load: ' + res.status + '</span>';
    return;
  }
  const d = await res.json();
  const t = d.totals;

  document.getElementById('biz').textContent = d.business.name;
  document.getElementById('range').textContent =
    d.business.trade.toUpperCase() + ' - last ' + d.days + ' days';

  const answered = t.conversations - t.abandoned;
  document.getElementById('tiles').innerHTML =
    tile('Calls handled', t.conversations, answered + ' answered end to end') +
    tile('Jobs booked', t.booked,
         t.conversations ? Math.round(t.booked / t.conversations * 100) + '% of calls' : '') +
    tile('Pipeline value', money(t.pipeline_low) + ' - ' + money(t.pipeline_high),
         'from booked jobs') +
    tile('Sent to a human', t.escalated, 'emergencies and edge cases') +
    tile('AI cost', '$' + Number(t.ai_cost).toFixed(2), 'for the whole period');

  // Single series plus its booked sub-total - one hue, light to dark.
  const max = Math.max(1, ...d.daily.map(x => x.conversations));
  document.getElementById('bars').innerHTML = d.daily.map(function (x) {
    const h = Math.round(x.conversations / max * 120);
    const bh = Math.round(x.booked / max * 120);
    return '<div class="col" title="' + x.day + ': ' + x.conversations +
           ' calls, ' + x.booked + ' booked">' +
           '<div class="bar" style="height:' + Math.max(2, h - bh) + 'px"></div>' +
           (bh > 0 ? '<div class="bar booked" style="height:' + bh + 'px"></div>' : '') +
           '<div class="d">' + x.day.slice(5) + '</div></div>';
  }).join('') || '<div class="empty">No conversations yet</div>';

  document.getElementById('esc').innerHTML = d.escalations.length
    ? '<table><tr><th>Reason</th><th>Detail</th><th>When</th><th>Seen</th></tr>' +
      d.escalations.map(function (e) {
        const cls = e.reason === 'emergency' ? 'emergency' : 'other';
        return '<tr><td><span class="pill ' + cls + '">' + e.reason + '</span></td>' +
               '<td>' + (e.detail || '') + '</td>' +
               '<td>' + e.created_at.slice(0, 16).replace('T', ' ') + '</td>' +
               '<td>' + (e.acknowledged ? 'yes' : 'not yet') + '</td></tr>';
      }).join('') + '</table>'
    : '<div class="empty">Nothing needed a human. That is the goal.</div>';

  document.getElementById('agents').innerHTML = d.agents.length
    ? '<table><tr><th>Agent</th><th>Result</th><th>Runs</th><th>Cost</th></tr>' +
      d.agents.map(function (a) {
        return '<tr><td>' + a.agent + '</td><td>' + a.status + '</td>' +
               '<td>' + a.runs + '</td><td>$' + a.cost.toFixed(4) + '</td></tr>';
      }).join('') + '</table>'
    : '<div class="empty">No agent runs recorded yet</div>';
}

load();
</script>
</body>
</html>
"""
