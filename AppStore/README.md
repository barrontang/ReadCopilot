# Mac App Store 发布流程

本目录保存 ReadCopilot 的 App Store 文案、截图与发布说明。构建产物不提交到仓库。

## 前置条件

1. App Store Connect 中已创建 macOS App 记录：
   - 名称：`ReadCopilot`
   - Bundle ID：`com.readcopilot.ReadCopilot`
   - SKU：`READCOPILOT2026`
   - 主要语言：简体中文
   - 价格：免费
   - 类别：效率
2. 本机安装有效的 `Apple Distribution` 与 `3rd Party Mac Developer Installer` 证书。
3. 准备 App Store Connect API Key（Key ID、Issuer ID、`.p8` 文件）。

> 注意：当前使用的 API Key 可以创建 Bundle ID，但没有 `POST /v1/apps` 权限。App 记录必须在 App Store Connect 网页端创建，或改用具有 App Manager / Admin 权限的 Key。

## 构建与导出

```bash
xcodegen generate
xcodebuild archive \
  -project ReadCopilot.xcodeproj \
  -scheme ReadCopilot \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath .build/AppStore/ReadCopilot-0.2.0.xcarchive \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$HOME/.appstoreconnect/private_keys/AuthKey_$ASC_KEY_ID.p8" \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID"

xcodebuild -exportArchive \
  -archivePath .build/AppStore/ReadCopilot-0.2.0.xcarchive \
  -exportPath .build/AppStore/export \
  -exportOptionsPlist .build/AppStore/ExportOptions.plist \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$HOME/.appstoreconnect/private_keys/AuthKey_$ASC_KEY_ID.p8" \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID"
```

导出结果：`.build/AppStore/export/ReadCopilot.pkg`

## 校验与上传

```bash
xcrun altool --validate-app \
  -f .build/AppStore/export/ReadCopilot.pkg \
  -t macos \
  --api-key "$ASC_KEY_ID" \
  --api-issuer "$ASC_ISSUER_ID" \
  --p8-file-path "$HOME/.appstoreconnect/private_keys/AuthKey_$ASC_KEY_ID.p8"

xcrun altool --upload-app \
  -f .build/AppStore/export/ReadCopilot.pkg \
  -t macos \
  --api-key "$ASC_KEY_ID" \
  --api-issuer "$ASC_ISSUER_ID" \
  --p8-file-path "$HOME/.appstoreconnect/private_keys/AuthKey_$ASC_KEY_ID.p8"
```

上传成功后，在 App Store Connect → 该 App → TestFlight / 构建版本中选择 Build 2，填写商店资料并提交审核。

## 截图重新生成

截图由 Debug 构建的演示模式生成，使用窗口内部渲染，不读取真实数据：

```bash
xcodebuild \
  -project ReadCopilot.xcodeproj \
  -scheme ReadCopilot \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/ScreenshotDD \
  CODE_SIGN_ENTITLEMENTS="" \
  build

open -n .build/ScreenshotDD/Build/Products/Debug/ReadCopilot.app \
  --args --demo --demo-screen=home --demo-shot=home
# 输出：$TMPDIR/readcopilot-home.png（2880×1800）
```

可用页面：`home`、`copilot`（配合 `--demo-report`）、`gallery`、`knowledge`。

## 提交前检查

- [ ] 隐私政策与支持页面已推送到公开仓库
- [ ] App Store Connect App 记录已创建
- [ ] 截图已上传（2880×1800）
- [ ] 隐私政策 URL 与支持 URL 可访问
- [ ] 构建版本通过 `altool --validate-app`
- [ ] 审核备注说明 BYOK 要求，或提供可体验的演示模式
