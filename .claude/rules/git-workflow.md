# Git ワークフロー

## コミットメッセージ形式

```
<type>: <description>

<optional body>
```

### タイプ
- `feat`: 新機能
- `fix`: バグ修正
- `refactor`: リファクタリング
- `docs`: ドキュメント
- `test`: テスト
- `chore`: その他（依存関係更新など）
- `perf`: パフォーマンス改善

### 例
```
feat: ユーザー認証機能を追加

- セッションベースの認証を実装
- ログイン/ログアウト機能
- remember me機能
```

## ブランチ戦略

- `main`: 本番環境
- `staging`: ステージング環境
- `feature/*`: 機能開発
- `fix/*`: バグ修正

## Pull Request 作成

1. **変更の確認**
```bash
git status
git diff main...HEAD
git log main..HEAD
```

2. **PR作成**
```bash
gh pr create --title "タイトル" --body "説明"
```

### PRテンプレート
```markdown
## 概要
[変更内容の概要]

## 変更点
- [変更1]
- [変更2]

## テスト計画
- [ ] テスト項目1
- [ ] テスト項目2
```

## 禁止事項

- mainブランチへの直接コミット
- force push（特にmain/staging）
- コミット前のセキュリティチェック省略

## 推奨フロー

1. **計画** - plannerエージェントで計画策定
2. **実装** - backend/frontendエージェントで実装
3. **テスト** - testコマンドでテスト実行
4. **レビュー** - reviewerエージェントでコードレビュー
5. **コミット** - 規約に従ったコミット
6. **PR作成** - 適切な説明を含むPR
