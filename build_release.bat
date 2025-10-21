@echo off
chcp 65001 >nul 2>&1
REM 乐栈音乐 - Release 构建脚本
REM 用于 Windows 系统

echo ========================================
echo 乐栈音乐 - Release 构建
echo ========================================
echo.

REM 检查是否存在签名配置
if not exist "android\key.properties" (
    echo [错误] 未找到签名配置文件！
    echo.
    echo 请先完成以下步骤：
    echo 1. 创建签名密钥（参考 RELEASE_BUILD_GUIDE.md）
    echo 2. 将 android\key.properties.template 复制为 android\key.properties
    echo 3. 在 key.properties 中填写您的密钥信息
    echo.
    pause
    exit /b 1
)

echo [1/4] 清理旧的构建...
call flutter clean
if errorlevel 1 (
    echo [错误] 清理失败！
    pause
    exit /b 1
)
echo.

echo [2/4] 获取依赖...
call flutter pub get
if errorlevel 1 (
    echo [错误] 获取依赖失败！
    pause
    exit /b 1
)
echo.

echo [3/4] 构建 Release APK...
echo.
echo 请选择构建类型：
echo 1. 通用 APK（单个文件，体积较大）
echo 2. 分架构 APK（多个文件，体积更小）
echo 3. AAB（用于应用商店）
echo 4. 仅 arm64-v8a APK（单个文件，体积小）推荐
echo.
set /p choice="请输入选择 (1/2/3/4): "

if "%choice%"=="1" (
    echo.
    echo 构建通用 APK...
    call flutter build apk --release
    set "output_path=build\app\outputs\flutter-apk\app-release.apk"
) else if "%choice%"=="2" (
    echo.
    echo 构建分架构 APK...
    call flutter build apk --split-per-abi --release
    set "output_path=build\app\outputs\flutter-apk\"
) else if "%choice%"=="3" (
    echo.
    echo 构建 AAB...
    call flutter build appbundle --release
    set "output_path=build\app\outputs\bundle\release\app-release.aab"
) else if "%choice%"=="4" (
    echo.
    echo 构建 arm64-v8a APK...
    call flutter build apk --release --target-platform android-arm64
    set "output_path=build\app\outputs\flutter-apk\app-arm64-v8a-release.apk"
) else (
    echo [错误] 无效的选择！
    pause
    exit /b 1
)

if errorlevel 1 (
    echo.
    echo [错误] 构建失败！
    echo.
    echo 可能的原因：
    echo - 签名配置有误
    echo - 代码存在错误
    echo - 依赖问题
    echo.
    echo 请查看上面的错误信息，或参考 RELEASE_BUILD_GUIDE.md
    pause
    exit /b 1
)
echo.

echo [4/4] 构建完成！
echo.
echo ========================================
echo 构建成功！
echo ========================================
echo.
echo 输出位置：%output_path%
echo.

if "%choice%"=="2" (
    echo 生成的文件：
    echo - app-armeabi-v7a-release.apk  [32位ARM]
    echo - app-arm64-v8a-release.apk    [64位ARM] 推荐
    echo - app-x86_64-release.apk       [64位x86]
    echo.
)

if "%choice%"=="4" (
    echo 生成的文件：
    echo - app-arm64-v8a-release.apk    [64位ARM, 31MB] 推荐
    echo.
    echo 优势：体积小，覆盖99%%的现代手机
    echo.
)

echo 下一步：
echo 1. 在真机上安装测试
echo 2. 验证所有功能正常
echo 3. 准备应用商店素材
echo 4. 提交到应用商店
echo.
echo 安装命令：
if "%choice%"=="2" (
    echo adb install build\app\outputs\flutter-apk\app-arm64-v8a-release.apk
) else if "%choice%"=="1" (
    echo adb install build\app\outputs\flutter-apk\app-release.apk
) else (
    echo AAB 文件需要通过应用商店分发，无法直接安装
)
echo.

pause

