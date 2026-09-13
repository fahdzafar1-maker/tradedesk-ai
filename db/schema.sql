CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE TABLE businesses (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name                TEXT        NOT NULL,
    trade               TEXT        NOT NULL
        CHECK (trade IN ('hvac','plumbing','electrical','roofing','multi')),
    phone               TEXT        NOT NULL,
    timezone            TEXT        NOT NULL DEFAULT 'America/New_York',
    service_area_zips   TEXT[]      NOT NULL DEFAULT '{}',
    business_hours      JSONB       NOT NULL DEFAULT
        '{"mon":["08:00","17:00"],"tue":["08:00","17:00"],"wed":["08:00","17:00"],
          "thu":["08:00","17:00"],"fri":["08:00","17:00"],"sat":[],"sun":[]}',
    emergency_phone     TEXT,
    monthly_cost_cap_usd NUMERIC(8,2) NOT NULL DEFAULT 50.00,
    active              BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE customers (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id  UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    name         TEXT,
    phone        TEXT NOT NULL,
    email        TEXT,
    address      TEXT,
    zip          TEXT,
    notes        TEXT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (business_id, phone)
);
CREATE INDEX idx_customers_business ON customers(business_id);
CREATE INDEX idx_customers_phone    ON customers(business_id, phone);
CREATE TABLE jobs (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id   UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    customer_id   UUID NOT NULL REFERENCES customers(id)  ON DELETE CASCADE,
    trade         TEXT NOT NULL,
    description   TEXT NOT NULL,
    urgency       TEXT NOT NULL DEFAULT 'normal'
        CHECK (urgency IN ('emergency','urgent','normal','quote_only')),
    status        TEXT NOT NULL DEFAULT 'requested'
        CHECK (status IN ('requested','scheduled','in_progress','completed','cancelled')),
    scheduled_for TIMESTAMPTZ,
    quoted_low    NUMERIC(10,2),
    quoted_high   NUMERIC(10,2),
    final_amount  NUMERIC(10,2),
    source        TEXT NOT NULL DEFAULT 'voice'
        CHECK (source IN ('voice','whatsapp','webchat','manual')),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_jobs_business  ON jobs(business_id);
CREATE INDEX idx_jobs_status    ON jobs(business_id, status);
CREATE INDEX idx_jobs_created   ON jobs(business_id, created_at DESC);
CREATE TABLE price_book (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id   UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    trade         TEXT NOT NULL,
    service_code  TEXT NOT NULL,
    service_name  TEXT NOT NULL,
    price_low     NUMERIC(10,2) NOT NULL,
    price_high    NUMERIC(10,2) NOT NULL,
    unit          TEXT NOT NULL DEFAULT 'job'
        CHECK (unit IN ('job','hour','visit')),
    notes         TEXT,
    active        BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE (business_id, service_code),
    CHECK (price_high >= price_low)
);
CREATE INDEX idx_price_book_business ON price_book(business_id, trade, active);
CREATE TABLE kb_documents (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id  UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    title        TEXT NOT NULL,
    source_type  TEXT NOT NULL DEFAULT 'manual'
        CHECK (source_type IN ('manual','pdf','website','faq')),
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE kb_chunks (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id  UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    document_id  UUID NOT NULL REFERENCES kb_documents(id) ON DELETE CASCADE,
    chunk_index  INT  NOT NULL,
    content      TEXT NOT NULL,
    embedding    VECTOR(1536),
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_kb_chunks_business ON kb_chunks(business_id);
CREATE INDEX idx_kb_chunks_vector
    ON kb_chunks USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
CREATE TABLE conversations (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id   UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    customer_id   UUID REFERENCES customers(id) ON DELETE SET NULL,
    channel       TEXT NOT NULL
        CHECK (channel IN ('voice','whatsapp','webchat')),
    external_id   TEXT,
    caller_phone  TEXT,
    outcome       TEXT
        CHECK (outcome IN ('booked','quoted','answered','escalated','abandoned','blocked')),
    job_id        UUID REFERENCES jobs(id) ON DELETE SET NULL,
    total_cost_usd NUMERIC(10,4) NOT NULL DEFAULT 0,
    started_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    ended_at      TIMESTAMPTZ
);
CREATE UNIQUE INDEX idx_conversations_external
    ON conversations(business_id, channel, external_id)
    WHERE external_id IS NOT NULL;
CREATE INDEX idx_conversations_business ON conversations(business_id, started_at DESC);
CREATE TABLE messages (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id  UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    role             TEXT NOT NULL CHECK (role IN ('customer','agent','system')),
    content          TEXT NOT NULL,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_messages_conversation ON messages(conversation_id, created_at);
CREATE TABLE agent_runs (
    id               BIGSERIAL PRIMARY KEY,
    business_id      UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    conversation_id  UUID REFERENCES conversations(id) ON DELETE CASCADE,
    agent            TEXT NOT NULL,
    input_summary    TEXT,
    output_status    TEXT NOT NULL
        CHECK (output_status IN ('OK','BLOCKED','RISKY','ERROR','ESCALATED')),
    output_summary   TEXT,
    tokens_in        INT,
    tokens_out       INT,
    cost_usd         NUMERIC(10,6) DEFAULT 0,
    duration_ms      INT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_agent_runs_business ON agent_runs(business_id, created_at DESC);
CREATE INDEX idx_agent_runs_conv     ON agent_runs(conversation_id);
CREATE INDEX idx_agent_runs_status   ON agent_runs(business_id, output_status);
CREATE TABLE escalations (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id      UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    conversation_id  UUID REFERENCES conversations(id) ON DELETE CASCADE,
    reason           TEXT NOT NULL
        CHECK (reason IN ('emergency','angry_customer','out_of_scope',
                          'low_confidence','injection_attempt','cost_cap')),
    detail           TEXT,
    notified_at      TIMESTAMPTZ,
    acknowledged_at  TIMESTAMPTZ,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_escalations_business ON escalations(business_id, created_at DESC);
CREATE OR REPLACE VIEW v_business_daily AS
SELECT
    c.business_id,
    date_trunc('day', c.started_at)                              AS day,
    COUNT(*)                                                     AS conversations,
    COUNT(*) FILTER (WHERE c.outcome = 'booked')                 AS booked,
    COUNT(*) FILTER (WHERE c.outcome = 'escalated')              AS escalated,
    COUNT(*) FILTER (WHERE c.outcome = 'abandoned')              AS abandoned,
    COALESCE(SUM(j.quoted_low), 0)                               AS pipeline_low,
    COALESCE(SUM(j.quoted_high), 0)                              AS pipeline_high,
    ROUND(SUM(c.total_cost_usd), 4)                              AS ai_cost_usd
FROM conversations c
LEFT JOIN jobs j ON j.id = c.job_id
GROUP BY c.business_id, date_trunc('day', c.started_at);
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'agent_ro') THEN
        CREATE ROLE agent_ro LOGIN PASSWORD 'CHANGE_ME_BEFORE_RUNNING';
    END IF;
END
$$;
GRANT CONNECT ON DATABASE railway TO agent_ro;
GRANT USAGE   ON SCHEMA public    TO agent_ro;
GRANT SELECT ON businesses, customers, jobs, price_book,
                kb_documents, kb_chunks TO agent_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON TABLES FROM agent_ro;
