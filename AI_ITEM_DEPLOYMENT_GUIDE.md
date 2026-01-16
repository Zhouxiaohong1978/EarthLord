# AI 生成物品功能 - 部署与测试指南

## ✅ 已完成的工作

### 1. UI 修复
- ✅ 创建 `AIItemRow` 组件用于显示 AI 生成的物品
- ✅ 修复 `ScavengeResultView` 中的类型不匹配问题
- ✅ 添加物品背景故事展开/收起功能
- ✅ 更新 Preview 使用 `AIGeneratedItem` 示例

**文件**: `EarthLord/Views/Exploration/ScavengeResultView.swift:121-246`

### 2. Edge Function 创建
- ✅ 创建 `generate-ai-item` Edge Function
- ✅ 集成阿里云百炼 API (qwen-flash 模型)
- ✅ 实现基于 POI 类型的智能物品生成
- ✅ 根据危险等级调整稀有度分布

**文件**: `supabase/functions/generate-ai-item/index.ts`

### 3. 客户端集成
- ✅ `AIItemGenerator.swift` - AI 生成器客户端
- ✅ `ExplorationManager.swift` - 搜刮逻辑集成（含降级方案）
- ✅ `ExplorationModels.swift` - 数据模型完善

---

## 📋 部署步骤

### 步骤 1：登录 Supabase Dashboard

