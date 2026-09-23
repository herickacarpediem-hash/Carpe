-- ====================================================================
-- CARPEDESAFIO — CORRIDA PELO PRÊMIO RECLAME AQUI
-- Schema PostgreSQL / Supabase + Row Level Security (RLS) Policies
-- ====================================================================

-- 1. USERS (Equipe DGG/Admin & Líderes)
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT UNIQUE NOT NULL,
    full_name TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('ADMIN', 'LEADER')),
    team_id UUID REFERENCES public.teams(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. TEAMS (Equipes participantes)
CREATE TABLE IF NOT EXISTS public.teams (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT UNIQUE NOT NULL,
    color TEXT DEFAULT '#3B82F6',
    leader_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    weekly_goal_multiplier INT DEFAULT 3,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. TEAM MEMBERS (Integrantes das equipes - sem login individual)
CREATE TABLE IF NOT EXISTS public.team_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    role TEXT DEFAULT 'Membro',
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 4. WEEKS (Semanas da campanha)
CREATE TABLE IF NOT EXISTS public.weeks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    number INT NOT NULL UNIQUE,
    title TEXT NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    status TEXT NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'IN_AUDIT', 'CLOSED')),
    closed_at TIMESTAMP WITH TIME ZONE,
    closed_by UUID REFERENCES public.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 5. MISSIONS (Missões Normais e Missões-Relâmpago)
CREATE TABLE IF NOT EXISTS public.missions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT,
    category TEXT NOT NULL, -- 'CarpeClub', 'WhatsApp', 'Instagram', 'LinkedIn', 'Status WhatsApp', 'Presencial', 'Blitz', 'Outra'
    points INT NOT NULL DEFAULT 10,
    is_blitz BOOLEAN DEFAULT false,
    start_date TIMESTAMP WITH TIME ZONE,
    end_date TIMESTAMP WITH TIME ZONE,
    max_submissions INT,
    requires_approval BOOLEAN DEFAULT true,
    status TEXT DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'ENDING_SOON', 'CLOSED')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 6. MISSION RULES (Regras de pontuação configuráveis)
CREATE TABLE IF NOT EXISTS public.mission_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category TEXT UNIQUE NOT NULL,
    points_per_unit INT NOT NULL DEFAULT 5,
    bonus_100_percent_participation INT DEFAULT 30,
    bonus_goal_met INT DEFAULT 50,
    requires_evidence_above_points INT DEFAULT 20,
    requires_admin_approval_above_points INT DEFAULT 50,
    tier_config JSONB DEFAULT '[]'::jsonb,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 7. SUBMISSIONS (Registro de ações)
CREATE TABLE IF NOT EXISTS public.submissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT UNIQUE NOT NULL, -- e.g. CP-2026-0922-00482
    team_id UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
    leader_id UUID NOT NULL REFERENCES public.users(id),
    week_id UUID REFERENCES public.weeks(id),
    mission_id UUID REFERENCES public.missions(id) ON DELETE SET NULL,
    category TEXT NOT NULL,
    action_date DATE NOT NULL,
    quantity INT NOT NULL DEFAULT 1,
    description TEXT,
    calculated_points INT NOT NULL DEFAULT 0,
    official_points INT DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'PENDING' CHECK (status IN ('DRAFT', 'PENDING', 'IN_REVIEW', 'APPROVED', 'REJECTED', 'CORRECTION_REQUESTED', 'CANCELLED')),
    is_possible_duplicate BOOLEAN DEFAULT false,
    duplicate_reason TEXT,
    rejection_reason TEXT,
    manual_override_justification TEXT,
    reviewed_at TIMESTAMP WITH TIME ZONE,
    reviewed_by UUID REFERENCES public.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 8. SUBMISSION PARTICIPANTS (Participantes vinculados à submissão)
CREATE TABLE IF NOT EXISTS public.submission_participants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    submission_id UUID NOT NULL REFERENCES public.submissions(id) ON DELETE CASCADE,
    member_id UUID NOT NULL REFERENCES public.team_members(id) ON DELETE CASCADE,
    UNIQUE(submission_id, member_id)
);

-- 9. EVIDENCE FILES (Comprovações anexadas + Anti-fraude hash)
CREATE TABLE IF NOT EXISTS public.evidence_files (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    submission_id UUID NOT NULL REFERENCES public.submissions(id) ON DELETE CASCADE,
    file_name TEXT NOT NULL,
    file_size INT NOT NULL,
    file_type TEXT NOT NULL,
    file_url TEXT NOT NULL,
    file_hash TEXT NOT NULL, -- SHA-256 Checksum for duplicity detection
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 10. WEEKLY SCORES (Histórico de fechamentos semanais)
CREATE TABLE IF NOT EXISTS public.weekly_scores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    week_id UUID NOT NULL REFERENCES public.weeks(id) ON DELETE CASCADE,
    team_id UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
    provisional_points INT DEFAULT 0,
    official_points INT DEFAULT 0,
    bonus_points INT DEFAULT 0,
    participation_percentage NUMERIC(5,2) DEFAULT 0.00,
    rank_position INT,
    is_frozen BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(week_id, team_id)
);

-- 11. AUDIT LOGS (Logs de auditoria imutáveis)
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    user_name TEXT NOT NULL,
    action TEXT NOT NULL, -- e.g., 'APPROVE_SUBMISSION', 'REJECT_SUBMISSION', 'SCORE_OVERRIDE', 'WEEK_CLOSE'
    target_type TEXT NOT NULL,
    target_id TEXT,
    details TEXT NOT NULL,
    justification TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 12. CAMPAIGN SETTINGS (Configurações gerais)
CREATE TABLE IF NOT EXISTS public.campaign_settings (
    key TEXT PRIMARY KEY,
    value JSONB NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ====================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ====================================================================

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.evidence_files ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- Policy Admin: Access all
CREATE POLICY admin_full_access ON public.users FOR ALL USING (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'ADMIN')
);

CREATE POLICY admin_teams_access ON public.teams FOR ALL USING (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'ADMIN')
);

CREATE POLICY admin_submissions_access ON public.submissions FOR ALL USING (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'ADMIN')
);

-- Policy Leader: Access own team submissions
CREATE POLICY leader_submissions_read ON public.submissions FOR SELECT USING (
    team_id IN (SELECT team_id FROM public.users WHERE id = auth.uid())
);

CREATE POLICY leader_submissions_insert ON public.submissions FOR INSERT WITH CHECK (
    team_id IN (SELECT team_id FROM public.users WHERE id = auth.uid())
);
