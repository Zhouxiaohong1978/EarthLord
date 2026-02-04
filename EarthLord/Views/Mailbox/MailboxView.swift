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

            Text("邮箱")
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

            // 批量删除
            if !mailboxManager.mails.filter({ $0.isClaimed }).isEmpty {
                Button(action: { showingDeleteConfirm = true }) {
                    Image(systemName: "trash")
                        .font(.system(size: 18))
                        .foregroundColor(.red)
                }
                .alert("确认删除", isPresented: $showingDeleteConfirm) {
                    Button("取消", role: .cancel) {}
                    Button("删除", role: .destructive) {
                        Task {
                            try? await mailboxManager.deleteClaimedMails()
                        }
                    }
                } message: {
                    Text("删除所有已领取的邮件？")
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
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "envelope.open")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))

            Text("暂无邮件")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("购买的物资包会发送到这里")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()
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
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}

#Preview {
    NavigationStack {
        MailboxView()
    }
}
