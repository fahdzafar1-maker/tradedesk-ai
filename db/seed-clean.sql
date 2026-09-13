INSERT INTO businesses (id, name, trade, phone, timezone, service_area_zips,
                        emergency_phone, monthly_cost_cap_usd)
VALUES (
    '11111111-1111-1111-1111-111111111111',
    'Northside Heating & Air',
    'hvac',
    '+15551234567',
    'America/Chicago',
    ARRAY['60601','60602','60614','60618','60625','60640'],
    '+15559876543',
    50.00
);
INSERT INTO price_book (business_id, trade, service_code, service_name,
                        price_low, price_high, unit, notes) VALUES
('11111111-1111-1111-1111-111111111111','hvac','DIAG','Diagnostic visit',
  89.00, 129.00, 'visit', 'Waived if repair is booked same visit'),
('11111111-1111-1111-1111-111111111111','hvac','AC_REPAIR','AC repair',
  180.00, 850.00, 'job', 'Depends on part; final price confirmed on site'),
('11111111-1111-1111-1111-111111111111','hvac','FURNACE_REPAIR','Furnace repair',
  200.00, 950.00, 'job', 'Depends on part; final price confirmed on site'),
('11111111-1111-1111-1111-111111111111','hvac','AC_INSTALL','AC system install',
  3800.00, 7500.00, 'job', 'Requires on-site sizing visit'),
('11111111-1111-1111-1111-111111111111','hvac','FURNACE_INSTALL','Furnace install',
  3200.00, 6800.00, 'job', 'Requires on-site sizing visit'),
('11111111-1111-1111-1111-111111111111','hvac','TUNEUP','Seasonal tune-up',
  119.00, 169.00, 'visit', 'Discounted on maintenance plan'),
('11111111-1111-1111-1111-111111111111','hvac','DUCT_CLEAN','Duct cleaning',
  350.00, 700.00, 'job', 'Price varies with number of vents'),
('11111111-1111-1111-1111-111111111111','hvac','EMERGENCY','After-hours emergency call-out',
  195.00, 295.00, 'visit', 'Call-out fee only; repair billed separately');
INSERT INTO kb_documents (id, business_id, title, source_type) VALUES
('22222222-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111',
 'Service area and hours','faq'),
('22222222-0000-0000-0000-000000000002','11111111-1111-1111-1111-111111111111',
 'Warranty and guarantees','faq'),
('22222222-0000-0000-0000-000000000003','11111111-1111-1111-1111-111111111111',
 'Payment and financing','faq'),
('22222222-0000-0000-0000-000000000004','11111111-1111-1111-1111-111111111111',
 'Emergency policy','faq');
INSERT INTO kb_chunks (business_id, document_id, chunk_index, content) VALUES
('11111111-1111-1111-1111-111111111111','22222222-0000-0000-0000-000000000001',0,
 'Northside Heating & Air serves the north side of Chicago, including zip codes 60601, 60602, 60614, 60618, 60625 and 60640. We do not currently service the south side or the western suburbs. Regular hours are Monday to Friday, 8:00 AM to 5:00 PM. We are closed weekends except for emergency call-outs.'),
('11111111-1111-1111-1111-111111111111','22222222-0000-0000-0000-000000000002',0,
 'All repair work carries a 90-day labour warranty. Parts carry the manufacturer warranty, typically one to five years depending on the part. New system installations include a two-year labour warranty and we register the manufacturer warranty on the customer''s behalf.'),
('11111111-1111-1111-1111-111111111111','22222222-0000-0000-0000-000000000003',0,
 'We accept cash, cheque, and all major credit cards. Payment is due on completion of the work. For system installations over 3,000 dollars we offer financing through a third-party lender, subject to credit approval. We do not take payment over the phone before a technician has visited.'),
('11111111-1111-1111-1111-111111111111','22222222-0000-0000-0000-000000000004',0,
 'Emergencies are: no heat when the outside temperature is below 40F, gas smell, carbon monoxide alarm, water leaking from the furnace or AC unit, and any burning smell from a unit. If a caller reports a gas smell or a carbon monoxide alarm they must be told to leave the building and call the gas utility or 911 first. Emergency call-outs are dispatched to the on-call technician immediately.');