访问 [https://supabase.com/dashboard](https://supabase.com/dashboard) 并登录您的账号。

### 步骤 2：选择项目

选择 **EarthLord** 项目（项目 ID: `bckczjqrrsuhfzudrkin`）

### 步骤 3：部署 Edge Function

#### 方法 A：使用 Supabase Dashboard（推荐）

1. 在左侧菜单点击 **Edge Functions**
2. 点击 **New function** 按钮
3. 函数名称填写：`generate-ai-item`
4. 将 `supabase/functions/generate-ai-item/index.ts` 的内容粘贴到编辑器
5. 点击 **Deploy** 按钮

#### 方法 B：使用 Supabase CLI

如果您已安装 Supabase CLI：

```bash
cd /Users/zhouxiaohong/Desktop/EarthLord

# 登录 Supabase
supabase login

# 链接项目
supabase link --project-ref bckczjqrrsuhfzudrkin

# 部署函数
supabase functions deploy generate-ai-item
```

### 步骤 4：配置环境变量（关键）

#### 获取阿里云百炼 API Key

1. 访问 [阿里云百炼控制台](https://bailian.console.aliyun.com/)
2. 创建或获取您的 API Key
3. 确保 API Key 有权限访问 qwen-flash 模型

#### 在 Supabase 中配置密钥

1. 在 Supabase Dashboard 左侧菜单点击 **Edge Functions**
2. 点击 **Manage secrets** 按钮（或 Settings → Secrets）
3. 添加新的密钥：
   - **Name**: `DASHSCOPE_API_KEY`
   - **Value**: 您的阿里云百炼 API Key
4. 点击 **Save**

> ⚠️ **重要**：配置环境变量后需要重新部署函数才能生效

### 步骤 5：验证部署

在 Supabase Dashboard 中：
1. 进入 Edge Functions 页面
2. 找到 `generate-ai-item` 函数
3. 查看 Status 是否为 **Active**
4. 记录函数 URL（格式：`https://bckczjqrrsuhfzudrkin.supabase.co/functions/v1/generate-ai-item`）

---

## 🧪 测试指南

### 测试 1：验证 Edge Function 是否可访问

使用 curl 测试函数端点：

```bash
curl -X POST https://bckczjqrrsuhfzudrkin.supabase.co/functions/v1/generate-ai-item \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -d '{
    "poiName": "废弃便利店",
    "poiType": "supermarket",
    "dangerLevel": 2,
    "itemCount": 3
  }'
```

**获取 Anon Key**：
1. Supabase Dashboard → Settings → API
2. 复制 **anon** 或 **public** key

**预期响应**：
```json
{
  "success": true,
  "items": [
    {
      "name": "生锈的矿泉水",
      "story": "瓶身已经生锈，但里面的水依然清澈...",
      "category": "water",
      "rarity": "common"
    },
    // ... 更多物品
  ],
  "timestamp": "2026-01-16T..."
}
```

### 测试 2：在 iOS 模拟器中测试

1. 在 Xcode 中运行项目 (Cmd+R)
2. 登录账号
3. 进入地图页面
4. 搜索 POI（如"便利店"）
5. 点击任意 POI 的 **搜刮** 按钮
6. 等待搜刮完成（3-5秒）
7. 查看搜刮结果弹窗

**验证要点**：
- ✅ 物品名称是 AI 生成的独特名称（不是 "water_bottle" 这样的 ID）
- ✅ 物品有背景故事，可以点击"展开"查看
- ✅ 稀有度颜色正确显示
- ✅ 物品图标与分类匹配

### 测试 3：验证降级方案

**模拟 AI 失败场景**（断网测试）：

1. 在模拟器中开启飞行模式
2. 触发 POI 搜刮
3. 验证系统是否自动使用预设物品库
4. 检查控制台日志是否有降级提示

**预期行为**：
- 即使 AI 调用失败，用户仍能获得物品
- 控制台输出类似：`⚠️ AI生成失败，使用降级方案`

### 测试 4：检查日志

在 Supabase Dashboard 中查看函数日志：

1. Edge Functions → `generate-ai-item` → Logs
2. 查看最近的调用记录
3. 确认是否有错误或异常

---

## 🐛 常见问题排查

### 问题 1：函数返回 "服务配置错误：缺少 API Key"

**原因**：环境变量未正确配置

**解决方案**：
1. 确认在 Supabase Dashboard 中已添加 `DASHSCOPE_API_KEY`
2. 重新部署函数
3. 等待 1-2 分钟后重试

### 问题 2：函数返回 401 Unauthorized

**原因**：JWT 验证失败或 Anon Key 不正确

**解决方案**：
1. 确认使用的是正确的 Anon Key
2. 检查 iOS 应用中的 `SupabaseManager` 配置
3. 确保用户已登录

### 问题 3：AI 响应格式错误

**原因**：AI 返回的不是有效的 JSON

**解决方案**：
1. 检查 Edge Function 日志中的 AI 原始响应
2. 可能需要调整系统提示词
3. 确认 qwen-flash 模型可用

### 问题 4：物品名称显示为 "item_id"

**原因**：`ScavengeResultView` 仍在使用旧的 `ItemRow`

**解决方案**：
1. 确认文件已保存并重新编译
2. Clean Build Folder (Cmd+Shift+K)
3. 重新运行项目

---

## 📊 成本估算

### 阿里云百炼 API 定价
- **模型**: qwen-flash
- **价格**: 约 ¥0.0013/次调用（假设每次生成 3 个物品，约 800 tokens）
- **预估月成本**：
  - 100 次搜刮/天 × 30 天 = 3000 次/月
  - 总成本：¥3.9/月

### Supabase Edge Functions 定价
- **免费额度**: 500,000 次调用/月
- **超出额度**: $2/百万次调用

---

## ✅ 验证清单

在正式上线前，请确认以下所有项目：

- [ ] Edge Function 部署成功且状态为 Active
- [ ] DASHSCOPE_API_KEY 环境变量已配置
- [ ] curl 测试返回正确的 AI 生成物品
- [ ] iOS 应用中搜刮 POI 能显示 AI 物品
- [ ] 物品名称是独特的中文名称（非 ID）
- [ ] 物品背景故事可以展开/收起
- [ ] 稀有度颜色和图标正确显示
- [ ] AI 失败时降级方案生效
- [ ] 搜刮结果弹窗动画流畅
- [ ] 物品成功保存到背包（待实现）

---

## 📝 后续优化建议

1. **物品持久化**
   - 将 AI 生成的物品保存到 Supabase 数据库
   - 实现背包系统展示已获得物品

2. **AI 优化**
   - 根据玩家等级调整物品质量
   - 添加 POI 搜刮历史，避免重复生成
   - 实现物品生成缓存

3. **用户体验**
   - 添加生成进度提示（"AI 正在寻找物品..."）
   - 物品卡片支持长按查看详情
   - 稀有物品获得特殊动画效果

4. **性能优化**
   - 实现 AI 响应缓存（相同 POI 24 小时内重用结果）
   - 批量生成物品减少 API 调用次数

---

## 🆘 需要帮助？

如果遇到问题：

1. 检查 Supabase Edge Function 日志
2. 查看 Xcode 控制台输出
3. 确认阿里云百炼 API Key 有效
4. 参考本文档的"常见问题排查"部分

---

**部署完成后，请运行测试并反馈结果！** 🚀
