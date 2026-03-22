//
//  MailboxView.swift
//  EarthLord
//
//  邮箱列表页面
//

import SwiftUI

struct MailboxView: View {
    @StateObject private var mailboxManager = MailboxManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedMail: Mail?
    @State private var showingDetail = false
    @State private var showingDeleteConfirm = false
    @State private var mailToDelete: Mail?
    @State private var showingSwipeDeleteConfirm = false

    var body: some View {
        ZStack {
            ApocalypseTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // 导航栏
                navigationBar

                if mailboxManager.isLoading {
                    loadingView
                } else if mailboxManager.mails.isEmpty {
                    emptyView
                } else {
                    mailListView
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingDetail) {
            if let mail = selectedMail {
                MailDetailView(mail: mail)
            }
        }
        .onAppear {
            Task {
                await mailboxManager.loadMails()
            }
        }
    }

    // MARK: - 导航栏
    private var navigationBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            Text(LocalizedStringKey("邮箱"))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()

            // 刷新按钮
            Button(action: {
                Task {
                    await mailboxManager.loadMails()
                }
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 18))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            // 批量删除（始终显示）
            Button(action: { showingDeleteConfirm = true }) {
                Image(systemName: "trash")
                    .font(.system(size: 18))
                    .foregroundColor(.red)
            }
            .alert(LocalizedStringKey("清理已领取邮件"), isPresented: $showingDeleteConfirm) {
                Button(LocalizedStringKey("取消"), role: .cancel) {}
                Button(LocalizedStringKey("删除"), role: .destructive) {
                    Task {
                        try? await mailboxManager.deleteClaimedMails()
                    }
                }
            } message: {
                if mailboxManager.mails.filter({ $0.isClaimed }).isEmpty {
                    Text(LocalizedStringKey("暂无已领取的邮件可清理"))
                } else {
                    Text(LocalizedStringKey("删除所有已领取的邮件？此操作不可撤销"))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ApocalypseTheme.cardBackground)
    }

    // MARK: - 加载视图
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
            Text("加载中...")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .padding(.top, 8)
            Spacer()
        }
    }

    // MARK: - 空状态
    private var emptyView: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer().frame(height: 20)

                Image(systemName: "envelope.open")
                    .font(.system(size: 56))
                    .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.4))

                Text(LocalizedStringKey("暂无邮件"))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                // 功能说明卡片
                VStack(alignment: .leading, spacing: 14) {
                    Text(LocalizedStringKey("邮箱用途"))
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.primary)

                    mailboxUsageRow(icon: "bag.fill", color: ApocalypseTheme.primary,
                                   title: "mailbox.usage.purchase.title",
                                   desc: "mailbox.usage.purchase.desc")
                    mailboxUsageRow(icon: "figure.walk", color: .green,
                                   title: "mailbox.usage.exploration.title",
                                   desc: "mailbox.usage.exploration.desc")
                    mailboxUsageRow(icon: "gift.fill", color: .orange,
                                   title: "mailbox.usage.daily.title",
                                   desc: "mailbox.usage.daily.desc")
                    mailboxUsageRow(icon: "arrow.left.arrow.right", color: ApocalypseTheme.info,
                                   title: "mailbox.usage.trade.title",
                                   desc: "mailbox.usage.trade.desc")

                    Divider().background(ApocalypseTheme.textSecondary.opacity(0.3))

                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text(LocalizedStringKey("mailbox.usage.expiry_note"))
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
                .padding(16)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(12)
                .padding(.horizontal, 16)

                Spacer().frame(height: 20)
            }
        }
    }

    private func mailboxUsageRow(icon: String, color: Color, title: LocalizedStringKey, desc: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Text(desc)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
    }

    // MARK: - 邮件列表
    private var mailListView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(mailboxManager.mails) { mail in
                    MailItemRow(mail: mail)
                        .onTapGesture {
                            selectedMail = mail
                            showingDetail = true
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                mailToDelete = mail
                                showingSwipeDeleteConfirm = true
                            } label: {
                                Label(LocalizedStringKey("删除"), systemImage: "trash")
                            }
                        }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .alert(LocalizedStringKey("删除邮件"), isPresented: $showingSwipeDeleteConfirm) {
            Button(LocalizedStringKey("取消"), role: .cancel) { mailToDelete = nil }
            Button(LocalizedStringKey("删除"), role: .destructive) {
                guard let mail = mailToDelete else { return }
                Task {
                    try? await mailboxManager.deleteMail(mail)
                    mailToDelete = nil
                }
            }
        } message: {
            Text(LocalizedStringKey("确定删除这封邮件？未领取的物品将一并删除"))
        }
    }
}

#Preview {
    NavigationStack {
        MailboxView()
    }
}
