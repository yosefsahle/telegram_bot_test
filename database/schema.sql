-- Digital Lottery Platform - MySQL/MariaDB schema
-- Designed to be installed alongside the existing registration database.
-- Does NOT alter or rename the existing `users` registration table.
SET NAMES utf8mb4;
SET time_zone = '+00:00';

CREATE TABLE IF NOT EXISTS lottery_participants (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  legacy_registration_user_id BIGINT UNSIGNED NULL,
  telegram_user_id BIGINT UNSIGNED NOT NULL,
  username VARCHAR(64) NULL,
  first_name VARCHAR(128) NOT NULL,
  last_name VARCHAR(128) NULL,
  phone_number VARCHAR(32) NULL,
  language_code VARCHAR(5) NOT NULL DEFAULT 'en',
  status VARCHAR(20) NOT NULL DEFAULT 'active',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  last_seen_at DATETIME NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_lottery_participant_telegram (telegram_user_id),
  UNIQUE KEY uq_lottery_participant_legacy (legacy_registration_user_id),
  KEY idx_lottery_participant_status (status),
  CONSTRAINT chk_lottery_participant_language CHECK (language_code IN ('en','am','ti','om')),
  CONSTRAINT chk_lottery_participant_status CHECK (status IN ('active','blocked','deleted'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS lottery_api_sessions (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  participant_id BIGINT UNSIGNED NOT NULL,
  token_hash CHAR(64) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  expires_at DATETIME NOT NULL,
  revoked_at DATETIME NULL,
  last_used_at DATETIME NULL,
  ip_hash CHAR(64) NULL,
  user_agent VARCHAR(255) NULL,
  PRIMARY KEY (id), UNIQUE KEY uq_lottery_session_hash (token_hash),
  KEY idx_lottery_session_participant (participant_id), KEY idx_lottery_session_expiry (expires_at),
  CONSTRAINT fk_lottery_session_participant FOREIGN KEY (participant_id) REFERENCES lottery_participants(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS lottery_admin_users (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  full_name VARCHAR(160) NOT NULL,
  username VARCHAR(80) NOT NULL,
  email VARCHAR(190) NULL,
  password_hash VARCHAR(255) NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'active',
  mfa_secret_enc TEXT NULL,
  last_login_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id), UNIQUE KEY uq_lottery_admin_username (username), UNIQUE KEY uq_lottery_admin_email (email),
  CONSTRAINT chk_lottery_admin_status CHECK (status IN ('active','disabled','locked'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS lottery_roles (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, name VARCHAR(60) NOT NULL, description VARCHAR(255) NULL,
  PRIMARY KEY (id), UNIQUE KEY uq_lottery_role_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE IF NOT EXISTS lottery_permissions (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, permission_key VARCHAR(100) NOT NULL, description VARCHAR(255) NULL,
  PRIMARY KEY (id), UNIQUE KEY uq_lottery_permission_key (permission_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE IF NOT EXISTS lottery_admin_role_assignments (
  admin_user_id BIGINT UNSIGNED NOT NULL, role_id BIGINT UNSIGNED NOT NULL, assigned_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (admin_user_id, role_id),
  CONSTRAINT fk_lara_admin FOREIGN KEY (admin_user_id) REFERENCES lottery_admin_users(id),
  CONSTRAINT fk_lara_role FOREIGN KEY (role_id) REFERENCES lottery_roles(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE IF NOT EXISTS lottery_role_permissions (
  role_id BIGINT UNSIGNED NOT NULL, permission_id BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (role_id, permission_id),
  CONSTRAINT fk_lrp_role FOREIGN KEY (role_id) REFERENCES lottery_roles(id),
  CONSTRAINT fk_lrp_permission FOREIGN KEY (permission_id) REFERENCES lottery_permissions(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS lottery_campaigns (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  code VARCHAR(40) NOT NULL, prize_type VARCHAR(30) NOT NULL, prize_value DECIMAL(14,2) NULL,
  ticket_quantity INT UNSIGNED NOT NULL, ticket_price DECIMAL(14,2) NOT NULL, currency CHAR(3) NOT NULL DEFAULT 'ETB',
  status VARCHAR(24) NOT NULL DEFAULT 'draft', starts_at DATETIME NULL, ends_at DATETIME NULL,
  terms_version VARCHAR(40) NULL, created_by BIGINT UNSIGNED NULL, updated_by BIGINT UNSIGNED NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id), UNIQUE KEY uq_lottery_campaign_code (code), KEY idx_lottery_campaign_status_dates (status,starts_at,ends_at),
  CONSTRAINT chk_lottery_campaign_prize CHECK (prize_type IN ('car','house','other')),
  CONSTRAINT chk_lottery_campaign_status CHECK (status IN ('draft','scheduled','active','paused','sold_out','closed','draw_pending','completed','cancelled')),
  CONSTRAINT chk_lottery_campaign_currency CHECK (currency = 'ETB'),
  CONSTRAINT chk_lottery_campaign_price CHECK (ticket_price >= 0 AND (prize_value IS NULL OR prize_value >= 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE IF NOT EXISTS lottery_campaign_translations (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, campaign_id BIGINT UNSIGNED NOT NULL, language_code VARCHAR(5) NOT NULL,
  title VARCHAR(200) NOT NULL, short_description VARCHAR(500) NULL, description MEDIUMTEXT NULL,
  prize_details MEDIUMTEXT NULL, eligibility MEDIUMTEXT NULL, rules MEDIUMTEXT NULL,
  PRIMARY KEY (id), UNIQUE KEY uq_campaign_language (campaign_id,language_code),
  CONSTRAINT fk_lct_campaign FOREIGN KEY (campaign_id) REFERENCES lottery_campaigns(id) ON DELETE CASCADE,
  CONSTRAINT chk_lct_language CHECK (language_code IN ('en','am','ti','om'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE IF NOT EXISTS lottery_campaign_media (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, campaign_id BIGINT UNSIGNED NOT NULL, storage_key VARCHAR(500) NOT NULL,
  media_type VARCHAR(30) NOT NULL DEFAULT 'image', alt_text VARCHAR(255) NULL, sort_order INT NOT NULL DEFAULT 0,
  PRIMARY KEY (id), KEY idx_campaign_media (campaign_id,sort_order),
  CONSTRAINT fk_lcm_campaign FOREIGN KEY (campaign_id) REFERENCES lottery_campaigns(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS lottery_orders (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, reference VARCHAR(40) NOT NULL,
  participant_id BIGINT UNSIGNED NOT NULL, campaign_id BIGINT UNSIGNED NOT NULL,
  quantity INT UNSIGNED NOT NULL, unit_price DECIMAL(14,2) NOT NULL, total_amount DECIMAL(14,2) NOT NULL,
  currency CHAR(3) NOT NULL DEFAULT 'ETB', status VARCHAR(30) NOT NULL DEFAULT 'pending_payment',
  idempotency_key VARCHAR(80) NULL, expires_at DATETIME NULL, proof_submitted_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id), UNIQUE KEY uq_lottery_order_reference (reference),
  UNIQUE KEY uq_order_idempotency (participant_id,idempotency_key), KEY idx_orders_status_expiry (status,expires_at),
  KEY idx_orders_campaign (campaign_id,created_at),
  CONSTRAINT fk_lo_participant FOREIGN KEY (participant_id) REFERENCES lottery_participants(id),
  CONSTRAINT fk_lo_campaign FOREIGN KEY (campaign_id) REFERENCES lottery_campaigns(id),
  CONSTRAINT chk_lo_amounts CHECK (unit_price >= 0 AND total_amount >= 0),
  CONSTRAINT chk_lo_status CHECK (status IN ('pending_payment','proof_submitted','under_review','payment_rejected','paid_confirmed','expired','cancelled','refund_pending','refunded')),
  CONSTRAINT chk_lo_currency CHECK (currency = 'ETB')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE IF NOT EXISTS lottery_tickets (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, campaign_id BIGINT UNSIGNED NOT NULL,
  ticket_number VARCHAR(32) NOT NULL, status VARCHAR(30) NOT NULL DEFAULT 'available',
  current_order_id BIGINT UNSIGNED NULL, participant_id BIGINT UNSIGNED NULL, reserved_until DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id), UNIQUE KEY uq_campaign_ticket_number (campaign_id,ticket_number),
  KEY idx_ticket_inventory (campaign_id,status,reserved_until), KEY idx_ticket_order (current_order_id),
  CONSTRAINT fk_lt_campaign FOREIGN KEY (campaign_id) REFERENCES lottery_campaigns(id),
  CONSTRAINT fk_lt_order FOREIGN KEY (current_order_id) REFERENCES lottery_orders(id),
  CONSTRAINT fk_lt_participant FOREIGN KEY (participant_id) REFERENCES lottery_participants(id),
  CONSTRAINT chk_lt_status CHECK (status IN ('available','reserved','pending_verification','confirmed','released','cancelled'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE IF NOT EXISTS lottery_order_tickets (
  order_id BIGINT UNSIGNED NOT NULL, ticket_id BIGINT UNSIGNED NOT NULL, ticket_number_snapshot VARCHAR(32) NOT NULL,
  unit_price_snapshot DECIMAL(14,2) NOT NULL, created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (order_id,ticket_id), UNIQUE KEY uq_ticket_order_once (ticket_id),
  CONSTRAINT fk_lot_order FOREIGN KEY (order_id) REFERENCES lottery_orders(id),
  CONSTRAINT fk_lot_ticket FOREIGN KEY (ticket_id) REFERENCES lottery_tickets(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS lottery_payment_methods (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, method_type VARCHAR(30) NOT NULL, display_name VARCHAR(120) NOT NULL,
  recipient_name VARCHAR(160) NULL, account_identifier VARCHAR(160) NULL, instructions_en MEDIUMTEXT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1, sort_order INT NOT NULL DEFAULT 0, created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id), KEY idx_payment_method_active (is_active,sort_order),
  CONSTRAINT chk_payment_method_type CHECK (method_type IN ('bank_transfer','mobile_money'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE IF NOT EXISTS lottery_payment_method_translations (
  payment_method_id BIGINT UNSIGNED NOT NULL, language_code VARCHAR(5) NOT NULL, instructions MEDIUMTEXT NOT NULL,
  PRIMARY KEY (payment_method_id,language_code),
  CONSTRAINT fk_lpmt_method FOREIGN KEY (payment_method_id) REFERENCES lottery_payment_methods(id) ON DELETE CASCADE,
  CONSTRAINT chk_lpmt_language CHECK (language_code IN ('en','am','ti','om'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE IF NOT EXISTS lottery_payments (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, order_id BIGINT UNSIGNED NOT NULL, payment_method_id BIGINT UNSIGNED NOT NULL,
  expected_amount DECIMAL(14,2) NOT NULL, submitted_amount DECIMAL(14,2) NULL, currency CHAR(3) NOT NULL DEFAULT 'ETB',
  transaction_reference VARCHAR(120) NULL, payer_name VARCHAR(160) NULL, payment_date DATE NULL,
  status VARCHAR(24) NOT NULL DEFAULT 'pending_verification', created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id), KEY idx_payment_review (status,created_at), KEY idx_payment_reference (transaction_reference),
  CONSTRAINT fk_lpay_order FOREIGN KEY (order_id) REFERENCES lottery_orders(id),
  CONSTRAINT fk_lpay_method FOREIGN KEY (payment_method_id) REFERENCES lottery_payment_methods(id),
  CONSTRAINT chk_lpay_status CHECK (status IN ('pending_verification','under_review','approved','rejected','voided')),
  CONSTRAINT chk_lpay_amount CHECK (expected_amount >= 0 AND (submitted_amount IS NULL OR submitted_amount >= 0)),
  CONSTRAINT chk_lpay_currency CHECK (currency = 'ETB')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE IF NOT EXISTS lottery_payment_evidence (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, payment_id BIGINT UNSIGNED NOT NULL, storage_key VARCHAR(500) NOT NULL,
  original_filename VARCHAR(255) NOT NULL, detected_mime VARCHAR(100) NOT NULL, file_size BIGINT UNSIGNED NOT NULL,
  sha256 CHAR(64) NOT NULL, uploaded_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id), KEY idx_payment_evidence_payment (payment_id), KEY idx_payment_evidence_hash (sha256),
  CONSTRAINT fk_lpe_payment FOREIGN KEY (payment_id) REFERENCES lottery_payments(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE IF NOT EXISTS lottery_payment_verifications (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, payment_id BIGINT UNSIGNED NOT NULL, verifier_admin_id BIGINT UNSIGNED NOT NULL,
  decision VARCHAR(20) NOT NULL, reason VARCHAR(500) NULL, notes MEDIUMTEXT NULL, created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id), KEY idx_payment_verification_history (payment_id,created_at),
  CONSTRAINT fk_lpv_payment FOREIGN KEY (payment_id) REFERENCES lottery_payments(id),
  CONSTRAINT fk_lpv_admin FOREIGN KEY (verifier_admin_id) REFERENCES lottery_admin_users(id),
  CONSTRAINT chk_lpv_decision CHECK (decision IN ('approved','rejected','reversed'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS lottery_draws (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, campaign_id BIGINT UNSIGNED NOT NULL, scheduled_at DATETIME NULL,
  conducted_at DATETIME NULL, venue VARCHAR(255) NULL, method VARCHAR(120) NULL, status VARCHAR(24) NOT NULL DEFAULT 'draft',
  notes MEDIUMTEXT NULL, created_by BIGINT UNSIGNED NOT NULL, approved_by BIGINT UNSIGNED NULL, approved_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id), KEY idx_draw_campaign (campaign_id,status),
  CONSTRAINT fk_ld_campaign FOREIGN KEY (campaign_id) REFERENCES lottery_campaigns(id),
  CONSTRAINT fk_ld_creator FOREIGN KEY (created_by) REFERENCES lottery_admin_users(id),
  CONSTRAINT fk_ld_approver FOREIGN KEY (approved_by) REFERENCES lottery_admin_users(id),
  CONSTRAINT chk_ld_status CHECK (status IN ('draft','recorded','pending_approval','approved','published','cancelled'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE IF NOT EXISTS lottery_draw_witnesses (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, draw_id BIGINT UNSIGNED NOT NULL, witness_name VARCHAR(160) NOT NULL,
  witness_role VARCHAR(120) NULL, confirmation_note VARCHAR(500) NULL, evidence_storage_key VARCHAR(500) NULL,
  PRIMARY KEY (id), KEY idx_draw_witness (draw_id),
  CONSTRAINT fk_ldw_draw FOREIGN KEY (draw_id) REFERENCES lottery_draws(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE IF NOT EXISTS lottery_winners (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, draw_id BIGINT UNSIGNED NOT NULL, ticket_id BIGINT UNSIGNED NOT NULL,
  participant_id BIGINT UNSIGNED NOT NULL, verification_status VARCHAR(24) NOT NULL DEFAULT 'pending',
  publication_status VARCHAR(24) NOT NULL DEFAULT 'private', consent_recorded_at DATETIME NULL, published_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id), UNIQUE KEY uq_draw_winner_ticket (draw_id,ticket_id),
  CONSTRAINT fk_lw_draw FOREIGN KEY (draw_id) REFERENCES lottery_draws(id),
  CONSTRAINT fk_lw_ticket FOREIGN KEY (ticket_id) REFERENCES lottery_tickets(id),
  CONSTRAINT fk_lw_participant FOREIGN KEY (participant_id) REFERENCES lottery_participants(id),
  CONSTRAINT chk_lw_verify CHECK (verification_status IN ('pending','verified','rejected')),
  CONSTRAINT chk_lw_publish CHECK (publication_status IN ('private','approved','published','withdrawn'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS lottery_notification_logs (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, participant_id BIGINT UNSIGNED NOT NULL, notification_type VARCHAR(80) NOT NULL,
  language_code VARCHAR(5) NOT NULL, payload_json JSON NULL, status VARCHAR(20) NOT NULL DEFAULT 'queued',
  attempts TINYINT UNSIGNED NOT NULL DEFAULT 0, last_error VARCHAR(500) NULL, scheduled_at DATETIME NULL,
  sent_at DATETIME NULL, created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id), KEY idx_notification_queue (status,scheduled_at), KEY idx_notification_participant (participant_id,created_at),
  CONSTRAINT fk_lnl_participant FOREIGN KEY (participant_id) REFERENCES lottery_participants(id),
  CONSTRAINT chk_lnl_status CHECK (status IN ('queued','sent','failed','cancelled'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE IF NOT EXISTS lottery_audit_logs (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, actor_type VARCHAR(20) NOT NULL, actor_id BIGINT UNSIGNED NULL,
  action VARCHAR(100) NOT NULL, entity_type VARCHAR(80) NOT NULL, entity_id BIGINT UNSIGNED NULL,
  before_json JSON NULL, after_json JSON NULL, ip_hash CHAR(64) NULL, user_agent VARCHAR(255) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id), KEY idx_audit_entity (entity_type,entity_id,created_at), KEY idx_audit_actor (actor_type,actor_id,created_at),
  CONSTRAINT chk_audit_actor CHECK (actor_type IN ('participant','admin','system'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO lottery_roles(name,description) VALUES
 ('super_administrator','Full system configuration and privileged access'),
 ('administrator','Operational administration within assigned permissions'),
 ('campaign_manager','Campaign setup and lifecycle management'),
 ('payment_verifier','Manual payment evidence review'),
 ('draw_manager','In-person draw record management');
INSERT IGNORE INTO lottery_permissions(permission_key,description) VALUES
 ('campaign.manage','Create and manage campaigns'),('ticket.manage','Manage ticket inventory'),
 ('payment.review','Approve or reject payment evidence'),('draw.manage','Record and manage draws'),
 ('participant.view','View participant records'),('reports.view','View and export reports'),
 ('admin.manage','Manage admin users and roles'),('settings.manage','Manage global settings and translations'),
 ('audit.view','View audit logs');
