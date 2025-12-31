# Google 登录配置说明

## ✅ 已完成的代码配置

1. ✅ GoogleAuthService - Google 登录服务类
2. ✅ GoogleConfig - Google 配置常量
3. ✅ AuthManager - 集成 Google 登录
4. ✅ AuthView - Google 登录按钮
5. ✅ EarthLordApp - URL 回调处理

## ⚠️ 需要在 Xcode 中手动配置 URL Schemes

由于删除了 Info.plist 文件（避免构建冲突），您需要在 Xcode 项目设置中手动添加 URL Schemes：

### 步骤 1：打开项目设置

1. 在 Xcode 中，点击左侧导航栏的 **EarthLord** 项目（蓝色图标）
2. 在 TARGETS 列表中选择 **EarthLord**
3. 点击顶部的 **Info** 标签页

### 步骤 2：添加 URL Types

1. 向下滚动到 **URL Types** 部分
2. 点击 **+** 按钮添加新的 URL Type
3. 填写以下信息：
   - **Identifier**: `com.google.oauth`
   - **URL Schemes**: `com.googleusercontent.apps.787278856146-gvlmqojud2qubju02ll0hih93m3c9ek3`
   - **Role**: `Editor`

### 步骤 3：（可选）添加自定义属性

如果需要在代码中读取 Client ID，可以添加自定义属性：

1. 在 **Custom iOS Target Properties** 部分
2. 点击 **+** 添加新属性
3. 填写：
   - **Key**: `GIDClientID`
   - **Type**: `String`
   - **Value**: `787278856146-gvlmqojud2qubju02ll0hih93m3c9ek3.apps.googleusercontent.com`

### 步骤 4：清理并重新构建

1. 在 Xcode 菜单栏选择：**Product** → **Clean Build Folder** (或按 Shift+Cmd+K)
2. 重新运行项目 (Cmd+R)

## 📋 配置信息

```
Client ID: 787278856146-gvlmqojud2qubju02ll0hih93m3c9ek3.apps.googleusercontent.com
URL Scheme: com.googleusercontent.apps.787278856146-gvlmqojud2qubju02ll0hih93m3c9ek3
```

## 🔍 验证配置

配置完成后，运行应用并点击 "通过 Google 登录"，查看 Xcode 控制台日志：

```
🔵 开始 Google 登录流程
✅ 成功获取 rootViewController
✅ Google Sign-In 配置完成
🔵 开始 Google 登录授权...
```

## ❌ 如果遇到问题

### 问题 1：构建失败 "duplicate output file"

**解决方案**：
- 确保已删除手动创建的 `Info.plist` 文件
- 在 Xcode 中，检查 **Build Settings** → 搜索 "Info.plist File"，确保路径为空或指向正确位置
- 清理 DerivedData：Product → Clean Build Folder

### 问题 2：Google 登录按钮无响应

**解决方案**：
- 检查是否正确添加了 URL Schemes
- 检查 Bundle ID 是否为 `com.zhouxiaohong.EarthLord`
- 确保 Google Cloud Console 中的 iOS Client ID 使用了正确的 Bundle ID

### 问题 3：登录后没有跳转回应用

**解决方案**：
- 检查 `EarthLordApp.swift` 中的 `.onOpenURL` 是否正确配置
- 检查 URL Schemes 是否正确

## 📝 相关文件

- `EarthLord/Managers/GoogleAuthService.swift` - Google 登录服务
- `EarthLord/Managers/GoogleConfig.swift` - Google 配置常量
- `EarthLord/Managers/AuthManager.swift` - 认证管理器
- `EarthLord/Views/Auth/AuthView.swift` - 登录界面
- `EarthLord/EarthLordApp.swift` - 应用入口
