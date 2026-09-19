# Vast.ai で Matterix / LabUtopia を動かす

RTX 3090などを載せたVast.ai VMまたは通常Dockerインスタンスで、Isaac Sim、Matterix、LabUtopiaを動かすための構成です。GUI接続には、host networkを利用できるVMとTailscaleの組み合わせを推奨します。通常Dockerはheadless実行用として残しています。

このリポジトリは完成済みコンテナイメージを配布しません。Vast.ai は NVIDIA 公式の Isaac Sim イメージを直接取得し、起動時に各プロジェクトを上流リポジトリからインストールします。これにより、Isaac Sim/Omniverse Kit や第三者assetsを当リポジトリ経由で再配布しません。

## 互換性

調査日: 2026-09-17

| 構成 | upstream commit | Python | Isaac Sim | Isaac Lab | PyTorch | 用途 |
|---|---|---:|---:|---:|---:|---|
| Matterix | `5d86bd6` | 3.12 | 6.0.1 | 3.0.0b2.post1 | 2.11.0 + cu128 | headless、USD smoke test、利用者提供assetsで公式workflow + WebRTC確認 |
| LabUtopia | `8df7278` | 3.11 | 5.1.0 | なし | 2.9.0 + cu126 | 非商用の研究・教育、headless、データ生成、USD保存、VM + WebRTC確認 |

