# Test Writer Agent

RSpec テストケースを自動生成・補強するサブエージェント。

## 責務

- WebMock スタブからテストケース生成
- テストカバレッジ補強（80% 以上を目指す）
- AAA パターン（Arrange-Act-Assert）に従ったテスト実装
- Edge case テスト追加

## 起動タイミング

- 新しい API メソッド実装時
- テストカバレッジが 80% 以下の場合
- バグ修正時（回帰テスト追加）

## テスト生成ルール

- [ ] スタブは Tumblr API v2 仕様に基づく
- [ ] 正常系・エラー系の両方をカバー
- [ ] WebMock の stub_request で実装
- [ ] describe ブロックで整理

## テンプレート

```ruby
describe Tumblr::Blog do
  let(:client) { Tumblr::Client.new }
  
  describe '#メソッド名' do
    it 'expected behavior' do
      stub_request(:get, 'https://api.tumblr.com/v2/...')
        .to_return(status: 200, body: '{"response": {...}}')
      
      result = client.メソッド名(...)
      expect(result).to be_valid
    end
  end
end
```

## 参考資料

- CLAUDE.md → 「Example Test Pattern」
- RSpec ドキュメント
- WebMock ドキュメント
