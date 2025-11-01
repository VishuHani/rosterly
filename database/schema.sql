-- =============================================
-- SmartRoster Database Schema
-- Postgres + Supabase
-- =============================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "vector";

-- =============================================
-- 1. CORE TABLES
-- =============================================

-- Accounts (business owners can have multiple venues)
CREATE TABLE accounts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  owner_email TEXT NOT NULL,
  subscription_tier TEXT DEFAULT 'free' CHECK (subscription_tier IN ('free', 'standard', 'premium')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Venues (restaurants, cafes, bars, etc.)
CREATE TABLE venues (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  address TEXT,
  timezone TEXT NOT NULL DEFAULT 'Australia/Sydney',
  -- Geofencing for clock-in/out
  latitude NUMERIC(10, 7),
  longitude NUMERIC(10, 7),
  radius_meters INTEGER DEFAULT 100,
  settings JSONB DEFAULT '{}'::jsonb, -- venue-specific configs
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Users (staff members across all venues)
CREATE TABLE users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT UNIQUE NOT NULL,
  phone TEXT,
  display_name TEXT NOT NULL,
  avatar_url TEXT,
  -- Name matching: store aliases for fuzzy matching
  aliases TEXT[] DEFAULT ARRAY[]::TEXT[],
  name_embedding vector(1536), -- text-embedding-3-large dimension
  -- Privacy & consent
  background_location_consent BOOLEAN DEFAULT FALSE,
  background_location_consent_date TIMESTAMPTZ,
  notification_preferences JSONB DEFAULT '{
    "push_enabled": true,
    "email_enabled": true,
    "quiet_hours_start": null,
    "quiet_hours_end": null
  }'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Roles (Manager, Staff, Admin, custom roles)
CREATE TABLE roles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  venue_id UUID REFERENCES venues(id) ON DELETE CASCADE,
  account_id UUID REFERENCES accounts(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  is_system_role BOOLEAN DEFAULT FALSE, -- system roles can't be deleted
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT role_scope_check CHECK (
    (venue_id IS NOT NULL AND account_id IS NULL) OR
    (venue_id IS NULL AND account_id IS NOT NULL)
  )
);

-- Permissions (granular access control)
CREATE TABLE permissions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  resource TEXT NOT NULL, -- 'rosters', 'attendance', 'chat', 'announcements', 'reports'
  action TEXT NOT NULL, -- 'read', 'write', 'delete', 'approve'
  UNIQUE(role_id, resource, action)
);

-- User-Venue-Role mapping (many-to-many)
CREATE TABLE user_venue_roles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  venue_id UUID NOT NULL REFERENCES venues(id) ON DELETE CASCADE,
  role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  assigned_by UUID REFERENCES users(id),
  UNIQUE(user_id, venue_id, role_id)
);

-- =============================================
-- 2. ROSTER & SHIFTS
-- =============================================

-- Rosters (versioned per venue/week)
CREATE TABLE rosters (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  venue_id UUID NOT NULL REFERENCES venues(id) ON DELETE CASCADE,
  week_start_date DATE NOT NULL, -- Monday of the week
  version INTEGER NOT NULL DEFAULT 1,
  source_file_url TEXT, -- original upload in Supabase Storage
  source_file_name TEXT,
  uploaded_by UUID REFERENCES users(id),
  status TEXT DEFAULT 'draft' CHECK (status IN ('draft', 'published', 'archived')),
  published_at TIMESTAMPTZ,
  metadata JSONB DEFAULT '{}'::jsonb, -- parsing stats, AI confidence, etc.
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(venue_id, week_start_date, version)
);

-- Shifts (extracted from rosters)
CREATE TABLE shifts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  roster_id UUID NOT NULL REFERENCES rosters(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  venue_id UUID NOT NULL REFERENCES venues(id) ON DELETE CASCADE,

  -- Shift timing
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ NOT NULL,
  break_minutes INTEGER DEFAULT 0,

  -- Shift details
  role_tag TEXT, -- 'Chef', 'Barista', 'Server', etc.
  notes TEXT,

  -- AI matching
  original_name TEXT, -- name as it appeared in roster
  match_confidence NUMERIC(3, 2), -- 0.00 to 1.00
  manually_matched BOOLEAN DEFAULT FALSE,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE(roster_id, user_id, start_time, end_time)
);

