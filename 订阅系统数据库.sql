-- =====================================================
-- 末日之主 - 订阅系统数据库配置
-- =====================================================
-- 创建时间：2026-02-06
-- 说明：配置订阅系统所需的数据库表、索引、RLS策略和RPC函数
-- =====================================================

-- ==================== 1. 创建订阅表 ====================

CREATE TABLE IF NOT EXISTS public.user_subscriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) NOT NULL,
    product_id TEXT NOT NULL,  -- 订阅商品ID（com.earthlord.sub.xxx）
    tier TEXT NOT NULL CHECK (tier IN ('explorer', 'lord')),  -- 订阅档位
    transaction_id TEXT UNIQUE NOT NULL,  -- 交易ID
    original_transaction_id TEXT,  -- 原始交易ID（续费时不变）
    purchase_date TIMESTAMPTZ NOT NULL,  -- 购买时间
    expires_at TIMESTAMPTZ NOT NULL,  -- 到期时间
    is_active BOOLEAN DEFAULT true,  -- 是否激活
    auto_renew BOOLEAN DEFAULT true,  -- 是否自动续费
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 添加注释
COMMENT ON TABLE public.user_subscriptions IS '用户订阅记录表';
COMMENT ON COLUMN public.user_subscriptions.tier IS '订阅档位：explorer（探索者）或 lord（领主）';
COMMENT ON COLUMN public.user_subscriptions.expires_at IS '订阅到期时间';
COMMENT ON COLUMN public.user_subscriptions.is_active IS '订阅是否激活（到期或取消后变为false）';

-- ==================== 2. 创建索引 ====================

CREATE INDEX IF NOT EXISTS idx_user_subscriptions_user_id ON public.user_subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_expires_at ON public.user_subscriptions(expires_at);
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_transaction_id ON public.user_subscriptions(transaction_id);
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_active ON public.user_subscriptions(user_id, is_active) WHERE is_active = true;

-- ==================== 3. 启用 RLS ====================

ALTER TABLE public.user_subscriptions ENABLE ROW LEVEL SECURITY;

-- 删除旧策略（如果存在）
DROP POLICY IF EXISTS "用户只能查看自己的订阅" ON public.user_subscriptions;
DROP POLICY IF EXISTS "用户只能插入自己的订阅" ON public.user_subscriptions;
DROP POLICY IF EXISTS "用户只能更新自己的订阅" ON public.user_subscriptions;

-- 创建 RLS 策略
CREATE POLICY "用户只能查看自己的订阅"
ON public.user_subscriptions FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "用户只能插入自己的订阅"
ON public.user_subscriptions FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "用户只能更新自己的订阅"
ON public.user_subscriptions FOR UPDATE
USING (auth.uid() = user_id);

-- ==================== 4. 创建触发器（自动更新时间戳） ====================

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_user_subscriptions_updated_at ON public.user_subscriptions;

CREATE TRIGGER update_user_subscriptions_updated_at
BEFORE UPDATE ON public.user_subscriptions
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

-- ==================== 5. RPC 函数：获取当前订阅状态 ====================

CREATE OR REPLACE FUNCTION public.get_current_subscription()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_subscription RECORD;
    v_tier TEXT;
BEGIN
    -- 获取当前用户ID
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object(
            'tier', 'free',
            'is_active', false,
            'expires_at', null
        );
    END IF;

    -- 查找激活的订阅（未过期）
    SELECT * INTO v_subscription
    FROM user_subscriptions
    WHERE user_id = v_user_id
      AND is_active = true
      AND expires_at > NOW()
    ORDER BY expires_at DESC
    LIMIT 1;

    IF FOUND THEN
        -- 有激活的订阅
        RETURN jsonb_build_object(
            'id', v_subscription.id,
            'tier', v_subscription.tier,
            'product_id', v_subscription.product_id,
            'is_active', true,
            'expires_at', v_subscription.expires_at,
            'auto_renew', v_subscription.auto_renew,
            'days_remaining', EXTRACT(DAY FROM (v_subscription.expires_at - NOW()))
        );
    ELSE
        -- 检查是否有过期的订阅
        SELECT tier INTO v_tier
        FROM user_subscriptions
        WHERE user_id = v_user_id
        ORDER BY expires_at DESC
        LIMIT 1;

        RETURN jsonb_build_object(
            'tier', COALESCE(v_tier, 'free'),
            'is_active', false,
            'expires_at', null
        );
    END IF;
END;
$$;

COMMENT ON FUNCTION public.get_current_subscription IS '获取当前用户的订阅状态';

-- ==================== 6. RPC 函数：更新订阅状态 ====================

