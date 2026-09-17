# Vast.ai で Matterix / LabUtopia を動かす

RTX 3090 などを載せた Vast.ai の通常 Docker インスタンスで、Isaac Sim、Matterix、LabUtopia を headless 実行するための構成です。VM と Docker-in-Docker は使いません。

このリポジトリは完成済みコンテナイメージを配布しません。Vast.ai は NVIDIA 公式の Isaac Sim イメージを直接取得し、起動時に各プロジェクトを上流リポジトリからインストールします。これにより、Isaac Sim/Omniverse Kit や第三者assetsを当リポジトリ経由で再配布しません。

## 互換性

調査日: 2026-09-17

| 構成 | upstream commit | Python | Isaac Sim | Isaac Lab | PyTorch | 用途 |
|---|---|---:|---:|---:|---:|---|
| Matterix | `5d86bd6` | 3.12 | 6.0.1 | 3.0.0b2.post1 | 2.10.0 + cu128 | headless、USD smoke test、コード導入確認 |
| LabUtopia | `8df7278` | 3.11 | 5.1.0 | なし | 2.9.0 + cu126 | 非商用の研究・教育、headless、データ生成、USD保存 |

Matterix の[現行README](https://github.com/AccelerationConsortium/Matterix/blob/5d86bd6e4fc7dd6ea83dead1d076c0176440be9e/README.md)は Isaac Lab 3.0.0b2.post1 と PyTorch 2.10.0 を指定しています。この Isaac Lab wheel に合わせて Isaac Sim 6.0.1 を使います。公式 `docker/` の永続化方法やroot実行設定は参考にしましたが、同ディレクトリには古いIsaac Sim指定も残るため、そのままでは使っていません。

LabUtopia は[現行README](https://github.com/Rui-li023/LabUtopia/blob/8df72784265c375a327ffa3f0a0cf8c676f229a7/README.md)に合わせて Isaac Sim 5.1.0 を使います。上流の `main.py` は `--headless` を解析しても `SimulationApp` に `headless=False` を渡すため、起動時に[最小patch](docker/labutopia/labutopia-headless.patch)を適用します。

## ライセンスと配布境界

利用前に [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) を確認してください。

- このリポジトリ独自のスクリプト、テンプレート、文書、Dockerfileは [MIT License](LICENSE) です。
- NVIDIA Isaac Sim は NVIDIA の条件に従います。`ACCEPT_EULA=Y` と `PRIVACY_CONSENT=Y` は、条件を確認して同意した利用者だけが設定してください。
- Matterix本体はBSD-3-Clauseです。ただし、固定された `Matterix_assets` submoduleには明示的なライセンスファイルがありません。そのため、インストーラーとDockerfileは同submoduleを取得しません。権利者の許可または明確なライセンスが得られるまで、assets依存taskは利用できません。
- LabUtopiaのコードはMIT、data assetsはCC BY-NC 4.0です。assetsは、非商用の研究・教育用途として条件を確認し、`LABUTOPIA_ACCEPT_CC_BY_NC_4_0=Y` を明示した場合だけ上流から取得します。
- GitHub Actionsは静的検査だけを行います。GHCRへのログイン、build、pushは行いません。

NVIDIAによると、Isaac SimとOmniverse Kitを第三者へ配布する場合はNVIDIA AI Enterpriseが必要になることがあります。このリポジトリのローカルbuild機能で作ったイメージを、権限を確認せず公開しないでください。

## Vast.ai テンプレート

通常は次のJSONをVast.aiのTemplates画面へ転記します。

- [Matterix template](vastai/matterix-template.json): `nvcr.io/nvidia/isaac-sim:6.0.1`
- [LabUtopia template](vastai/labutopia-template.json): `nvcr.io/nvidia/isaac-sim:5.1.0`
- [WebRTC Identity Port template](vastai/webrtc-identity-template.json): 実験用

どのテンプレートも公式NVIDIAイメージを直接選び、On-start scriptでこの公開リポジトリの `vastai/bootstrap.sh` を取得します。bootstrapは固定commitのMatterixまたはLabUtopiaを上流から導入し、`/workspace/.setup` に完了markerを置きます。`/workspace` を永続volumeにすれば、cache、log、outputを再利用できます。

推奨offer条件は次のとおりです。

- GPU RAM 20 GB以上。RTX 3090の24 GBで最小規模の確認が可能
- disk 80 GB以上
- CUDA 12.8以上（Matterix）、12.6以上（LabUtopia）
- reliability 0.98以上
- 大きな公式イメージを取得するため、download回線とdisk速度を価格と一緒に確認

起動中の導入状況は次で確認できます。

```bash
tail -f /workspace/logs/bootstrap-matterix.log
# または
tail -f /workspace/logs/bootstrap-labutopia.log
```

### Vast.ai CLI の例

次の例はNVIDIAの条件に同意済みであることを前提にします。`<OFFER_ID>` は検索結果のIDへ置き換えてください。

```bash
BOOTSTRAP='mkdir -p /workspace/logs; python3 -c '\''import urllib.request; urllib.request.urlretrieve("https://raw.githubusercontent.com/noguhiro2002/isaacsim-vastai/main/vastai/bootstrap.sh", "/tmp/vast-bootstrap.sh")'\''; bash /tmp/vast-bootstrap.sh matterix 2>&1 | tee /workspace/logs/bootstrap-matterix.log'

vastai create instance <OFFER_ID> \
  --image nvcr.io/nvidia/isaac-sim:6.0.1 \
  --disk 80 --ssh --direct \
  --env '-e ACCEPT_EULA=Y -e PRIVACY_CONSENT=Y -e OMNI_KIT_ALLOW_ROOT=1 -e NVIDIA_VISIBLE_DEVICES=all -e NVIDIA_DRIVER_CAPABILITIES=all -e VAST_PERSIST_ROOT=/workspace' \
  --onstart-cmd "$BOOTSTRAP"
```

LabUtopiaではimageを `nvcr.io/nvidia/isaac-sim:5.1.0` に変更し、環境変数へ `-e LABUTOPIA_ACCEPT_CC_BY_NC_4_0=Y` を追加します。bootstrapの引数とlog名も `labutopia` に変えてください。

## GPUとIsaac Simを確認する

SSH接続後に実行します。

```bash
verify-gpu
isaac-python -c 'import torch; print(torch.__version__); print(torch.cuda.get_device_name(0))'
```

最小stageをheadlessで作り、USDとして保存します。

```bash
isaac-usd-smoke
test -s /workspace/output/isaac-headless-smoke.usda
```

Isaac Simのfull appを画面なしで起動する場合は次を使います。終了は `Ctrl+C` です。

```bash
isaacsim-headless
```

batch処理では `isaac-python your_script.py` を使い、生成物を `/workspace/output` 以下へ保存してください。

## Matterixを確認する

導入したcommit、Isaac Lab、assets除外markerを確認します。

```bash
git -C /opt/matterix rev-parse HEAD
isaac-python -c 'import importlib.metadata as m; print(m.version("isaaclab"))'
test -f /opt/matterix/source/matterix_assets/data/ASSETS_NOT_INSTALLED.md
```

期待値はそれぞれ `5d86bd6e4fc7dd6ea83dead1d076c0176440be9e`、`3.0.0b2.post1`、終了code 0です。Isaac SimとUSD出力は前節の `isaac-usd-smoke` で確認します。

Matterixのtaskはassetsを参照するため、この構成では実行対象外です。`Matterix_assets`の権利者から明示的な許可を得た場合だけ、利用者自身の責任で `/opt/matterix/source/matterix_assets/data` を用意してください。当リポジトリは取得手順や再配布物を提供しません。

## LabUtopiaを確認する

設定ファイルの軽量testを実行します。

```bash
cd /opt/labutopia
isaac-python -m pytest tests/test_config_files.py -q
```

1 episodeだけheadless実行し、合成stageをUSDへ保存します。

```bash
labutopia-run \
  --config-name level1_pick \
  --headless \
  --no-video \
  --max-episodes 1 \
  --save-usd /workspace/output/labutopia-level1-pick.usda
```

通常のデータ収集では `--max-episodes 1` を外します。Hydraの `outputs/` はproject directoryに作られるため、保存したい結果は `/workspace/output` へ移すか、設定の出力先を同directoryへ変更してください。

## ローカルbuild（内部利用のみ）

Dockerfileの再現性確認や、利用者自身の管理下で使う場合に限りbuildできます。Docker Engine、BuildKit、NVIDIA Container Toolkit、80 GB以上の空き容量を用意してください。

```bash
make build-matterix
make LABUTOPIA_ACCEPT_CC_BY_NC_4_0=Y build-labutopia
```

LabUtopiaのbuild引数は、非商用条件を確認した場合だけ `Y` にしてください。生成したイメージを公開registryへpushするworkflowはありません。

静的検査は次で実行します。

```bash
make check
```

この検査は、Vast.aiテンプレートが公式NVIDIAイメージを指すこと、CIにGHCR push権限・actionがないこと、JSON・shell・Pythonの基本構文を確認します。

## WebRTCとIdentity Port

[実験用template](vastai/webrtc-identity-template.json)はTCP 70000とUDP 70001を同じ内外portとして要求します。起動後、割当状況とlogを確認します。

```bash
env | grep -E '^VAST_(TCP|UDP)_PORT_'
tail -f /workspace/logs/webrtc.log
```

ただし、NVIDIAのcontainer streaming手順はhost networkを前提としています。Vast.aiの通常Dockerインスタンスではhost networkを指定できず、Identity Portでport番号を合わせてもnetwork namespaceやICE/NATの制約は残ります。このためWebRTCは保証対象外です。接続できない場合は調査を打ち切り、headless、dataset生成、動画・USD保存を正式なfallbackにしてください。

LabUtopiaのIsaac Sim 5.1はmedia UDP port 47998を使うため、今回のIdentity Port実験の対象外です。WebRTC endpointには認証・暗号化もないため、公開範囲を制限できないhostでは起動しないでください。

## known limitations

- Matterixのassetsは意図的に未導入です。assets依存taskは動きません。
- MatterixはIsaac Lab 3.0 betaを使うため、破壊的変更や一時的なregressionがあり得ます。
- LabUtopia assetsはCC BY-NC 4.0です。商用利用向けではありません。
- LabUtopiaのupstream commitを変えると、headless patchが適用できない場合があります。
- RTX 3090の24 GB VRAMは、高解像度camera、多数environment、複雑なsceneでは不足する場合があります。
- 初回起動は公式イメージ、Python packages、LabUtopiaのGit LFS assets、shader cacheを取得するため時間がかかります。
- Vast.ai hostごとにdriver、RAM、disk I/O、UDP品質が異なります。安価なofferほど個体差があります。
- WebRTCは通常Docker/NATでは非対応です。headless運用を標準経路とします。

## ディレクトリ

| path | 内容 |
|---|---|
| `/opt/matterix` | 起動時に上流から取得したMatterix |
| `/opt/labutopia` | 起動時に上流から取得したLabUtopia |
| `/workspace/cache` | Isaac Sim、pip、shader cache |
| `/workspace/logs` | bootstrap、Omniverse、WebRTC log |
| `/workspace/output` | USD、動画、datasetなどの成果物 |
| `/workspace/.setup` | 導入済みcommit marker |
