
# RSpecテストガイドライン

## 基本原則

### テストブロックの記述言語

- **describe, context, itブロックの文字列は基本的に日本語で記述する**
  - メソッド名やクラス名など、コード内の識別子はそのまま記載
  - テストの説明文は日本語で記述
  - 例: `describe "User#name"`, `context "ユーザーが有効な場合"`,
    `it "trueを返すこと"`
- テスト内のコメントやエラーメッセージは日本語で記述する

### テストコードの2つの重要な役割

- **対象コードの仕様が一目でわかること（仕様書として機能すること）**
- **確実にバグを検出できること**

### テストの価値基準

- **テストは必ずビジネス価値またはリスク軽減の目的で書く**
- **判断基準**: 「そのテストが失敗したら、実際に問題が発生するか？」を自問する
- **フレームワークの基本機能はテストしない**: Active
  Recordやフレームワークが提供する基本機能のテストは不要
- **テストコードレビューの観点**: 「このテストが無くても困らないなら書かない」
- **価値のないテストの特徴**:
  - フレームワークの動作確認（new_record?, persisted?, created_at
    の存在確認など）
  - 明らかに正しく動作することが保証されている処理
  - 実装の詳細に依存しすぎているテスト
- **プライベートメソッドは直接テストしない**
  - プライベートメソッドは実装の詳細であり、パブリックインターフェースを通じて間接的にテストする
  - プライベートメソッドが複雑すぎる場合は、別クラスへの抽出を検討する

### テストコードの記述方針

- **Arrange-Act-Assert (AAA)パターンに従う**
  - Arrange: テストの前提条件を設定
  - Act: テスト対象のメソッドを実行
  - Assert: 期待される結果を検証
  - 各ステップを明確に分離し、コメントで区切ることも検討
- **テストの期待値にDRY原則を適用しない**
  - 期待値は明示的に書く（計算ロジックから導出しない）
  - 例：`expect(cloth.half_price).to eq 500` （500という具体的な値を明記）
  - **変数を使った検証は禁止** - 期待値は必ずベタ書きする
    - NG: `expect(page).to have_content(project.title)`
    - OK: `expect(page).to have_content("プロジェクトタイトル")`
  - **factory_botの暗黙的な初期値に依存した検証は禁止**
    - factoryで設定されている値も明示的に記述する
    - テストを読むだけで期待される動作が完全に理解できるようにする
- **テストコードに複雑なロジックを含めない**
  - 過度な条件分岐を避ける
  - 大量のループ処理を避ける
  - 複雑な計算ロジックを避ける
- **読みやすさを最優先にする**
  - 一目で理解できるテストコードを書く
  - 上から下へストレートに読める構造にする
  - 期待される動作を明示的に示す
- **簡潔さよりも明確さを優先する**
  - プロダクションコードではDRY原則が重要だが、テストコードでは意図を曖昧にする可能性がある
  - テストが生きたドキュメントとして機能することを目指す
  - 「スマートさ」より「わかりやすさ」を重視

### RSpec DSLの構築ルール

- **DSLは静的に構築する**
  - 動的なメタプログラミングやループでletやitを生成しない
  - 悪い例：`1.upto(10) { |n| let!("user_#{n}") { create(:user) } }`
  - 良い例：`let!(:users) { create_list(:user, 10) }`
- **beforeブロックの適切な使用**
  - Arrangeステップのみをbeforeブロックに記述
  - Actステップはbeforeブロックではなくitブロック内で実行
  - 複数のテストで共通のセットアップのみをbeforeで行う
- **subjectの使用は慎重に**
  - 単純な一行のテストでのみ使用を検討
  - 複雑なテストではsubjectを避け、明示的な記述を優先
  - 可読性が損なわれる場合はsubjectを使わない
- **トップレベルのdescribeは1つのみ**
  - ファイルごとに1つのトップレベルdescribeブロックを維持
  - 関連するテストは内部のcontextで整理
- **メソッドやshared_examplesはdescribe内で定義**
  - グローバルスコープでの定義を避ける
  - スコープを最小限に保つ
- **変数や定数の定義は慎重に**
  - describe/contextブロック内で直接変数を定義しない
  - letやbeforeブロックを適切に使用

### 具体的なアンチパターンと改善例

```ruby
# NG: 動的にテストケースを生成
[1, 5, 10].each do |count|
  it "#{count}個のアイテムを処理できること" do
    items = create_list(:item, count)
    expect(service.process(items)).to be_successful
  end
end

# OK: 代表的なケースを明示的に記述
it "1個のアイテムを処理できること" do
  item = create(:item)
  expect(service.process([item])).to be_successful
end

it "複数のアイテムを処理できること" do
  items = create_list(:item, 5)
  expect(service.process(items)).to be_successful
end

# NG: beforeブロックにActステップを含める
describe '#cancel' do
  before { reservation.cancel! }

  it 'キャンセル料が発生すること' do
    expect(user.billings.count).to eq 1
  end
end

# OK: AAAパターンを明確に分離
describe '#cancel' do
  it 'キャンセルするとキャンセル料が発生すること' do
    # Act
    reservation.cancel!

    # Assert
    expect(user.billings.count).to eq 1
    billing = user.billings.first
    expect(billing.amount).to eq 500
  end
end
```

