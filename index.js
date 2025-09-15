// デバッグログを有効化（node-record-lpcm16の内部ログ）
process.env.DEBUG = process.env.DEBUG || 'record';
const fs = require('fs');
const path = require('path');
const { spawnSync, spawn } = require('child_process');
const recorder = require('node-record-lpcm16');
const player = require('play-sound')();

class AudioApp {
    constructor() {
        this.recordingsDir = './recordings';
        this.favoritesDir = path.join(this.recordingsDir, 'favorites');
        this.ensureRecordingsDir();
        this.ensureFavoritesDir();
    }

    // recordingsディレクトリが存在しない場合は作成
    ensureRecordingsDir() {
        if (!fs.existsSync(this.recordingsDir)) {
            fs.mkdirSync(this.recordingsDir);
            console.log(`📁 ${this.recordingsDir} ディレクトリを作成しました`);
        }
    }

    // お気に入りディレクトリが存在しない場合は作成
    ensureFavoritesDir() {
        if (!fs.existsSync(this.favoritesDir)) {
            fs.mkdirSync(this.favoritesDir, { recursive: true });
            console.log(`📁 ${this.favoritesDir} ディレクトリを作成しました`);
        }
    }

    // 利用可能な録音コマンドを検出
    getAvailableRecorderProgram() {
        const candidates = process.platform === 'win32'
            ? ['sox']
            : (process.platform === 'darwin' ? ['rec', 'sox'] : ['arecord', 'sox', 'rec']);
        for (const cmd of candidates) {
            const res = spawnSync(cmd, ['--version'], { stdio: 'ignore' });
            if (!res.error) return cmd;
        }
        return null;
    }

    // 録音機能
    async recordAudio(filename, duration = 5000) {
        return new Promise((resolve) => {
            const program = this.getAvailableRecorderProgram();
            if (!program) {
                console.log('❌ 録音に必要なコマンドが見つかりませんでした。');
                if (process.platform === 'win32') {
                    console.log('Windows では SoX のインストールが必要です:');
                    console.log('  choco install sox   または   scoop install sox');
                    console.log('インストール後にターミナルを再起動して再度お試しください。');
                } else {
                    console.log('sox または arecord をインストールしてください。例: sudo apt install sox / sudo apt install alsa-utils');
                }
                return resolve();
            }

            const filepath = path.join(this.recordingsDir, filename);

            // Windows では SoX を直接呼び出してファイルに書き込む方が安定
            if (process.platform === 'win32' && program === 'sox') {
                console.log(`🎤 録音を開始します... (${duration/1000}秒間)`);
                console.log('録音中... (Ctrl+C で停止)');

                const durationSec = (duration / 1000).toString();
                // Windows/SoX: waveaudio ドライバを明示。出力はPCM16 WAV。
                const args = ['-V1', '-t', 'waveaudio', 'default', '-r', '44100', '-c', '1', '-b', '16', '-e', 'signed-integer', filepath, 'trim', '0', durationSec];
                const cp = spawn('sox', args, { stdio: ['ignore', 'ignore', 'pipe'] });

                let soxErr = '';

                cp.stderr.on('data', (chunk) => { soxErr += chunk.toString(); });

                const cleanup = () => {
                    try { cp.kill(); } catch {}
                };

                const onExit = (code) => {
                    cleanup();
                    if (code === 0) {
                        try {
                            const st = fs.statSync(filepath);
                            if (st.size > 100) {
                                console.log(` 録音完了: ${filepath}`);
                                return resolve(filepath);
                            }
                        } catch {}
                        try { fs.unlinkSync(filepath); } catch {}
                        console.error(' 録音エラー: 出力が空です');
                        return resolve();
                    }
                    try { fs.unlinkSync(filepath); } catch {}
                    console.error(' 録音エラー(sox):', soxErr.trim() || `exit code ${code}`);
                    console.log('ヒント: 設定 > プライバシーとセキュリティ > マイク でアプリのマイクアクセスを許可してください。既定の入力デバイスが有効かも確認してください。');
                    resolve();
                };

                cp.on('close', onExit);
                cp.on('error', (err) => {
                    console.error('❌ sox起動エラー:', err.message);
                    resolve();
                });

                const sigintHandler = () => {
                    process.removeListener('SIGINT', sigintHandler);
                    try { cp.kill(); } catch {}
                };
                process.on('SIGINT', sigintHandler);
                return;
            }

            // それ以外の環境は node-record-lpcm16 を使用
            const file = fs.createWriteStream(filepath);
            console.log(`🎤 録音を開始します... (${duration/1000}秒間)`);
            console.log('録音中... (Ctrl+C で停止)');

            const recordOptions = {
                sampleRate: 44100,
                channels: 1,
                threshold: 0,
                verbose: false,
                audioType: 'wav',
                recorder: program,
            };

            let finished = false;
            let timeoutId;
            const finish = (ok) => {
                if (finished) return;
                finished = true;
                try { clearTimeout(timeoutId); } catch {}
                try { recorder.stop(); } catch {}
                try { file.end(); } catch {}
                if (ok) {
                    file.once('close', () => {
                        console.log(`✅ 録音完了: ${filepath}`);
                        resolve(filepath);
                    });
                } else {
                    try { fs.unlinkSync(filepath); } catch {}
                    resolve();
                }
            };

            const recording = recorder.record(recordOptions);
            const stream = recording.stream();
            stream.on('error', (err) => {
                const message = (err && err.message) ? err.message : String(err);
                console.error('❌ 録音エラー:', message);
                finish(false);
            });
            stream.pipe(file);
            timeoutId = setTimeout(() => finish(true), duration);
            const sigintHandler = () => {
                process.removeListener('SIGINT', sigintHandler);
                finish(true);
            };
            process.on('SIGINT', sigintHandler);
        });
    }

