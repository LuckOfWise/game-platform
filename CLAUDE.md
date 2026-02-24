# GamePlatform - Claude Code 設定

## プロジェクト概要

Railsアプリケーション（Rails 8.1 / Ruby 4.0 / PostgreSQL / Hotwired / esbuild）。

## 重要なルール

### 基本原則
- **推測ではなく確認** - 実装前に関連ファイルを必ず確認
- **コメントは基本不要** - コードは自己説明的に
- **日本語でコミュニケーション**

### セキュリティ（最重要）
- ハードコードされた秘密情報禁止
- Strong Parameters必須
- SQLインジェクション・XSS・CSRF対策

## ガイドライン

詳細なガイドラインは以下を参照：

- [@doc/agent/general.md](doc/agent/general.md) - 基本原則・品質保証
- [@doc/agent/models.md](doc/agent/models.md) - モデル開発
- [@doc/agent/controllers.md](doc/agent/controllers.md) - コントローラー開発
- [@doc/agent/views.md](doc/agent/views.md) - ビュー開発
- [@doc/agent/spec.md](doc/agent/spec.md) - テスト
- [@doc/agent/code-review.md](doc/agent/code-review.md) - コードレビュー

## エージェント

`.claude/agents/` に専門エージェントを配置：

| エージェント | 用途 |
|-------------|------|
| **planner** | 実装計画策定（複雑な機能、リファクタリング前） |
| **backend** | バックエンド開発（モデル、コントローラー、マイグレーション） |
| **frontend** | フロントエンド開発（ビュー、CSS、JavaScript） |
| **reviewer** | コードレビュー（コード変更後に必須） |
| **security-reviewer** | セキュリティ分析 |

## コマンド

`.claude/commands/` に定義されたワークフロー：

- `/plan` - 実装計画を策定
- `/code-review` - コードレビューを実行
- `/build-fix` - ビルドエラーを修正
- `/test` - テストを実行・分析

## ルール

`.claude/rules/` に配置されたルール：

### 常時適用
- `security.md` - セキュリティガイドライン
- `coding-style.md` - コーディングスタイル
- `git-workflow.md` - Git ワークフロー
- `agents.md` - エージェント運用ガイド

### パス指定あり（該当ファイル編集時に適用）
- `models.md` - モデル開発（app/models/**）
- `controllers.md` - コントローラー開発（app/controllers/**）
- `views.md` - ビュー開発（app/views/**）
- `styles.md` - スタイル開発（app/assets/stylesheets/**）
- `routes.md` - ルーティング（config/routes.rb）
- `migrate.md` - マイグレーション（db/migrate/**）
- `spec.md` - テスト（spec/**）

## 作業フロー

### 新機能実装
1. **planner** エージェントで計画策定
2. **backend** / **frontend** エージェントで実装
3. **reviewer** エージェントでコードレビュー
4. テスト実行・品質チェック

### バグ修正
1. 原因調査
2. **backend** または **frontend** エージェントで修正
3. **reviewer** エージェントでレビュー

## 品質チェックコマンド

```bash
bundle exec rspec              # テスト
bundle exec rubocop            # Ruby Lint
bundle exec brakeman           # セキュリティ
```