### TDD開発後の品質管理

- **TDDでの開発後は必ずテストのコメントを適切に見直す**
  - 開発中に追加した一時的なコメントや説明を整理する
  - テストの意図が明確に伝わるよう、説明文やコメントを最適化する
  - 不要になった古いコメントや重複した説明は削除する

### 必要なテストタイプ

基本的に以下のテストのみ作成・維持する。

- **モデル用スペック** (spec/models)
  - モデルのバリデーション、関連、スコープなどのテスト
  - **単純なバリデーションのテストは不要**（presence、length、formatなどの基本的なバリデーション）
  - 複雑なビジネスロジックを含むバリデーションやカスタムバリデーションのみテストする
- **システムスペック** (spec/system)
  - **画面のあるページのテストはシステムスペックで実装する**
  - ユーザー視点での画面操作とその結果を検証
  - Capybaraを使用したブラウザテスト
  - 正常系のユーザーフローを中心にテスト
- **リクエストスペック** (spec/requests)
  - **APIエンドポイントのテスト**に使用
  - **認証・認可のテスト**（権限がない場合のリダイレクト確認など）
  - HTTPレベルでの検証が必要な場合に使用
- **メーラースペック** (spec/mailers)
  - メール送信のテスト
  - メール内容の検証

### システムスペック vs リクエストスペックの使い分け

| ケース | 使用するスペック |
|--------|------------------|
| 画面表示・フォーム送信の正常系 | システムスペック |
| ユーザーフロー全体のテスト | システムスペック |
| 認証・認可のテスト（権限チェック） | リクエストスペック |
| APIエンドポイントのテスト | リクエストスペック |
| リダイレクトやHTTPステータスの検証 | リクエストスペック |

**システムスペックの実装例**：

```ruby
RSpec.describe "ゲーム管理", type: :system do
  let(:user) { create(:user) }

  before do
    driven_by(:rack_test)
    sign_in(user)
  end

  describe "ゲーム作成" do
    it "新しいゲームを作成できる" do
      visit new_game_path

      fill_in "ゲーム名", with: "テストゲーム"
      fill_in "説明", with: "テスト用の説明文"
      click_button "作成"

      expect(page).to have_content("ゲームを作成しました")
      expect(page).to have_content("テストゲーム")
    end
  end
end
```

### factory_botの適切な使用方法
- **traitを最優先で使用する**
  - 必要な属性の組み合わせに対応するtraitが既に定義されている場合は、必ずtraitを使用する
  - 直接的な属性指定よりもtraitを優先する
- **traitの冗長な指定を避ける**
  - traitが既に設定している属性を再度明示的に指定してはいけない
- **traitの内容を理解してから使用する**
  - traitがどの属性を設定するかを事前に確認する
  - 複数のtraitを組み合わせる際は、重複する属性がないか確認する
- **factoryファイルの構造を活用する**
  - 関連するtraitは同じfactoryファイル内で定義し、相互の関係を明確にする
  - trait名は設定する属性を明確に示すようにする

**絶対に作成してはいけないテスト**：

- **コントローラースペック** (spec/controllers) - **禁止**（画面テストはシステムスペック、認証・認可はリクエストスペックを使用）
- **ビュースペック** (spec/views) - **禁止**
- **ルーティングスペック** (spec/routing) - **禁止**
- **ジョブスペック** (spec/jobs) - **禁止**
- **ヘルパースペック** (spec/helpers) - **禁止**

### 重要な注意事項

**画面のあるページのテストについて**：

- 画面のあるページのテストは**システムスペック**で実装する
- ユーザー操作とその結果（画面表示、フォーム送信など）をテストする
- 正常系のユーザーフローを中心にテストする

**認証・認可のテストについて**：

- 認証・認可機能のテストは**リクエストスペック**で実装する
- 権限がない場合のリダイレクト確認など、HTTPレベルの検証が必要な場合に使用
- before_actionのテストもリクエストスペックで実装

**リクエストスペックの実装例**（認証・認可のテスト）：

```ruby
RSpec.describe "Admin::Users", type: :request do
  let(:admin_user) { create(:user, admin: true) }
  let(:normal_user) { create(:user, admin: false) }

  describe "GET /admins/users" do
    context "管理者としてログインしている場合" do
      before { sign_in admin_user }

      it "アクセスできる" do
        get admins_users_path
        expect(response).to have_http_status(:success)
      end
    end

    context "一般ユーザーとしてログインしている場合" do
      before { sign_in normal_user }

      it "リダイレクトされる" do
        get admins_users_path
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
```
