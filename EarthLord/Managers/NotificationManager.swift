//
//  NotificationManager.swift
//  EarthLord
//
//  本地通知管理器 - 每日任务提醒 + 探索/邮件触发通知
//

import Foundation
import UserNotifications

@MainActor
final class NotificationManager: ObservableObject {

    static let shared = NotificationManager()

    @Published var isAuthorized = false

    private init() {}

    // MARK: - Permission

    func requestPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
            if granted {
                scheduleDailyTaskReminder()
            }
        } catch {
            print("通知权限请求失败: \(error)")
        }
    }

    func checkAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }

    // MARK: - 每日任务提醒（08:00 重复）

    func scheduleDailyTaskReminder() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["daily_task_reminder"])

        let content = UNMutableNotificationContent()
        content.title = String(localized: "每日任务已刷新")
        content.body = String(localized: "新的每日任务等你完成，完成后可领取建造材料奖励！")
        content.sound = .default

        var dc = DateComponents()
        dc.hour = 8
        dc.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
        let request = UNNotificationRequest(identifier: "daily_task_reminder",
                                            content: content,
                                            trigger: trigger)
        center.add(request)
    }

    // MARK: - 触发式通知

    func sendExplorationCompleteNotification(tierName: String) {
        guard isAuthorized else { return }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "探索完成")
        content.body = String(format: String(localized: "获得 %@ 级奖励，已发送到邮箱！"), tierName)
        content.sound = .default
        schedule(content, id: "exploration_\(Date().timeIntervalSince1970)")
    }

    func sendNewMailNotification(title: String) {
        guard isAuthorized else { return }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "新邮件")
        content.body = title
        content.sound = .default
        schedule(content, id: "mail_\(Date().timeIntervalSince1970)")
    }

    func sendTaskRewardNotification(taskTitle: String) {
        guard isAuthorized else { return }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "任务奖励已发放")
        content.body = String(format: String(localized: "【%@】奖励已发送到邮箱"), taskTitle)
        content.sound = .default
        schedule(content, id: "task_reward_\(Date().timeIntervalSince1970)")
    }

    // MARK: - Private

    private func schedule(_ content: UNMutableNotificationContent, id: String) {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