CREATE OR REPLACE FUNCTION public.update_subscription(
    p_product_id TEXT,
    p_tier TEXT,
    p_transaction_id TEXT,
    p_original_transaction_id TEXT,
    p_purchase_date TIMESTAMPTZ,
    p_expires_at TIMESTAMPTZ,
    p_auto_renew BOOLEAN DEFAULT true
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_existing_sub RECORD;
    v_subscription_id UUID;
BEGIN
    -- 获取当前用户ID
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION '用户未登录';
    END IF;

    -- 检查是否已存在该交易ID
    SELECT * INTO v_existing_sub
    FROM user_subscriptions
    WHERE transaction_id = p_transaction_id;

    IF FOUND THEN
        -- 更新现有订阅
        UPDATE user_subscriptions
        SET expires_at = p_expires_at,
            is_active = true,
            auto_renew = p_auto_renew,
            updated_at = NOW()
        WHERE id = v_existing_sub.id
        RETURNING id INTO v_subscription_id;

        RETURN jsonb_build_object(
            'success', true,
            'subscription_id', v_subscription_id,
            'action', 'updated'
        );
    ELSE
        -- 停用该用户的其他订阅（一个用户同时只能有一个激活的订阅）
        UPDATE user_subscriptions
        SET is_active = false
        WHERE user_id = v_user_id
          AND is_active = true;

        -- 插入新订阅
        INSERT INTO user_subscriptions (
            user_id,
            product_id,
            tier,
            transaction_id,
            original_transaction_id,
            purchase_date,
            expires_at,
            is_active,
            auto_renew
        ) VALUES (
            v_user_id,
            p_product_id,
            p_tier,
            p_transaction_id,
            p_original_transaction_id,
            p_purchase_date,
            p_expires_at,
            true,
            p_auto_renew
        )
        RETURNING id INTO v_subscription_id;

        RETURN jsonb_build_object(
            'success', true,
            'subscription_id', v_subscription_id,
            'action', 'created'
        );
    END IF;
END;
$$;

COMMENT ON FUNCTION public.update_subscription IS '更新用户订阅状态（购买或续费）';

-- ==================== 7. RPC 函数：取消订阅 ====================

CREATE OR REPLACE FUNCTION public.cancel_subscription()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_updated_count INT;
BEGIN
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION '用户未登录';
    END IF;

    -- 将自动续费设置为false
    UPDATE user_subscriptions
    SET auto_renew = false,
        updated_at = NOW()
    WHERE user_id = v_user_id
      AND is_active = true;

    GET DIAGNOSTICS v_updated_count = ROW_COUNT;

    RETURN jsonb_build_object(
        'success', true,
        'message', '已取消自动续费，订阅将在到期后失效'
    );
END;
$$;

COMMENT ON FUNCTION public.cancel_subscription IS '取消订阅自动续费';

-- ==================== 8. RPC 函数：检查过期订阅（定时任务） ====================

CREATE OR REPLACE FUNCTION public.expire_old_subscriptions()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_expired_count INT;
BEGIN
    -- 将已过期的订阅标记为不激活
    UPDATE user_subscriptions
    SET is_active = false,
        updated_at = NOW()
    WHERE is_active = true
      AND expires_at < NOW();

    GET DIAGNOSTICS v_expired_count = ROW_COUNT;

    RETURN jsonb_build_object(
        'success', true,
        'expired_count', v_expired_count
    );
END;
$$;

COMMENT ON FUNCTION public.expire_old_subscriptions IS '将过期订阅标记为不激活（定时任务）';

-- ==================== 9. 创建每日礼包领取记录表 ====================

CREATE TABLE IF NOT EXISTS public.daily_rewards (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) NOT NULL,
    reward_date DATE NOT NULL,  -- 领取日期
    tier TEXT NOT NULL,  -- 领取时的订阅档位
    items JSONB NOT NULL,  -- 领取的物品列表
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, reward_date)  -- 每天只能领取一次
);

CREATE INDEX IF NOT EXISTS idx_daily_rewards_user_date ON public.daily_rewards(user_id, reward_date);

ALTER TABLE public.daily_rewards ENABLE ROW LEVEL SECURITY;

CREATE POLICY "用户只能查看自己的每日礼包"
ON public.daily_rewards FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "用户只能插入自己的每日礼包"
ON public.daily_rewards FOR INSERT
WITH CHECK (auth.uid() = user_id);

COMMENT ON TABLE public.daily_rewards IS '每日礼包领取记录';

-- ==================== 10. RPC 函数：检查今日是否已领取礼包 ====================

CREATE OR REPLACE FUNCTION public.check_daily_reward_claimed()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_claimed BOOLEAN;
BEGIN
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RETURN false;
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM daily_rewards
        WHERE user_id = v_user_id
          AND reward_date = CURRENT_DATE
    ) INTO v_claimed;

    RETURN v_claimed;
END;
$$;

-- ==================== 完成 ====================

-- 显示创建的对象
SELECT '✅ 订阅系统数据库配置完成！' AS status;

SELECT '创建的表：' AS info, table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('user_subscriptions', 'daily_rewards');

SELECT '创建的函数：' AS info, routine_name
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name LIKE '%subscription%' OR routine_name LIKE '%daily_reward%';
