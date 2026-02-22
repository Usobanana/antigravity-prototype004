# Godot 4 Web Export Guide (HTML5)

Godot 4のWebエクスポート（HTML5）において、ブラウザのセキュリティ制限やパフォーマンス調整を行うためのガイドラインです。

## 1. SharedArrayBuffer とスレッド（Thread）の注意点
Godot 4のWebエクスポートはデフォルトでマルチプラットフォーム対応の高度な機能（WebAssembly のスレッド機能、SharedArrayBuffer）を利用します。しかし、これを利用するにはサーバー側で**特定のセキュリティヘッダー（COOP / COEP）**が必須となります。

### ✅ 解決策
サーバー側（GitHub Pages、Itch.ioなど）でヘッダーを設定できない・したくない場合は、以下の設定を行ってください。
1. Godot の **[プロジェクト設定] -> [エクスポート]** を開く。
2. プリセットから **[Web]** を選ぶ。
3. `Export Type` を `Threads` ではなく **`Single-Threaded` (Export Typeが存在しない場合、Godot 4.3以降はエクスポートオプションから `Thread Support` のチェックを外す)** にしてください。
※ `SharedArrayBuffer` のエラーが出る原因の9割が、このスレッドサポートがONになっていることです。

## 2. iPhone (Safari) などの音声遅延・鳴らない問題の対策
Safari や Chrome などの最新ブラウザは「ユーザーの操作（タップ・クリック）」があるまで音声をミュートする仕様（Audio Context suspended）を持っています。

### ✅ 解決策
既に本プロジェクトでは `_unhandled_input` を実装しているため、Godot 4は自動的に最初のタップを検知して Audio Context を再開します。
もしそれでも音が遅れる、鳴らない場合は以下を確認してください。

1. **[プロジェクト設定] -> [オーディオ] -> [一般 (General)]**
   - `Output Latency.web` の値を `50` に設定する（デフォルトならそのままでOK）。
   - 必要に応じて `Mix Rate` を `44100` のままにする（Webは44100が最も安定します）。
2. （将来的な確実な仕組みとして）タイトル画面を用意し、「TAP TO START」ボタンを押したときに無音のダミー音声を一回だけPlayする処理を挟むと、iOSでも確実にそれ以降の全音声が鳴るようになります。

## 3. その他のWeb最適化
- **VRAM圧縮設定**: モバイルブラウザ向けに、プロジェクト設定の `[レンダリング] -> [テクスチャ] -> [VRAM Compression]` で **ETC2 / ASTC** を有効にしておくと、スマホでのテクスチャ読み込みがスムーズになります。
- **フルスクリーン設定**: Webエクスポート設定で `Focus Canvas on Top` と `Clear Color` の設定を確認してください。