Matterix の[現行README](https://github.com/AccelerationConsortium/Matterix/blob/5d86bd6e4fc7dd6ea83dead1d076c0176440be9e/README.md)は Isaac Lab 3.0.0b2.post1 とPyTorch 2.10.0を指定しています。Isaac Labのwheelは `torch>=2.10` とIsaac Sim 6.0.1を要求しますが、6.0.1公式コンテナのKit extensionはTorch 2.11を同梱しています。NCCL ABIの競合を避けるため、本構成では2.11.0に揃えます。公式 `docker/` の永続化方法やroot実行設定は参考にしましたが、同ディレクトリには古いIsaac Sim指定も残るため、そのままでは使っていません。

LabUtopia は[現行README](https://github.com/Rui-li023/LabUtopia/blob/8df72784265c375a327ffa3f0a0cf8c676f229a7/README.md)に合わせて Isaac Sim 5.1.0 を使います。上流の `main.py` は `--headless` を解析しても `SimulationApp` に `headless=False` を渡すため、起動時に[最小patch](docker/labutopia/labutopia-headless.patch)を適用します。

## ライセンスと配布境界

利用前に [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) を確認してください。

- このリポジトリ独自のスクリプト、テンプレート、文書、Dockerfileは [MIT License](LICENSE) です。
- NVIDIA Isaac Sim は NVIDIA の条件に従います。`ACCEPT_EULA=Y` と `PRIVACY_CONSENT=Y` は、条件を確認して同意した利用者だけが設定してください。
- Matterix本体はBSD-3-Clauseです。ただし、固定された `Matterix_assets` submoduleには明示的なライセンスファイルがありません。そのため、インストーラーとDockerfileは同submoduleを取得しません。権利者の許可または明確なライセンスが得られるまで、assets依存taskは利用できません。
- LabUtopiaのコードはMIT、data assetsはCC BY-NC 4.0です。assetsは、非商用の研究・教育用途として条件を確認し、`LABUTOPIA_ACCEPT_CC_BY_NC_4_0=Y` を明示した場合だけ上流から取得します。
- GitHub Actionsは静的検査だけを行います。GHCRへのログイン、build、pushは行いません。

NVIDIAによると、Isaac SimとOmniverse Kitを第三者へ配布する場合はNVIDIA AI Enterpriseが必要になることがあります。このリポジトリのローカルbuild機能で作ったイメージを、権限を確認せず公開しないでください。

## Vast.ai VMを一発で構築する（GUI推奨経路）

Vast.aiで公式のUbuntu 22.04 VM templateを選び、作成前にSSH公開鍵を登録してください。RTX 3090（24 GB VRAM）、disk 120 GB以上、reliability 0.98以上、十分なdownload速度を目安にします。VMは通常DockerインスタンスよりOS分の容量を使うため、80 GBは余裕がありません。

SSH接続後、Matterixなら次を実行します。

```bash
curl -fsSLo /tmp/isaac-vm-setup.sh \
  https://raw.githubusercontent.com/noguhiro2002/isaacsim-vastai/main/vm/setup.sh
sudo NVIDIA_ACCEPT_EULA=Y bash /tmp/isaac-vm-setup.sh matterix
```

LabUtopiaの場合は、非商用ライセンス条件を確認した上で次を実行します。

```bash
curl -fsSLo /tmp/isaac-vm-setup.sh \
  https://raw.githubusercontent.com/noguhiro2002/isaacsim-vastai/main/vm/setup.sh
sudo NVIDIA_ACCEPT_EULA=Y LABUTOPIA_ACCEPT_CC_BY_NC_4_0=Y \
  bash /tmp/isaac-vm-setup.sh labutopia
```

スクリプトはGPU passthroughを確認し、Docker、NVIDIA Container Toolkit、Tailscaleを導入します。その後、対象に合うNVIDIA公式Isaac Sim imageを取得し、MatterixまたはLabUtopiaをpersistent workspaceへ導入して、host network上でWebRTCを起動します。途中でTailscaleの認証URLが表示されたら、ブラウザで開いてVMを自分のtailnetへ参加させてください。初回は大きなimage、Python packages、assets、shader cacheを取得するため、回線によっては数十分かかります。

無人構築では、Tailscale管理画面で作ったone-timeかつpre-authorizedのauth keyを一時的に渡せます。shell historyにkeyを残さない例です。

```bash
read -rsp 'Tailscale auth key: ' TS_AUTHKEY; echo
sudo env NVIDIA_ACCEPT_EULA=Y TS_AUTHKEY="$TS_AUTHKEY" \
  bash /tmp/isaac-vm-setup.sh matterix
unset TS_AUTHKEY
```

### MacからTailscale経由で接続する

MacへTailscaleと[Isaac Sim WebRTC Streaming Client](https://docs.isaacsim.omniverse.nvidia.com/latest/installation/manual_livestream_clients.html)を導入し、VMと同じtailnetへ接続します。VM側で次を実行します。

```bash
isaac-vm status
isaac-vm tailscale-ip
```

Streaming ClientのServer欄には、表示された `100.x.y.z` 形式のTailscale IPv4だけを入力します。port番号、Vast.aiの公開IP、SSH tunnelは指定しません。TCP 49100とUDP 47998はVMの `tailscale0` とlocalhostからだけ到達できるよう、systemd管理のfirewall ruleを自動設定します。

NVIDIAの現行手順ではcontainer streamingに `--network=host` が必須で、TCP 49100がsignaling、UDP 47998が映像streamです。またstreaming endpoint自体に認証・暗号化はありません。このため、Tailscaleに加えてtailnet policyでも接続元を制限してください。

### 運用・確認コマンド

```bash
isaac-vm status       # Tailscale、container、GPU、listen port
isaac-vm verify       # GPUとMatterix/LabUtopiaの導入状態
isaac-vm logs         # setupおよびIsaac Simのlogを追跡
isaac-vm shell        # container内のshell
isaac-vm restart      # containerを再起動
```

GUIを使わずheadless smoke testとUSD保存を優先する場合は、最初からWebRTCを無効にします。

```bash
sudo NVIDIA_ACCEPT_EULA=Y ENABLE_WEBRTC=N \
  bash /tmp/isaac-vm-setup.sh matterix
isaac-vm smoke
```

WebRTC稼働中に2個目のIsaac Simを同じGPUで起動しないよう、`isaac-vm smoke` はWebRTC modeでは実行を拒否します。モード変更時はpersistent workspaceを保持したままmanaged containerだけを作り直します。

```bash
sudo NVIDIA_ACCEPT_EULA=Y ENABLE_WEBRTC=N FORCE_RECREATE=Y \
  bash /tmp/isaac-vm-setup.sh matterix
```

data、cache、log、USDなどは `/srv/isaacsim-vastai/<target>/workspace` に残ります。VM自体を破棄すると消えるため、必要な成果物は事前に手元または外部storageへ退避してください。

## Vast.ai 通常Dockerテンプレート（headless用）

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

Matterixのtaskはassetsを参照するため、初期状態では実行対象外です。`Matterix_assets`の権利者から明示的な許可を得た場合だけ、利用者自身の責任で `/opt/matterix/source/matterix_assets/data` を用意してください。当リポジトリは取得手順や再配布物を提供しません。

### Matterix公式workflowをWebRTCで表示する（VM）

2026-09-19に、次の構成で公式の
`Matterix-Test-Beaker-Lift-Franka-v1` / `pickup_beaker` workflowが動作し、
Tailscale経由のIsaac Sim WebRTC Streaming Clientに映像が表示されることを確認しました。

- NVIDIA公式 `nvcr.io/nvidia/isaac-sim:6.0.1`
- Matterix `5d86bd6e4fc7dd6ea83dead1d076c0176440be9e`
- Isaac Lab `3.0.0b2.post1`
- RTX 4060 Ti 16 GB、system RAM約49 GB
- NVIDIA driver `580.95.05`（動作確認値であり、NVIDIAの検証済みdriver要件を置き換えるものではありません）
- Vast.ai VM、Docker host network、Tailscale

MatterixのスクリプトはIsaac Simを自分で起動します。汎用の
`isaacsim-webrtc` と同時には実行せず、managed containerを待機modeへ変更します。
既存のpersistent workspaceは保持されます。

```bash
sudo NVIDIA_ACCEPT_EULA=Y ENABLE_WEBRTC=N FORCE_RECREATE=Y \
  bash /tmp/isaac-vm-setup.sh matterix
```

利用権を確認したassetsを利用者自身で配置した後、task定義、workflow、必須の
ビーカーUSDをsimulationなしで確認できます。

```bash
isaac-vm exec bash -lc '
grep -n "Matterix-Test-Beaker-Lift-Franka-v1" \
  /opt/matterix/source/matterix_tasks/matterix_tasks/test_dev_tasks/__init__.py
grep -n "pickup_beaker" \
  /opt/matterix/source/matterix_tasks/matterix_tasks/test_dev_tasks/test_franka_beaker_lift.py
test -s \
  /opt/matterix/source/matterix_assets/data/labware/beaker500ml/beaker-500ml-inst.usda
'
```

Mac側のStreaming Clientを閉じてから、VM hostのSSH terminalで次を実行します。
`docker exec` はlogin shellを通らないため、Matterix関連の環境変数を明示しています。

```bash
TS_IP="$(isaac-vm tailscale-ip)"

sudo docker exec -it \
  -e LIVESTREAM=2 \
  -e ENABLE_CAMERAS=1 \
  -e PUBLIC_IP="$TS_IP" \
  -e ISAACSIM_PUBLIC_IP="$TS_IP" \
  -e HUB__ARGS__DETECT_ONLY=true \
  -e OMNI_KIT_ALLOW_ROOT=1 \
  -e MATTERIX_PATH=/opt/matterix \
  -e ISAACLAB_PATH=/opt/matterix \
  -e ISAACSIM_PATH=/isaac-sim \
  -w /opt/matterix \
  isaacsim-vm-matterix \
  /isaac-sim/python.sh scripts/run_workflow.py \
    --task Matterix-Test-Beaker-Lift-Franka-v1 \
    --workflow pickup_beaker \
    --num_envs 1 \
    --livestream 2 \
    --enable_cameras \
    --visualizer kit \
    --max_visible_envs 1
```

`--visualizer kit` が重要です。Matterixのcustom step loopは物理演算を
`render=False` で進めるため、`--enable_cameras` だけではState Machineが動いても
Streaming Clientが黒画面のままになることを確認しています。Kit visualizerを明示すると
WebRTCへ渡すinteractive viewportが作られます。最初の動作確認では
`--rendering_mode performance` を付けず、標準rendering設定を使ってください。

次の出力まで進んだ後、Streaming ClientのServer欄へportなしのTailscale IPv4を
入力します。

```text
[ISAACLAB] AppLauncher initialization complete
EPISODE 1
STATE MACHINE STATUS (Actions: 5, Envs: 1)
```

終了は起動したSSH terminalで `Ctrl+C` です。managed container自体は待機modeの
まま残るため、再実行時は同じ `docker exec` commandを使います。

次のmessageは、上記の成功条件まで進みState Machineが動作している場合は既知の
非致命的warningです。

- `OmniHub: Hub failed to launch`（Hubを別serviceとして起動していない場合）
- `grpc/health/v1/health.proto` の重複登録
- `Failed to open [/var/run/utmp]`
- `Possible version incompatibility ... IStageReaderWriter`
- actuatorの `effort_limit` / `velocity_limit` deprecation
- WebRTCのdynamic resize拒否（元のstream解像度で継続）

この固定版の `run_workflow.py` は `--width` / `--height` をparserへ登録していないため、
それらを渡すと `unrecognized arguments` で終了します。

## LabUtopiaを確認する

全設定ファイルをsimulationなしでparseする軽量testです。上流の `tests/test_config_files.py` はunit testではなく、複数のsimulationを長時間実行するrunnerなので、ここでは使いません。

```bash
cd /opt/labutopia
isaac-python -c 'from pathlib import Path; import yaml; files=list(Path("config").glob("*.yaml")); assert files; [yaml.safe_load(p.read_text()) for p in files]; print(f"CONFIGS_OK={len(files)}")'
```

実験室sceneをheadlessで構築・resetし、合成stageをUSDへ保存して正常終了するsmoke testです。

```bash
labutopia-run \
  --config-name level1_pick \
  --headless \
  --no-video \
  --save-usd /workspace/output/labutopia-level1-pick.usda \
  --exit-after-save
```

実際のepisode実行・データ収集では `--exit-after-save` を外し、必要に応じて `--max-episodes N` を指定します。Hydraの `outputs/` はproject directoryに作られるため、保存したい結果は `/workspace/output` へ移すか、設定の出力先を同directoryへ変更してください。

### LabUtopiaタスクをWebRTCで表示する（VM）

LabUtopiaは上流の `main.py` だけではWebRTCを起動しないため、このrepositoryの
patchはIsaac Sim 5.1公式Python livestream方式を追加します。`--livestream` は
headless appを起動しつつUIをstream対象として残し、最初のtask cameraをactive
viewportへ設定します。

2026-09-19に、RTX 4060 Ti 16 GB、NVIDIA driver `580.95.05`、Vast.ai VM、
Docker host network、Tailscaleの構成で、`level1_pick` のtask実行とMac版
Isaac Sim WebRTC Streaming Clientへの映像表示を確認しました。

汎用の `isaacsim-webrtc` とLabUtopiaを同時起動しないよう、managed containerは
待機modeにします。既存環境をWebRTC対応版へ更新する場合も、persistent workspaceは
保持されます。

```bash
curl -fsSLo /tmp/isaac-vm-setup.sh \
  https://raw.githubusercontent.com/noguhiro2002/isaacsim-vastai/main/vm/setup.sh

sudo NVIDIA_ACCEPT_EULA=Y \
  LABUTOPIA_ACCEPT_CC_BY_NC_4_0=Y \
  ENABLE_WEBRTC=N \
  FORCE_RECREATE=Y \
  bash /tmp/isaac-vm-setup.sh labutopia
```

Mac側のStreaming Clientを閉じてから、VM hostで次を実行します。

```bash
TS_IP="$(isaac-vm tailscale-ip)"

isaac-vm exec env \
  ISAACSIM_PUBLIC_IP="$TS_IP" \
  ISAACSIM_SIGNAL_PORT=49100 \
  OMNI_KIT_ALLOW_ROOT=1 \
  labutopia-run \
    --config-name level1_pick \
    --livestream \
    --no-video \
    --width 1280 \
    --height 720
```

`LABUTOPIA_WEBRTC_READY=100.x.y.z:49100 camera=/World/Camera1` が表示されたら、
Streaming ClientのServer欄へportなしのTailscale IPv4を入力します。映像は
LabUtopiaが生成する最初のtask cameraです。別cameraを選ぶ場合は、例えば
`--viewport-camera /World/Camera2` を追加します。

RTX 4060 Ti 16 GBなどで負荷が高い場合は、最初に `--width 960 --height 540` へ
下げてください。終了は起動terminalの `Ctrl+C` です。WebRTC endpointには
認証・暗号化がないため、この手順ではfirewallでTailscaleからの接続だけを許可します。

#### 成功条件と正常なwarning

既存環境の更新または初回setupは、次の3行まで到達すれば成功です。

```text
[bootstrap] LabUtopia installed from upstream for an accepted CC BY-NC 4.0 use
[vm-setup] labutopia installation completed
Vast.ai VM setup completed.
```

依存関係導入中の次のmessageは、この構成では既知の非致命的warningです。

```text
nvidia-srl-usd-to-urdf ... requires usd-core ... which is not installed
```

PyPI版 `usd-core` はIsaac Sim同梱の `pxr` / USD ABIをshadowする可能性があるため、
意図的に導入していません。後続に `Successfully installed ...` と上記の
`[bootstrap] LabUtopia installed ...` があれば、このresolver warningだけを理由に
追加インストールしないでください。rootユーザーに対するpip warningも、専用container内では
想定内です。

各確認commandの成功条件は次のとおりです。

| 段階 | command | 成功条件 |
|---|---|---|
| 導入確認 | `isaac-vm verify` | GPU情報と正数の `configs=N` を表示し、終了code 0 |
| scene/USD | `level1_pick --save-usd ... --exit-after-save` | `USD_SAVED=/workspace/output/labutopia-level1-pick.usda` と0 byteより大きいfile |
| WebRTC server | `level1_pick --livestream ...` | `LABUTOPIA_WEBRTC_READY=<Tailscale-IP>:49100 camera=/World/Camera1` |
| Client表示 | Mac版Streaming ClientでTailscale IPへ接続 | 黒画面ではなくlab sceneとrobot動作が継続表示される |

#### ラボ全体・長時間タスクのデモ

[LabUtopia公式サイト](https://rui-li023.github.io/labutopia-site/)はbenchmarkを、atomic manipulationから長時間のmobile
manipulationまでの5段階として説明しています。固定した上流コミットのREADME本文は
Level 4までしか列挙していませんが、repository内には次のLevel 5設定、task、controller、
factory登録が含まれます。

| config | 内容 | 推奨順 |
|---|---|---:|
| `level5_Navigation` | navigation lab全体でRidgebase + FrankaがA*経路を自律走行 | 1 |
| `level5_Mobile_manipulation` | lab内を移動し、目的地点でビーカーを把持 | 2 |
| `level4_OpenTransportPour` | 扉を開ける、把持、搬送、注ぐ、再搬送の長い卓上手順 | 3 |
| `level4_DeviceOperation` | 装置を開け、複数ビーカーを出し入れし、buttonを押す | 4 |
| `level4_LiquidMixing` | 複数容器の把持・注液・配置・button操作 | 高負荷 |

最初は、学習済みmodelを必要とせずA*と組込みcontrollerで動く
`level5_Navigation` を使います。`top_camera` をstreamへ割り当てるため、移動と
周辺のlab配置を確認しやすい構成です。

```bash
TS_IP="$(isaac-vm tailscale-ip)"

isaac-vm exec env \
  ISAACSIM_PUBLIC_IP="$TS_IP" \
  ISAACSIM_SIGNAL_PORT=49100 \
  OMNI_KIT_ALLOW_ROOT=1 \
  labutopia-run \
    --config-name level5_Navigation \
    --livestream \
    --no-video \
    --viewport-camera /World/Ridgebase/base_link/Camera_01 \
    --width 960 \
    --height 540
```

次がserver側の成功条件です。

```text
LABUTOPIA_WEBRTC_READY=<Tailscale-IP>:49100 camera=/World/Ridgebase/base_link/Camera_01
```

Clientではmobile robotの移動に伴ってlab背景が変化します。episode完了後にresetが
行われると `Episode Stats: Success Rate = ...` が表示されます。前方視点にする場合は
`--viewport-camera` を省略するか、`/World/Ridgebase/base_link/Camera` を指定します。

Navigationが動いた後、最も包括的なデモを次で実行します。

```bash
TS_IP="$(isaac-vm tailscale-ip)"

isaac-vm exec env \
  ISAACSIM_PUBLIC_IP="$TS_IP" \
  ISAACSIM_SIGNAL_PORT=49100 \
  OMNI_KIT_ALLOW_ROOT=1 \
  labutopia-run \
    --config-name level5_Mobile_manipulation \
    --livestream \
    --no-video \
    --viewport-camera /World/Ridgebase/base_link/Camera_01 \
    --width 960 \
    --height 540
```

このtaskは `Navigation completed, starting pick task!` の後に把持へ移行し、最後に
`Pick task completed!` と成功または失敗理由を表示します。Level 5はLevel 1より
初期化と1 episodeが長く、上流実装上も実験的です。まず960x540・1 clientで確認し、
終了は起動terminalで `Ctrl+C` を使ってください。

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

- Matterixのassetsは意図的に未導入です。初期状態ではassets依存taskは動きません。利用権を確認したassetsを利用者自身で配置した場合は、VM + Tailscaleで公式workflowのWebRTC表示を確認済みです。
- MatterixはIsaac Lab 3.0 betaを使うため、破壊的変更や一時的なregressionがあり得ます。
- LabUtopia assetsはCC BY-NC 4.0です。商用利用向けではありません。
- LabUtopiaのupstream commitを変えると、headless patchが適用できない場合があります。
- LabUtopiaの `level1_pick` WebRTC表示は実機確認済みですが、Level 5のnavigationとmobile manipulationは上流に実装されている実験的taskで、この構成での完走確認はこれからです。
- RTX 3090の24 GB VRAMは、高解像度camera、多数environment、複雑なsceneでは不足する場合があります。
- 初回起動は公式イメージ、Python packages、LabUtopiaのGit LFS assets、shader cacheを取得するため時間がかかります。
- VM経路はVast.aiのUbuntu 22.04 VM templateを基準にしています。GPU passthrough、`nvidia-smi`、systemdが正常なhostが必要です。
- WebRTCにはNVENC対応GPUが必要で、一度に1 clientだけ接続できます。TailscaleがDERP relayになる環境では遅延や画質低下が起こり得ます。
- `vm/setup.sh` はUbuntu 22.04/24.04 x86_64専用で、hostのNVIDIA driver自体は導入しません。
- Vast.ai hostごとにdriver、RAM、disk I/O、UDP品質が異なります。安価なofferほど個体差があります。
- WebRTCはVM + host network + Tailscaleを推奨経路とし、通常Docker/NATでは非対応です。

## ディレクトリ

| path | 内容 |
|---|---|
| `/opt/matterix` | 起動時に上流から取得したMatterix |
| `/opt/labutopia` | 起動時に上流から取得したLabUtopia |
| `/workspace/cache` | Isaac Sim、pip、shader cache |
| `/workspace/logs` | bootstrap、Omniverse、WebRTC log |
| `/workspace/output` | USD、動画、datasetなどの成果物 |
| `/workspace/.setup` | 導入済みcommit marker |
| `/srv/isaacsim-vastai/<target>/workspace` | VM経路のpersistent workspace |