    // 音声再生機能
    async playAudio(filepath) {
        return new Promise((resolve, reject) => {
            if (!fs.existsSync(filepath)) {
                reject(new Error(`ファイルが見つかりません: ${filepath}`));
                return;
            }

            console.log(`🔊 再生開始: ${filepath}`);
            
            player.play(filepath, (err) => {
                if (err) {
                    console.error('❌ 再生エラー:', err.message);
                    reject(err);
                } else {
                    console.log('✅ 再生完了');
                    resolve();
                }
            });
        });
    }

    // 保存された録音ファイル一覧を表示
    listRecordings() {
        const files = fs.readdirSync(this.recordingsDir)
            .filter(file => file.endsWith('.wav'))
            .sort((a, b) => {
                const statA = fs.statSync(path.join(this.recordingsDir, a));
                const statB = fs.statSync(path.join(this.recordingsDir, b));
                return statB.mtime - statA.mtime; // 新しい順
            });

        if (files.length === 0) {
            console.log('📝 保存された録音ファイルはありません');
            return [];
        }

        console.log('📝 保存された録音ファイル:');
        files.forEach((file, index) => {
            const filepath = path.join(this.recordingsDir, file);
            const stats = fs.statSync(filepath);
            const sizeKB = Math.round(stats.size / 1024);
            const date = stats.mtime.toLocaleString('ja-JP');
            console.log(`  ${index + 1}. ${file} (${sizeKB}KB, ${date})`);
        });

        return files;
    }

    // 録音をお気に入りに移動
    async moveRecordingToFavorites() {
        const files = this.listRecordings();
        if (files.length === 0) return;

        const fileIndex = await this.getUserInput('お気に入りに移動するファイルの番号を入力してください: ');
        const index = parseInt(fileIndex) - 1;

        if (!(index >= 0 && index < files.length)) {
            console.log('❌ 無効な番号です');
            return;
        }

        try {
            this.ensureFavoritesDir();
            const selected = files[index];
            const srcPath = path.join(this.recordingsDir, selected);
            const parsed = path.parse(selected);
            let destPath = path.join(this.favoritesDir, selected);

            if (fs.existsSync(destPath)) {
                const candidate = path.join(this.favoritesDir, `${parsed.name}_favorite${parsed.ext}`);
                if (!fs.existsSync(candidate)) {
                    destPath = candidate;
                } else {
                    destPath = path.join(this.favoritesDir, `${parsed.name}_favorite_${Date.now()}${parsed.ext}`);
                }
            }

            fs.renameSync(srcPath, destPath);
            console.log(`⭐ お気に入りに移動しました: ${path.basename(destPath)}`);
        } catch (error) {
            console.error('❌ お気に入りへの移動に失敗しました:', error.message);
        }
    }

    // メインメニュー
    async showMenu() {
        console.log('\n🎵 音声録音・再生アプリ');
        console.log('========================');
        console.log('1. 録音する (5秒)');
        console.log('2. 録音する (カスタム時間)');
        console.log('3. 録音ファイル一覧');
        console.log('4. 録音を再生');
        console.log('5. お気に入りに移動');
        console.log('6. 終了');
        console.log('========================');
    }

    // ユーザー入力待ち
    async getUserInput(question) {
        const readline = require('readline');
        const rl = readline.createInterface({
            input: process.stdin,
            output: process.stdout
        });

        return new Promise((resolve) => {
            rl.question(question, (answer) => {
                rl.close();
                resolve(answer.trim());
            });
        });
    }

    // アプリケーション実行
    async run() {
        console.log('🎵 音声録音・再生アプリを開始します');
        
        while (true) {
            await this.showMenu();
            const choice = await this.getUserInput('選択してください (1-6): ');

            switch (choice) {
                case '1':
                    const filename1 = `recording_${Date.now()}.wav`;
                    await this.recordAudio(filename1, 5000);
                    break;

                case '2':
                    const duration = await this.getUserInput('録音時間を秒で入力してください: ');
                    const durationMs = parseInt(duration) * 1000;
                    if (isNaN(durationMs) || durationMs <= 0) {
                        console.log('❌ 無効な時間です');
                        break;
                    }
                    const filename2 = `recording_${Date.now()}.wav`;
                    await this.recordAudio(filename2, durationMs);
                    break;

                case '3':
                    this.listRecordings();
                    break;

                case '4':
                    const files = this.listRecordings();
                    if (files.length === 0) break;
                    
                    const fileIndex = await this.getUserInput('再生するファイルの番号を入力してください: ');
                    const index = parseInt(fileIndex) - 1;
                    
                    if (index >= 0 && index < files.length) {
                        const filepath = path.join(this.recordingsDir, files[index]);
                        try {
                            await this.playAudio(filepath);
                        } catch (error) {
                            console.log('❌ 再生に失敗しました:', error.message);
                        }
                    } else {
                        console.log('❌ 無効な番号です');
                    }
                    break;

                case '5':
                    await this.moveRecordingToFavorites();
                    break;

                case '6':
                    console.log('👋 アプリケーションを終了します');
                    process.exit(0);

                default:
                    console.log('❌ 無効な選択です');
            }

            console.log('\nEnterキーを押して続行...');
            await this.getUserInput('');
        }
    }
}

// アプリケーション実行
if (require.main === module) {
    const app = new AudioApp();
    app.run().catch(console.error);
}

module.exports = AudioApp;
