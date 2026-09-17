# Vast.ai で Matterix / LabUtopia を動かす

RTX 3090 などの GPU を載せた Vast.ai の通常 Docker インスタンスで、Matterix または LabUtopia を起動するためのイメージです。Docker-in-Docker と VM は使いません。両プロジェクトは必要な Isaac Sim 世代が違うため、イメージを分けています。

初回は「互換性」「GHCR へ publish」「Vast.ai テンプレート」の順に読んでください。起動後は「GPU を確認する」以降を逆引きで使えます。

## 互換性は 2 イメージで固定する

調査日: 2026-09-17

| イメージ | upstream commit | Python | Isaac Sim | Isaac Lab | PyTorch | 根拠と判断 |
|---|---|---:|---:|---:|---:|---|
| Matterix | `5d86bd6` | 3.12 | 6.0.1 | 3.0.0b2.post1 | 2.10.0 + cu128 | [現行 README](https://github.com/AccelerationConsortium/Matterix/blob/5d86bd6e4fc7dd6ea83dead1d076c0176440be9e/README.md) は Isaac Lab 3.0.0b2.post1 と Torch 2.10.0 を指定。この Isaac Lab wheel は Isaac Sim 6.0.1 を要求するため、それに合わせた。 |
| LabUtopia | `8df7278` | 3.11 | 5.1.0 | なし | 2.9.0 + cu126 | [現行 README](https://github.com/Rui-li023/LabUtopia/blob/8df72784265c375a327ffa3f0a0cf8c676f229a7/README.md) の指定をそのまま採用した。 |

Matterix 公式の `docker/` は、永続化対象、`_isaac_sim` の symlink、`OMNI_KIT_ALLOW_ROOT=1` などを参考にしました。ただし [`.env.base`](https://github.com/AccelerationConsortium/Matterix/blob/5d86bd6e4fc7dd6ea83dead1d076c0176440be9e/docker/.env.base) は Isaac Sim 4.5.0、README の badge は 5.0.0、Python インストール手順は実質 6.0.1 を指しており、現在は三者が一致していません。また、公式 Dockerfile だけでは外部の Isaac Lab 本体が入りません。このリポジトリでは現行 Python 依存を優先し、NVIDIA の `nvcr.io/nvidia/isaac-sim:6.0.1` に Isaac Lab 3.0.0b2.post1 を追加しています。

LabUtopia には公式 Dockerfile がありません。さらに現行 `main.py` は `--headless` を解析する一方、`SimulationApp` へ常に `headless=False` を渡します。このイメージは [最小 patch](docker/labutopia/labutopia-headless.patch) で修正し、短い確認実行用の `--max-episodes` と、合成 stage 保存用の `--save-usd` も加えます。

## まずライセンスを確認する

イメージを実行すると NVIDIA Isaac Sim の EULA と privacy terms に同意した扱いになります。`ACCEPT_EULA=Y` と `PRIVACY_CONSENT=Y` は、同意した利用者だけが設定してください。

LabUtopia のコードは MIT、同梱 assets は CC BY-NC 4.0 です。LabUtopia assets を含む GHCR image は非商用の研究・教育用途に限定し、公開範囲も所属組織の方針に合わせてください。

## ローカルで build する

前提は Docker Engine 26 以降、BuildKit、NVIDIA Container Toolkit、十分な空き容量です。どちらの build も NGC base image、Python packages、Git LFS assets を取得するため、80 GB 以上の空きを推奨します。2026-09-17 のローカル実測では、展開後の Matterix image は約 50.3 GB、LabUtopia image は約 37.6 GB でした。

```bash
make build-matterix
make build-labutopia
```

直接 build する場合:

```bash
docker build -f docker/matterix/Dockerfile -t isaacsim-vastai-matterix:local .
docker build -f docker/labutopia/Dockerfile -t isaacsim-vastai-labutopia:local .
```

upstream commit は再現性のため固定しています。更新を試す場合だけ build arg を上書きします。

```bash
docker build -f docker/matterix/Dockerfile \
  --build-arg MATTERIX_REF=<commit-sha> \
  -t isaacsim-vastai-matterix:test .
```

## GitHub Actions から GHCR へ publish する

[build-images.yml](.github/workflows/build-images.yml) は `linux/amd64` の 2 イメージを build し、次へ push します。

```text
ghcr.io/<owner>/<repository>-matterix:<tag>
ghcr.io/<owner>/<repository>-labutopia:<tag>
```

GitHub の Actions タブから `Build and publish GPU images` を手動実行するか、`main` へ対象ファイルを push してください。workflow は `GITHUB_TOKEN` の `packages:write` を使うため、追加の registry token は不要です。Vast.ai から認証なしで pull するなら、publish 後に各 package を public にします。private のまま使う場合は、Vast.ai の registry credentials に GHCR の read token を登録してください。

Isaac Sim image は大きいため、GitHub-hosted runner の空き容量が足りない場合があります。workflow は不要な SDK を削除しますが、それでも不足する場合は 100 GB 以上の disk を持つ self-hosted runner に `runs-on` を変更してください。

## Vast.ai では SSH テンプレートを使う

1. [matterix-template.json](vastai/matterix-template.json) または [labutopia-template.json](vastai/labutopia-template.json) を開く。
2. `OWNER/REPOSITORY` を GHCR の実パスへ置き換える。
3. Vast.ai の Templates 画面で同じ値を設定する。通常運用は `SSH` launch mode と direct SSH を選ぶ。
4. RTX 3090 なら GPU RAM 24 GB、disk 80 GB 以上、十分な system RAM を持つ offer を選ぶ。
5. 起動後、Vast.ai に表示された SSH コマンドで接続する。

Vast.ai の SSH/Jupyter mode は image の `ENTRYPOINT` を置き換えます。そのため template の On-start script は次のまま残してください。

```bash
env | grep _ >> /etc/environment; /usr/local/bin/vast-init
```

永続 volume を付ける場合は `/workspace` へ mount します。プロジェクト本体は `/opt/matterix` または `/opt/labutopia` にあるため、volume で隠れません。出力は `/workspace/output`、user files は `/workspace/user`、cache は `/workspace/cache`、log は `/workspace/logs` に置きます。Isaac Sim の config、data、package cache も `/workspace/config`、`/workspace/data`、`/workspace/pkg` へ接続されます。

### Vast.ai CLI で作る例

```bash
vastai create instance <OFFER_ID> \
  --image ghcr.io/<owner>/<repository>-matterix:latest \
  --disk 80 \
  --ssh --direct \
  --env '-e ACCEPT_EULA=Y -e PRIVACY_CONSENT=Y -e OMNI_KIT_ALLOW_ROOT=1' \
  --onstart-cmd 'env | grep _ >> /etc/environment; /usr/local/bin/vast-init'
```

LabUtopia は image 名の末尾を `-labutopia:latest` に変えます。

## GPU を確認する

Vast.ai へ SSH したら、まず次を実行します。

```bash
verify-gpu
```

この command は `nvidia-smi` と NVENC の `libnvidia-encode` を確認します。NVENC がなくても headless simulation は動く場合がありますが、WebRTC は動きません。Python からも確認できます。

```bash
isaac-python -c 'import torch; print(torch.__version__); print(torch.cuda.get_device_name(0))'
```

## Isaac Sim headless と USD 保存を先に確認する

GUI を使わず、最小 stage を `/workspace/output` へ保存します。これは project task より小さく、GPU・Kit・USD 書き込み経路を切り分ける smoke test です。

```bash
isaac-usd-smoke
test -s /workspace/output/isaac-headless-smoke.usda
```

Isaac Sim の full app を画面なしで起動する場合:

```bash
isaacsim-headless
```

これは app を起動し続けます。終了は `Ctrl+C` です。batch job では `isaac-python your_script.py` を使い、生成物を `/workspace/output` 以下へ保存してください。

## Matterix が task を列挙できれば import と登録は通っている

最初の確認:

```bash
cd /opt/matterix
isaac-python scripts/list_envs.py
```

Matterix environment を headless で動かす例:

```bash
cd /opt/matterix
isaac-python scripts/zero_agent.py \
  --task Matterix-Test-Beakers-Franka-v1 \
  --num_envs 1 \
  --headless
```

workflow の確認:

```bash
cd /opt/matterix
isaac-python scripts/list_workflows.py \
  --task Matterix-Test-Beaker-Lift-Franka-v1

isaac-python scripts/run_workflow.py \
  --task Matterix-Test-Beaker-Lift-Franka-v1 \
  --workflow pickup_beaker \
  --num_envs 1 \
  --headless
```

動画も生成する場合は `--record_video --enable_cameras --video_dir /workspace/output/videos` を追加します。Matterix の zero agent と workflow runner は継続実行するため、確認後は `Ctrl+C` で止めます。

## LabUtopia は 1 episode と USD 保存で確認する

設定ファイルだけを確認する軽量 test:

```bash
cd /opt/labutopia
isaac-python -m pytest tests/test_config_files.py -q
```

実際の Isaac Sim、assets、controller、データ出力まで通す確認:

```bash
labutopia-run \
  --config-name level1_pick \
  --headless \
  --no-video \
  --max-episodes 1 \
  --save-usd /workspace/output/labutopia-level1-pick.usda
```

通常のデータ収集は episode 制限を外します。

```bash
labutopia-run --config-name level1_pick --headless --no-video
```

LabUtopia は Hydra の `outputs/` を project directory に作るため、長期保存したい結果は実行後に `/workspace/output` へ移してください。設定の `multi_run.run_dir` 自体を `/workspace/output/...` に変更すれば、最初から永続 volume へ書き込めます。

## Identity Port を使う WebRTC は実験扱い

Vast.ai は 70000 番台の予約 port request を Identity Port として扱い、割り当てた外部 port と内部 port を一致させます。この構成では request 用に TCP 70000 と UDP 70001 を指定し、起動時に `VAST_TCP_PORT_70000` と `VAST_UDP_PORT_70001` から実際の port を読み取ります。

[webrtc-identity-template.json](vastai/webrtc-identity-template.json) を使うか、通常 template に次を加えます。この template は Matterix / Isaac Sim 6.0.1 専用です。

Docker options:

```text
-p 70000:70000 -p 70001:70001/udp
```

On-start script:

```bash
env | grep _ >> /etc/environment
/usr/local/bin/vast-init
nohup /usr/local/bin/isaacsim-webrtc >/workspace/logs/webrtc.log 2>&1 &
```

起動後に確認します。

```bash
env | grep -E '^VAST_(TCP|UDP)_PORT_'
tail -f /workspace/logs/webrtc.log
```

`Isaac Sim Full Streaming App is loaded.` が出たら、Vast.ai の IP Port Info で public IP を確認し、Isaac Sim WebRTC Streaming Client に接続します。client が custom signaling port を受け付ける版なら、log に表示された `PUBLIC_IP:SIGNAL_PORT` を指定します。自動検出した IP が違う場合は `ISAACSIM_PUBLIC_IP=<public-ip>` を template の環境変数へ追加してください。

ただし、この経路の成立は保証できません。[NVIDIA の現行手順](https://docs.isaacsim.omniverse.nvidia.com/latest/installation/manual_livestream_clients.html) は container streaming に `--network=host` を必須とし、Docker bridge の `-p` mapping は動かないと明記しています。一方、[Vast.ai の template Docker options](https://docs.vast.ai/guides/instances/connect/networking) が受け付けるのは environment、hostname、port であり、通常 Docker instance に host network を要求できません。Identity Port は port 番号の不一致を解消しますが、network namespace と ICE/NAT の制約までは解消しません。

LabUtopia の Isaac Sim 5.1 は旧 streaming 設定を使い、media UDP port が 47998 固定です。Vast.ai の Identity Port へ変更できないため、LabUtopia image では Identity Port WebRTC を対象外とし、headless 運用を正式経路にします。

WebRTC endpoint には認証も暗号化もありません。public Internet へ無制限に公開せず、利用者 IP を制限できる host だけを選んでください。接続できない場合は調査を打ち切り、`isaac-usd-smoke`、Matterix/LabUtopia の `--headless`、動画・dataset・USD 保存を正式な fallback とします。

## known limitations

- Matterix の upstream は Isaac Lab 3.0 beta を採用しており、破壊的変更や一時的な regression があり得ます。Dockerfile は検証した commit に固定しています。
- Matterix upstream 内には 4.5.0 / 5.0.0 / 6.0.1 に相当する記述が混在します。本構成は現行 pip dependency が固定する 6.0.1 を採用しています。
- LabUtopia の headless flag は upstream のままでは機能しないため build 時に patch します。`LABUTOPIA_REF` を変えたとき patch が適用できなければ、upstream の修正有無を確認してください。
- LabUtopia assets は CC BY-NC 4.0 です。商用利用向け image ではありません。
- Isaac Sim 5.1 同梱の NVIDIA SRL packages は外部 `usd-core` を依存 metadata に持ちますが、Kit は内蔵 USD/pxr を使います。PyPI の `usd-core` は ABI を競合させる可能性があるため追加しておらず、`pip check` にはこの2件だけが残ります。
- RTX 3090 の 24 GB VRAM は最小規模の確認には向きますが、高解像度 camera、多数 environment、複雑な fluid/powder scene では不足する場合があります。
- 初回起動は shader cache 生成で数分以上かかることがあります。`/workspace/cache` を永続化すると再起動後の待ち時間を減らせます。
- Vast.ai host ごとに driver、system RAM、disk I/O、公開 UDP の品質が違います。安価な offer ほど個体差を見込んでください。
- Git LFS assets を image に含めるため image は大きくなります。Vast.ai で 80 GB 以上の disk を確保してください。
- WebRTC は通常 Docker/NAT では非対応です。Identity Port template は可能性を確認するための実験で、headless 運用が標準です。

## 用語

- **headless**: local window を開かずに simulation/rendering を実行する方式。
- **Identity Port**: Vast.ai が割り当てる外部 port と container 内部 port を同じ番号にする仕組み。
- **GHCR**: GitHub Container Registry。GitHub Actions が完成 image を保存する場所。
- **USD**: Universal Scene Description。scene、asset、simulation state を表すファイル形式。
- **NVENC**: NVIDIA GPU の hardware video encoder。WebRTC streaming に必要。

不具合を報告するときは、使用 image tag、upstream commit、`nvidia-smi`、`verify-gpu`、該当する `/workspace/logs` の末尾を添えてください。