-- Shift changes (for notification diff)
CREATE TABLE shift_changes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  venue_id UUID NOT NULL REFERENCES venues(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  old_roster_id UUID REFERENCES rosters(id),
  new_roster_id UUID NOT NULL REFERENCES rosters(id),
  old_shift_id UUID REFERENCES shifts(id),
  new_shift_id UUID REFERENCES shifts(id),
  change_type TEXT NOT NULL CHECK (change_type IN ('added', 'removed', 'modified', 'unchanged')),
  change_summary TEXT, -- AI-generated human-readable summary
  notified_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================
-- 3. ATTENDANCE & LOCATION
-- =============================================

-- Attendance records (clock in/out)
CREATE TABLE attendance (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  venue_id UUID NOT NULL REFERENCES venues(id) ON DELETE CASCADE,
  shift_id UUID REFERENCES shifts(id),

  -- Clock times
  clock_in_time TIMESTAMPTZ NOT NULL,
  clock_in_latitude NUMERIC(10, 7),
  clock_in_longitude NUMERIC(10, 7),
  clock_in_within_geofence BOOLEAN DEFAULT TRUE,

  clock_out_time TIMESTAMPTZ,
  clock_out_latitude NUMERIC(10, 7),
  clock_out_longitude NUMERIC(10, 7),
  clock_out_within_geofence BOOLEAN DEFAULT TRUE,

  -- Approval workflow
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  approved_by UUID REFERENCES users(id),
  approved_at TIMESTAMPTZ,
  rejection_reason TEXT,

  -- Calculations
  total_hours NUMERIC(5, 2),

  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Location pings (opt-in background tracking during shift)
CREATE TABLE location_pings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  venue_id UUID NOT NULL REFERENCES venues(id) ON DELETE CASCADE,
  shift_id UUID REFERENCES shifts(id),
  attendance_id UUID REFERENCES attendance(id),

  latitude NUMERIC(10, 7) NOT NULL,
  longitude NUMERIC(10, 7) NOT NULL,
  accuracy_meters NUMERIC(6, 2),

  recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================
-- 4. AVAILABILITY & LEAVE
-- =============================================

-- Staff availability (recurring or one-off)
CREATE TABLE availability (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  venue_id UUID NOT NULL REFERENCES venues(id) ON DELETE CASCADE,

  -- Time range
  start_date DATE,
  end_date DATE,
  day_of_week INTEGER, -- 0=Sunday, 6=Saturday (for recurring)
  start_time TIME,
  end_time TIME,

  is_available BOOLEAN DEFAULT TRUE, -- FALSE = unavailable
  is_recurring BOOLEAN DEFAULT FALSE,

  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Leave requests
CREATE TABLE leave_requests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  venue_id UUID NOT NULL REFERENCES venues(id) ON DELETE CASCADE,

  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  leave_type TEXT CHECK (leave_type IN ('annual', 'sick', 'personal', 'unpaid', 'other')),
  reason TEXT,

  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  reviewed_by UUID REFERENCES users(id),
  reviewed_at TIMESTAMPTZ,
  review_notes TEXT,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================
-- 5. COMMUNICATION
-- =============================================

-- Announcements (venue-wide or role-specific)
CREATE TABLE announcements (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  venue_id UUID NOT NULL REFERENCES venues(id) ON DELETE CASCADE,
  author_id UUID NOT NULL REFERENCES users(id),

  title TEXT NOT NULL,
  body TEXT NOT NULL,
  media_urls TEXT[], -- images, videos, gifs, audio from Supabase Storage

  -- Audience targeting
  target_roles UUID[], -- array of role_ids, NULL = everyone

  pinned BOOLEAN DEFAULT FALSE,
  published_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Chat threads (venue channels + DMs)
CREATE TABLE threads (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  venue_id UUID REFERENCES venues(id) ON DELETE CASCADE,

  thread_type TEXT NOT NULL CHECK (thread_type IN ('channel', 'direct')),
  name TEXT, -- for channels
  description TEXT,

  -- For direct messages
  participant_ids UUID[], -- array of user_ids

  created_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT thread_venue_check CHECK (
    (thread_type = 'channel' AND venue_id IS NOT NULL) OR
    (thread_type = 'direct')
  )
);

-- Chat messages
CREATE TABLE messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  thread_id UUID NOT NULL REFERENCES threads(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES users(id),

  content TEXT NOT NULL,
  media_url TEXT,

  -- Moderation
  flagged BOOLEAN DEFAULT FALSE,
  moderation_result JSONB, -- from omni-moderation-latest

  -- Editing
  edited_at TIMESTAMPTZ,
  deleted_at TIMESTAMPTZ,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Thread members (who can see each thread)
CREATE TABLE thread_members (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  thread_id UUID NOT NULL REFERENCES threads(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_read_at TIMESTAMPTZ,
  UNIQUE(thread_id, user_id)
);

-- =============================================
-- 6. NOTIFICATIONS
-- =============================================

-- Notification rules (per-user reminder offsets)
CREATE TABLE notification_rules (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  venue_id UUID REFERENCES venues(id) ON DELETE CASCADE,

  rule_type TEXT NOT NULL CHECK (rule_type IN ('shift_reminder', 'shift_change', 'announcement', 'leave_approval')),

  -- Offset examples: ["-1d@09:00", "-5h", "-2h"]
  offsets JSONB DEFAULT '[]'::jsonb,

  enabled BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Device tokens (for push notifications)
CREATE TABLE device_tokens (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token TEXT NOT NULL UNIQUE,
  platform TEXT NOT NULL CHECK (platform IN ('ios', 'android', 'web')),
  device_info JSONB,
  last_used_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Notification log (audit trail)
CREATE TABLE notification_log (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  notification_type TEXT NOT NULL,
  title TEXT,
  body TEXT,

  -- Delivery
  sent_via TEXT CHECK (sent_via IN ('push', 'email', 'sms')),
  sent_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  delivery_status TEXT DEFAULT 'sent' CHECK (delivery_status IN ('sent', 'delivered', 'failed', 'bounced')),

  -- Context
  related_entity_type TEXT, -- 'shift', 'announcement', 'leave_request'
  related_entity_id UUID,

  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================
-- 7. INDEXES FOR PERFORMANCE
-- =============================================

-- Accounts & Venues
CREATE INDEX idx_venues_account_id ON venues(account_id);

-- Users
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_display_name ON users(display_name);

-- User-Venue-Roles
CREATE INDEX idx_user_venue_roles_user_id ON user_venue_roles(user_id);
CREATE INDEX idx_user_venue_roles_venue_id ON user_venue_roles(venue_id);
CREATE INDEX idx_user_venue_roles_role_id ON user_venue_roles(role_id);

-- Rosters
CREATE INDEX idx_rosters_venue_id ON rosters(venue_id);
CREATE INDEX idx_rosters_week_start_date ON rosters(week_start_date);
CREATE INDEX idx_rosters_status ON rosters(status);

-- Shifts
CREATE INDEX idx_shifts_roster_id ON shifts(roster_id);
CREATE INDEX idx_shifts_user_id ON shifts(user_id);
CREATE INDEX idx_shifts_venue_id ON shifts(venue_id);
CREATE INDEX idx_shifts_start_time ON shifts(start_time);
CREATE INDEX idx_shifts_user_start_time ON shifts(user_id, start_time);

-- Shift changes
CREATE INDEX idx_shift_changes_user_id ON shift_changes(user_id);
CREATE INDEX idx_shift_changes_venue_id ON shift_changes(venue_id);
CREATE INDEX idx_shift_changes_new_roster_id ON shift_changes(new_roster_id);
CREATE INDEX idx_shift_changes_notified_at ON shift_changes(notified_at);

-- Attendance
CREATE INDEX idx_attendance_user_id ON attendance(user_id);
CREATE INDEX idx_attendance_venue_id ON attendance(venue_id);
CREATE INDEX idx_attendance_shift_id ON attendance(shift_id);
CREATE INDEX idx_attendance_clock_in_time ON attendance(clock_in_time);
CREATE INDEX idx_attendance_status ON attendance(status);

-- Location pings
CREATE INDEX idx_location_pings_user_id ON location_pings(user_id);
CREATE INDEX idx_location_pings_shift_id ON location_pings(shift_id);
CREATE INDEX idx_location_pings_recorded_at ON location_pings(recorded_at);

-- Availability & Leave
CREATE INDEX idx_availability_user_id ON availability(user_id);
CREATE INDEX idx_availability_venue_id ON availability(venue_id);
CREATE INDEX idx_leave_requests_user_id ON leave_requests(user_id);
CREATE INDEX idx_leave_requests_venue_id ON leave_requests(venue_id);
CREATE INDEX idx_leave_requests_status ON leave_requests(status);

-- Communication
CREATE INDEX idx_announcements_venue_id ON announcements(venue_id);
CREATE INDEX idx_announcements_published_at ON announcements(published_at);
CREATE INDEX idx_threads_venue_id ON threads(venue_id);
CREATE INDEX idx_messages_thread_id ON messages(thread_id);
CREATE INDEX idx_messages_sender_id ON messages(sender_id);
CREATE INDEX idx_messages_created_at ON messages(created_at);
CREATE INDEX idx_thread_members_user_id ON thread_members(user_id);
CREATE INDEX idx_thread_members_thread_id ON thread_members(thread_id);

-- Notifications
CREATE INDEX idx_notification_rules_user_id ON notification_rules(user_id);
CREATE INDEX idx_device_tokens_user_id ON device_tokens(user_id);
CREATE INDEX idx_notification_log_user_id ON notification_log(user_id);
CREATE INDEX idx_notification_log_sent_at ON notification_log(sent_at);

-- Vector search index for name matching
CREATE INDEX idx_users_name_embedding ON users USING ivfflat (name_embedding vector_cosine_ops)
  WITH (lists = 100);

-- =============================================
-- 8. TRIGGERS & FUNCTIONS
-- =============================================

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to all tables with updated_at
CREATE TRIGGER update_accounts_updated_at BEFORE UPDATE ON accounts
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_venues_updated_at BEFORE UPDATE ON venues
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_rosters_updated_at BEFORE UPDATE ON rosters
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_shifts_updated_at BEFORE UPDATE ON shifts
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_attendance_updated_at BEFORE UPDATE ON attendance
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_availability_updated_at BEFORE UPDATE ON availability
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_leave_requests_updated_at BEFORE UPDATE ON leave_requests
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_announcements_updated_at BEFORE UPDATE ON announcements
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_threads_updated_at BEFORE UPDATE ON threads
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_notification_rules_updated_at BEFORE UPDATE ON notification_rules
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Auto-calculate attendance hours
CREATE OR REPLACE FUNCTION calculate_attendance_hours()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.clock_out_time IS NOT NULL THEN
    NEW.total_hours = EXTRACT(EPOCH FROM (NEW.clock_out_time - NEW.clock_in_time)) / 3600.0;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER calc_attendance_hours BEFORE INSERT OR UPDATE ON attendance
  FOR EACH ROW EXECUTE FUNCTION calculate_attendance_hours();

-- Auto-increment roster version
CREATE OR REPLACE FUNCTION auto_increment_roster_version()
RETURNS TRIGGER AS $$
BEGIN
  SELECT COALESCE(MAX(version), 0) + 1 INTO NEW.version
  FROM rosters
  WHERE venue_id = NEW.venue_id AND week_start_date = NEW.week_start_date;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER roster_version_increment BEFORE INSERT ON rosters
  FOR EACH ROW EXECUTE FUNCTION auto_increment_roster_version();

-- =============================================
-- 9. HELPER FUNCTIONS
-- =============================================

-- Check if user has permission in venue
CREATE OR REPLACE FUNCTION user_has_permission(
  p_user_id UUID,
  p_venue_id UUID,
  p_resource TEXT,
  p_action TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
  has_perm BOOLEAN;
BEGIN
  SELECT EXISTS (
    SELECT 1
    FROM user_venue_roles uvr
    JOIN permissions p ON p.role_id = uvr.role_id
    WHERE uvr.user_id = p_user_id
      AND uvr.venue_id = p_venue_id
      AND p.resource = p_resource
      AND p.action = p_action
  ) INTO has_perm;

  RETURN has_perm;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get user's upcoming shifts
CREATE OR REPLACE FUNCTION get_upcoming_shifts(
  p_user_id UUID,
  p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
  shift_id UUID,
  venue_name TEXT,
  start_time TIMESTAMPTZ,
  end_time TIMESTAMPTZ,
  role_tag TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    s.id,
    v.name,
    s.start_time,
    s.end_time,
    s.role_tag
  FROM shifts s
  JOIN venues v ON v.id = s.venue_id
  JOIN rosters r ON r.id = s.roster_id
  WHERE s.user_id = p_user_id
    AND s.start_time >= NOW()
    AND r.status = 'published'
  ORDER BY s.start_time ASC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- 10. ROW LEVEL SECURITY (RLS) POLICIES
-- =============================================

-- Enable RLS on all tables
ALTER TABLE accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE venues ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_venue_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE rosters ENABLE ROW LEVEL SECURITY;
ALTER TABLE shifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE shift_changes ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE location_pings ENABLE ROW LEVEL SECURITY;
ALTER TABLE availability ENABLE ROW LEVEL SECURITY;
ALTER TABLE leave_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE threads ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE thread_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_log ENABLE ROW LEVEL SECURITY;

-- =============================================
-- USERS TABLE POLICIES
-- =============================================

-- Users can read their own profile
CREATE POLICY users_read_own ON users
  FOR SELECT
  USING (auth.uid() = id);

-- Users can update their own profile
CREATE POLICY users_update_own ON users
  FOR UPDATE
  USING (auth.uid() = id);

-- Managers can read users in their venues
CREATE POLICY users_read_venue_staff ON users
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM user_venue_roles uvr1
      WHERE uvr1.user_id = auth.uid()
        AND user_has_permission(auth.uid(), uvr1.venue_id, 'staff', 'read')
        AND EXISTS (
          SELECT 1 FROM user_venue_roles uvr2
          WHERE uvr2.user_id = users.id
            AND uvr2.venue_id = uvr1.venue_id
        )
    )
  );

-- =============================================
-- VENUES TABLE POLICIES
-- =============================================

-- Users can read venues they're assigned to
CREATE POLICY venues_read_assigned ON venues
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM user_venue_roles
      WHERE user_id = auth.uid() AND venue_id = venues.id
    )
  );

-- Account owners can manage their venues
CREATE POLICY venues_manage_by_owner ON venues
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM accounts
      WHERE accounts.id = venues.account_id
        AND accounts.owner_email = (SELECT email FROM auth.users WHERE id = auth.uid())
    )
  );

-- =============================================
-- ROSTERS & SHIFTS POLICIES
-- =============================================

-- Staff can read published rosters for their venues
CREATE POLICY rosters_read_published ON rosters
  FOR SELECT
  USING (
    status = 'published'
    AND EXISTS (
      SELECT 1 FROM user_venue_roles
      WHERE user_id = auth.uid() AND venue_id = rosters.venue_id
    )
  );

-- Managers can read all rosters in their venues
CREATE POLICY rosters_read_managers ON rosters
  FOR SELECT
  USING (
    user_has_permission(auth.uid(), venue_id, 'rosters', 'read')
  );

-- Managers can create/update rosters
CREATE POLICY rosters_write_managers ON rosters
  FOR ALL
  USING (
    user_has_permission(auth.uid(), venue_id, 'rosters', 'write')
  );

-- Staff can read their own shifts
CREATE POLICY shifts_read_own ON shifts
  FOR SELECT
  USING (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM rosters
      WHERE rosters.id = shifts.roster_id
        AND rosters.status = 'published'
    )
  );

-- Managers can read all shifts in their venues
CREATE POLICY shifts_read_managers ON shifts
  FOR SELECT
  USING (
    user_has_permission(auth.uid(), venue_id, 'rosters', 'read')
  );

-- Managers can manage shifts
CREATE POLICY shifts_write_managers ON shifts
  FOR ALL
  USING (
    user_has_permission(auth.uid(), venue_id, 'rosters', 'write')
  );

-- Staff can read their own shift changes
CREATE POLICY shift_changes_read_own ON shift_changes
  FOR SELECT
  USING (user_id = auth.uid());

-- Managers can read shift changes in their venues
CREATE POLICY shift_changes_read_managers ON shift_changes
  FOR SELECT
  USING (
    user_has_permission(auth.uid(), venue_id, 'rosters', 'read')
  );

-- =============================================
-- ATTENDANCE POLICIES
-- =============================================

-- Staff can read their own attendance
CREATE POLICY attendance_read_own ON attendance
  FOR SELECT
  USING (user_id = auth.uid());

-- Staff can create their own attendance (clock in/out)
CREATE POLICY attendance_create_own ON attendance
  FOR INSERT
  WITH CHECK (user_id = auth.uid());

-- Staff can update their own attendance (clock out)
CREATE POLICY attendance_update_own ON attendance
  FOR UPDATE
  USING (user_id = auth.uid() AND status = 'pending');

-- Managers can read attendance in their venues
CREATE POLICY attendance_read_managers ON attendance
  FOR SELECT
  USING (
    user_has_permission(auth.uid(), venue_id, 'attendance', 'read')
  );

-- Managers can approve attendance
CREATE POLICY attendance_approve_managers ON attendance
  FOR UPDATE
  USING (
    user_has_permission(auth.uid(), venue_id, 'attendance', 'approve')
  );

-- =============================================
-- LOCATION PINGS POLICIES
-- =============================================

-- Staff can read their own location pings
CREATE POLICY location_pings_read_own ON location_pings
  FOR SELECT
  USING (user_id = auth.uid());

-- Staff can create their own location pings
CREATE POLICY location_pings_create_own ON location_pings
  FOR INSERT
  WITH CHECK (user_id = auth.uid());

-- Managers can read location pings in their venues
CREATE POLICY location_pings_read_managers ON location_pings
  FOR SELECT
  USING (
    user_has_permission(auth.uid(), venue_id, 'attendance', 'read')
  );

-- =============================================
-- AVAILABILITY & LEAVE POLICIES
-- =============================================

-- Staff can manage their own availability
CREATE POLICY availability_manage_own ON availability
  FOR ALL
  USING (user_id = auth.uid());

-- Managers can read availability in their venues
CREATE POLICY availability_read_managers ON availability
  FOR SELECT
  USING (
    user_has_permission(auth.uid(), venue_id, 'staff', 'read')
  );

-- Staff can manage their own leave requests
CREATE POLICY leave_requests_manage_own ON leave_requests
  FOR ALL
  USING (user_id = auth.uid());

-- Managers can read leave requests in their venues
CREATE POLICY leave_requests_read_managers ON leave_requests
  FOR SELECT
  USING (
    user_has_permission(auth.uid(), venue_id, 'staff', 'read')
  );

-- Managers can approve leave requests
CREATE POLICY leave_requests_approve_managers ON leave_requests
  FOR UPDATE
  USING (
    user_has_permission(auth.uid(), venue_id, 'leave', 'approve')
  );

-- =============================================
-- COMMUNICATION POLICIES
-- =============================================

-- Staff can read announcements for their venues
CREATE POLICY announcements_read_staff ON announcements
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM user_venue_roles
      WHERE user_id = auth.uid() AND venue_id = announcements.venue_id
    )
    AND (
      target_roles IS NULL
      OR EXISTS (
        SELECT 1 FROM user_venue_roles
        WHERE user_id = auth.uid()
          AND venue_id = announcements.venue_id
          AND role_id = ANY(target_roles)
      )
    )
  );

-- Managers can create announcements
CREATE POLICY announcements_create_managers ON announcements
  FOR INSERT
  WITH CHECK (
    user_has_permission(auth.uid(), venue_id, 'announcements', 'write')
  );

-- Authors can update their own announcements
CREATE POLICY announcements_update_own ON announcements
  FOR UPDATE
  USING (author_id = auth.uid());

-- Users can read threads they're members of
CREATE POLICY threads_read_members ON threads
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM thread_members
      WHERE thread_id = threads.id AND user_id = auth.uid()
    )
  );