INSERT INTO customers (id, business_id, name, phone, address, zip) VALUES
('33333333-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111',
 'Dana Whitfield','+15550101','2140 W Foster Ave','60625'),
('33333333-0000-0000-0000-000000000002','11111111-1111-1111-1111-111111111111',
 'Marcus Ellery','+15550102','915 N Sheffield Ave','60614'),
('33333333-0000-0000-0000-000000000003','11111111-1111-1111-1111-111111111111',
 'Priya Raghunathan','+15550103','4402 N Kedzie Ave','60625');
INSERT INTO jobs (id, business_id, customer_id, trade, description, urgency,
                  status, scheduled_for, quoted_low, quoted_high, source) VALUES
('44444444-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111',
 '33333333-0000-0000-0000-000000000001','hvac',
 'AC blowing warm air, unit runs but no cooling','normal','scheduled',
 now() + interval '2 days', 180.00, 850.00, 'voice'),
('44444444-0000-0000-0000-000000000002','11111111-1111-1111-1111-111111111111',
 '33333333-0000-0000-0000-000000000002','hvac',
 'No heat overnight, furnace not igniting','emergency','completed',
 now() - interval '3 days', 200.00, 950.00, 'voice'),
('44444444-0000-0000-0000-000000000003','11111111-1111-1111-1111-111111111111',
 '33333333-0000-0000-0000-000000000003','hvac',
 'Seasonal tune-up before winter','quote_only','requested',
 NULL, 119.00, 169.00, 'whatsapp');
INSERT INTO conversations (id, business_id, customer_id, channel, external_id,
                           caller_phone, outcome, job_id, total_cost_usd,
                           started_at, ended_at) VALUES
('55555555-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111',
 '33333333-0000-0000-0000-000000000001','voice','demo-call-001','+15550101',
 'booked','44444444-0000-0000-0000-000000000001', 0.0184,
 now() - interval '1 day', now() - interval '1 day' + interval '4 minutes'),
('55555555-0000-0000-0000-000000000002','11111111-1111-1111-1111-111111111111',
 '33333333-0000-0000-0000-000000000002','voice','demo-call-002','+15550102',
 'escalated','44444444-0000-0000-0000-000000000002', 0.0061,
 now() - interval '3 days', now() - interval '3 days' + interval '1 minute'),
('55555555-0000-0000-0000-000000000003','11111111-1111-1111-1111-111111111111',
 NULL,'webchat','demo-chat-003',NULL,
 'answered',NULL, 0.0092,
 now() - interval '5 hours', now() - interval '5 hours' + interval '2 minutes');
INSERT INTO agent_runs (business_id, conversation_id, agent, input_summary,
                        output_status, output_summary, cost_usd, duration_ms) VALUES
('11111111-1111-1111-1111-111111111111','55555555-0000-0000-0000-000000000001',
 'supervisor','AC not cooling, wants appointment','OK','routed to intake_agent',0.0021,780),
('11111111-1111-1111-1111-111111111111','55555555-0000-0000-0000-000000000001',
 'intake','collected name, address, issue','OK','job created, 60625 in service area',0.0074,1420),
('11111111-1111-1111-1111-111111111111','55555555-0000-0000-0000-000000000001',
 'quote','AC repair band requested','OK','returned 180-850 band, final on site',0.0089,1150),
('11111111-1111-1111-1111-111111111111','55555555-0000-0000-0000-000000000002',
 'supervisor','no heat overnight, 28F outside','OK','routed to escalation_agent',0.0019,640),
('11111111-1111-1111-1111-111111111111','55555555-0000-0000-0000-000000000002',
 'escalation','no heat below 40F','ESCALATED','on-call tech notified, AI stood down',0.0042,510),
('11111111-1111-1111-1111-111111111111','55555555-0000-0000-0000-000000000003',
 'knowledge','do you cover Oak Park?','OK','answered from service area doc: not covered',0.0092,1330);
INSERT INTO escalations (business_id, conversation_id, reason, detail, notified_at) VALUES
('11111111-1111-1111-1111-111111111111','55555555-0000-0000-0000-000000000002',
 'emergency','No heat reported, outside temperature 28F — below the 40F emergency threshold',
 now() - interval '3 days');
