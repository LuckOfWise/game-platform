# Capybaraテストガイドライン

> **注意**: このガイドラインは将来システムスペックを導入する際の参考です。
> 現在のテスト戦略については `spec.md` を参照してください。

## テスト環境のデフォルト設定

### JavaScriptはデフォルトで有効
```ruby
RSpec.describe 'パスワードリセット', type: :system do
  it 'JavaScriptが自動的に有効' do
    # JavaScript依存の動作も問題なくテスト可能
  end
end
```

## 要素選択の優先順位

### 1. テキストコンテンツでの検証（最優先）
```ruby
expect(page).to have_content('ページが見つかりません')
expect(page).to have_content('登録が完了しました')
click_button '送信'
click_link 'ホームへ戻る'

within('section', text: 'コメント一覧') do
  expect(page).to have_content('最初のコメント')
end
```

### 2. セマンティックな属性（name, label）
```ruby
fill_in 'user[email]', with: 'test@example.com'
fill_in 'メールアドレス', with: 'test@example.com'
choose 'プレミアムプラン'
select '東京都', from: '都道府県'
```

### 3. data-test-selector属性（テキストで特定困難な場合のみ）

**重要**: `data-testid`の使用は禁止です。必ず`data-test-selector`属性を使用してください。

```erb
<!-- OK: data-test-selectorで統一 -->
<div data-test-selector="image-upload-area">
  <%= file_field_tag :image %>
</div>
```

```ruby
within(:data_test, 'image-upload-area') do
  attach_file 'image', test_image_path
end
```

## data-test-selector属性の使用場面

### 推奨される使用場面
```ruby
# アイコンボタンなどテキストがない要素
click_button :data_test, 'delete-icon'

# 動的に生成されるコンテンツエリア
within(:data_test, 'notifications-container') do
  expect(page).to have_selector('.notification', count: 3)
end

# 複雑なUIコンポーネント（モーダル、ドロップダウンなど）
within(:data_test, 'user-settings-modal') do
  fill_in 'プロフィール', with: '新しい自己紹介'
end
```

## 繰り返し要素の選択戦略

### 共通のdata-test-selector + textで十分な場合（推奨）
```ruby
within(:data_test, 'comment-item', text: '初期コメント') do
  accept_confirm do
    find(:data_test, 'delete-comment').click
  end
end

within(:data_test, 'user-row', text: 'user@example.com') do
  click_link '編集'
end
```

## フォーム入力のセレクタ優先順位

### fill_in等でのセレクタ選択指針
```ruby
# 1. name属性を優先
fill_in 'user[email]', with: 'test@example.com'

# 2. label要素による指定
fill_in 'メールアドレス', with: 'test@example.com'

# 3. data-test-selector属性（上記が使えない場合）
fill_in :data_test, 'custom-input', with: '入力値'
```

### 避けるべき方法と理由
```ruby
# NG - data-test-selector属性を直接CSSセレクタとして使用するのも禁止
within('[data-test-selector="follows-grid"]') do  # NG
end

# OK - 必ず:data_testカスタムセレクタを使用
within(:data_test, 'follows-grid') do  # OK
end

# NG - CSSクラスはスタイル変更で壊れる
find('.btn-primary').click

# NG - DOM構造に依存し保守困難
find('div > form > input').set('x')

# OK - テキストコンテンツやdata-test-selectorを使用
click_button '送信'
find(:data_test, 'email-input').set('test@example.com')
```

## 非同期処理の待機
```ruby
it '画像のアップロード' do
  attach_file :data_test, 'image-upload', test_image_path
  expect(page).to have_selector(:data_test, 'image-preview', wait: 5)
end
```