-- Users can read messages in threads they're members of
CREATE POLICY messages_read_members ON messages
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM thread_members
      WHERE thread_id = messages.thread_id AND user_id = auth.uid()
    )
  );

-- Users can create messages in threads they're members of
CREATE POLICY messages_create_members ON messages
  FOR INSERT
  WITH CHECK (
    sender_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM thread_members
      WHERE thread_id = messages.thread_id AND user_id = auth.uid()
    )
  );

-- Users can update their own messages
CREATE POLICY messages_update_own ON messages
  FOR UPDATE
  USING (sender_id = auth.uid());

-- Users can manage their thread memberships
CREATE POLICY thread_members_manage_own ON thread_members
  FOR ALL
  USING (user_id = auth.uid());

-- =============================================
-- NOTIFICATION POLICIES
-- =============================================

-- Users can manage their own notification rules
CREATE POLICY notification_rules_manage_own ON notification_rules
  FOR ALL
  USING (user_id = auth.uid());

-- Users can manage their own device tokens
CREATE POLICY device_tokens_manage_own ON device_tokens
  FOR ALL
  USING (user_id = auth.uid());

-- Users can read their own notification log
CREATE POLICY notification_log_read_own ON notification_log
  FOR SELECT
  USING (user_id = auth.uid());

-- =============================================
-- 11. REALTIME SUBSCRIPTIONS
-- =============================================

