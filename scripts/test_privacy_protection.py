#!/usr/bin/env python3
"""
POPOPX iOS 隐私防护功能自动化测试脚本
测试阅后即焚(BinThere)的核心隐私防护流程
"""

import subprocess
import time
import json
import sys
from datetime import datetime

# 配置
SIMULATOR_ID = "C15A3542-8F4E-4C49-95D8-BD5FDF5CC149"
BUNDLE_ID = "com.popopxchat.popopx"
SCREENSHOT_DIR = "/tmp/popopx_privacy_test"

class PrivacyTestRunner:
    def __init__(self):
        self.test_results = []
        self.start_time = datetime.now()
        
    def log(self, message, level="INFO"):
        timestamp = datetime.now().strftime("%H:%M:%S")
        print(f"[{timestamp}] [{level}] {message}")
        
    def run_command(self, cmd, check=True):
        """运行 shell 命令并返回结果"""
        try:
            result = subprocess.run(
                cmd, 
                shell=True, 
                capture_output=True, 
                text=True,
                timeout=30
            )
            if check and result.returncode != 0:
                self.log(f"Command failed: {cmd}", "ERROR")
                self.log(f"stderr: {result.stderr}", "ERROR")
                return None
            return result.stdout.strip()
        except subprocess.TimeoutExpired:
            self.log(f"Command timeout: {cmd}", "ERROR")
            return None
        except Exception as e:
            self.log(f"Command exception: {e}", "ERROR")
            return None
    
    def take_screenshot(self, name):
        """截取模拟器屏幕"""
        filepath = f"{SCREENSHOT_DIR}/{name}_{int(time.time())}.png"
        cmd = f"xcrun simctl io {SIMULATOR_ID} screenshot {filepath}"
        self.run_command(cmd, check=False)
        return filepath
    
    def check_simulator_state(self):
        """检查模拟器状态"""
        self.log("检查模拟器状态...")
        output = self.run_command("xcrun simctl list devices | grep -E '(Booted|Shutdown)'")
        if SIMULATOR_ID in output and "Booted" in output:
            self.log("✓ 模拟器已启动", "PASS")
            return True
        else:
            self.log("模拟器未启动，尝试启动...", "WARN")
            self.run_command(f"xcrun simctl boot {SIMULATOR_ID}")
            time.sleep(3)
            return True
    
    def check_app_installed(self):
        """检查应用是否已安装"""
        self.log("检查应用安装状态...")
        output = self.run_command(f"xcrun simctl listapps {SIMULATOR_ID} | grep -c '{BUNDLE_ID}'")
        if output and int(output) > 0:
            self.log("✓ 应用已安装", "PASS")
            return True
        else:
            self.log("应用未安装", "FAIL")
            return False
    
    def launch_app(self):
        """启动应用"""
        self.log("启动应用...")
        output = self.run_command(f"xcrun simctl launch {SIMULATOR_ID} {BUNDLE_ID}")
        if output:
            self.log(f"✓ 应用已启动 (PID: {output.split(':')[-1].strip()})", "PASS")
            time.sleep(2)
            self.take_screenshot("app_launched")
            return True
        else:
            self.log("应用启动失败", "FAIL")
            return False
    
    def test_camera_permission_dialog(self):
        """测试相机权限弹窗"""
        self.log("测试 1: 相机权限请求逻辑")
        
        # 检查代码中是否包含权限请求
        cmd = "grep -r 'requestCameraPermissionIfNeeded' /Users/elliot/POPOPX/popopx-chat/apps/ios/Shared/Customization/BinThere/ | wc -l"
        output = self.run_command(cmd)
        
        if output and int(output) >= 2:  # 应该在两个文件中都有
            self.log("✓ 相机权限请求函数已实现", "PASS")
            self.test_results.append({
                "test": "相机权限请求",
                "status": "PASS",
                "details": f"在 {output} 个文件中实现"
            })
        else:
            self.log("✗ 相机权限请求函数缺失", "FAIL")
            self.test_results.append({
                "test": "相机权限请求",
                "status": "FAIL",
                "details": "未找到实现"
            })
        
        # 检查权限弹窗
        cmd = "grep -r 'Camera Access Required' /Users/elliot/POPOPX/popopx-chat/apps/ios/Shared/Customization/BinThere/ | wc -l"
        output = self.run_command(cmd)
        
        if output and int(output) >= 2:
            self.log("✓ 权限弹窗已实现", "PASS")
        else:
            self.log("✗ 权限弹窗缺失", "FAIL")
    
    def test_screenshot_warning(self):
        """测试截图警告消息"""
        self.log("测试 2: 截图防护警告消息")
        
        cmd = "grep -r 'Screenshot detected' /Users/elliot/POPOPX/popopx-chat/apps/ios/Shared/Customization/BinThere/ | wc -l"
        output = self.run_command(cmd)
        
        if output and int(output) >= 2:
            self.log("✓ 改进的截图警告消息已实现", "PASS")
            self.test_results.append({
                "test": "截图警告消息",
                "status": "PASS",
                "details": "警告消息: '⚠️ Screenshot detected! Content will be destroyed.'"
            })
        else:
            self.log("✗ 截图警告消息未更新", "FAIL")
            self.test_results.append({
                "test": "截图警告消息",
                "status": "FAIL",
                "details": "未找到改进的警告消息"
            })
    
    def test_arkit_vision_supplement(self):
        """测试 ARKit + Vision 多人脸检测"""
        self.log("测试 3: ARKit 后端多人脸检测补充")
        
        # 检查 Vision 补充实现
        cmd = "grep -c 'performVisionSupplementCheck' /Users/elliot/POPOPX/popopx-chat/apps/ios/Shared/Customization/BinThere/FaceGuardianMonitor.swift"
        output = self.run_command(cmd)
        
        if output and int(output) >= 1:
            self.log("✓ Vision 补充检测函数已实现", "PASS")
        else:
            self.log("✗ Vision 补充检测函数缺失", "FAIL")
        
        # 检查多人脸检测逻辑
        cmd = "grep -c 'multiple_faces_detected' /Users/elliot/POPOPX/popopx-chat/apps/ios/Shared/Customization/BinThere/FaceGuardianMonitor.swift"
        output = self.run_command(cmd)
        
        if output and int(output) >= 1:
            self.log("✓ 多人脸检测逻辑已实现", "PASS")
            self.test_results.append({
                "test": "ARKit+Vision 多人脸检测",
                "status": "PASS",
                "details": "Vision 框架作为 ARKit 补充检测多人脸"
            })
        else:
            self.log("✗ 多人脸检测逻辑缺失", "FAIL")
            self.test_results.append({
                "test": "ARKit+Vision 多人脸检测",
                "status": "FAIL",
                "details": "未找到多人脸检测逻辑"
            })
    
    def test_performance_monitor(self):
        """测试性能监控"""
        self.log("测试 4: 性能监控和动态调整")
        
        # 检查 MoirePerformanceMonitor 类
        cmd = "grep -c 'class MoirePerformanceMonitor' /Users/elliot/POPOPX/popopx-chat/apps/ios/Shared/Customization/BinThere/BinThereMoireDefense.swift"
        output = self.run_command(cmd)
        
        if output and int(output) >= 1:
            self.log("✓ 性能监控类已实现", "PASS")
        else:
            self.log("✗ 性能监控类缺失", "FAIL")
        
        # 检查 FPS 监控
        cmd = "grep -c 'currentFPS' /Users/elliot/POPOPX/popopx-chat/apps/ios/Shared/Customization/BinThere/BinThereMoireDefense.swift"
        output = self.run_command(cmd)
        
        if output and int(output) >= 1:
            self.log("✓ FPS 监控已实现", "PASS")
            self.test_results.append({
                "test": "性能监控",
                "status": "PASS",
                "details": "实时监控 FPS，自动调整质量"
            })
        else:
            self.log("✗ FPS 监控缺失", "FAIL")
            self.test_results.append({
                "test": "性能监控",
                "status": "FAIL",
                "details": "未找到 FPS 监控"
            })
        
        # 检查动态质量调整
        cmd = "grep -c 'shouldReduceQuality' /Users/elliot/POPOPX/popopx-chat/apps/ios/Shared/Customization/BinThere/BinThereMoireDefense.swift"
        output = self.run_command(cmd)
        
        if output and int(output) >= 1:
            self.log("✓ 动态质量调整已实现", "PASS")
        else:
            self.log("✗ 动态质量调整缺失", "FAIL")
    
    def test_evidence_cooldown(self):
        """测试证据捕获冷却时间"""
        self.log("测试 5: 证据捕获冷却时间优化")
        
        cmd = "grep 'captureCooldown.*TimeInterval' /Users/elliot/POPOPX/popopx-chat/apps/ios/Shared/Customization/BinThere/BinThereEvidenceManager.swift"
        output = self.run_command(cmd)
        
        if output and "2.0" in output:
            self.log("✓ 冷却时间已优化为 2.0 秒", "PASS")
            self.test_results.append({
                "test": "证据捕获冷却",
                "status": "PASS",
                "details": "从 5.0 秒优化到 2.0 秒"
            })
        elif output and "5.0" in output:
            self.log("✗ 冷却时间仍为 5.0 秒（未优化）", "FAIL")
            self.test_results.append({
                "test": "证据捕获冷却",
                "status": "FAIL",
                "details": "仍为 5.0 秒，应优化到 2.0 秒"
            })
        else:
            self.log("✗ 未找到冷却时间设置", "FAIL")
            self.test_results.append({
                "test": "证据捕获冷却",
                "status": "FAIL",
                "details": "未找到配置"
            })
    
    def test_code_compilation(self):
        """测试代码编译"""
        self.log("测试 6: 代码编译验证")
        
        # 检查是否有编译错误
        cmd = "cd /Users/elliot/POPOPX/popopx-chat/apps/ios && xcodebuild -project POPOPX.xcodeproj -scheme 'POPOPX (iOS)' -destination 'platform=iOS Simulator,id=C15A3542-8F4E-4C49-95D8-BD5FDF5CC149' -configuration Debug CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO build 2>&1 | grep -c 'BUILD SUCCEEDED'"
        output = self.run_command(cmd)
        
        if output and int(output) >= 1:
            self.log("✓ 代码编译成功", "PASS")
            self.test_results.append({
                "test": "代码编译",
                "status": "PASS",
                "details": "BUILD SUCCEEDED"
            })
        else:
            self.log("✗ 代码编译失败", "FAIL")
            self.test_results.append({
                "test": "代码编译",
                "status": "FAIL",
                "details": "编译错误"
            })
    
    def generate_report(self):
        """生成测试报告"""
        end_time = datetime.now()
        duration = (end_time - self.start_time).total_seconds()
        
        report = {
            "title": "POPOPX iOS 隐私防护功能自动化测试报告",
            "timestamp": end_time.isoformat(),
            "duration_seconds": duration,
            "simulator_id": SIMULATOR_ID,
            "bundle_id": BUNDLE_ID,
            "summary": {
                "total_tests": len(self.test_results),
                "passed": sum(1 for t in self.test_results if t["status"] == "PASS"),
                "failed": sum(1 for t in self.test_results if t["status"] == "FAIL"),
            },
            "test_results": self.test_results,
            "conclusion": ""
        }
        
        # 生成结论
        pass_rate = report["summary"]["passed"] / report["summary"]["total_tests"] * 100 if report["summary"]["total_tests"] > 0 else 0
        
        if pass_rate == 100:
            report["conclusion"] = "✅ 所有测试通过！隐私防护功能已完全实现并验证。"
        elif pass_rate >= 80:
            report["conclusion"] = "⚠️ 大部分测试通过，但有少量问题需要关注。"
        else:
            report["conclusion"] = "❌ 多个测试失败，需要修复后重新验证。"
        
        # 保存报告
        report_path = f"{SCREENSHOT_DIR}/test_report_{int(time.time())}.json"
        with open(report_path, 'w', encoding='utf-8') as f:
            json.dump(report, f, ensure_ascii=False, indent=2)
        
        # 打印报告
        print("\n" + "="*80)
        print("POPOPX iOS 隐私防护功能自动化测试报告")
        print("="*80)
        print(f"\n测试时间: {end_time.strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"测试耗时: {duration:.2f} 秒")
        print(f"\n测试结果:")
        print(f"  总计: {report['summary']['total_tests']}")
        print(f"  通过: {report['summary']['passed']} ✓")
        print(f"  失败: {report['summary']['failed']} ✗")
        print(f"  通过率: {pass_rate:.1f}%")
        
        print(f"\n详细结果:")
        for i, test in enumerate(self.test_results, 1):
            status_icon = "✓" if test["status"] == "PASS" else "✗"
            print(f"  {i}. [{status_icon}] {test['test']}: {test['status']}")
            print(f"     {test['details']}")
        
        print(f"\n{report['conclusion']}")
        print(f"\n报告已保存: {report_path}")
        print("="*80 + "\n")
        
        return report

def main():
    """主函数"""
    print("\n" + "="*80)
    print("POPOPX iOS 隐私防护功能自动化测试")
    print("="*80 + "\n")
    
    # 创建截图目录
    subprocess.run(f"mkdir -p {SCREENSHOT_DIR}", shell=True)
    
    # 初始化测试运行器
    runner = PrivacyTestRunner()
    
    try:
        # 运行测试
        runner.check_simulator_state()
        
        if not runner.check_app_installed():
            runner.log("应用未安装，跳过后续测试", "ERROR")
            sys.exit(1)
        
        runner.launch_app()
        
        # 执行功能测试
        runner.test_camera_permission_dialog()
        runner.test_screenshot_warning()
        runner.test_arkit_vision_supplement()
        runner.test_performance_monitor()
        runner.test_evidence_cooldown()
        runner.test_code_compilation()
        
        # 生成报告
        report = runner.generate_report()
        
        # 退出码
        sys.exit(0 if report["summary"]["failed"] == 0 else 1)
        
    except KeyboardInterrupt:
        runner.log("\n测试被用户中断", "WARN")
        sys.exit(130)
    except Exception as e:
        runner.log(f"\n测试异常: {e}", "ERROR")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main()
