# セキュリティガイドライン

## 必須セキュリティチェック

コミット前に必ず確認：

- [ ] ハードコードされた秘密情報がない（APIキー、パスワード、トークン）
- [ ] すべてのユーザー入力が検証されている
- [ ] SQLインジェクション対策（パラメータ化クエリ）
- [ ] XSS対策（HTMLのサニタイズ）
- [ ] CSRF対策が有効
- [ ] 認証・認可が正しく実装されている
- [ ] エラーメッセージに機密情報が含まれていない

## 秘密情報の管理

```ruby
# 禁止: ハードコードされた秘密情報
api_key = "sk-xxxxx"

# 必須: 環境変数または credentials を使用
api_key = ENV.fetch('API_KEY')
api_key = Rails.application.credentials.api_key!
```

## 入力検証

```ruby
# Strong Parameters 必須
def user_params
  params.require(:user).permit(:name, :email)
end

# ホワイトリスト方式
ALLOWED_STATUSES = %w[active inactive].freeze
validates :status, inclusion: { in: ALLOWED_STATUSES }
```

## SQLインジェクション対策

```ruby
# 禁止: 文字列結合
User.where("name = '#{params[:name]}'")

# 必須: パラメータ化
User.where(name: params[:name])
User.where("name = ?", params[:name])
```

## XSS対策

```erb
<%# 禁止: raw出力 %>
<%= raw user_input %>

<%# 必須: 自動エスケープ %>
<%= user_input %>

<%# HTMLが必要な場合: sanitize %>
<%= sanitize user_input, tags: %w[p br strong] %>
```

## セキュリティ問題発見時の対応

1. **即座に停止** - 他の作業を中断
2. **security-reviewer エージェントを使用**
3. **CRITICAL問題は修正してから続行**
4. **露出した秘密情報があればローテーション**
5. **同様の問題がないかコードベース全体を確認**