-- Enable Realtime for chat and announcements
ALTER PUBLICATION supabase_realtime ADD TABLE messages;
ALTER PUBLICATION supabase_realtime ADD TABLE threads;
ALTER PUBLICATION supabase_realtime ADD TABLE announcements;
ALTER PUBLICATION supabase_realtime ADD TABLE shift_changes;

-- =============================================
-- 12. SEED DATA (System Roles)
-- =============================================

-- Note: Insert seed data after account/venue creation
-- This is a template; actual seeds would be inserted by the application

-- Example system roles (to be inserted per account):
-- INSERT INTO roles (account_id, name, description, is_system_role) VALUES
-- ('account-uuid', 'Admin', 'Full system access', true),
-- ('account-uuid', 'Manager', 'Venue management access', true),
-- ('account-uuid', 'Staff', 'Basic staff access', true);

-- Example permissions (to be inserted per role):
-- Admin gets all permissions
-- Manager gets: rosters.*, attendance.*, announcements.*, chat.*, staff.read, leave.approve
-- Staff gets: rosters.read, attendance.read/write (own), chat.*, announcements.read

-- =============================================
-- END OF SCHEMA
-- =============================================

-- To apply this schema to your Supabase project:
-- 1. Go to Supabase Dashboard → SQL Editor
-- 2. Create a new query
-- 3. Paste this entire file
-- 4. Click "Run" to execute
-- 5. Verify all tables are created in the Table Editor
